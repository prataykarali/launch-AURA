#!/usr/bin/env python3
"""
SAM 3-HOUR LIVE TEST — Uses the AURA bar's DB, opens real browsers,
captures webcam + screen, tests memory/vision/proactive/multiturn.
The AURA bar on screen shows proactive popups and TTS responses.
"""
import cv2, numpy as np, onnxruntime as ort, subprocess, os, json, random, time, sqlite3, pytesseract, signal, sys
from pathlib import Path
from datetime import datetime, timedelta
from mss import mss

DB = os.path.expanduser("~/.local/share/aura_notebook/aura_memory.db")
SAM_CHAT = "/home/pratay-karali/launch-AURA/AURA-Proj/candle_LNN/aura_lnn/target/release/sam_chat"
YOLO_P = "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/yolov8n.onnx"
POSE_P = "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/yolov8n-pose.onnx"
EMO_P = "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/emotion-ferplus-8.onnx"
LOG = "/home/pratay-karali/launch-AURA/Mitacs/research/benchmark_logs/sam_3hr_final.json"
CHROME = "/home/pratay-karali/.cache/puppeteer/chrome/linux-150.0.7871.24/chrome-linux64/chrome"
COCO = ["person","bicycle","car","motorcycle","airplane","bus","train","truck","boat","traffic light","fire hydrant","stop sign","parking meter","bench","bird","cat","dog","horse","sheep","cow","elephant","bear","zebra","giraffe","backpack","umbrella","handbag","tie","suitcase","frisbee","skis","snowboard","sports ball","kite","baseball bat","baseball glove","skateboard","surfboard","tennis racket","bottle","wine glass","cup","fork","knife","spoon","bowl","banana","apple","sandwich","orange","broccoli","carrot","hot dog","pizza","donut","cake","chair","couch","potted plant","bed","dining table","toilet","tv","laptop","mouse","remote","keyboard","cell phone","microwave","oven","toaster","sink","refrigerator","book","clock","vase","scissors","teddy bear","hair drier","toothbrush"]
EMO_L = ["neutral","happy","surprise","sad","angry","disgust","fear","contempt"]
KP = ["nose","l_eye","r_eye","l_ear","r_ear","l_sh","r_sh","l_el","r_el","l_wr","r_wr","l_hip","r_hip","l_kn","r_kn","l_an","r_an"]
DUR = int(os.environ.get("SAM_DURATION", 180))
START = datetime.now()
log = []
stats = {"chats":0,"facts":0,"proactive":0,"emotions":0,"ocr":0,"objects":0,"gestures":0,"recall_pass":0,"recall_fail":0,"browser_tabs":0}
emo_timeline = []
proactive_events = []
bandit_snapshots = []

def ts(): return datetime.now().strftime("%H:%M:%S")
def elog(c,a,d="",r=""):
    e={"time":ts(),"min":(datetime.now()-START).total_seconds()/60,"cat":c,"act":a,"d":d,"r":r}
    log.append(e)
    print(f"[{ts()}] [{c}] {a}" + (f" — {d}" if d else "") + (f" → {r[:80]}" if r else ""))

# ─── AURA Chat (via sam_chat binary, same DB as bar app) ──────────────
def aura(msg):
    stats["chats"] += 1
    elog("SAM", f'"{msg}"')
    r = subprocess.run([SAM_CHAT, msg, DB], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=120)
    resp = ""
    for line in r.stdout.split("\n"):
        line = line.strip()
        if line.startswith("RESPONSE:"): resp = line[9:]
        elif line.startswith("FACTS_EXTRACTED:"):
            facts = [f for f in line[15:].split("|") if f.strip()]
            stats["facts"] += len(facts)
            elog("MEMORY", f"Extracted {len(facts)} facts", r=str(facts[:3]))
        elif line.startswith("PROACTIVE_FIRED:"):
            parts = line[15:].split(":")
            tid, label = parts[0], parts[1] if len(parts)>1 else ""
            stats["proactive"] += 1
            proactive_events.append({"time":ts(),"id":tid,"label":label})
            elog("PROACTIVE", f"*** {label} ***", r=f"ID={tid}")
            # Simulate engagement
            tid_i = int(tid) if tid.isdigit() else 0
            engaged = random.random() < (0.7 if tid_i in [1,2,5] else 0.3)
            try:
                conn = sqlite3.connect(DB)
                conn.execute("UPDATE triggers SET n_shown=n_shown+1, n_engaged=n_engaged+?, total_reward=total_reward+?, engagement_score=(total_reward+?)/CAST(n_shown+1 AS REAL) WHERE trigger_id=?",
                    (1 if engaged else 0, 1.0 if engaged else 0.0, 1.0 if engaged else 0.0, tid_i))
                conn.execute("INSERT INTO proactive_log (trigger_id,label,trigger_type,engaged) VALUES (?,?,?,?)",(tid_i,label,"bandit",1 if engaged else 0))
                conn.commit(); conn.close()
                elog("BANDIT", f"Engagement: {'ENGAGED' if engaged else 'IGNORED'}")
            except Exception as e: elog("ERROR", f"Engagement record failed: {e}")
        elif line.startswith("ALL_FACTS:"):
            facts = [f for f in line[11:].split("|") if f.strip()]
            elog("MEMORY", f"Total facts: {len(facts)}", r=facts[:4])
        elif line.startswith("BANDIT_SCORES:"):
            scores = []
            for s in line[14:].split(","):
                p = s.split(":")
                if len(p)>=3: scores.append({"id":p[0],"label":p[1],"score":float(p[2]),"shown":int(p[3]) if len(p)>3 else 0,"engaged":int(p[4]) if len(p)>4 else 0})
            bandit_snapshots.append({"time":ts(),"scores":scores})
            if scores:
                top = sorted(scores, key=lambda x:-x["score"])[:3]
                elog("BANDIT", f"Top: {[(s['label'][:15],s['score']) for s in top]}")
    elog("AURA", f"Response: {resp[:80]}", r=resp[:120])
    return resp

def recall(q, expected, label=""):
    stats["recall_fail"] += 1  # count as fail first
    resp = aura(q)
    hit = any(k.lower() in resp.lower() for k in expected)
    if hit: stats["recall_pass"] += 1; stats["recall_fail"] -= 1
    status = "PASS" if hit else "FAIL"
    elog("RECALL", f"'{label}': {status}", r=f"expected={expected} got={resp[:60]}")
    return hit

# ─── Vision ───────────────────────────────────────────────────────────
_ys=_ps=_es=None
def models():
    global _ys,_ps,_es
    if _ys is None:
        _ys=ort.InferenceSession(YOLO_P,providers=["CPUExecutionProvider"])
        _ps=ort.InferenceSession(POSE_P,providers=["CPUExecutionProvider"])
        _es=ort.InferenceSession(EMO_P,providers=["CPUExecutionProvider"])
    return _ys,_ps,_es

def nms(d):
    d=sorted(d,key=lambda x:-x["conf"]); k=[]
    while d:
        b=d.pop(0); k.append(b)
        d=[x for x in d if _iou(b["bbox"],x["bbox"])<0.45]
    return k
def _iou(a,b):
    x1,y1,x2,y2=max(a[0],b[0]),max(a[1],b[1]),min(a[2],b[2]),min(a[3],b[3])
    i=max(0,x2-x1)*max(0,y2-y1)
    return i/((a[2]-a[0])*(a[3]-a[1])+(b[2]-b[0])*(b[3]-b[1])-i+1e-6)

def yolo(img):
    ys,_,_=models(); h,w=img.shape[:2]
    r=cv2.resize(img,(640,640))
    inp=r[:,:,::-1].transpose(2,0,1).astype(np.float32)/255.0
    out=ys.run(None,{ys.get_inputs()[0].name:inp[np.newaxis]})[0][0].T
    d=[]
    for row in out:
        cx,cy,bw,bh=row[:4]; sc=row[4:]; cid=int(np.argmax(sc)); s=float(sc[cid])
        if s<0.25: continue
        d.append({"label":COCO[cid],"conf":s,"bbox":[int((cx-bw/2)/640*w),int((cy-bh/2)/640*h),int((cx+bw/2)/640*w),int((cy+bh/2)/640*h)]})
    return nms(d)

def emotion(img, bbox):
    _,_,es=models(); x1,y1,x2,y2=bbox
    fh=int((y2-y1)*0.40); fw=int((x2-x1)*0.60)
    fx1=max(0,(x1+x2)//2-fw//2); fy1=max(0,y1)
    fx2=min(img.shape[1],(x1+x2)//2+fw//2); fy2=min(img.shape[0],y1+fh)
    face=img[fy1:fy2,fx1:fx2]
    if face.size==0: return None
    gray=cv2.cvtColor(face,cv2.COLOR_BGR2GRAY)
    fc=cv2.CascadeClassifier(cv2.data.haarcascades+'haarcascade_frontalface_default.xml')
    faces=fc.detectMultiScale(gray,1.1,3)
    if len(faces)>0:
        fx,fy,fw2,fh2=max(faces,key=lambda f:f[2]*f[3])
        face_crop=gray[fy:fy+fh2,fx:fx+fw2]
    else: face_crop=gray
    face_crop=cv2.resize(face_crop,(64,64)).astype(np.float32)/255.0
    out=es.run(None,{es.get_inputs()[0].name:face_crop.reshape(1,1,64,64)})[0][0]
    exp=np.exp(out-np.max(out)); probs=exp/exp.sum()
    cid=int(np.argmax(probs))
    return {"emotion":EMO_L[cid],"conf":float(probs[cid])}

def gesture(img):
    _,ps,_=models(); h,w=img.shape[:2]
    r=cv2.resize(img,(640,640))
    inp=r[:,:,::-1].transpose(2,0,1).astype(np.float32)/255.0
    out=ps.run(None,{ps.get_inputs()[0].name:inp[np.newaxis]})[0][0].T
    best,bc=None,0
    for row in out:
        c=row[4] if len(row)>4 else 0
        if c>bc: bc,best=c,row
    if best is None or bc<0.25: return []
    kd=best[5:]; kpts=[]
    for i in range(17):
        if i*3+2<len(kd): kpts.append((kd[i*3]/640*w,kd[i*3+1]/640*h,kd[i*3+2]))
    g=[]
    if len(kpts)==17:
        nose,lw,rw=kpts[0],kpts[9],kpts[10]
        if nose[2]>0.3 and lw[2]>0.3 and lw[1]<nose[1]: g.append("LEFT HAND RAISED")
        if nose[2]>0.3 and rw[2]>0.3 and rw[1]<nose[1]: g.append("RIGHT HAND RAISED")
    return g

def vision(ctx=""):
    elog("VISION", f"Check {ctx}")
    wc="/tmp/sam_wc.jpg"
    subprocess.run(["fswebcam","-d","/dev/video0","-r","640x480","--no-banner",wc],capture_output=True,timeout=10)
    if Path(wc).exists():
        img=cv2.imread(wc)
        dets=yolo(img)
        stats["objects"]+=len(dets)
        persons=[d for d in dets if d["label"]=="person"]
        emo=None
        if persons:
            p=max(persons,key=lambda d:d["conf"])
            emo=emotion(img,p["bbox"])
            if emo:
                stats["emotions"]+=1
                emo_timeline.append({"time":ts(),"emotion":emo["emotion"],"conf":emo["conf"]})
                elog("VISION", f"Emotion: {emo['emotion']} ({emo['conf']*100:.0f}%)")
        g=gesture(img)
        if g:
            stats["gestures"]+=len(g)
            elog("VISION", f"GESTURE: {g}")
        elog("VISION", f"Webcam: {[d[chr(39)+chr(108)+chr(97)+chr(98)+chr(101)+chr(108)+chr(39)] for d in dets]}")
    sc="/tmp/sam_sc.png"
    with mss() as s: s.shot(output=sc)
    if Path(sc).exists():
        img=cv2.imread(sc)
        gray=cv2.cvtColor(img,cv2.COLOR_BGR2GRAY)
        text=pytesseract.image_to_string(gray,config="--psm 6")
        lines=[l for l in text.split("\n") if l.strip()]
        stats["ocr"]+=len(lines)
        elog("VISION", f"Screen OCR: {len(lines)} lines", r=lines[:3] if lines else "none")

# ─── Browser ──────────────────────────────────────────────────────────
def browser(url, label=""):
    stats["browser_tabs"] += 1
    elog("BROWSER", f"Opening {label or url}")
    subprocess.Popen([CHROME,"--no-sandbox","--disable-gpu","--new-window",url],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    time.sleep(5)
    vision(f"browser: {label}")

def close_browser():
    subprocess.run(["pkill","-f","chrome"],capture_output=True)
    time.sleep(1)
    elog("BROWSER","Closed")

# ─── DB Monitor ───────────────────────────────────────────────────────
def db_check():
    if not Path(DB).exists(): return
    try:
        conn=sqlite3.connect(DB); c=conn.cursor()
        facts=c.execute("SELECT count(*) FROM facts").fetchone()[0]
        turns=c.execute("SELECT count(*) FROM turns").fetchone()[0]
        plogs=c.execute("SELECT count(*) FROM proactive_log").fetchone()[0]
        elog("DB", f"Facts={facts} Turns={turns} ProactiveLog={plogs}")
        scores=c.execute("SELECT trigger_id,label,engagement_score,n_shown,n_engaged FROM triggers").fetchall()
        if scores:
            elog("BANDIT", f"Scores: {[(s[1][:15],round(s[2],2),s[3],s[4]) for s in scores[:4]]}")
        recent_facts=c.execute("SELECT fact FROM facts ORDER BY timestamp DESC LIMIT 5").fetchall()
        if recent_facts:
            elog("MEMORY", f"Recent facts: {[f[0][:30] for f in recent_facts]}")
        conn.close()
    except: pass

# ─── SAM Activities (interleaved) ─────────────────────────────────────
def act_intro():
    for m in ["Hi I'm Sam, I'm 39 years old","I live in San Francisco and I'm the CEO of OpenAI","I'm obsessed with AI and I drink way too much coffee","I have a cat named Patchwork","I'm learning Rust for my next big project"]:
        aura(m); time.sleep(2)

def act_code():
    elog("WORK","Sam writes Python code")
    code="import numpy as np\ndef softmax(x):\n    e=np.exp(x-np.max(x))\n    return e/e.sum()\nprint(softmax(np.array([2.1,3.4,0.8])))"
    Path("/tmp/sam_code.py").write_text(code)
    r=subprocess.run(["python3","/tmp/sam_code.py"],capture_output=True,text=True,timeout=10)
    elog("WORK",f"Code output: {r.stdout.strip()[:80]}")
    vision("coding")

def act_browser_research():
    urls=[("https://arxiv.org/abs/1706.03762","Attention paper"),("https://chat.openai.com","ChatGPT"),("https://github.com","GitHub"),("https://news.ycombinator.com","Hacker News"),("https://www.google.com/search?q=GPT-5+bar+exam","GPT-5 search")]
    url,label=random.choice(urls)
    browser(url,label)
    aura("I'm looking at something on my browser right now")
    time.sleep(3)
    close_browser()

def act_chatgpt():
    browser("https://chat.openai.com","ChatGPT")
    aura("I'm talking to ChatGPT right now, comparing it to you AURA")
    time.sleep(5)
    close_browser()

def act_stress():
    aura(random.choice(["ugh this board meeting is stressing me out","I'm feeling really overwhelmed with everything","the investors are going to grill me tomorrow"]))
    vision("stress")

def act_excited():
    aura(random.choice(["holy shit GPT-5 just passed the bar exam!","the model is working better than we hoped!","this is incredible, we actually did it!"]))
    vision("excited")

def act_frustrated():
    aura(random.choice(["this code keeps crashing and I hate it","I've been debugging for an hour","why is this bug so hard to find"]))
    vision("frustrated")

def act_happy():
    aura(random.choice(["just got back from a walk feeling great","I got my coffee and the sun is out","I'm actually really happy right now"]))
    vision("happy")

def act_tired():
    aura(random.choice(["it's getting late I should wrap up","I'm exhausted been working for hours","I need coffee but I'm too tired to make it"]))
    vision("tired")

def act_break():
    elog("BREAK","Sam walks away (10s)")
    time.sleep(10)
    elog("BREAK","Sam returns")
    aura("I'm back, got some fresh air")
    vision("back from break")

def act_schedule():
    aura(random.choice(["remind me to call my board members at 2pm","remind me to review the GPT-5 paper before the meeting","set a reminder to feed Patchwork","don't let me forget to email the team about the launch"]))

def act_vision_q():
    aura(random.choice(["what do you see right now?","what am I doing?","can you see my screen?","how do I look?"]))
    vision("vision query")

def act_correction():
    aura("my cat's name is Patchwork")
    time.sleep(1)
    aura("actually my cat's name is Patches")
    time.sleep(1)
    recall("what is my cat's name?",["patches"],"correction")

def act_new_fact():
    aura(random.choice(["I'm reading a book called Thinking Fast and Slow","I just moved to Mission District","I'm allergic to shellfish","my favorite language is Python","I have a meeting with Elon next Tuesday"]))

def act_random():
    aura(random.choice(["what's the meaning of life?","do you dream?","tell me something interesting","I'm bored entertain me","if you could have a superpower what would it be?"]))

def act_multiturn():
    aura("what did I accomplish today?")
    time.sleep(2)
    aura("how was I feeling earlier?")
    time.sleep(2)
    aura("what should I work on next based on what you know?")

# Recall tests
def r_name(): recall("what is my name?",["sam"],"name")
def r_age(): recall("how old am I?",["39"],"age")
def r_job(): recall("what do I do for work?",["ceo","openai"],"job")
def r_cat(): recall("what is my cat's name?",["patchwork"],"cat")
def r_loc(): recall("where do I live?",["san francisco","francisco"],"location")
def r_coffee(): recall("what do I like to drink?",["coffee"],"coffee")
def r_rust(): recall("what am I learning?",["rust"],"rust")
def r_all(): recall("tell me everything you know about me",["sam","39","francisco","openai","coffee","patchwork","rust"],"synthesis")

ACTS=[act_code,act_browser_research,act_chatgpt,act_stress,act_excited,act_frustrated,act_happy,act_tired,act_break,act_schedule,act_vision_q,act_correction,act_new_fact,act_random,act_multiturn,r_name,r_age,r_job,r_cat,r_loc,r_coffee,r_rust,r_all,act_code,act_browser_research,act_stress,act_excited,act_vision_q,act_vision_q,r_name,r_cat,r_all,act_new_fact,act_browser_research,act_chatgpt]

def main():
    global START
    START=datetime.now()
    END=START+timedelta(minutes=DUR)
    print(f"\n{'='*70}")
    print(f"  SAM 3-HOUR LIVE TEST — AURA Bar + Vision + Browser + Proactive")
    print(f"  Start: {START.strftime('%H:%M:%S')}  Duration: {DUR}min")
    print(f"  DB: {DB}")
    print(f"{'='*70}\n")

    elog("PHASE","Phase 1: Sam introduces himself")
    act_intro()
    db_check()
    time.sleep(5)

    elog("PHASE","Phase 2: Interleaved activities begin")
    count=0
    while datetime.now()<END:
        el=(datetime.now()-START).total_seconds()/60
        elog("STATUS",f"{el:.1f}min/{DUR}min | chats={stats['chats']} facts={stats['facts']} proactive={stats['proactive']} emotions={stats['emotions']} ocr={stats['ocr']} recall={stats['recall_pass']}/{stats['recall_pass']+stats['recall_fail']} browsers={stats['browser_tabs']}")
        try: random.choice(ACTS)(); count+=1
        except Exception as e: elog("ERROR",str(e))
        if count%3==0: db_check()
        if count%4==0: vision(f"periodic #{count}")
        time.sleep(random.uniform(20,50))

    elog("PHASE","Phase 3: Final analysis")
    db_check()
    r_all()
    vision("final")

    print(f"\n{'='*70}")
    print(f"  FINAL REPORT — SAM 3-HOUR TEST")
    print(f"{'='*70}")
    print(f"  Duration: {(datetime.now()-START).total_seconds()/60:.1f}min")
    print(f"  Chats: {stats['chats']}")
    print(f"  Facts stored: {stats['facts']}")
    print(f"  Proactive fired: {stats['proactive']}")
    print(f"  Recall: {stats['recall_pass']}/{stats['recall_pass']+stats['recall_fail']}")
    print(f"  Emotions detected: {stats['emotions']}")
    print(f"  OCR lines: {stats['ocr']}")
    print(f"  Objects detected: {stats['objects']}")
    print(f"  Gestures: {stats['gestures']}")
    print(f"  Browser tabs opened: {stats['browser_tabs']}")
    print(f"  Emotion timeline: {len(emo_timeline)} entries")
    for e in emo_timeline: print(f"    {e['time']} {e['emotion']} ({e['conf']*100:.0f}%)")
    print(f"  Proactive events: {len(proactive_events)}")
    for p in proactive_events[:10]: print(f"    {p['time']} {p['label']}")
    print(f"  Bandit snapshots: {len(bandit_snapshots)}")
    if bandit_snapshots:
        last=bandit_snapshots[-1]
        for s in sorted(last["scores"],key=lambda x:-x["score"])[:5]:
            print(f"    {s['label'][:30]}: score={s['score']:.2f} shown={s.get('shown',0)} engaged={s.get('engaged',0)}")
    print(f"\n{'='*70}")

    Path(LOG).write_text(json.dumps({"stats":stats,"log":log,"emotion_timeline":emo_timeline,"proactive_events":proactive_events,"bandit_snapshots":bandit_snapshots},indent=2,default=str))
    print(f"  Log: {LOG}")

if __name__=="__main__":
    def h(sig,frame):
        Path(LOG).write_text(json.dumps({"stats":stats,"log":log,"emotion_timeline":emo_timeline,"proactive_events":proactive_events,"bandit_snapshots":bandit_snapshots},indent=2,default=str))
        print(f"\nInterrupted. Log saved to {LOG}")
        sys.exit(0)
    signal.signal(signal.SIGINT,h)
    main()
