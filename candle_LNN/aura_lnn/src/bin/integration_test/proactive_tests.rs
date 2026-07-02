use std::time::Instant;
use std::collections::HashSet;
use aura_lnn::memory::store::MemoryStore;

use super::types::{TestResult, schedule_detect};

pub fn run_proactive_tests() -> Vec<TestResult> {
    let mut r = Vec::new();
    let mut id = 51;

    // Schedule extraction — 18 cases
    let se = [
        ("simple","remind me to call mom",true),("simple","remind me to take my medicine",true),
        ("simple","wake me up at 7am",true),("simple","set a reminder for my meeting",true),
        ("medium","remind me to call the dentist tomorrow afternoon",true),
        ("medium","don't let me forget to pick up groceries after work",true),
        ("medium","schedule a meeting with my professor next week",true),
        ("medium","wake me up before my flight at 6am",true),
        ("extreme","remind me to wish my mom happy birthday on March 15th and buy flowers",true),
        ("extreme","hi",false),("extreme","REMIND ME TO SUBMIT THE REPORT",true),
        ("edge","can you remind me to study",true),("edge","pls remind me",true),
        ("edge","remind",false),("edge","dont let me forget to feed the cat",true),
        ("edge","what's the weather",false),("edge","tell me a joke",false),
        ("edge","set a reminder",true),
    ];
    for (d,q,e) in se { let s=Instant::now(); let det=schedule_detect(q); let p=det==e; r.push(TestResult{id,suite:"proactive".into(),category:"schedule".into(),difficulty:d.into(),passed:p,description:format!("Sched: '{}'",q),detail:format!("det={} exp={}",det,e),duration_ms:s.elapsed().as_millis() as u64}); id+=1; }

    // Bandit — 12 cases
    r.push(bt_empty(id,&mut id));
    r.push(bt_prefers_high(id,&mut id));
    r.push(bt_single_always(id,&mut id));
    r.push(bt_mark_fired(id,&mut id));
    r.push(bt_engagement_up(id,&mut id));
    r.push(bt_engagement_ignored(id,&mut id));
    r.push(bt_n_engaged(id,&mut id));
    r.push(bt_log_types(id,&mut id));
    r.push(bt_cooldown_blocks(id,&mut id));
    r.push(bt_multi_fire(id,&mut id));
    r.push(bt_score_floor(id,&mut id));
    r.push(bt_repeated_selection(id,&mut id));

    // Spam prevention — 8 cases
    r.push(sp_no_refire(id,&mut id));
    r.push(sp_normal_chat(id,&mut id));
    r.push(sp_short_reject(id,&mut id));
    r.push(sp_long_reject(id,&mut id));
    r.push(sp_double_remind(id,&mut id));
    r.push(sp_schedule_case_sensitive(id,&mut id));
    r.push(sp_remind_myself_reject(id,&mut id));
    r.push(sp_empty_msg(id,&mut id));

    // Context retrieval — 7 cases
    r.push(ctx_empty(id,&mut id));
    r.push(ctx_facts(id,&mut id));
    r.push(ctx_turns(id,&mut id));
    r.push(ctx_vision(id,&mut id));
    r.push(ctx_summary(id,&mut id));
    r.push(ctx_prioritized(id,&mut id));
    r.push(ctx_char_limit(id,&mut id));

    // Trigger types — 5 cases
    for ty in ["bandit","clock","idle","debug"] { r.push(tt_test(id,ty,&mut id)); }
    r.push(tt_mixed(id,&mut id));

    r
}

fn mk_store(p:&str)->MemoryStore{let db=format!("temp_pro_{}_{}.db",p,std::process::id());let _=std::fs::remove_file(&db);let _=std::fs::remove_file(format!("{}-wal",db));let _=std::fs::remove_file(format!("{}-shm",db));MemoryStore::open(&db).unwrap()}
fn rm_store(p:&str){let db=format!("temp_pro_{}_{}.db",p,std::process::id());let _=std::fs::remove_file(&db);let _=std::fs::remove_file(format!("{}-wal",db));let _=std::fs::remove_file(format!("{}-shm",db));}
fn ins_trigger(s:&MemoryStore,id:i64,label:&str,score:f64){let c=s.acquire_conn().unwrap();c.execute("INSERT OR REPLACE INTO triggers (trigger_id,label,engagement_score,n_shown,n_engaged,total_reward,last_fired) VALUES (?,?,?,0,0,0.0,0)",rusqlite::params![id,label,score]).unwrap();}

fn bt_empty(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let st=mk_store("empty");let r=st.get_proactive_suggestion().unwrap();let p=r.is_none();rm_store("empty");*idr+=1;TestResult{id,suite:"proactive".into(),category:"bandit".into(),difficulty:"simple".into(),passed:p,description:"Empty DB returns None".into(),detail:format!("{:?}",r.map(|x|x.1)),duration_ms:s.elapsed().as_millis() as u64}}

fn bt_prefers_high(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let st=mk_store("pref");ins_trigger(&st,1,"low",0.05);ins_trigger(&st,2,"high",0.95);let mut h=0;let mut l=0;for _ in 0..100{if let Some((t,_))=st.get_proactive_suggestion().unwrap(){if t==2{h+=1;}if t==1{l+=1;}}}let p=h>l*2;rm_store("pref");*idr+=1;TestResult{id,suite:"proactive".into(),category:"bandit".into(),difficulty:"medium".into(),passed:p,description:"Prefers higher score".into(),detail:format!("high={} low={}",h,l),duration_ms:s.elapsed().as_millis() as u64}}

fn bt_single_always(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let st=mk_store("single");ins_trigger(&st,1,"only",0.5);let mut c=0;for _ in 0..10{if st.get_proactive_suggestion().unwrap().is_some(){c+=1;}}let p=c==10;rm_store("single");*idr+=1;TestResult{id,suite:"proactive".into(),category:"bandit".into(),difficulty:"simple".into(),passed:p,description:"Single trigger always returns".into(),detail:format!("{}/10",c),duration_ms:s.elapsed().as_millis() as u64}}

fn bt_mark_fired(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let st=mk_store("mark");ins_trigger(&st,1,"a",0.5);ins_trigger(&st,2,"b",0.5);let s1=st.get_proactive_suggestion().unwrap();let b=s1.is_some();let fid=s1.map(|x|x.0).unwrap_or(0);st.mark_trigger_fired(fid).unwrap();let s2=st.get_proactive_suggestion().unwrap();let a=s2.is_some()&&s2.map(|x|x.0).unwrap_or(0)!=fid;let p=b&&a;rm_store("mark");*idr+=1;TestResult{id,suite:"proactive".into(),category:"bandit".into(),difficulty:"simple".into(),passed:p,description:"Mark fired blocks trigger".into(),detail:format!("before={} after_diff={}",b,a),duration_ms:s.elapsed().as_millis() as u64}}

fn bt_engagement_up(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let st=mk_store("eng_up");ins_trigger(&st,1,"t",0.0);st.record_engagement(1,true).unwrap();let c=st.acquire_conn().unwrap();let sc:f64=c.query_row("SELECT engagement_score FROM triggers WHERE trigger_id=1",[],|r|r.get(0)).unwrap();let p=sc>0.0;rm_store("eng_up");*idr+=1;TestResult{id,suite:"proactive".into(),category:"bandit".into(),difficulty:"simple".into(),passed:p,description:"Engagement increases score".into(),detail:format!("score={:.3}",sc),duration_ms:s.elapsed().as_millis() as u64}}

fn bt_engagement_ignored(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let st=mk_store("eng_ign");ins_trigger(&st,1,"t",0.5);st.record_engagement(1,false).unwrap();let c=st.acquire_conn().unwrap();let sc:f64=c.query_row("SELECT engagement_score FROM triggers WHERE trigger_id=1",[],|r|r.get(0)).unwrap();let p=sc<0.1;rm_store("eng_ign");*idr+=1;TestResult{id,suite:"proactive".into(),category:"bandit".into(),difficulty:"simple".into(),passed:p,description:"Ignored drops score".into(),detail:format!("score={:.4}",sc),duration_ms:s.elapsed().as_millis() as u64}}

fn bt_n_engaged(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let st=mk_store("n_eng");ins_trigger(&st,1,"t",0.0);st.record_engagement(1,true).unwrap();st.record_engagement(1,false).unwrap();st.record_engagement(1,true).unwrap();let c=st.acquire_conn().unwrap();let ns:i64=c.query_row("SELECT n_shown FROM triggers WHERE trigger_id=1",[],|r|r.get(0)).unwrap();let ne:i64=c.query_row("SELECT n_engaged FROM triggers WHERE trigger_id=1",[],|r|r.get(0)).unwrap();let p=ns==3&&ne==2;rm_store("n_eng");*idr+=1;TestResult{id,suite:"proactive".into(),category:"bandit".into(),difficulty:"medium".into(),passed:p,description:"n_engaged correct".into(),detail:format!("shown={} engaged={}",ns,ne),duration_ms:s.elapsed().as_millis() as u64}}

fn bt_log_types(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let st=mk_store("log");ins_trigger(&st,1,"t",0.5);st.log_proactive(1,"t","bandit",true).unwrap();st.log_proactive(1,"t","bandit",false).unwrap();st.log_proactive(1,"t","clock",true).unwrap();let l=st.recent_proactive_log(10).unwrap();let p=l.len()==3&&l[0].trigger_type=="clock";rm_store("log");*idr+=1;TestResult{id,suite:"proactive".into(),category:"bandit".into(),difficulty:"simple".into(),passed:p,description:"Log types correct".into(),detail:format!("{} logs",l.len()),duration_ms:s.elapsed().as_millis() as u64}}

fn bt_cooldown_blocks(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let st=mk_store("cd");ins_trigger(&st,1,"a",0.5);ins_trigger(&st,2,"b",0.5);st.mark_trigger_fired(1).unwrap();let mut a=0;for _ in 0..20{if let Some((t,_))=st.get_proactive_suggestion().unwrap(){if t==1{a+=1;}}}let p=a==0;rm_store("cd");*idr+=1;TestResult{id,suite:"proactive".into(),category:"bandit".into(),difficulty:"medium".into(),passed:p,description:"Cooldown blocks fired trigger".into(),detail:format!("fired_1_appeared={}",a),duration_ms:s.elapsed().as_millis() as u64}}

fn bt_multi_fire(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let st=mk_store("mf");for i in 1..=5{ins_trigger(&st,i,&format!("t{}",i),0.5);}st.mark_trigger_fired(1).unwrap();st.mark_trigger_fired(2).unwrap();st.mark_trigger_fired(3).unwrap();let mut av=Vec::new();for _ in 0..20{if let Some((t,_))=st.get_proactive_suggestion().unwrap(){if !av.contains(&t){av.push(t);}}}let p=av.iter().all(|t|*t==4||*t==5)&&!av.is_empty();rm_store("mf");*idr+=1;TestResult{id,suite:"proactive".into(),category:"bandit".into(),difficulty:"medium".into(),passed:p,description:"Multi-fire blocks correctly".into(),detail:format!("available={:?}",av),duration_ms:s.elapsed().as_millis() as u64}}

fn bt_score_floor(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let st=mk_store("sf");ins_trigger(&st,1,"zero",0.0);ins_trigger(&st,2,"also_zero",0.0);let mut got=0;for _ in 0..20{if st.get_proactive_suggestion().unwrap().is_some(){got+=1;}}let p=got>0;rm_store("sf");*idr+=1;TestResult{id,suite:"proactive".into(),category:"bandit".into(),difficulty:"hard".into(),passed:p,description:"Score floor prevents starvation".into(),detail:format!("got {}/20",got),duration_ms:s.elapsed().as_millis() as u64}}

fn bt_repeated_selection(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let st=mk_store("rs");for i in 1..=3{ins_trigger(&st,i,&format!("t{}",i),0.5);}let mut ids=HashSet::new();for _ in 0..30{if let Some((t,_))=st.get_proactive_suggestion().unwrap(){ids.insert(t);}}let p=ids.len()>=2;rm_store("rs");*idr+=1;TestResult{id,suite:"proactive".into(),category:"bandit".into(),difficulty:"medium".into(),passed:p,description:"Selection varies across triggers".into(),detail:format!("unique={}",ids.len()),duration_ms:s.elapsed().as_millis() as u64}}

fn sp_no_refire(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let st=mk_store("sp_nr");ins_trigger(&st,1,"nudge",0.5);st.mark_trigger_fired(1).unwrap();let r=st.get_proactive_suggestion().unwrap();let p=r.is_none();rm_store("sp_nr");*idr+=1;TestResult{id,suite:"proactive".into(),category:"spam".into(),difficulty:"simple".into(),passed:p,description:"No refire within cooldown".into(),detail:format!("{:?}",r.map(|x|x.1)),duration_ms:s.elapsed().as_millis() as u64}}

fn sp_normal_chat(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let msgs=["hi","how are you","what's 2+2","tell me a joke","I like pizza","good morning"];let mut ok=true;for m in &msgs{if schedule_detect(m){ok=false;}}*idr+=1;TestResult{id,suite:"proactive".into(),category:"spam".into(),difficulty:"medium".into(),passed:ok,description:"Normal chat not schedule".into(),detail:format!("{} msgs tested",msgs.len()),duration_ms:s.elapsed().as_millis() as u64}}

fn sp_short_reject(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let p=!schedule_detect("remind");*idr+=1;TestResult{id,suite:"proactive".into(),category:"spam".into(),difficulty:"edge".into(),passed:p,description:"Short input rejected".into(),detail:"'remind' is 6 chars".into(),duration_ms:s.elapsed().as_millis() as u64}}

fn sp_long_reject(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let lm=format!("remind me to {} please","do something ".repeat(30));let p=!schedule_detect(&lm);*idr+=1;TestResult{id,suite:"proactive".into(),category:"spam".into(),difficulty:"edge".into(),passed:p,description:"Long input rejected".into(),detail:format!("len={}",lm.len()),duration_ms:s.elapsed().as_millis() as u64}}

fn sp_double_remind(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let p=schedule_detect("remind me to remind me to call mom");*idr+=1;TestResult{id,suite:"proactive".into(),category:"spam".into(),difficulty:"edge".into(),passed:p,description:"Double remind detected".into(),detail:format!("det={}",p),duration_ms:s.elapsed().as_millis() as u64}}

fn sp_schedule_case_sensitive(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let p=schedule_detect("REMIND ME TO CALL MOM");*idr+=1;TestResult{id,suite:"proactive".into(),category:"spam".into(),difficulty:"edge".into(),passed:p,description:"Case insensitive detection".into(),detail:format!("det={}",p),duration_ms:s.elapsed().as_millis() as u64}}

fn sp_remind_myself_reject(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let p=!schedule_detect("I need to remind myself to call her");*idr+=1;TestResult{id,suite:"proactive".into(),category:"spam".into(),difficulty:"edge".into(),passed:p,description:"'remind myself' not detected".into(),detail:format!("det={}",!p),duration_ms:s.elapsed().as_millis() as u64}}

fn sp_empty_msg(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let p=!schedule_detect("");*idr+=1;TestResult{id,suite:"proactive".into(),category:"spam".into(),difficulty:"edge".into(),passed:p,description:"Empty msg rejected".into(),detail:format!("det={}",!p),duration_ms:s.elapsed().as_millis() as u64}}

fn ctx_empty(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let st=mk_store("ctx_e");let c=st.get_proactive_context().unwrap_or_default();let p=c.is_empty()||c.len()<20;rm_store("ctx_e");*idr+=1;TestResult{id,suite:"proactive".into(),category:"context".into(),difficulty:"simple".into(),passed:p,description:"Empty context".into(),detail:format!("len={}",c.len()),duration_ms:s.elapsed().as_millis() as u64}}

fn ctx_facts(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let st=mk_store("ctx_f");st.insert_fact("User's name is Alice").unwrap();st.insert_fact("User likes ramen").unwrap();let c=st.get_proactive_context().unwrap_or_default();let p=c.to_lowercase().contains("alice")&&c.to_lowercase().contains("ramen");rm_store("ctx_f");*idr+=1;TestResult{id,suite:"proactive".into(),category:"context".into(),difficulty:"simple".into(),passed:p,description:"Context has facts".into(),detail:format!("alice={} ramen={}",c.contains("Alice"),c.contains("ramen")),duration_ms:s.elapsed().as_millis() as u64}}

fn ctx_turns(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let st=mk_store("ctx_t");st.insert_turn("user","I'm feeling great today").unwrap();st.insert_turn("assistant","That's wonderful!").unwrap();let c=st.get_proactive_context().unwrap_or_default();let p=c.to_lowercase().contains("feeling great")||c.to_lowercase().contains("wonderful");rm_store("ctx_t");*idr+=1;TestResult{id,suite:"proactive".into(),category:"context".into(),difficulty:"medium".into(),passed:p,description:"Context has turns".into(),detail:format!("has_turn={}",p),duration_ms:s.elapsed().as_millis() as u64}}

fn ctx_vision(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let st=mk_store("ctx_v");st.insert_memory_note("Vision","vision: laptop and coffee visible on desk",false,false,None).unwrap();let c=st.get_proactive_context().unwrap_or_default();let p=c.to_lowercase().contains("vision:")||c.to_lowercase().contains("laptop");rm_store("ctx_v");*idr+=1;TestResult{id,suite:"proactive".into(),category:"context".into(),difficulty:"medium".into(),passed:p,description:"Context has vision".into(),detail:format!("has_vision={}",p),duration_ms:s.elapsed().as_millis() as u64}}

fn ctx_summary(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let st=mk_store("ctx_s");st.insert_turn("user","I love hiking in the mountains").unwrap();st.insert_turn("assistant","The mountains sound beautiful!").unwrap();st.replace_recent_conversation_summary(10).unwrap();let c=st.get_proactive_context().unwrap_or_default();let p=c.to_lowercase().contains("summary")||c.to_lowercase().contains("hiking");rm_store("ctx_s");*idr+=1;TestResult{id,suite:"proactive".into(),category:"context".into(),difficulty:"hard".into(),passed:p,description:"Context has summary".into(),detail:format!("has_sum={}",p),duration_ms:s.elapsed().as_millis() as u64}}

fn ctx_prioritized(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let st=mk_store("ctx_p");st.insert_fact("User's name is Bob").unwrap();st.insert_turn("user","just chatting about stuff").unwrap();let c=st.get_proactive_context().unwrap_or_default();let fp=c.to_lowercase().find("bob").unwrap_or(usize::MAX);let tp=c.to_lowercase().find("chatting").unwrap_or(usize::MAX);let p=fp<tp;rm_store("ctx_p");*idr+=1;TestResult{id,suite:"proactive".into(),category:"context".into(),difficulty:"hard".into(),passed:p,description:"Facts before turns".into(),detail:format!("fact={} turn={}",fp,tp),duration_ms:s.elapsed().as_millis() as u64}}

fn ctx_char_limit(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let st=mk_store("ctx_c");for i in 0..20{st.insert_fact(&format!("User likes thing {}",i)).unwrap();}let c=st.get_proactive_context().unwrap_or_default();let p=c.len()<2000;rm_store("ctx_c");*idr+=1;TestResult{id,suite:"proactive".into(),category:"context".into(),difficulty:"edge".into(),passed:p,description:"Char limit enforced".into(),detail:format!("len={}",c.len()),duration_ms:s.elapsed().as_millis() as u64}}

fn tt_test(id:usize,ty:&str,idr:&mut usize)->TestResult{let s=Instant::now();let st=mk_store(&format!("tt_{}",ty));ins_trigger(&st,1,"t",0.5);st.log_proactive(1,"t",ty,true).unwrap();let l=st.recent_proactive_log(1).unwrap();let p=!l.is_empty()&&l[0].trigger_type==ty&&l[0].engaged;rm_store(&format!("tt_{}",ty));*idr+=1;TestResult{id,suite:"proactive".into(),category:"trigger_type".into(),difficulty:"simple".into(),passed:p,description:format!("Type: {}",ty),detail:format!("got={}",l.first().map(|x|x.trigger_type.clone()).unwrap_or_default()),duration_ms:s.elapsed().as_millis() as u64}}

fn tt_mixed(id:usize,idr:&mut usize)->TestResult{let s=Instant::now();let st=mk_store("tt_mix");ins_trigger(&st,1,"bt",0.5);ins_trigger(&st,2,"ct",0.5);st.log_proactive(1,"bt","bandit",true).unwrap();st.log_proactive(2,"ct","clock",false).unwrap();let l=st.recent_proactive_log(10).unwrap();let b=l.iter().filter(|x|x.trigger_type=="bandit").count();let c=l.iter().filter(|x|x.trigger_type=="clock").count();let p=b==1&&c==1;rm_store("tt_mix");*idr+=1;TestResult{id,suite:"proactive".into(),category:"trigger_type".into(),difficulty:"medium".into(),passed:p,description:"Mixed types logged".into(),detail:format!("bandit={} clock={}",b,c),duration_ms:s.elapsed().as_millis() as u64}}
