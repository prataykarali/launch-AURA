#!/usr/bin/env python3
"""Real YOLOv8n + pose + emotion detection on webcam photo and screen screenshot."""
import cv2
import numpy as np
import onnxruntime as ort
from pathlib import Path
import json
import sys

YOLO_PATH = "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/yolov8n.onnx"
POSE_PATH = "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/yolov8n-pose.onnx"
EMOTION_PATH = "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/emotion-ferplus-8.onnx"

COCO_CLASSES = [
    "person","bicycle","car","motorcycle","airplane","bus","train","truck","boat",
    "traffic light","fire hydrant","stop sign","parking meter","bench","bird","cat",
    "dog","horse","sheep","cow","elephant","bear","zebra","giraffe","backpack",
    "umbrella","handbag","tie","suitcase","frisbee","skis","snowboard","sports ball",
    "kite","baseball bat","baseball glove","skateboard","surfboard","tennis racket",
    "bottle","wine glass","cup","fork","knife","spoon","bowl","banana","apple",
    "sandwich","orange","broccoli","carrot","hot dog","pizza","donut","cake",
    "chair","couch","potted plant","bed","dining table","toilet","tv","laptop",
    "mouse","remote","keyboard","cell phone","microwave","oven","toaster","sink",
    "refrigerator","book","clock","vase","scissors","teddy bear","hair drier","toothbrush"
]

EMOTION_LABELS = ["neutral","happy","surprise","sad","angry","disgust","fear","contempt"]

def load_yolo(path):
    try:
        return ort.InferenceSession(path, providers=["CPUExecutionProvider"])
    except Exception as e:
        print(f"  [ERROR] Failed to load {path}: {e}")
        return None

def preprocess_yolo(img):
    h, w = img.shape[:2]
    img = cv2.resize(img, (640, 640))
    img = img[:, :, ::-1].transpose(2, 0, 1).astype(np.float32) / 255.0
    img = np.expand_dims(img, 0)
    return img, (w, h)

def run_yolo(session, img):
    inp, (ow, oh) = preprocess_yolo(img)
    out = session.run(None, {session.get_inputs()[0].name: inp})[0]
    # YOLOv8 output: [1, 84, 8400] → transpose to [8400, 84]
    out = out[0].T
    detections = []
    for row in out:
        cx, cy, bw, bh = row[:4]
        scores = row[4:]
        cls_id = int(np.argmax(scores))
        score = float(scores[cls_id])
        if score < 0.25:
            continue
        x1 = int((cx - bw/2) / 640 * ow)
        y1 = int((cy - bh/2) / 640 * oh)
        x2 = int((cx + bw/2) / 640 * ow)
        y2 = int((cy + bh/2) / 640 * oh)
        detections.append({
            "label": COCO_CLASSES[cls_id] if cls_id < len(COCO_CLASSES) else f"class_{cls_id}",
            "confidence": score,
            "bbox": [x1, y1, x2, y2],
        })
    # NMS — suppress overlapping boxes
    detections = nms(detections, iou_threshold=0.45)
    return detections

def nms(dets, iou_threshold=0.45):
    if not dets:
        return []
    dets = sorted(dets, key=lambda x: -x["confidence"])
    keep = []
    while dets:
        best = dets.pop(0)
        keep.append(best)
        dets = [d for d in dets if iou(best["bbox"], d["bbox"]) < iou_threshold]
    return keep

def iou(box1, box2):
    x1 = max(box1[0], box2[0])
    y1 = max(box1[1], box2[1])
    x2 = min(box1[2], box2[2])
    y2 = min(box1[3], box2[3])
    inter = max(0, x2 - x1) * max(0, y2 - y1)
    area1 = (box1[2]-box1[0]) * (box1[3]-box1[1])
    area2 = (box2[2]-box2[0]) * (box2[3]-box2[1])
    union = area1 + area2 - inter
    return inter / union if union > 0 else 0

def preprocess_emotion(img):
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
    faces = face_cascade.detectMultiScale(gray, 1.1, 4)
    return faces, gray

def run_emotion(session, gray, face_bbox):
    x, y, w, h = face_bbox
    face = gray[y:y+h, x:x+w]
    face = cv2.resize(face, (64, 64)).astype(np.float32) / 255.0
    face = np.expand_dims(face, (0, 1))
    out = session.run(None, {session.get_inputs()[0].name: face})[0]
    probs = out[0]
    cls_id = np.argmax(probs)
    return EMOTION_LABELS[cls_id], float(probs[cls_id])

def run_pose(session, img):
    inp, (ow, oh) = preprocess_yolo(img)
    out = session.run(None, {session.get_inputs()[0].name: inp})[0]
    # YOLOv8-pose output: [1, 56, 8400] → [8400, 56]
    # Format: cx, cy, bw, bh, conf, x1,y1,v1, x2,y2,v2, ... x17,y17,v17
    out = out[0].T  # [8400, 56]
    
    best = None
    best_conf = 0
    for row in out:
        conf = row[4] if len(row) > 4 else 0
        if conf > best_conf:
            best_conf = conf
            best = row
    
    if best is None or best_conf < 0.25:
        return None, []
    
    # Extract keypoints: 17 keypoints × 3 (x, y, confidence)
    kpt_data = best[5:]  # Skip bbox + conf
    kpts = []
    for i in range(17):
        if i*3+2 < len(kpt_data):
            kx = kpt_data[i*3] / 640 * ow
            ky = kpt_data[i*3+1] / 640 * oh
            kv = kpt_data[i*3+2]
            kpts.append((kx, ky, kv))
    
    return best[:4], kpts

def analyze_image(image_path, label):
    print(f"\n{'='*70}")
    print(f"  ANALYZING: {label}")
    print(f"  File: {image_path}")
    print(f"{'='*70}")

    img = cv2.imread(str(image_path))
    if img is None:
        print(f"  [ERROR] Could not read image: {image_path}")
        return

    h, w = img.shape[:2]
    print(f"  Image size: {w}x{h}")

    # ── YOLO Object Detection ────────────────────────────────────────
    print(f"\n  [YOLOv8n] Object detection:")
    yolo = load_yolo(YOLO_PATH)
    if yolo:
        dets = run_yolo(yolo, img)
        if dets:
            print(f"    Found {len(dets)} objects:")
            for d in sorted(dets, key=lambda x: -x["confidence"]):
                x1,y1,x2,y2 = d["bbox"]
                print(f"      -> {d['label']} ({d['confidence']*100:.0f}%)  bbox=[{x1},{y1},{x2},{y2}]")
        else:
            print(f"    No objects detected (threshold: 25%)")

        # Draw bounding boxes and save
        for d in dets:
            x1,y1,x2,y2 = d["bbox"]
            color = (0, 255, 0) if d["label"] == "person" else (255, 100, 0)
            cv2.rectangle(img, (x1,y1), (x2,y2), color, 2)
            cv2.putText(img, f"{d['label']} {d['confidence']*100:.0f}%", (x1, y1-5),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 1)
        out_path = f"/tmp/aura_{label}_yolo_annotated.jpg"
        cv2.imwrite(out_path, img)
        print(f"    Annotated image saved: {out_path}")
    else:
        print(f"    [SKIP] YOLO model not loaded")

    # ── Emotion Detection (FER+) ─────────────────────────────────────
    print(f"\n  [FER+] Emotion detection:")
    emotion = load_yolo(EMOTION_PATH)  # reuse loader
    if emotion:
        faces, gray = preprocess_emotion(img)
        if len(faces) > 0:
            print(f"    Found {len(faces)} face(s):")
            for i, (x, y, fw, fh) in enumerate(faces):
                try:
                    label_name, conf = run_emotion(emotion, gray, (x, y, fw, fh))
                    print(f"      Face {i+1}: {label_name} ({conf*100:.0f}%) at [{x},{y},{fw},{fh}]")
                except Exception as e:
                    print(f"      Face {i+1}: emotion inference failed: {e}")
        else:
            print(f"    No faces detected by Haar cascade.")
    else:
        print(f"    [SKIP] Emotion model not loaded")

    # ── Pose Detection ───────────────────────────────────────────────
    print(f"\n  [YOLOv8n-Pose] Pose detection:")
    pose = load_yolo(POSE_PATH)
    if pose:
        try:
            bbox, kpts = run_pose(pose, img)
            if kpts and len(kpts) == 17:
                visible_kpts = [(i, k) for i, k in enumerate(kpts) if k[2] > 0.3]
                print(f"    {len(visible_kpts)}/17 keypoints visible (conf={best_conf if 'best_conf' in dir() else '?'})")
                
                # Keypoint names for reference
                KP_NAMES = ["nose","left_eye","right_eye","left_ear","right_ear",
                           "left_shoulder","right_shoulder","left_elbow","right_elbow",
                           "left_wrist","right_wrist","left_hip","right_hip",
                           "left_knee","right_knee","left_ankle","right_ankle"]
                
                # Print visible keypoints
                for i, k in visible_kpts:
                    print(f"      {KP_NAMES[i]}: ({k[0]:.0f},{k[1]:.0f}) conf={k[2]:.2f}")

                # Gesture check: hands raised above nose
                gestures = []
                nose = kpts[0]
                lwrist = kpts[9]
                rwrist = kpts[10]
                
                if nose[2] > 0.3:
                    if lwrist[2] > 0.3 and lwrist[1] < nose[1]:
                        gestures.append("LEFT HAND RAISED (wave!)")
                    if rwrist[2] > 0.3 and rwrist[1] < nose[1]:
                        gestures.append("RIGHT HAND RAISED (wave!)")
                    
                    # Open palm check: wrist above elbow above shoulder
                    if lwrist[2] > 0.3:
                        lshoulder = kpts[5]
                        lelbow = kpts[7]
                        if lelbow[2] > 0.3 and lshoulder[2] > 0.3:
                            if lwrist[1] < lelbow[1] < lshoulder[1]:
                                gestures.append("LEFT ARM UP (open palm / wave)")
                    if rwrist[2] > 0.3:
                        rshoulder = kpts[6]
                        relbow = kpts[8]
                        if relbow[2] > 0.3 and rshoulder[2] > 0.3:
                            if rwrist[1] < relbow[1] < rshoulder[1]:
                                gestures.append("RIGHT ARM UP (open palm / wave)")

                if gestures:
                    print(f"    *** GESTURES DETECTED: {', '.join(gestures)} ***")
                else:
                    print(f"    No gestures detected (hands not raised)")
                    
                # Posture summary
                if len(visible_kpts) >= 5:
                    print(f"    Posture: person detected with {len(visible_kpts)} keypoints")
            else:
                print(f"    No pose keypoints detected")
        except Exception as e:
            print(f"    Pose inference failed: {e}")
    else:
        print(f"    [SKIP] Pose model not loaded")

    # ── AURA Semantic Understanding ──────────────────────────────────
    print(f"\n  [AURA Semantic Understanding]:")
    if yolo:
        dets = run_yolo(yolo, img)
        labels = [d["label"] for d in dets]
        has = lambda l: l in labels
        has_any = lambda ls: any(has(l) for l in ls)

        if has("person") and has_any(["laptop","keyboard","mouse","tv"]):
            activity = "coding / debugging"
        elif has("person") and has_any(["book","cell phone"]):
            activity = "studying / reading"
        elif has("person"):
            activity = "present / attending"
        elif has_any(["laptop","keyboard","mouse","tv"]):
            activity = "computer use / workspace active"
        else:
            activity = "environment / object observation"

        print(f"    Objects: {labels if labels else 'none'}")
        print(f"    Activity: {activity}")
        if has("person"):
            print(f"    Person detected — AURA knows you're there")
        if has("laptop"):
            print(f"    Laptop detected — AURA knows you're working")
        if has("couch"):
            print(f"    Couch detected — AURA knows you're relaxing")
        if has("tv"):
            print(f"    TV detected — AURA knows you're watching something")

        memory_text = f"vision: activity={activity} objects={labels} source=camera"
        print(f"    Memory text: {memory_text}")

if __name__ == "__main__":
    webcam = Path("/tmp/aura_webcam_photo.jpg")
    screen = Path("/tmp/aura_screen_screenshot.png")

    if webcam.exists():
        analyze_image(webcam, "webcam")
    else:
        print("No webcam photo found!")

    if screen.exists():
        analyze_image(screen, "screen")
    else:
        print("No screen screenshot found!")
