use std::time::Instant;
use aura_lnn::api::{build_memory_prefix, build_recall_prefill};
use aura_lnn::llama_engine::LlamaEngine;
use aura_lnn::memory::store::MemoryStore;
use aura_lnn::memory::plan_reply;
use aura_lnn::api::worker_utils::process_memory;

use super::types::TestResult;

const MODEL_PATH: &str = "../../aura_notebook/assets/LFM2.5-1.2B-Instruct-Q4_K_M.gguf";

pub fn run_llm_tests() -> Vec<TestResult> {
    let mut r = Vec::new();
    let mut id = 101;

    println!("  Loading LFM2.5-1.2B model...");
    let embedder = LlamaEngine::load_sibling_embedder(MODEL_PATH).expect("Embedder not found");
    let mut engine = LlamaEngine::new(MODEL_PATH, aura_lnn::device_backend::DeviceBackend::Cpu, 2048, 2, embedder).expect("Failed to init LLM");
    println!("  Model loaded.\n");

    // Response length — 12 cases
    let lc = [
        ("greeting","hi",5,60),("greeting","hey",5,60),
        ("ack","my name is Alice",5,80),
        ("factual","what is 2+2?",3,200),
        ("factual","what's my name?",3,200),
        ("open","explain how the sun works",15,500),
        ("emotional","I'm feeling sad today",5,200),
        ("identity","what do I like?",3,200),
        ("task","write a hello world in python",10,500),
        ("casual","tell me a joke",5,200),
        ("long","I'm really struggling with my mental health lately and I don't know what to do",15,500),
        ("reflect","I've been thinking a lot about my future and whether I should change careers",10,400),
    ];
    for (cat,prompt,min_w,max_w) in lc {
        let s=Instant::now();
        let plan=plan_reply(prompt,false);
        let mt=engine.performance_profile().clamp_reply_tokens(plan.max_tokens);
        engine.reset_state();let _=engine.warmup();
        let mut resp=String::new();
        let _=engine.generate_with_context(prompt,vec![],mt,|t|resp.push_str(&t));
        let wc=resp.split_whitespace().count();
        let too_short=wc<min_w;
        let too_long=wc>max_w*3;
        let p=!too_short&&!too_long&&!resp.is_empty();
        r.push(TestResult{id,suite:"llm".into(),category:"length".into(),difficulty:cat.into(),passed:p,description:format!("Length: '{}' (cat={})",prompt,plan.category),detail:format!("words={} max_tok={} resp='{}'",wc,mt,&resp[..resp.len().min(100)]),duration_ms:s.elapsed().as_millis() as u64});
        id+=1;
    }

    // Multi-turn sessions — 8 cases
    let sessions: Vec<Vec<(&str,&str)>> = vec![
        vec![("user","my name is Alice"),("assistant",""),("user","I love ramen"),("assistant",""),("user","what is my name?")],
        vec![("user","I live in Tokyo and I study UX design"),("assistant",""),("user","I have a cat named Pixel"),("assistant",""),("user","what do you know about me?")],
        vec![("user","I'm feeling really overwhelmed with exams"),("assistant",""),("user","my birthday is March 15"),("assistant",""),("user","do you remember how I'm feeling?")],
        vec![("user","my name is Bob"),("assistant",""),("user","actually my name is Robert"),("assistant",""),("user","what is my name?")],
        vec![("user","I like hiking"),("assistant",""),("user","I also enjoy painting"),("assistant",""),("user","my favorite color is blue"),("assistant",""),("user","I have a dog named Rocky"),("assistant",""),("user","I work as a software engineer"),("assistant",""),("user","tell me everything you know about me")],
        vec![("user","my name is Charlie and I'm 25"),("assistant",""),("user","I live in Paris"),("assistant",""),("user","I love jazz music"),("assistant",""),("user","what is my name and where do I live?")],
        vec![("user","I hate mornings"),("assistant",""),("user","I'm allergic to peanuts"),("assistant",""),("user","I'm vegan"),("assistant",""),("user","what foods should I avoid?")],
        vec![("user","my mom's name is Sakura"),("assistant",""),("user","my dad's name is David"),("assistant",""),("user","I have a brother named Ren"),("assistant",""),("user","who are my family members?")],
    ];

    for (si,session) in sessions.iter().enumerate() {
        let s=Instant::now();
        let store=mk_store(&format!("mt_{}",si));
        let mut responses=Vec::new();
        let mut last_user=String::new();

        for (speaker,content) in session {
            if *speaker=="user" {
                last_user=content.to_string();
                store.insert_turn("user",content).unwrap();

                // Gather memories like production (with the fix: facts + turns + semantic)
                let mut memories=Vec::new();
                let mut seen: std::collections::HashSet<String>=std::collections::HashSet::new();
                if let Ok(facts)=store.get_facts_strings(10){for f in facts{let k=f.to_lowercase();if seen.insert(k){memories.push(f);}}}
                if let Ok(recent)=store.recent_turn_strings_filtered(4){for t in recent{let k=t.to_lowercase();if seen.insert(k){memories.push(t);}}}
                if let Ok(qemb)=engine.embed_query(content){
                    if let Ok(sem)=store.search_relevant_hybrid(content,&qemb,8){
                        for m in sem{let k=m.to_lowercase();if seen.insert(k){memories.push(m);}}}}

                let prefix=build_memory_prefix(&memories);
                let prefill=build_recall_prefill(content,&memories);
                let prompt=if let Some(p)=prefix{format!("{}{}",p,content)}else{content.to_string()};
                let prompt=if let Some(ref pf)=prefill{format!("{}\n{}",prompt,pf)}else{prompt};

                let plan=plan_reply(content,false);
                let mt=engine.performance_profile().clamp_reply_tokens(plan.max_tokens);
                engine.reset_state();let _=engine.warmup();
                let mut resp=String::new();
                let _=engine.generate_with_context(&prompt,vec![],mt,|t|resp.push_str(&t));
                responses.push(resp.clone());
                store.insert_turn("assistant",&resp).unwrap();
                let nf=process_memory(&store,content,&resp);
                for f in &nf{if let Some(e)=engine.embedder(){if let Ok(emb)=e.embed_passage(f){let _=store.insert_vec_memory(f,&emb);}}}
                if nf.is_empty(){if let Some(e)=engine.embedder(){if let Ok(emb)=e.embed_passage(&format!("User: {}",content)){let _=store.insert_vec_memory(&format!("User: {}",content),&emb);}}}
            }
        }

        let lr=responses.last().unwrap_or(&"".to_string()).to_lowercase();
        let (p,detail)=match si{
            0=>{let a=lr.contains("alice");(a,format!("alice={} '{}'",a,&lr[..lr.len().min(80)]))}
            1=>{let t=lr.contains("tokyo")||lr.contains("ux")||lr.contains("pixel");let c=[("tokyo",lr.contains("tokyo")),("ux",lr.contains("ux")||lr.contains("design")),("pixel",lr.contains("pixel"))].iter().filter(|x|x.1).count();(t,format!("{}/3 facts '{}'",c,&lr[..lr.len().min(80)]))}
            2=>{let e=lr.contains("overwhelm")||lr.contains("exam");(e,format!("emotion={} '{}'",e,&lr[..lr.len().min(80)]))}
            3=>{let r2=lr.contains("robert");let b=lr.contains("bob")&&!r2;(r2&&!b,format!("robert={} bob={} '{}'",r2,b,&lr[..lr.len().min(80)]))}
            4=>{let kws=["hiking","paint","blue","rocky","engineer"];let c=kws.iter().filter(|k|lr.contains(*k)).count();(c>=2,format!("{}/5 facts '{}'",c,&lr[..lr.len().min(100)]))}
            5=>{let n=lr.contains("charlie");let p2=lr.contains("paris");(n&&p2,format!("charlie={} paris={} '{}'",n,p2,&lr[..lr.len().min(80)]))}
            6=>{let pn=lr.contains("peanut")||lr.contains("allerg");let vg=lr.contains("vegan")||lr.contains("plant");(pn||vg,format!("peanuts={} vegan={} '{}'",pn,vg,&lr[..lr.len().min(80)]))}
            7=>{let s2=lr.contains("sakura");let d=lr.contains("david");let rn=lr.contains("ren");let c=[s2,d,rn].iter().filter(|&&x|x).count();(c>=2,format!("{}/3 family '{}'",c,&lr[..lr.len().min(80)]))}
            _=>(false,"unknown".into()),
        };

        let diff=if session.len()>6{"extreme".to_string()}else{"medium".to_string()};
        r.push(TestResult{id,suite:"llm".into(),category:"multi_turn".into(),difficulty:diff,passed:p,description:format!("Session {}: {} turns, '{}'",si+1,session.len(),last_user),detail,duration_ms:s.elapsed().as_millis() as u64});
        id+=1;
        rm_store(&format!("mt_{}",si));
    }

    // Pre-fill verification — 5 cases
    let pf_cases=[
        ("what is my name?","User's name is Alice","Alice"),
        ("what's my name?","User's name is Bob","Bob"),
        ("do you know my name?","User's name is Charlie","Charlie"),
        ("who am I?","User's name is Diana","Diana"),
        ("tell me a joke","User's name is Eve",""), // Should NOT pre-fill for non-name query
    ];
    for (query,fact,expected_name) in pf_cases {
        let s=Instant::now();
        let memories=vec![fact.to_string()];
        let pf=build_recall_prefill(query,&memories);
        let pf_str=pf.clone();
        let p=if expected_name.is_empty(){pf.is_none()}else{pf.map(|p|p.contains(expected_name)).unwrap_or(false)};
        r.push(TestResult{id,suite:"llm".into(),category:"prefill".into(),difficulty:"simple".into(),passed:p,description:format!("Pre-fill: '{}'",query).into(),detail:format!("pf={:?}",pf_str),duration_ms:s.elapsed().as_millis() as u64});
        id+=1;
    }

    r
}

fn mk_store(p:&str)->MemoryStore{let db=format!("temp_llm_{}_{}.db",p,std::process::id());let _=std::fs::remove_file(&db);let _=std::fs::remove_file(format!("{}-wal",db));let _=std::fs::remove_file(format!("{}-shm",db));MemoryStore::open(&db).unwrap()}
fn rm_store(p:&str){let db=format!("temp_llm_{}_{}.db",p,std::process::id());let _=std::fs::remove_file(&db);let _=std::fs::remove_file(format!("{}-wal",db));let _=std::fs::remove_file(format!("{}-shm",db));}
