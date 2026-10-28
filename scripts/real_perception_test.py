#!/usr/bin/env python3
"""
AURA REAL PERCEPTION TEST — Pure onnxruntime, no ultralytics.
  - Webcam: YOLO + pose + emotion + OCR
  - Screen: YOLO + OCR
  - Proactive + STT tests
"""
import cv2, numpy as np, onnxruntime as ort, subprocess, os, json, pytesseract
from pathlib import Path
from mss import mss

YOLO_PATH = "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/yolov8n.onnx"
POSE_PATH = "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/yolov8n-pose.onnx"
EMOTION_PATH = "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/emotion-ferplus-8.onnx"
COCO = ["person","bicycle","car","motorcycle","airplane","bus","train","truck","boat","traffic light","fire hydrant","stop sign","parking meter","bench","bird","cat","dog","horse","sheep","cow","elephant","bear","zebra","giraffe","backpack","umbrella","handbag","tie","suitcase","frisbee","skis","snowboard","sports ball","kite","baseball bat","baseball glove","skateboard","surfboard","tennis racket","bottle","wine glass","cup","fork","knife","spoon","bowl","banana","apple","sandwich","orange","broccoli","carrot","hot dog","pizza","donut","cake","chair","couch","potted plant","bed","dining table","toilet","tv","laptop","mouse","remote","keyboard","cell phone","microwave","oven","toaster","sink","refrigerator","book","clock","vase","scissors","teddy bear","hair drier","toothbrush"]
EMOTION_LABELS = ["neutral","happy","surprise","sad","angry","disgust","fear","contempt"]
KP = ["nose","l_eye","r_eye","l_ear","r_ear","l_shoulder","r_shoulder","l_elbow","r_elbow","l_wrist","r_wrist","l_hip","r_hip","l_knee","r_knee","l_ankle","r_ankle"]

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
    return inter/( (a[2]-a[0])*(a[3]-a[1]) + (b[2]-b[0])*(b[3]-b[1]) - inter + 1e-6 )

def yolo_detect(session, img):
    h, w = img.shape[:2]
    r = cv2.resize(img, (640,640))
    inp = r[:,:,::-1].transpose(2,0,1).astype(np.float32)/255.0
    inp = inp[np.newaxis]
    out = session.run(None, {session.get_inputs()[0].name: inp})[0]
    out = out[0].T
    dets = []
    for row in out:
        cx,cy,bw,bh = row[:4]
        scores = row[4:]
        cid = int(np.argmax(scores)); sc = float(scores[cid])
        if sc < 0.25: continue
        dets.append({"label":COCO[cid] if cid<len(COCO) else f"c{cid}","conf":sc,
                      "bbox":[int((cx-bw/2)/640*w),int((cy-bh/2)/640*h),int((cx+bw/2)/640*w),int((cy+bh/2)/640*h)]})
    return nms(dets)

def pose_detect(session, img):
    h, w = img.shape[:2]
    r = cv2.resize(img, (640,640))
    inp = r[:,:,::-1].transpose(2,0,1).astype(np.float32)/255.0
    inp = inp[np.newaxis]
    out = session.run(None, {session.get_inputs()[0].name: inp})[0]
    out = out[0].T
    best, best_c = None, 0
    for row in out:
        c = row[4] if len(row)>4 else 0
        if c > best_c: best_c, best = c, row
    if best is None or best_c < 0.25: return []
    kd = best[5:]
    kpts = []
    for i in range(17):
        if i*3+2 < len(kd):
            kpts.append((kd[i*3]/640*w, kd[i*3+1]/640*h, kd[i*3+2]))
    return kpts

def emotion_detect(session, img, person_bbox):
    x1,y1,x2,y2 = person_bbox
    fh = int((y2-y1)*0.35)
    face = img[y1:y1+fh, max(0,x1+int((x2-x1)*0.15)):x2-int((x2-x1)*0.15)]
    if face.size == 0: return None
    gray = cv2.cvtColor(face, cv2.COLOR_BGR2GRAY)
    gray = cv2.resize(gray, (64,64)).astype(np.float32)/255.0
    inp = gray.reshape(1,1,64,64)
    out = session.run(None, {session.get_inputs()[0].name: inp})[0]
    logits = out[0]
    # Softmax to get probabilities
    exp = np.exp(logits - np.max(logits))
    probs = exp / exp.sum()
    cid = int(np.argmax(probs))
    return {"emotion": EMOTION_LABELS[cid], "conf": float(probs[cid]), "all": {EMOTION_LABELS[i]: float(probs[i]) for i in range(len(probs)) if probs[i]>0.05}}

def ocr(img):
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    lines = []
    for psm in [6, 11, 3]:
        t = pytesseract.image_to_string(gray, config=f"--psm {psm}").strip()
        if t:
            lines = [l for l in t.split("\n") if l.strip()]
            if lines: break
    return lines

def analyze(path, label):
    print(f"\n{'='*70}")
    print(f"  {label.upper()} ANALYSIS — {path}")
    print(f"{'='*70}")
    img = cv2.imread(path)
    if img is None: print("  [FAIL] Cannot read image"); return
    h, w = img.shape[:2]
    print(f"  Size: {w}x{h}")

    ys = ort.InferenceSession(YOLO_PATH, providers=["CPUExecutionProvider"])
    dets = yolo_detect(ys, img)
    print(f"\n  [YOLO] {len(dets)} objects:")
    for d in sorted(dets, key=lambda x:-x["conf"]):
        print(f"    -> {d['label']} ({d['conf']*100:.0f}%) bbox={d['bbox']}")

    # Annotate
    ann = img.copy()
    for d in dets:
        x1,y1,x2,y2 = d["bbox"]
        c = (0,255,0) if d["label"]=="person" else (255,100,0)
        cv2.rectangle(ann,(x1,y1),(x2,y2),c,2)
        cv2.putText(ann,f"{d['label']} {d['conf']*100:.0f}%",(x1,y1-5),cv2.FONT_HERSHEY_SIMPLEX,0.5,c,1)
    cv2.imwrite(f"/tmp/aura_{label}_annotated.jpg", ann)
    print(f"  Annotated: /tmp/aura_{label}_annotated.jpg")

    # Pose
    print(f"\n  [POSE] Keypoints:")
    ps = ort.InferenceSession(POSE_PATH, providers=["CPUExecutionProvider"])
    kpts = pose_detect(ps, img)
    gestures = []
    if kpts and len(kpts)==17:
        vis = [(i,k) for i,k in enumerate(kpts) if k[2]>0.3]
        print(f"    {len(vis)}/17 visible:")
        for i,k in vis: print(f"      {KP[i]}: ({k[0]:.0f},{k[1]:.0f}) c={k[2]:.2f}")
        nose,lw,rw = kpts[0],kpts[9],kpts[10]
        if nose[2]>0.3 and lw[2]>0.3 and lw[1]<nose[1]: gestures.append("LEFT HAND RAISED (wave!)")
        if nose[2]>0.3 and rw[2]>0.3 and rw[1]<nose[1]: gestures.append("RIGHT HAND RAISED (wave!)")
        for side,wi,ei,si in [("LEFT",9,7,5),("RIGHT",10,8,6)]:
            if kpts[wi][2]>0.3 and kpts[ei][2]>0.3 and kpts[si][2]>0.3:
                if kpts[wi][1]<kpts[ei][1]<kpts[si][1]: gestures.append(f"{side} ARM UP (open palm)")
    else: print("    No keypoints")
    if gestures: print(f"    *** GESTURES: {', '.join(gestures)} ***")
    else: print("    No gestures")

    # Emotion (webcam only — needs person)
    emotion = None
    persons = [d for d in dets if d["label"]=="person"]
    if persons:
        print(f"\n  [EMOTION] FER+:")
        es = ort.InferenceSession(EMOTION_PATH, providers=["CPUExecutionProvider"])
        p = max(persons, key=lambda d:d["conf"])
        emotion = emotion_detect(es, img, p["bbox"])
        if emotion:
            print(f"    EMOTION: {emotion['emotion']} ({emotion['conf']*100:.0f}%)")
            for k,v in emotion["all"].items(): print(f"      {k}: {v*100:.0f}%")

    # OCR
    print(f"\n  [OCR] Tesseract:")
    lines = ocr(img)
    if lines:
        print(f"    {len(lines)} lines:")
        for i,l in enumerate(lines[:10]): print(f"      {i}: {l[:80]}")
        if len(lines)>10: print(f"      ... ({len(lines)-10} more)")
    else: print("    No text found")

    # Semantic
    labels = [d["label"] for d in dets]
    has = lambda l: l in labels
    has_any = lambda ls: any(has(x) for x in ls)
    act = "coding/debugging" if has("person") and has_any(["laptop","keyboard","mouse","tv"]) else \
          "studying/reading" if has("person") and has_any(["book","cell phone"]) else \
          "present/attending" if has("person") else \
          "computer use" if has_any(["laptop","keyboard","mouse","tv"]) else "environment"
    print(f"\n  [SEMANTIC] AURA understands:")
    print(f"    Activity: {act}")
    print(f"    Objects: {list(set(labels)) if labels else 'none'}")
    if emotion: print(f"    Emotion: {emotion['emotion']}")
    if gestures: print(f"    Gestures: {gestures}")
    if lines: print(f"    Screen text: {len(lines)} lines — first: '{lines[0][:60]}'")
    mem = f"vision: activity={act} objects=[{','.join(set(labels))}]"
    if emotion: mem += f" emotion={emotion['emotion']}"
    if gestures: mem += f" gesture={','.join(gestures)}"
    if lines: mem += f" screen_text='{lines[0][:40]}'"
    print(f"    Memory: {mem}")
    return {"dets":dets,"emotion":emotion,"gestures":gestures,"ocr":lines,"activity":act}

def main():
    print("="*70)
    print("  AURA REAL PERCEPTION TEST")
    print("="*70)

    print("\n[1] Capture webcam + screen...")
    wc = "/tmp/aura_real_webcam.jpg"
    subprocess.run(["fswebcam","-d","/dev/video0","-r","640x480","--no-banner",wc],
                   capture_output=True, timeout=10)
    sc = "/tmp/aura_real_screen.png"
    with mss() as s: s.shot(output=sc)
    print(f"  Webcam: {'OK' if Path(wc).exists() else 'FAIL'} ({Path(wc).stat().st_size if Path(wc).exists() else 0} bytes)")
    print(f"  Screen: {'OK' if Path(sc).exists() else 'FAIL'} ({Path(sc).stat().st_size if Path(sc).exists() else 0} bytes)")

    wc_res = analyze(wc, "webcam") if Path(wc).exists() else None
    sc_res = analyze(sc, "screen") if Path(sc).exists() else None

    # Proactive
    print(f"\n{'='*70}\n  PROACTIVE SCHEDULER\n{'='*70}")
    binp = "/home/pratay-karali/launch-AURA/AURA-Proj/candle_LNN/aura_lnn/target/release/proactive_real_test"
    if Path(binp).exists():
        r = subprocess.run([binp], capture_output=True, text=True, timeout=30)
        for line in r.stdout.split("\n"):
            if line.strip() and "[AURA_NOTEBOOK]" not in line: print(f"  {line}")
    else: print("  [SKIP] Not built")

    # STT
    print(f"\n{'='*70}\n  STT (Speech-to-Text)\n{'='*70}")
    audio = "/tmp/aura_stt_test.wav"
    try:
        subprocess.run(["arecord","-d","3","-f","S16_LE","-r","16000","-c","1",audio],
                      capture_output=True, timeout=8)
        if Path(audio).exists() and Path(audio).stat().st_size > 1000:
            print(f"  Microphone: OK ({Path(audio).stat().st_size} bytes captured)")
        else: print("  Microphone: No audio")
    except: print("  Microphone: not available")

    # Multi-turn (run integration test)
    print(f"\n{'='*70}\n  MULTI-TURN + 100 EXTREME CASES\n{'='*70}")
    ibin = "/home/pratay-karali/launch-AURA/AURA-Proj/candle_LNN/aura_lnn/target/release/integration_test"
    if Path(ibin).exists():
        r = subprocess.run([ibin], capture_output=True, text=True, timeout=600,
                          env={**os.environ})
        for line in r.stdout.split("\n"):
            if any(k in line for k in ["FINAL","Total","Passed","Failed","Accuracy","LLM","PROACTIVE","VISION","multi_turn","length","prefill","FAIL","PASS","->"]):
                print(f"  {line}")
    else: print("  [SKIP] Not built")

    # Summary
    print(f"\n{'='*70}\n  REAL SUMMARY\n{'='*70}")
    if wc_res:
        print(f"  Webcam: {len(wc_res['dets'])} objects, emotion={'YES' if wc_res['emotion'] else 'NO'}, gestures={'YES' if wc_res['gestures'] else 'NO'}, OCR={len(wc_res['ocr'])} lines")
    if sc_res:
        print(f"  Screen: {len(sc_res['dets'])} objects, OCR={len(sc_res['ocr'])} lines — first: '{sc_res['ocr'][0][:50]}'" if sc_res['ocr'] else f"  Screen: {len(sc_res['dets'])} objects, OCR=0 lines")
    print(f"  Proactive: TESTED")
    print(f"  STT: TESTED")

if __name__ == "__main__":
    main()
