use std::path::{Path, PathBuf};

use ort::session::Session;

pub const YOLO_URL: &str =
    "https://github.com/ultralytics/assets/releases/download/v8.4.0/yolov8n.onnx";
pub const POSE_URL: &str =
    "https://huggingface.co/Xenova/yolov8n-pose/resolve/main/onnx/model.onnx";
pub const EMOTION_URL: &str =
    "https://github.com/onnx/models/raw/main/validated/vision/body_analysis/emotion_ferplus/model/emotion-ferplus-8.onnx";

pub const COCO_CLASSES: [&str; 80] = [
    "person",
    "bicycle",
    "car",
    "motorcycle",
    "airplane",
    "bus",
    "train",
    "truck",
    "boat",
    "traffic light",
    "fire hydrant",
    "stop sign",
    "parking meter",
    "bench",
    "bird",
    "cat",
    "dog",
    "horse",
    "sheep",
    "cow",
    "elephant",
    "bear",
    "zebra",
    "giraffe",
    "backpack",
    "umbrella",
    "handbag",
    "tie",
    "suitcase",
    "frisbee",
    "skis",
    "snowboard",
    "sports ball",
    "kite",
    "baseball bat",
    "baseball glove",
    "skateboard",
    "surfboard",
    "tennis racket",
    "bottle",
    "wine glass",
    "cup",
    "fork",
    "knife",
    "spoon",
    "bowl",
    "banana",
    "apple",
    "sandwich",
    "orange",
    "broccoli",
    "carrot",
    "hot dog",
    "pizza",
    "donut",
    "cake",
    "chair",
    "couch",
    "potted plant",
    "bed",
    "dining table",
    "toilet",
    "tv",
    "laptop",
    "mouse",
    "remote",
    "keyboard",
    "cell phone",
    "microwave",
    "oven",
    "toaster",
    "sink",
    "refrigerator",
    "book",
    "clock",
    "vase",
    "scissors",
    "teddy bear",
    "hair drier",
    "toothbrush",
];

pub const EMOTION_LABELS: [&str; 8] = [
    "neutral",
    "happiness",
    "surprise",
    "sadness",
    "anger",
    "disgust",
    "fear",
    "contempt",
];

pub fn get_yolo_path() -> PathBuf {
    if let Ok(p) = std::env::var("AURA_YOLO_PATH") {
        return PathBuf::from(p);
    }
    if let Some(m_dir) = crate::api::MODEL_DIR.get() {
        let p = Path::new(m_dir).join("yolov8n.onnx");
        return p;
    }
    let p = PathBuf::from(
        "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/yolov8n.onnx",
    );
    if p.parent().map(|parent| parent.exists()).unwrap_or(false) {
        return p;
    }
    PathBuf::from("assets/yolov8n.onnx")
}

pub fn get_pose_path() -> PathBuf {
    if let Ok(p) = std::env::var("AURA_POSE_PATH") {
        return PathBuf::from(p);
    }
    if let Some(m_dir) = crate::api::MODEL_DIR.get() {
        return Path::new(m_dir).join("yolov8n-pose.onnx");
    }
    let p = PathBuf::from(
        "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/yolov8n-pose.onnx",
    );
    if p.parent().map(|parent| parent.exists()).unwrap_or(false) {
        return p;
    }
    PathBuf::from("assets/yolov8n-pose.onnx")
}

pub fn get_emotion_path() -> PathBuf {
    if let Ok(p) = std::env::var("AURA_EMOTION_PATH") {
        return PathBuf::from(p);
    }
    if let Some(m_dir) = crate::api::MODEL_DIR.get() {
        return Path::new(m_dir).join("emotion-ferplus-8.onnx");
    }
    let p = PathBuf::from(
        "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/emotion-ferplus-8.onnx",
    );
    if p.parent().map(|parent| parent.exists()).unwrap_or(false) {
        return p;
    }
    PathBuf::from("assets/emotion-ferplus-8.onnx")
}

pub fn download_model_if_missing(
    dest_path: &Path,
    url: &str,
    min_bytes: u64,
    label: &str,
) -> anyhow::Result<()> {
    // If file already exists AND is large enough to be a real ONNX model (>100KB), use it.
    if dest_path.exists() {
        let sz = std::fs::metadata(dest_path).map(|m| m.len()).unwrap_or(0);
        if sz > min_bytes {
            return Ok(());
        }
        eprintln!(
            "[VISION] Removing corrupt/incomplete {} model ({} bytes), re-downloading...",
            label, sz
        );
        let _ = std::fs::remove_file(dest_path);
    }

    eprintln!("[VISION] Downloading {} model to {:?}", label, dest_path);
    if let Some(parent) = dest_path.parent() {
        std::fs::create_dir_all(parent)?;
    }

    // --fail: exit non-zero on HTTP 4xx/5xx so we detect 404 properly
    // -L: follow redirects (GitHub/HuggingFace redirect to CDN)
    let status = std::process::Command::new("curl")
        .arg("--fail")
        .arg("-L")
        .arg("--progress-bar")
        .arg("-o")
        .arg(dest_path)
        .arg(url)
        .status();

    let downloaded = match status {
        Ok(s) if s.success() => true,
        _ => {
            eprintln!("[VISION] curl failed, trying wget...");
            let ws = std::process::Command::new("wget")
                .arg("--show-progress")
                .arg("-O")
                .arg(dest_path)
                .arg(url)
                .status();
            ws.map(|s| s.success()).unwrap_or(false)
        }
    };

    if !downloaded {
        anyhow::bail!("Failed to download {} model from {}", label, url);
    }

    let sz = std::fs::metadata(dest_path).map(|m| m.len()).unwrap_or(0);
    if sz < min_bytes {
        let _ = std::fs::remove_file(dest_path);
        anyhow::bail!(
            "Downloaded {} model is too small ({} bytes) — likely a 404 page. Check your internet connection.",
            label,
            sz
        );
    }

    eprintln!(
        "[VISION] Downloaded {} model ({:.1} MB)",
        label,
        sz as f64 / 1_048_576.0
    );
    Ok(())
}

pub fn load_optional_session(
    label: &str,
    path: &Path,
    url: &str,
    min_bytes: u64,
) -> Option<Session> {
    match download_model_if_missing(path, url, min_bytes, label).and_then(|_| {
        eprintln!("[VISION] Loading {} model from {:?}", label, path);
        Session::builder()
            .map_err(|e| anyhow::anyhow!("ort session builder: {e}"))?
            .with_intra_threads(1)
            .map_err(|e| anyhow::anyhow!("ort intra_threads: {e}"))?
            .commit_from_file(path)
            .map_err(|e| anyhow::anyhow!("ort model load: {e}"))
    }) {
        Ok(session) => Some(session),
        Err(e) => {
            eprintln!(
                "[VISION] Optional {} model unavailable; continuing without it: {:?}",
                label, e
            );
            None
        }
    }
}
