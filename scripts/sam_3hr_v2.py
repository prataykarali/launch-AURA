#!/usr/bin/env python3
"""
SAM 3-HOUR LIVE TEST v2
- AURA bar stays alive on screen (shows proactive popups + TTS)
- sam_chat binary writes to the SAME DB (bar sees the data)
- Opens real browser tabs, text editors, writes files
- Captures webcam (YOLO/emotion/gesture) and screen (OCR) periodically
- Monitors bar stderr for proactive triggers
- Auto-restarts bar if it dies
"""
import subprocess, os, json, random, time, sqlite3, signal, sys, threading
from pathlib import Path
from datetime import datetime, timedelta

DB = os.path.expanduser("~/.local/share/aura_notebook/aura_memory.db")
SAM_CHAT = "/home/pratay-karali/launch-AURA/AURA-Proj/candle_LNN/aura_lnn/target/release/sam_chat"
BAR_APP = "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/build/linux/x64/debug/bundle/aura_notebook"
BAR_DIR = "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook"
CHROME = "/home/pratay-karali/.cache/puppeteer/chrome/linux-150.0.7871.24/chrome-linux64/chrome"
LOG = "/home/pratay-karali/launch-AURA/Mitacs/research/benchmark_logs/sam_3hr_v2.json"
STDERR_LOG = "/tmp/aura_bar_stderr.log"
DUR = int(os.environ.get("SAM_DURATION", 180))
START = datetime.now()
log = []
stats = {"chats":0,"facts":0,"proactive":0,"emotions":0,"ocr":0,"objects":0,"gestures":0,"recall_pass":0,"recall_fail":0,"browsers":0,"files_edited":0,"bar_restarts":0}
emo_timeline = []
proactive_events = []
bar_pid = None

def ts(): return datetime.now().strftime("%H:%M:%S")
def elog(c,a,d=""):
    e={"time":ts(),"min":(datetime.now()-START).total_seconds()/60,"cat":c,"act":a,"d":d}
    log.append(e)
    print(f"[{ts()}] [{c}] {a}" + (f" — {d}" if d else ""), flush=True)

# ─── Bar lifecycle (does NOT start bar — bar started manually) ───────
bar_pid = None

def start_bar():
    pass  # Bar is started manually, not by this script

def bar_alive():
    return subprocess.run(["pgrep","-f","bundle/aura_notebook"],capture_output=True).returncode==0

def ensure_bar():
    pass  # Don't restart bar from here

# ─── Chat via sam_chat (same DB as bar) ───────────────────────────────
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
            elog("MEMORY", f"Extracted {len(facts)}: {facts[:3]}")
        elif line.startswith("PROACTIVE_FIRED:"):
            parts = line[15:].split(":")
            tid, label = parts[0], parts[1] if len(parts)>1 else ""
            stats["proactive"] += 1
            proactive_events.append({"time":ts(),"id":tid,"label":label})
            elog("PROACTIVE", f"*** {label} ***")
            # Simulate engagement
            tid_i = int(tid) if tid.isdigit() else 0
            engaged = random.random() < (0.7 if tid_i in [1,2,5] else 0.3)
            try:
                conn = sqlite3.connect(DB)
                conn.execute("UPDATE triggers SET n_shown=n_shown+1,n_engaged=n_engaged+?,total_reward=total_reward+?,engagement_score=(total_reward+?)/CAST(n_shown+1 AS REAL) WHERE trigger_id=?",
                    (1 if engaged else 0, 1.0 if engaged else 0.0, 1.0 if engaged else 0.0, tid_i))
                conn.execute("INSERT INTO proactive_log (trigger_id,label,trigger_type,engaged) VALUES (?,?,?,?)",(tid_i,label,"bandit",1 if engaged else 0))
                conn.commit(); conn.close()
                elog("BANDIT", f"{'ENGAGED' if engaged else 'IGNORED'}")
            except: pass
        elif line.startswith("ALL_FACTS:"):
            facts = [f for f in line[11:].split("|") if f.strip()]
            elog("MEMORY", f"Total: {len(facts)} facts")
        elif line.startswith("BANDIT_SCORES:"):
            scores = []
            for s in line[14:].split(","):
                p = s.split(":")
                if len(p)>=5: scores.append((p[1][:20],float(p[2]),int(p[3]),int(p[4])))
            if scores:
                elog("BANDIT", f"Top: {sorted(scores,key=lambda x:-x[1])[:3]}")
    elog("AURA", f'"{resp[:80]}"')
    return resp

def recall(q, expected, label=""):
    stats["recall_fail"] += 1
    resp = aura(q)
    hit = any(k.lower() in resp.lower() for k in expected)
    if hit: stats["recall_pass"] += 1; stats["recall_fail"] -= 1
    elog("RECALL", f"{label}: {'PASS' if hit else 'FAIL'} (expected {expected})")
    return hit

# ─── Vision (webcam + screen) ─────────────────────────────────────────
def vision(ctx=""):
    elog("VISION", f"Check {ctx}")
    # Webcam
    wc = "/tmp/sam_wc.jpg"
    subprocess.run(["fswebcam","-d","/dev/video0","-r","640x480","--no-banner",wc], capture_output=True, timeout=10)
    if Path(wc).exists():
        r = subprocess.run(["python3","-c",f"""
import cv2,numpy as np,onnxruntime as ort,sys
YOLO='/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/yolov8n.onnx'
EMO='/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/emotion-ferplus-8.onnx'
POSE='/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/yolov8n-pose.onnx'
COCO={["person","bicycle","car","motorcycle","airplane","bus","train","truck","boat","traffic light","fire hydrant","stop sign","parking meter","bench","bird","cat","dog","horse","sheep","cow","elephant","bear","zebra","giraffe","backpack","umbrella","handbag","tie","suitcase","frisbee","skis","snowboard","sports ball","kite","baseball bat","baseball glove","skateboard","surfboard","tennis racket","bottle","wine glass","cup","fork","knife","spoon","bowl","banana","apple","sandwich","orange","broccoli","carrot","hot dog","pizza","donut","cake","chair","couch","potted plant","bed","dining table","toilet","tv","laptop","mouse","remote","keyboard","cell phone","microwave","oven","toaster","sink","refrigerator","book","clock","vase","scissors","teddy bear","hair drier","toothbrush"]}
EL=["neutral","happy","surprise","sad","angry","disgust","fear","contempt"]
img=cv2.imread('{wc}')
h,w=img.shape[:2]
ys=ort.InferenceSession(YOLO,providers=['CPUExecutionProvider'])
r=cv2.resize(img,(640,640)); inp=r[:,:,::-1].transpose(2,0,1).astype(np.float32)/255.0
out=ys.run(None,{{ys.get_inputs()[0].name:inp[np.newaxis]}})[0][0].T
dets=[]
for row in out:
    cx,cy,bw,bh=row[:4];sc=row[4:];cid=int(np.argmax(sc));s=float(sc[cid])
    if s<0.25: continue
    dets.append('{{label:COCO[cid],conf:s}}')
# NMS
dets=sorted(dets,key=lambda x:-x['conf']);keep=[]
while dets: b=dets.pop(0);keep.append(b);dets=[d for d in dets if _iou(b,d)<0.45]
# Emotion
emo='none'
persons=[d for d in keep if d['label']=='person']
if persons:
    p=max(persons,key=lambda d:d['conf'])
    x1,y1,x2,y2=p['bbox'];fh=int((y2-y1)*0.4);fw=int((x2-x1)*0.6)
    fx1=max(0,(x1+x2)//2-fw//2);fy1=max(0,y1);fx2=min(w,(x1+x2)//2+fw//2);fy2=min(h,y1+fh)
    face=img[fy1:fy2,fx1:fx2]
    if face.size>0:
        gray=cv2.cvtColor(face,cv2.COLOR_BGR2GRAY)
        fc=cv2.CascadeClassifier(cv2.data.haarcascades+'haarcascade_frontalface_default.xml')
        faces=fc.detectMultiScale(gray,1.1,3)
        if len(faces)>0: fx,fy,fw2,fh2=max(faces,key=lambda f:f[2]*f[3]);face=gray[fy:fy+fh2,fx:fx+fw2]
        else: face=gray
        face=cv2.resize(face,(64,64)).astype(np.float32)/255.0
        es=ort.InferenceSession(EMO,providers=['CPUExecutionProvider'])
        o=es.run(None,{{es.get_inputs()[0].name:face.reshape(1,1,64,64)}})[0][0]
        exp=np.exp(o-np.max(o));pr=exp/exp.sum();eid=int(np.argmax(pr))
        emo=EL[eid]
# Pose/gesture
ps=ort.InferenceSession(POSE,providers=['CPUExecutionProvider'])
o=ps.run(None,{{ps.get_inputs()[0].name:inp[np.newaxis]}})[0][0].T
best,bc=None,0
for row in o:
    c=row[4] if len(row)>4 else 0
    if c>bc: bc,best=c,row
gest='none'
if best and bc>0.25:
    kd=best[5:];kpts=[]
    for i in range(17):
        if i*3+2<len(kd):kpts.append((kd[i*3]/640*w,kd[i*3+1]/640*h,kd[i*3+2]))
    if len(kpts)==17:
        nose,lw,rw=kpts[0],kpts[9],kpts[10]
        if nose[2]>0.3 and lw[2]>0.3 and lw[1]<nose[1]:gest='LEFT_HAND_RAISED'
        if nose[2]>0.3 and rw[2]>0.3 and rw[1]<nose[1]:gest='RIGHT_HAND_RAISED'
print(f"OBJECTS={{[d['label'] for d in keep]}}")
print(f"EMOTION={{emo}}")
print(f"GESTURE={{gest}}")
def _iou(a,b):
    x1,y1,x2,y2=max(a[0],b[0]),max(a[1],b[1]),min(a[2],b[2]),min(a[3],b[3])
    i=max(0,x2-x1)*max(0,y2-y1);return i/((a[2]-a[0])*(a[3]-a[1])+(b[2]-b[0])*(b[3]-b[1])-i+1e-6)
"""], capture_output=True, text=True, timeout=30)
        objs = "[]"; emo = "none"; gest = "none"
        for line in r.stdout.split("\n"):
            if line.startswith("OBJECTS="): objs = line[8:]
            elif line.startswith("EMOTION="): emo = line[8:]
            elif line.startswith("GESTURE="): gest = line[8:]
        stats["objects"] += len(eval(objs)) if objs != "[]" else 0
        if emo != "none":
            stats["emotions"] += 1
            emo_timeline.append({"time":ts(),"emotion":emo})
            elog("VISION", f"Emotion: {emo}")
        if gest != "none":
            stats["gestures"] += 1
            elog("VISION", f"GESTURE: {gest}")
        elog("VISION", f"Webcam: {objs} emo={emo} gest={gest}")
    # Screen OCR
    sc = "/tmp/sam_sc.png"
    subprocess.run(["DISPLAY=:1 scrot "+sc], shell=True, capture_output=True, timeout=5)
    if Path(sc).exists():
        r = subprocess.run(["python3","-c",f"""
import cv2,pytesseract
img=cv2.imread('{sc}')
gray=cv2.cvtColor(img,cv2.COLOR_BGR2GRAY)
t=pytesseract.image_to_string(gray,config='--psm 6')
lines=[l for l in t.split('\\n') if l.strip()]
print(len(lines))
for l in lines[:5]: print(l)
"""], capture_output=True, text=True, timeout=15)
        lines = r.stdout.strip().split("\n")
        count = int(lines[0]) if lines else 0
        stats["ocr"] += count
        elog("VISION", f"Screen OCR: {count} lines — {lines[1:4] if len(lines)>1 else 'none'}")

# ─── Real desktop activities ──────────────────────────────────────────
def open_browser(url, label=""):
    stats["browsers"] += 1
    elog("BROWSER", f"Opening {label or url}")
    subprocess.Popen([CHROME,"--no-sandbox","--disable-gpu","--new-window",url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(5)

def close_browser():
    subprocess.run(["pkill","-f","chrome"], capture_output=True)
    time.sleep(1)
    elog("BROWSER","Closed")

def edit_file(filename, content):
    stats["files_edited"] += 1
    path = f"/tmp/sam_{filename}"
    Path(path).write_text(content)
    elog("FILE", f"Edited {path} ({len(content)} chars)")
    # Open in gedit or xdg-open
    subprocess.Popen(["xdg-open", path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(3)

def check_bar_stderr():
    """Check AURA bar stderr for proactive triggers and responses."""
    try:
        with open(STDERR_LOG, 'r') as f:
            content = f.read()
        # Find recent proactive triggers
        for line in content.split("\n")[-20:]:
            if "PROACTIVE TEST" in line and "Dispatching" in line:
                elog("BAR_PROACTIVE", line.strip()[:80])
            elif "AuraBarBrain: LLM stream done" in line:
                elog("BAR_RESPONSE", line.strip()[:80])
            elif "Bar visible" in line:
                elog("BAR", "Bar became visible (gesture watch started)")
            elif "Bar hidden" in line:
                elog("BAR", "Bar hidden (gesture watch stopped)")
    except: pass

def db_check():
    if not Path(DB).exists(): return
    try:
        conn = sqlite3.connect(DB); c = conn.cursor()
        facts = c.execute("SELECT count(*) FROM facts").fetchone()[0]
        turns = c.execute("SELECT count(*) FROM turns").fetchone()[0]
        plogs = c.execute("SELECT count(*) FROM proactive_log").fetchone()[0]
        elog("DB", f"Facts={facts} Turns={turns} PLogs={plogs}")
        scores = c.execute("SELECT label,engagement_score,n_shown,n_engaged FROM triggers").fetchall()
        if scores:
            elog("BANDIT", f"{[(s[0][:15],round(s[1],2),s[2],s[3]) for s in scores[:4]]}")
        conn.close()
    except: pass

# ─── SAM Activities ───────────────────────────────────────────────────
def act_intro():
    for m in ["Hi I'm Sam, I'm 39 years old","I live in San Francisco and I'm the CEO of OpenAI","I'm obsessed with AI and I drink way too much coffee","I have a cat named Patchwork","I'm learning Rust for my next big project"]:
        aura(m); time.sleep(2); ensure_bar()

def act_code():
    elog("WORK","Sam writes Python")
    code = "import numpy as np\ndef softmax(x):\n    e=np.exp(x-np.max(x))\n    return e/e.sum()\nprint(softmax(np.array([2.1,3.4,0.8])))"
    edit_file("experiment.py", code)
    subprocess.run(["python3","/tmp/sam_experiment.py"], capture_output=True, timeout=10)
    vision("coding")

def act_browser():
    urls = [("https://arxiv.org/abs/1706.03762","Arxiv paper"),("https://chat.openai.com","ChatGPT"),("https://github.com","GitHub"),("https://news.ycombinator.com","Hacker News"),("https://www.google.com","Google")]
    url,label = random.choice(urls)
    open_browser(url,label)
    aura(f"I'm looking at {label} on my browser right now")
    vision(f"browser:{label}")
    time.sleep(3)
    close_browser()

def act_stress(): aura(random.choice(["ugh this board meeting is stressing me out","I'm feeling really overwhelmed","the investors are going to grill me"])); vision("stress")
def act_excited(): aura(random.choice(["GPT-5 just passed the bar exam!","the model is working amazingly!","this is incredible!"])); vision("excited")
def act_frustrated(): aura(random.choice(["this code keeps crashing","I hate debugging","why is this so hard"])); vision("frustrated")
def act_happy(): aura(random.choice(["feeling great after a walk","got my coffee, sun is out","I'm really happy right now"])); vision("happy")
def act_tired(): aura(random.choice(["getting late, should wrap up","I'm exhausted","too tired for more coffee"])); vision("tired")
def act_break(): elog("BREAK","away 10s"); time.sleep(10); elog("BREAK","back"); aura("I'm back, got some fresh air"); vision("back")
def act_schedule(): aura(random.choice(["remind me to call my board at 2pm","remind me to review the GPT-5 paper","set a reminder to feed Patchwork"]))
def act_vision_q(): aura(random.choice(["what do you see?","what am I doing?","can you see my screen?","how do I look?"])); vision("vision_q")
def act_correction(): aura("my cat's name is Patchwork"); time.sleep(1); aura("actually my cat's name is Patches"); time.sleep(1); recall("what is my cat's name?",["patches"],"correction")
def act_new_fact(): aura(random.choice(["I'm reading Thinking Fast and Slow","I just moved to Mission District","I'm allergic to shellfish","my favorite language is Python","I have a meeting with Elon next Tuesday"]))
def act_random(): aura(random.choice(["what's the meaning of life?","do you dream?","tell me something interesting","I'm bored"]))
def act_multiturn(): aura("what did I do today?"); time.sleep(2); aura("how was I feeling?"); time.sleep(2); aura("what should I work on next?")
def act_write_doc():
    elog("WORK","Sam writes a document")
    edit_file("notes.txt", "Board Meeting Agenda\n1. GPT-5 results\n2. Funding round\n3. Hiring plan\n4. Safety review\n5. Next quarter goals")
    vision("writing doc")
def act_read_code():
    elog("WORK","Sam reads a Rust file")
    edit_file("main.rs", 'fn main() {\n    println!("Hello from Sam!");\n    let x = vec![1,2,3];\n    let sum: i32 = x.iter().sum();\n    println!("Sum: {}", sum);\n}')
    vision("reading code")

def r_name(): recall("what is my name?",["sam"],"name")
def r_age(): recall("how old am I?",["39"],"age")
def r_job(): recall("what do I do for work?",["ceo","openai"],"job")
def r_cat(): recall("what is my cat's name?",["patchwork"],"cat")
def r_loc(): recall("where do I live?",["san francisco","francisco"],"location")
def r_coffee(): recall("what do I like to drink?",["coffee"],"coffee")
def r_rust(): recall("what am I learning?",["rust"],"rust")
def r_all(): recall("tell me everything you know about me",["sam","39","francisco","openai","coffee","patchwork","rust"],"synthesis")

ACTS = [act_code,act_browser,act_stress,act_excited,act_frustrated,act_happy,act_tired,
        act_break,act_schedule,act_vision_q,act_correction,act_new_fact,act_random,
        act_multiturn,act_write_doc,act_read_code,
        r_name,r_age,r_job,r_cat,r_loc,r_coffee,r_rust,r_all,
        act_code,act_browser,act_stress,act_excited,act_vision_q,act_vision_q,
        r_name,r_cat,r_all,act_new_fact,act_browser,act_write_doc]

# ─── Main ─────────────────────────────────────────────────────────────
def main():
    global START
    START = datetime.now()
    END = START + timedelta(minutes=DUR)
    print(f"\n{'='*70}")
    print(f"  SAM 3-HOUR LIVE TEST v2 — Bar + Vision + Browser + Files")
    print(f"  Start: {START.strftime('%H:%M:%S')}  Duration: {DUR}min")
    print(f"{'='*70}\n")

    # Bar should already be running (started manually)
    if bar_alive():
        elog("BAR", "Bar is alive (started manually)")
    else:
        elog("BAR", "WARNING: Bar not detected — run launch.sh first")

    # Phase 1: Intro
    elog("PHASE","Phase 1: Sam introduces himself")
    act_intro()
    db_check()
    time.sleep(5)

    # Phase 2: Interleaved
    elog("PHASE","Phase 2: Interleaved activities")
    count = 0
    while datetime.now() < END:
        el = (datetime.now()-START).total_seconds()/60
        elog("STATUS", f"{el:.0f}min/{DUR}min chats={stats['chats']} facts={stats['facts']} proactive={stats['proactive']} emo={stats['emotions']} ocr={stats['ocr']} recall={stats['recall_pass']}/{stats['recall_pass']+stats['recall_fail']} browsers={stats['browsers']} files={stats['files_edited']}")
        ensure_bar()
        try: random.choice(ACTS)(); count += 1
        except Exception as e: elog("ERROR", str(e))
        if count % 3 == 0: db_check(); check_bar_stderr()
        if count % 4 == 0: vision(f"periodic#{count}")
        time.sleep(random.uniform(20,50))

    # Phase 3: Final
    elog("PHASE","Phase 3: Final analysis")
    db_check(); check_bar_stderr()
    r_all(); vision("final")

    print(f"\n{'='*70}")
    print(f"  FINAL REPORT")
    print(f"{'='*70}")
    print(f"  Duration: {(datetime.now()-START).total_seconds()/60:.0f}min")
    print(f"  Chats: {stats['chats']}  Facts: {stats['facts']}")
    print(f"  Proactive: {stats['proactive']}  Bar restarts: {stats['bar_restarts']}")
    print(f"  Recall: {stats['recall_pass']}/{stats['recall_pass']+stats['recall_fail']}")
    print(f"  Emotions: {stats['emotions']}  OCR: {stats['ocr']}  Objects: {stats['objects']}")
    print(f"  Gestures: {stats['gestures']}  Browsers: {stats['browsers']}  Files: {stats['files_edited']}")
    print(f"  Emotion timeline:")
    for e in emo_timeline: print(f"    {e['time']} {e['emotion']}")
    print(f"  Proactive events: {len(proactive_events)}")
    for p in proactive_events[:10]: print(f"    {p['time']} {p['label']}")
    print(f"{'='*70}")

    Path(LOG).write_text(json.dumps({"stats":stats,"log":log,"emotion_timeline":emo_timeline,"proactive_events":proactive_events},indent=2,default=str))
    print(f"  Log: {LOG}")

if __name__ == "__main__":
    def h(sig,frame):
        Path(LOG).write_text(json.dumps({"stats":stats,"log":log,"emotion_timeline":emo_timeline,"proactive_events":proactive_events},indent=2,default=str))
        print(f"\nSaved to {LOG}"); sys.exit(0)
    signal.signal(signal.SIGINT, h)
    main()
