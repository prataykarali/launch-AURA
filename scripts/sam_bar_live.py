#!/usr/bin/env python3
"""
SAM LIVE BAR TEST — Types directly into the AURA bar on screen using xdotool.
This simulates a real human (Sam Altman) interacting with the AURA bar.
Clean memory, fresh start. Tests vision, proactive, memory, multi-turn.
"""
import subprocess, time, random, os, json, sqlite3, cv2, numpy as np, onnxruntime as ort, pytesseract
from pathlib import Path
from datetime import datetime, timedelta
from mss import mss

DB_PATH = os.path.expanduser("~/.local/share/aura_notebook/aura_memory.db")
LOG = "/home/pratay-karali/launch-AURA/Mitacs/research/benchmark_logs/sam_bar_live_log.json"
YOLO_PATH = "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/yolov8n.onnx"
EMOTION_PATH = "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/emotion-ferplus-8.onnx"
POSE_PATH = "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/yolov8n-pose.onnx"
COCO = ["person","bicycle","car","motorcycle","airplane","bus","train","truck","boat","traffic light","fire hydrant","stop sign","parking meter","bench","bird","cat","dog","horse","sheep","cow","elephant","bear","zebra","giraffe","backpack","umbrella","handbag","tie","suitcase","frisbee","skis","snowboard","sports ball","kite","baseball bat","baseball glove","skateboard","surfboard","tennis racket","bottle","wine glass","cup","fork","knife","spoon","bowl","banana","apple","sandwich","orange","broccoli","carrot","hot dog","pizza","donut","cake","chair","couch","potted plant","bed","dining table","toilet","tv","laptop","mouse","remote","keyboard","cell phone","microwave","oven","toaster","sink","refrigerator","book","clock","vase","scissors","teddy bear","hair drier","toothbrush"]
EMOTION_LABELS = ["neutral","happy","surprise","sad","angry","disgust","fear","contempt"]
KP = ["nose","l_eye","r_eye","l_ear","r_ear","l_shoulder","r_shoulder","l_elbow","r_elbow","l_wrist","r_wrist","l_hip","r_hip","l_knee","r_knee","l_ankle","r_ankle"]

log = []
stats = {"chats":0,"facts":0,"proactive":0,"emotions":0,"ocr":0,"objects":0,"gestures":0,"recall_pass":0,"recall_fail":0}
emotion_timeline = []
proactive_events = []
START = datetime.now()
DURATION = int(os.environ.get("SAM_DURATION", 180))

def ts(): return datetime.now().strftime("%H:%M:%S")
def elog(cat, act, detail="", result=""):
    e = {"time":ts(),"min":(datetime.now()-START).total_seconds()/60,"cat":cat,"act":act,"detail":detail,"result":result}
    log.append(e)
    print(f"[{ts()}] [{cat}] {act}" + (f" — {detail}" if detail else "") + (f" → {result[:80]}" if result else ""))

def type_to_aura(msg):
    """Type message into the AURA bar using xdotool."""
    stats["chats"] += 1
    elog("CHAT", f"Sam types: \"{msg}\"")
    # Focus the AURA bar window
    subprocess.run(["xdotool","search","--name","AURA","windowactivate"], capture_output=True, timeout=5)
    time.sleep(0.5)
    subprocess.run(["xdotool","search","--name","AURA","windowfocus"], capture_output=True, timeout=5)
    time.sleep(0.3)
    # Click on the bar area (center of screen, lower third)
    subprocess.run(["xdotool","mousemove","960","900","click","1"], capture_output=True, timeout=5)
    time.sleep(0.3)
    # Type the message
    subprocess.run(["xdotool","type","--delay","30",msg], capture_output=True, timeout=30)
    time.sleep(0.5)
    # Press Enter
    subprocess.run(["xdotool","key","Return"], capture_output=True, timeout=5)
    # Wait for AURA to respond
    time.sleep(15)
    # Screenshot to capture AURA's response
    sc = "/tmp/sam_bar_screen.png"
    with mss() as s: s.shot(output=sc)
    img = cv2.imread(sc)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    text = pytesseract.image_to_string(gray, config="--psm 6")
    lines = [l for l in text.split("\n") if l.strip()]
    # Find AURA's response — look for lines that aren't VS Code UI
    response = ""
    for l in lines:
        if len(l) > 10 and not any(x in l.lower() for x in ["file","edit","selection","view","terminal","help","launch","debug","problems","output","port","opencode","loading","dart","codex","config","authjson","spaces","utf-8","ln","col"]):
            response = l
    elog("CHAT", f"AURA responded", result=response[:120] if response else "no response in OCR")
    return response

def capture_webcam():
    out = "/tmp/sam_bar_webcam.jpg"
    subprocess.run(["fswebcam","-d","/dev/video0","-r","640x480","--no-banner",out], capture_output=True, timeout=10)
    return out if Path(out).exists() else None

def yolo_detect(img):
    h, w = img.shape[:2]
    r = cv2.resize(img, (640,640))
    inp = r[:,:,::-1].transpose(2,0,1).astype(np.float32)/255.0
    sess = ort.InferenceSession(YOLO_PATH, providers=["CPUExecutionProvider"])
    out = sess.run(None, {sess.get_inputs()[0].name: inp[np.newaxis]})[0][0].T
    dets = []
    for row in out:
        cx,cy,bw,bh = row[:4]; scores = row[4:]
        cid = int(np.argmax(scores)); sc = float(scores[cid])
        if sc < 0.25: continue
        dets.append({"label":COCO[cid],"conf":sc,"bbox":[int((cx-bw/2)/640*w),int((cy-bh/2)/640*h),int((cx+bw/2)/640*w),int((cy+bh/2)/640*h)]})
    # NMS
    dets = sorted(dets, key=lambda x:-x["conf"])
    keep = []
    while dets:
        b = dets.pop(0); keep.append(b)
        dets = [d for d in dets if _iou(b["bbox"],d["bbox"])<0.45]
    return keep

def _iou(a,b):
    x1,y1,x2,y2=max(a[0],b[0]),max(a[1],b[1]),min(a[2],b[2]),min(a[3],b[3])
    inter=max(0,x2-x1)*max(0,y2-y1)
    return inter/((a[2]-a[0])*(a[3]-a[1])+(b[2]-b[0])*(b[3]-b[1])-inter+1e-6)

def detect_emotion(img, person_bbox):
    x1,y1,x2,y2 = person_bbox
    fh = int((y2-y1)*0.40); fw = int((x2-x1)*0.60)
    fx1 = max(0,(x1+x2)//2-fw//2); fy1 = max(0,y1)
    fx2 = min(img.shape[1],(x1+x2)//2+fw//2); fy2 = min(img.shape[0],y1+fh)
    face = img[fy1:fy2, fx1:fx2]
    if face.size == 0: return None
    gray = cv2.cvtColor(face, cv2.COLOR_BGR2GRAY)
    fc = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
    faces = fc.detectMultiScale(gray, 1.1, 3)
    if len(faces) > 0:
        fx,fy,fw2,fh2 = max(faces, key=lambda f:f[2]*f[3])
        face_crop = gray[fy:fy+fh2, fx:fx+fw2]
    else: face_crop = gray
    face_crop = cv2.resize(face_crop, (64,64)).astype(np.float32)/255.0
    sess = ort.InferenceSession(EMOTION_PATH, providers=["CPUExecutionProvider"])
    out = sess.run(None, {sess.get_inputs()[0].name: face_crop.reshape(1,1,64,64)})[0][0]
    exp = np.exp(out-np.max(out)); probs = exp/exp.sum()
    cid = int(np.argmax(probs))
    return {"emotion":EMOTION_LABELS[cid],"conf":float(probs[cid])}

def detect_gesture(img):
    h, w = img.shape[:2]
    r = cv2.resize(img, (640,640))
    inp = r[:,:,::-1].transpose(2,0,1).astype(np.float32)/255.0
    sess = ort.InferenceSession(POSE_PATH, providers=["CPUExecutionProvider"])
    out = sess.run(None, {sess.get_inputs()[0].name: inp[np.newaxis]})[0][0].T
    best, bc = None, 0
    for row in out:
        c = row[4] if len(row)>4 else 0
        if c > bc: bc, best = c, row
    if best is None or bc < 0.25: return []
    kd = best[5:]; kpts = []
    for i in range(17):
        if i*3+2 < len(kd): kpts.append((kd[i*3]/640*w, kd[i*3+1]/640*h, kd[i*3+2]))
    gestures = []
    if len(kpts)==17:
        nose,lw,rw = kpts[0],kpts[9],kpts[10]
        if nose[2]>0.3 and lw[2]>0.3 and lw[1]<nose[1]: gestures.append("LEFT HAND RAISED")
        if nose[2]>0.3 and rw[2]>0.3 and rw[1]<nose[1]: gestures.append("RIGHT HAND RAISED")
    return gestures

def vision_check(ctx=""):
    elog("VISION", f"Vision check {ctx}")
    wc = capture_webcam()
    if wc:
        img = cv2.imread(wc)
        dets = yolo_detect(img)
        stats["objects"] += len(dets)
        persons = [d for d in dets if d["label"]=="person"]
        emotion = None
        if persons:
            p = max(persons, key=lambda d:d["conf"])
            emotion = detect_emotion(img, p["bbox"])
            if emotion:
                stats["emotions"] += 1
                emotion_timeline.append({"time":ts(),"emotion":emotion["emotion"],"conf":emotion["conf"]})
                elog("VISION", f"Emotion: {emotion['emotion']} ({emotion['conf']*100:.0f}%)")
        gestures = detect_gesture(img)
        if gestures:
            stats["gestures"] += len(gestures)
            elog("VISION", f"GESTURE: {gestures}")
        elog("VISION", f"Webcam: {[d['label'] for d in dets]}")
    # Screen OCR
    sc = "/tmp/sam_bar_screen.png"
    with mss() as s: s.shot(output=sc)
    if Path(sc).exists():
        img = cv2.imread(sc)
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        text = pytesseract.image_to_string(gray, config="--psm 6")
        lines = [l for l in text.split("\n") if l.strip()]
        stats["ocr"] += len(lines)
        elog("VISION", f"Screen OCR: {len(lines)} lines", result=lines[:3] if lines else "none")

def check_db():
    if not Path(DB_PATH).exists(): return
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    try:
        facts = c.execute("SELECT fact FROM facts").fetchall()
        elog("MEMORY", f"DB has {len(facts)} facts", result=[f[0][:30] for f in facts[:5]])
    except: pass
    try:
        triggers = c.execute("SELECT trigger_id,label,engagement_score,n_shown,n_engaged FROM triggers").fetchall()
        if triggers:
            elog("BANDIT", f"Scores: {[(t[1][:20],round(t[2],2)) for t in triggers[:3]]}")
    except: pass
    try:
        plogs = c.execute("SELECT trigger_id,label,trigger_type,engaged FROM proactive_log ORDER BY id DESC LIMIT 5").fetchall()
        if plogs: elog("PROACTIVE", f"Recent: {plogs}")
    except: pass
    conn.close()

def recall(query, expected, label=""):
    stats["chats"] += 1
    resp = type_to_aura(query)
    hit = any(k.lower() in resp.lower() for k in expected)
    if hit: stats["recall_pass"] += 1
    else: stats["recall_fail"] += 1
    elog("RECALL", f"'{label or query}': {'PASS' if hit else 'FAIL'}", result=f"expected={expected} got={resp[:60]}")
    return hit

def open_browser(url, label=""):
    elog("BROWSER", f"Opening {label or url}")
    chrome = "/home/pratay-karali/.cache/puppeteer/chrome/linux-150.0.7871.24/chrome-linux64/chrome"
    subprocess.Popen([chrome,"--no-sandbox","--disable-gpu","--new-window",url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(4)
    vision_check("browser")

def close_browser():
    subprocess.run(["pkill","-f","chrome"], capture_output=True)
    time.sleep(1)
    elog("BROWSER", "Closed")

# ─── SAM's activities (interleaved, random) ───────────────────────────
def act_introduce():
    for m in ["Hi I'm Sam","I'm 39 years old","I live in San Francisco","I'm the CEO of OpenAI","I love coffee and I'm obsessed with AI","I have a cat named Patchwork","I'm learning Rust for my next project"]:
        type_to_aura(m); time.sleep(2)

def act_recall_name(): recall("what is my name?",["sam"],"name")
def act_recall_age(): recall("how old am I?",["39"],"age")
def act_recall_job(): recall("what do I do for work?",["ceo","openai"],"job")
def act_recall_cat(): recall("what is my cat's name?",["patchwork"],"cat")
def act_recall_all(): recall("tell me everything you know about me",["sam","39","francisco","openai","coffee","patchwork","rust"],"synthesis")

def act_stress():
    type_to_aura(random.choice(["ugh this board meeting is stressing me out","I'm feeling really overwhelmed","the investors are going to grill me"]))
    vision_check("stress")

def act_excited():
    type_to_aura(random.choice(["holy shit GPT-5 just passed the bar exam!","the model is working better than we hoped!","this is incredible!"]))
    vision_check("excited")

def act_frustrated():
    type_to_aura(random.choice(["this code keeps crashing","I hate debugging","why is this so hard"]))
    vision_check("frustrated")

def act_happy():
    type_to_aura(random.choice(["just got back from a walk feeling great","the sun is out and I got my coffee","I'm actually really happy right now"]))
    vision_check("happy")

def act_tired():
    type_to_aura(random.choice(["it's getting late I should wrap up","I'm exhausted","I need coffee but I'm too tired"]))
    vision_check("tired")

def act_schedule():
    type_to_aura(random.choice(["remind me to call my board members at 2pm","remind me to review the GPT-5 paper","set a reminder to feed Patchwork"]))

def act_vision_q():
    type_to_aura(random.choice(["what do you see?","what am I doing right now?","can you see my screen?","how do I look?"]))
    vision_check("vision query")

def act_browser():
    urls = [("https://chat.openai.com","ChatGPT"),("https://arxiv.org","Arxiv"),("https://github.com","GitHub"),("https://news.ycombinator.com","HN")]
    url,label = random.choice(urls)
    open_browser(url,label)
    type_to_aura("I'm looking at something on my browser, can you see it?")
    time.sleep(3)
    close_browser()

def act_code():
    elog("WORK","Sam codes")
    code = "import numpy as np\ndef softmax(x):\n    e=np.exp(x-np.max(x))\n    return e/e.sum()\nprint(softmax(np.array([2.1,3.4,0.8])))"
    Path("/tmp/sam_code.py").write_text(code)
    subprocess.run(["python3","/tmp/sam_code.py"],capture_output=True,timeout=10)
    vision_check("coding")

def act_break():
    elog("BREAK","Sam walks away")
    time.sleep(10)
    elog("BREAK","Sam returns")
    type_to_aura("I'm back, got some fresh air")
    vision_check("back from break")

def act_correction():
    type_to_aura("my cat's name is Patchwork")
    time.sleep(1)
    type_to_aura("actually my cat's name is Patches")
    time.sleep(1)
    recall("what is my cat's name?",["patches"],"correction")

def act_new_fact():
    type_to_aura(random.choice(["I'm reading Thinking Fast and Slow","I just moved to Mission District","I'm allergic to shellfish","my favorite language is Python"]))

def act_random():
    type_to_aura(random.choice(["what's the meaning of life?","do you dream?","tell me something interesting","I'm bored"]))

def act_multiturn():
    type_to_aura("what did I do today?")
    time.sleep(2)
    type_to_aura("how was I feeling earlier?")
    time.sleep(2)
    type_to_aura("what should I work on next?")

ACTS = [act_introduce,act_recall_name,act_recall_age,act_recall_job,act_recall_cat,
        act_recall_all,act_stress,act_excited,act_frustrated,act_happy,act_tired,
        act_schedule,act_vision_q,act_browser,act_code,act_break,act_correction,
        act_new_fact,act_random,act_multiturn,
        act_code,act_browser,act_stress,act_excited,act_vision_q,act_vision_q,
        act_recall_name,act_recall_cat,act_recall_all,act_new_fact]

def main():
    global START
    START = datetime.now()
    END = START + timedelta(minutes=DURATION)
    print(f"\n{'='*70}")
    print(f"  SAM LIVE BAR TEST — {DURATION}min")
    print(f"  Start: {START.strftime('%H:%M:%S')}  DB: {DB_PATH}")
    print(f"{'='*70}\n")

    # Phase 1: Introduce Sam
    elog("PHASE","Phase 1: Sam introduces himself to AURA")
    act_introduce()
    check_db()
    time.sleep(5)

    # Phase 2: Interleaved random
    elog("PHASE","Phase 2: Interleaved activities")
    count = 0
    while datetime.now() < END:
        elapsed = (datetime.now()-START).total_seconds()/60
        elog("STATUS",f"{elapsed:.1f}min/{DURATION}min | chats={stats['chats']} facts={stats['facts']} proactive={stats['proactive']} emotions={stats['emotions']} ocr={stats['ocr']} recall={stats['recall_pass']}/{stats['recall_pass']+stats['recall_fail']}")
        act = random.choice(ACTS)
        try: act(); count+=1
        except Exception as e: elog("ERROR",str(e))
        if count%3==0: check_db()
        if count%5==0: vision_check(f"periodic #{count}")
        time.sleep(random.uniform(20,60))

    # Final
    elog("PHASE","Phase 3: Final analysis")
    check_db()
    recall("tell me everything you know about me",["sam"],"final synthesis")
    vision_check("final")

    print(f"\n{'='*70}")
    print(f"  FINAL REPORT")
    print(f"{'='*70}")
    print(f"  Duration: {(datetime.now()-START).total_seconds()/60:.1f}min")
    print(f"  Chats: {stats['chats']}")
    print(f"  Recall: {stats['recall_pass']}/{stats['recall_pass']+stats['recall_fail']}")
    print(f"  Emotions: {stats['emotions']}")
    print(f"  OCR: {stats['ocr']}")
    print(f"  Objects: {stats['objects']}")
    print(f"  Gestures: {stats['gestures']}")
    print(f"  Emotion timeline: {len(emotion_timeline)}")
    for e in emotion_timeline: print(f"    {e['time']} {e['emotion']} ({e['conf']*100:.0f}%)")
    print(f"{'='*70}")

    Path(LOG).write_text(json.dumps({"stats":stats,"log":log,"emotion_timeline":emotion_timeline,"proactive_events":proactive_events},indent=2,default=str))
    print(f"Log: {LOG}")

if __name__ == "__main__":
    import signal,sys
    def h(sig,frame):
        Path(LOG).write_text(json.dumps({"stats":stats,"log":log,"emotion_timeline":emotion_timeline},indent=2,default=str))
        sys.exit(0)
    signal.signal(signal.SIGINT,h)
    main()
