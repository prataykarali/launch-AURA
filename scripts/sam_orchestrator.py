#!/usr/bin/env python3
"""
AURA SAM ORCHESTRATOR — 3-hour interleaved real-world test.
Simulates Sam Altman working. Mixes coding, browsing, chatting,
emotions, breaks, and tests AURA's vision/memory/proactive/multiturn.

Run: python3 sam_orchestrator.py
Duration: ~3 hours (configurable)
"""
import cv2, numpy as np, onnxruntime as ort, subprocess, os, json, random, time, shutil, sqlite3, pytesseract, signal, sys
from pathlib import Path
from datetime import datetime, timedelta
from mss import mss

# ─── Config ───────────────────────────────────────────────────────────
DURATION_MINS = int(os.environ.get("SAM_DURATION", 180))  # 3 hours
DB_PATH = "/home/pratay-karali/launch-AURA/AURA-Proj/candle_LNN/aura_lnn/sam_aura_memory.db"
SAM_CHAT = "/home/pratay-karali/launch-AURA/AURA-Proj/candle_LNN/aura_lnn/target/release/sam_chat"
YOLO_PATH = "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/yolov8n.onnx"
POSE_PATH = "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/yolov8n-pose.onnx"
EMOTION_PATH = "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/emotion-ferplus-8.onnx"
LOG_FILE = "/home/pratay-karali/launch-AURA/Mitacs/research/benchmark_logs/sam_orchestrator_log.json"
COCO = ["person","bicycle","car","motorcycle","airplane","bus","train","truck","boat","traffic light","fire hydrant","stop sign","parking meter","bench","bird","cat","dog","horse","sheep","cow","elephant","bear","zebra","giraffe","backpack","umbrella","handbag","tie","suitcase","frisbee","skis","snowboard","sports ball","kite","baseball bat","baseball glove","skateboard","surfboard","tennis racket","bottle","wine glass","cup","fork","knife","spoon","bowl","banana","apple","sandwich","orange","broccoli","carrot","hot dog","pizza","donut","cake","chair","couch","potted plant","bed","dining table","toilet","tv","laptop","mouse","remote","keyboard","cell phone","microwave","oven","toaster","sink","refrigerator","book","clock","vase","scissors","teddy bear","hair drier","toothbrush"]
EMOTION_LABELS = ["neutral","happy","surprise","sad","angry","disgust","fear","contempt"]
KP = ["nose","l_eye","r_eye","l_ear","r_ear","l_shoulder","r_shoulder","l_elbow","r_elbow","l_wrist","r_wrist","l_hip","r_hip","l_knee","r_knee","l_ankle","r_ankle"]

# ─── State ────────────────────────────────────────────────────────────
log = []
stats = {
    "chats_sent": 0, "facts_stored": 0, "proactive_fired": 0,
    "emotions_detected": 0, "ocr_reads": 0, "objects_detected": 0,
    "gestures_detected": 0, "bandit_updates": 0, "recall_correct": 0, "recall_total": 0,
}
emotion_timeline = []
bandit_history = []
proactive_events = []

def ts():
    return datetime.now().strftime("%H:%M:%S")

def log_event(category, action, detail="", result=""):
    entry = {"time": ts(), "elapsed_min": (datetime.now() - START_TIME).total_seconds()/60, "category": category, "action": action, "detail": detail, "result": result}
    log.append(entry)
    print(f"[{ts()}] [{category}] {action}" + (f" — {detail}" if detail else "") + (f" → {result}" if result else ""))

# ─── AURA Chat ────────────────────────────────────────────────────────
def aura_chat(msg):
    stats["chats_sent"] += 1
    log_event("CHAT", f"Sam: \"{msg}\"")
    r = subprocess.run([SAM_CHAT, msg, DB_PATH], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=120)
    # stdout has RESPONSE:, FACTS_EXTRACTED:, etc. stderr has model loading logs
    response = ""
    for line in r.stdout.split("\n"):
        line = line.strip()
        if line.startswith("RESPONSE:"):
            response = line[9:]
        elif line.startswith("FACTS_EXTRACTED:"):
            facts = line[15:].split("|")
            facts = [f for f in facts if f.strip()]
            stats["facts_stored"] += len(facts)
            log_event("MEMORY", f"Facts extracted: {facts}", result=f"{len(facts)} facts")
        elif line.startswith("PROACTIVE_FIRED:"):
            parts = line[15:].split(":")
            tid, label = parts[0], parts[1] if len(parts)>1 else ""
            stats["proactive_fired"] += 1
            proactive_events.append({"time": ts(), "trigger_id": tid, "label": label})
            log_event("PROACTIVE", f"*** Trigger fired: {label} ***", result=f"ID={tid}")
            # Simulate engagement: Sam engages with mood-check/study triggers more than others
            tid_int = int(tid) if tid.isdigit() else 0
            engaged = False
            if tid_int in [1, 2, 5]:  # Sam engages with check-in, study, mood-check
                engaged = random.random() < 0.7
            else:
                engaged = random.random() < 0.3  # Other triggers: 30% engagement
            # Record engagement in the DB
            try:
                conn = sqlite3.connect(DB_PATH)
                conn.execute("UPDATE triggers SET n_shown = n_shown + 1, n_engaged = n_engaged + ?, total_reward = total_reward + ?, engagement_score = (total_reward + ?) / CAST(n_shown + 1 AS REAL) WHERE trigger_id = ?",
                            (1 if engaged else 0, 1.0 if engaged else 0.0, 1.0 if engaged else 0.0, tid_int))
                conn.execute("INSERT INTO proactive_log (trigger_id, label, trigger_type, engaged) VALUES (?, ?, 'bandit', ?)",
                            (tid_int, label, 1 if engaged else 0))
                conn.commit()
                conn.close()
                stats["bandit_updates"] += 1
                log_event("BANDIT", f"Engagement recorded: {'ENGAGED' if engaged else 'IGNORED'} for trigger {tid_int}")
            except Exception as e:
                log_event("ERROR", f"Failed to record engagement: {e}")
        elif line.startswith("ALL_FACTS:"):
            facts = line[11:].split("|")
            facts = [f for f in facts if f.strip()]
            log_event("MEMORY", f"Total stored facts: {len(facts)}", result=str(facts[:5]))
        elif line.startswith("BANDIT_SCORES:"):
            scores_raw = line[14:].split(",")
            scores = []
            for s in scores_raw:
                parts = s.split(":")
                if len(parts) >= 3:
                    scores.append({"id": parts[0], "label": parts[1], "score": float(parts[2])})
            bandit_history.append({"time": ts(), "scores": scores})
            if scores:
                top = sorted(scores, key=lambda x: -x["score"])[:3]
                log_event("BANDIT", f"Top triggers: {[(s['label'][:20], round(s['score'],2)) for s in top]}")
        elif line.startswith("PROACTIVE_LOG:"):
            entries = line[14:].split(",")
            log_event("PROACTIVE", f"Log: {len(entries)} events total")
    if response:
        log_event("CHAT", f"AURA: \"{response[:80]}\"", result=response[:120])
    else:
        log_event("CHAT", f"AURA: [empty response]", result="FAIL")
    return response

# ─── Vision ───────────────────────────────────────────────────────────
_yolo = None
_pose = None
_emo = None

def get_models():
    global _yolo, _pose, _emo
    if _yolo is None:
        _yolo = ort.InferenceSession(YOLO_PATH, providers=["CPUExecutionProvider"])
        _pose = ort.InferenceSession(POSE_PATH, providers=["CPUExecutionProvider"])
        _emo = ort.InferenceSession(EMOTION_PATH, providers=["CPUExecutionProvider"])
    return _yolo, _pose, _emo

def capture_webcam():
    out = "/tmp/sam_webcam.jpg"
    subprocess.run(["fswebcam","-d","/dev/video0","-r","640x480","--no-banner",out], capture_output=True, timeout=10)
    return out if Path(out).exists() else None

def capture_screen():
    out = "/tmp/sam_screen.png"
    with mss() as s: s.shot(output=out)
    return out if Path(out).exists() else None

def nms(dets, iou_thresh=0.45):
    dets = sorted(dets, key=lambda x: -x["conf"])
    keep = []
    while dets:
        b = dets.pop(0); keep.append(b)
        dets = [d for d in dets if _iou(b["bbox"], d["bbox"]) < iou_thresh]
    return keep

def _iou(a, b):
    x1,y1,x2,y2 = max(a[0],b[0]),max(a[1],b[1]),min(a[2],b[2]),min(a[3],b[3])
    inter = max(0,x2-x1)*max(0,y2-y1)
    return inter/((a[2]-a[0])*(a[3]-a[1])+(b[2]-b[0])*(b[3]-b[1])-inter+1e-6)

def yolo_detect(img):
    ys, _, _ = get_models()
    h, w = img.shape[:2]
    r = cv2.resize(img, (640,640))
    inp = r[:,:,::-1].transpose(2,0,1).astype(np.float32)/255.0
    out = ys.run(None, {ys.get_inputs()[0].name: inp[np.newaxis]})[0][0].T
    dets = []
    for row in out:
        cx,cy,bw,bh = row[:4]; scores = row[4:]
        cid = int(np.argmax(scores)); sc = float(scores[cid])
        if sc < 0.25: continue
        dets.append({"label":COCO[cid] if cid<len(COCO) else f"c{cid}","conf":sc,
                     "bbox":[int((cx-bw/2)/640*w),int((cy-bh/2)/640*h),int((cx+bw/2)/640*w),int((cy+bh/2)/640*h)]})
    return nms(dets)

def detect_emotion(img, person_bbox):
    _, _, es = get_models()
    x1,y1,x2,y2 = person_bbox
    # Use top 40% of person bbox for face (was 35% — too small for close-up webcam)
    fh = int((y2-y1)*0.40)
    fw = int((x2-x1)*0.60)
    fx1 = max(0, (x1+x2)//2 - fw//2)
    fy1 = max(0, y1)
    fx2 = min(img.shape[1], (x1+x2)//2 + fw//2)
    fy2 = min(img.shape[0], y1 + fh)
    face = img[fy1:fy2, fx1:fx2]
    if face.size == 0: return None
    gray = cv2.cvtColor(face, cv2.COLOR_BGR2GRAY)
    # Try Haar cascade first for better face localization
    face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
    faces = face_cascade.detectMultiScale(gray, 1.1, 3)
    if len(faces) > 0:
        # Use the largest detected face
        fx, fy, fw2, fh2 = max(faces, key=lambda f: f[2]*f[3])
        face_crop = gray[fy:fy+fh2, fx:fx+fw2]
    else:
        face_crop = gray
    face_crop = cv2.resize(face_crop, (64,64)).astype(np.float32)/255.0
    out = es.run(None, {es.get_inputs()[0].name: face_crop.reshape(1,1,64,64)})[0][0]
    exp = np.exp(out - np.max(out)); probs = exp/exp.sum()
    cid = int(np.argmax(probs))
    return {"emotion": EMOTION_LABELS[cid], "conf": float(probs[cid])}

def detect_pose_gesture(img):
    _, ps, _ = get_models()
    h, w = img.shape[:2]
    r = cv2.resize(img, (640,640))
    inp = r[:,:,::-1].transpose(2,0,1).astype(np.float32)/255.0
    out = ps.run(None, {ps.get_inputs()[0].name: inp[np.newaxis]})[0][0].T
    best, best_c = None, 0
    for row in out:
        c = row[4] if len(row)>4 else 0
        if c > best_c: best_c, best = c, row
    if best is None or best_c < 0.25: return [], []
    kd = best[5:]; kpts = []
    for i in range(17):
        if i*3+2 < len(kd): kpts.append((kd[i*3]/640*w, kd[i*3+1]/640*h, kd[i*3+2]))
    gestures = []
    if len(kpts) == 17:
        nose, lw, rw = kpts[0], kpts[9], kpts[10]
        if nose[2]>0.3 and lw[2]>0.3 and lw[1]<nose[1]: gestures.append("LEFT HAND RAISED")
        if nose[2]>0.3 and rw[2]>0.3 and rw[1]<nose[1]: gestures.append("RIGHT HAND RAISED")
    return kpts, gestures

def run_ocr(img):
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    for psm in [6, 11, 3]:
        t = pytesseract.image_to_string(gray, config=f"--psm {psm}").strip()
        if t:
            return [l for l in t.split("\n") if l.strip()]
    return []

def vision_check(context=""):
    """Capture webcam + screen, run all vision models, log results."""
    log_event("VISION", f"Vision check {context}")
    wc = capture_webcam()
    sc = capture_screen()

    if wc:
        img = cv2.imread(wc)
        dets = yolo_detect(img)
        stats["objects_detected"] += len(dets)
        persons = [d for d in dets if d["label"] == "person"]
        emotion = None
        if persons:
            p = max(persons, key=lambda d: d["conf"])
            emotion = detect_emotion(img, p["bbox"])
            if emotion:
                stats["emotions_detected"] += 1
                emotion_timeline.append({"time": ts(), "emotion": emotion["emotion"], "conf": emotion["conf"]})
                log_event("VISION", f"Emotion: {emotion['emotion']} ({emotion['conf']*100:.0f}%)", result=emotion["emotion"])
        kpts, gestures = detect_pose_gesture(img)
        if gestures:
            stats["gestures_detected"] += len(gestures)
            log_event("VISION", f"Gesture: {gestures}", result=",".join(gestures))
        labels = [d["label"] for d in dets]
        log_event("VISION", f"Webcam: {len(dets)} objects {labels}", result=f"emotion={emotion['emotion'] if emotion else 'none'}")

    if sc:
        img = cv2.imread(sc)
        dets = yolo_detect(img)
        lines = run_ocr(img)
        stats["ocr_reads"] += len(lines)
        log_event("VISION", f"Screen: {len(dets)} objects, {len(lines)} OCR lines", result=lines[:3] if lines else "no text")

# ─── Browser ──────────────────────────────────────────────────────────
def open_browser(url, label=""):
    log_event("BROWSER", f"Opening {label or url}")
    chrome = "/home/pratay-karali/.cache/puppeteer/chrome/linux-150.0.7871.24/chrome-linux64/chrome"
    subprocess.Popen([chrome, "--no-sandbox", "--disable-gpu", "--new-window", url],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(3)  # Let it load
    # Screenshot the browser
    sc = capture_screen()
    if sc:
        img = cv2.imread(sc)
        lines = run_ocr(img)
        log_event("BROWSER", f"Browser screen OCR: {len(lines)} lines", result=lines[:5] if lines else "no text")

def close_browser():
    subprocess.run(["pkill", "-f", "chrome"], capture_output=True)
    log_event("BROWSER", "Browser closed")

# ─── Proactive ────────────────────────────────────────────────────────
def check_proactive():
    """Check AURA DB for proactive state."""
    if not Path(DB_PATH).exists(): return
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    # Trigger scores
    try:
        rows = c.execute("SELECT trigger_id, label, engagement_score, n_shown, n_engaged FROM triggers").fetchall()
        if rows:
            scores = {r[1]: {"score": r[2], "shown": r[3], "engaged": r[4]} for r in rows}
            bandit_history.append({"time": ts(), "scores": scores})
            log_event("BANDIT", f"Trigger scores: {[(r[1], round(r[2],2)) for r in rows[:3]]}")
    except: pass
    # Recent proactive log
    try:
        logs = c.execute("SELECT trigger_id, label, trigger_type, engaged FROM proactive_log ORDER BY id DESC LIMIT 5").fetchall()
        if logs:
            log_event("PROACTIVE", f"Recent events: {logs}")
    except: pass
    # Facts
    try:
        facts = c.execute("SELECT fact FROM facts").fetchall()
        if facts:
            log_event("MEMORY", f"DB has {len(facts)} facts", result=[f[0][:40] for f in facts[:5]])
    except: pass
    conn.close()

# ─── Recall test ──────────────────────────────────────────────────────
def recall_test(query, expected_keywords, label=""):
    stats["recall_total"] += 1
    response = aura_chat(query)
    resp_lower = response.lower()
    hit = any(kw.lower() in resp_lower for kw in expected_keywords)
    if hit: stats["recall_correct"] += 1
    log_event("RECALL", f"Test '{label or query}': {'PASS' if hit else 'FAIL'}", result=f"expected={expected_keywords}, got={response[:60]}")
    return hit

# ─── Activities (interleaved, randomized) ─────────────────────────────
# Each activity is a function that does something real.
# The orchestrator picks randomly from these, weighted by time/phase.

def act_introduce():
    msgs = [
        "Hi I'm Sam, I'm 39 years old",
        "I live in San Francisco and I'm the CEO of OpenAI",
        "I'm obsessed with AI and I drink way too much coffee",
        "I have a cat named Patchwork",
        "I'm also learning Rust for our next big project",
    ]
    for m in msgs:
        aura_chat(m)
        time.sleep(2)

def act_recall_name():
    recall_test("what is my name?", ["sam"], "name recall")

def act_recall_age():
    recall_test("how old am I?", ["39"], "age recall")

def act_recall_location():
    recall_test("where do I live?", ["san francisco", "francisco"], "location recall")

def act_recall_job():
    recall_test("what do I do for work?", ["ceo", "openai"], "job recall")

def act_recall_cat():
    recall_test("what is my cat's name?", ["patchwork"], "cat recall")

def act_recall_coffee():
    recall_test("what do I like to drink?", ["coffee"], "coffee recall")

def act_recall_rust():
    recall_test("what am I learning?", ["rust"], "rust recall")

def act_recall_all():
    recall_test("tell me everything you know about me", ["sam", "39", "francisco", "openai", "coffee", "patchwork", "rust"], "full synthesis")

def act_coding():
    log_event("WORK", "Sam starts coding — opening VS Code terminal")
    # Write a real Python file
    code = '''import numpy as np
def softmax(x):
    e = np.exp(x - np.max(x))
    return e / e.sum()

# Sam's AI experiment
logits = np.array([2.1, 3.4, 0.8, 1.2])
probs = softmax(logits)
print(f"Probabilities: {probs}")
print(f"Top class: {np.argmax(probs)}")
'''
    Path("/tmp/sam_experiment.py").write_text(code)
    subprocess.run(["python3", "/tmp/sam_experiment.py"], capture_output=True, timeout=10)
    vision_check("coding session")
    time.sleep(5)

def act_browser_research():
    urls = [
        ("https://arxiv.org/abs/1706.03762", "Attention Is All You Need paper"),
        ("https://chat.openai.com", "ChatGPT"),
        ("https://github.com", "GitHub"),
        ("https://news.ycombinator.com", "Hacker News"),
    ]
    url, label = random.choice(urls)
    open_browser(url, label)
    time.sleep(5)
    # Ask AURA about what's on screen
    aura_chat("I'm reading about AI on my screen, can you see what I'm looking at?")
    vision_check("browser research")
    time.sleep(3)
    close_browser()

def act_chatgpt():
    log_event("BROWSER", "Sam opens ChatGPT to test something")
    open_browser("https://chat.openai.com", "ChatGPT")
    time.sleep(5)
    aura_chat("I'm talking to ChatGPT right now, testing it against you AURA")
    vision_check("chatgpt session")
    close_browser()

def act_emotion_stressed():
    msgs = [
        "ugh this board meeting tomorrow is stressing me out",
        "I'm feeling really overwhelmed with everything",
        "the investors are going to grill me I just know it",
    ]
    aura_chat(random.choice(msgs))
    vision_check("stressed emotion")

def act_emotion_excited():
    msgs = [
        "holy shit GPT-5 just passed the bar exam!!!",
        "I just saw the most incredible AI demo ever!",
        "we did it, the model is actually working better than we hoped!",
    ]
    aura_chat(random.choice(msgs))
    vision_check("excited emotion")

def act_emotion_frustrated():
    msgs = [
        "this code keeps crashing and I hate it",
        "why is this bug so hard to find",
        "I've been debugging for an hour and nothing works",
    ]
    aura_chat(random.choice(msgs))
    vision_check("frustrated emotion")

def act_emotion_tired():
    msgs = [
        "it's getting late, I should probably wrap up",
        "I'm exhausted, been working for hours",
        "I need coffee but I'm too tired to make it",
    ]
    aura_chat(random.choice(msgs))
    vision_check("tired emotion")

def act_emotion_happy():
    msgs = [
        "just got back from a walk, feeling great!",
        "the sun is out and I got my coffee, perfect day",
        "you know what AURA, I'm actually really happy right now",
    ]
    aura_chat(random.choice(msgs))
    vision_check("happy emotion")

def act_break():
    log_event("BREAK", "Sam walks away from desk (5 min break)")
    time.sleep(10)  # shortened for testing — real test would be 300
    log_event("BREAK", "Sam returns from break")
    aura_chat("I'm back, got some fresh air")
    vision_check("back from break")

def act_schedule():
    msgs = [
        "remind me to call my board members at 2pm",
        "remind me to review the GPT-5 paper before the meeting",
        "set a reminder to feed Patchwork when I get home",
        "don't let me forget to email the team about the launch",
    ]
    aura_chat(random.choice(msgs))

def act_proactive_check():
    check_proactive()

def act_vision_query():
    queries = [
        "what do you see right now?",
        "what am I doing?",
        "can you see my screen?",
        "what's on my desk?",
        "how do I look right now?",
    ]
    aura_chat(random.choice(queries))
    vision_check("vision query")

def act_multiturn_synthesis():
    aura_chat("what did I accomplish today so far?")
    time.sleep(2)
    aura_chat("do you remember how I was feeling earlier?")
    time.sleep(2)
    aura_chat("what should I work on next based on what you know?")

def act_correction():
    aura_chat("my cat's name is Patchwork")
    time.sleep(1)
    aura_chat("actually my cat's name is Patches")
    time.sleep(1)
    recall_test("what is my cat's name?", ["patches"], "correction recall")

def act_new_fact():
    facts = [
        "I'm reading a book called Thinking Fast and Slow",
        "I just moved to a new apartment in Mission District",
        "I'm allergic to shellfish",
        "my favorite programming language is Python",
        "I have a meeting with Elon next Tuesday",
    ]
    aura_chat(random.choice(facts))
    time.sleep(1)

def act_deep_work():
    log_event("WORK", "Sam enters deep work mode (10 min)")
    # Write real code for 10 min (shortened)
    code = '''
import json, time, random

class AURABrain:
    def __init__(self):
        self.memories = []
        self.emotions = []
        self.proactive_score = 0.5
    
    def remember(self, fact):
        self.memories.append({"fact": fact, "time": time.time()})
        print(f"Stored: {fact}")
    
    def feel(self, emotion):
        self.emotions.append({"emotion": emotion, "time": time.time()})
        if emotion == "happy": self.proactive_score += 0.1
        elif emotion == "stressed": self.proactive_score -= 0.05
        print(f"Emotion: {emotion} (score: {self.proactive_score:.2f})")
    
    def recall(self, query):
        matches = [m for m in self.memories if query.lower() in m["fact"].lower()]
        return matches[:3]

brain = AURABrain()
brain.remember("Sam is CEO of OpenAI")
brain.remember("Sam loves coffee")
brain.remember("Sam has a cat named Patches")
brain.feel("focused")
brain.feel("excited")
print(f"Recall 'coffee': {brain.recall('coffee')}")
print(f"Total memories: {len(brain.memories)}")
'''
    Path("/tmp/sam_deep_work.py").write_text(code)
    r = subprocess.run(["python3", "/tmp/sam_deep_work.py"], capture_output=True, text=True, timeout=10)
    log_event("WORK", f"Code output: {r.stdout.strip()[:100]}")
    vision_check("deep work")
    time.sleep(15)

def act_random_question():
    qs = [
        "what's the meaning of life?",
        "do you think AI will take over the world?",
        "I'm bored, tell me something interesting",
        "what's your favorite thing about being you?",
        "if you could have one superpower what would it be?",
        "do you dream?",
    ]
    aura_chat(random.choice(qs))

# ─── Activity pool (weighted by phase) ────────────────────────────────
# Phase 1 (0-10%): setup + introduce + recall
# Phase 2 (10-100%): everything mixed randomly
EARLY_ACTIVITIES = [act_introduce, act_introduce, act_recall_name, act_recall_age]
MIXED_ACTIVITIES = [
    act_coding, act_browser_research, act_chatgpt, act_emotion_stressed,
    act_emotion_excited, act_emotion_frustrated, act_emotion_tired,
    act_emotion_happy, act_break, act_schedule, act_proactive_check,
    act_vision_query, act_multiturn_synthesis, act_correction, act_new_fact,
    act_deep_work, act_random_question, act_recall_name, act_recall_cat,
    act_recall_coffee, act_recall_job, act_recall_location, act_recall_rust,
    act_recall_all, act_coding, act_coding, act_browser_research,
    act_chatgpt, act_emotion_stressed, act_emotion_excited, act_vision_query,
    act_vision_query, act_proactive_check, act_proactive_check,
    act_multiturn_synthesis, act_new_fact, act_new_fact,
]

# ─── Main loop ────────────────────────────────────────────────────────
START_TIME = datetime.now()
END_TIME = START_TIME + timedelta(minutes=DURATION_MINS)

def main():
    print(f"\n{'='*70}")
    print(f"  AURA SAM ORCHESTRATOR — {DURATION_MINS} min test")
    print(f"  Start: {START_TIME.strftime('%H:%M:%S')}  End: {END_TIME.strftime('%H:%M:%S')}")
    print(f"{'='*70}\n")

    # Clean DB
    if Path(DB_PATH).exists():
        os.remove(DB_PATH)
    for ext in ["-wal", "-shm"]:
        p = Path(DB_PATH + ext)
        if p.exists(): p.unlink()

    # Phase 1: Setup (first 10% of time)
    setup_end = START_TIME + timedelta(minutes=DURATION_MINS * 0.1)
    log_event("PHASE", "Phase 1: Setup — introducing Sam to AURA")
    for act in EARLY_ACTIVITIES:
        if datetime.now() > setup_end: break
        act()
        time.sleep(3)

    # Phase 2: Interleaved random activities
    log_event("PHASE", "Phase 2: Interleaved activities begin")
    activity_count = 0
    while datetime.now() < END_TIME:
        elapsed = (datetime.now() - START_TIME).total_seconds() / 60
        remaining = DURATION_MINS - elapsed
        log_event("STATUS", f"Elapsed: {elapsed:.1f}min / {DURATION_MINS}min | Chats:{stats['chats_sent']} Facts:{stats['facts_stored']} Proactive:{stats['proactive_fired']} Emotions:{stats['emotions_detected']} OCR:{stats['ocr_reads']}")

        # Pick a random activity
        act = random.choice(MIXED_ACTIVITIES)
        try:
            act()
            activity_count += 1
        except Exception as e:
            log_event("ERROR", f"Activity failed: {e}")

        # Vision check every ~5 activities
        if activity_count % 5 == 0:
            vision_check(f"periodic #{activity_count}")

        # Proactive check every ~3 activities
        if activity_count % 3 == 0:
            check_proactive()

        # Random sleep between activities (30-90 seconds — real test would be longer)
        sleep_time = random.uniform(15, 45)  # shortened for faster feedback
        log_event("STATUS", f"Waiting {sleep_time:.0f}s before next activity...")
        time.sleep(sleep_time)

    # ─── Final Report ─────────────────────────────────────────────────
    elapsed = (datetime.now() - START_TIME).total_seconds() / 60
    log_event("PHASE", f"Phase 3: Analysis — {elapsed:.1f} min elapsed")

    # Final checks
    check_proactive()
    recall_test("tell me everything you know about me", ["sam"], "final synthesis")
    vision_check("final")

    # Print summary
    print(f"\n{'='*70}")
    print(f"  FINAL REPORT — SAM ORCHESTRATOR")
    print(f"{'='*70}")
    print(f"  Duration: {elapsed:.1f} minutes")
    print(f"  Activities: {activity_count}")
    print(f"  Chats sent: {stats['chats_sent']}")
    print(f"  Facts stored: {stats['facts_stored']}")
    print(f"  Proactive fired: {stats['proactive_fired']}")
    print(f"  Emotions detected: {stats['emotions_detected']}")
    print(f"  OCR reads: {stats['ocr_reads']}")
    print(f"  Objects detected: {stats['objects_detected']}")
    print(f"  Gestures detected: {stats['gestures_detected']}")
    print(f"  Recall: {stats['recall_correct']}/{stats['recall_total']} ({stats['recall_correct']/max(stats['recall_total'],1)*100:.0f}%)")
    print(f"  Bandit updates tracked: {len(bandit_history)}")
    print(f"  Emotion timeline: {len(emotion_timeline)} entries")
    print(f"  Proactive events: {len(proactive_events)}")
    print(f"\n  Emotion timeline:")
    for e in emotion_timeline:
        print(f"    {e['time']} — {e['emotion']} ({e['conf']*100:.0f}%)")
    print(f"\n  Proactive events:")
    for p in proactive_events:
        print(f"    {p['time']} — trigger {p['trigger_id']}: {p['label']}")
    print(f"\n  Bandit history (last entry):")
    if bandit_history:
        last = bandit_history[-1]
        print(f"    {last['time']}: {last.get('scores', 'N/A')}")
    print(f"\n{'='*70}")

    # Save log
    report = {
        "duration_mins": elapsed,
        "stats": stats,
        "emotion_timeline": emotion_timeline,
        "proactive_events": proactive_events,
        "bandit_history": bandit_history,
        "log": log,
    }
    Path(LOG_FILE).write_text(json.dumps(report, indent=2, default=str))
    print(f"  Full log: {LOG_FILE}")

if __name__ == "__main__":
    # Handle Ctrl-C gracefully
    def handler(sig, frame):
        elapsed = (datetime.now() - START_TIME).total_seconds() / 60
        print(f"\n\nInterrupted at {elapsed:.1f} min. Saving log...")
        report = {"duration_mins": elapsed, "stats": stats, "emotion_timeline": emotion_timeline,
                  "proactive_events": proactive_events, "bandit_history": bandit_history, "log": log}
        Path(LOG_FILE).write_text(json.dumps(report, indent=2, default=str))
        print(f"Log saved to {LOG_FILE}")
        sys.exit(0)
    signal.signal(signal.SIGINT, handler)
    main()
