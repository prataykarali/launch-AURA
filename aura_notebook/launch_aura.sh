#!/bin/bash
# Launch AURA notebook (release bundle) with Aura-Aria (LFM2.5-VL-450M).
set -euo pipefail
cd "$(dirname "$0")"

# 1. Path to Intel MKL libraries (oneAPI or distro package)
if [ -d /opt/intel/oneapi/mkl/latest/lib/intel64 ]; then
  export MKL_PATH=/opt/intel/oneapi/mkl/latest/lib/intel64
else
  export MKL_PATH="${MKL_PATH:-/usr/lib/x86_64-linux-gnu}"
fi

# 2. Path to compiled Rust library
export RUST_LIB_PATH="$(pwd)/linux_libs"
if [ ! -d "$RUST_LIB_PATH" ]; then
  export RUST_LIB_PATH="$(pwd)/build/linux/x64/release/bundle/lib"
fi

# 3. Library path
export LD_LIBRARY_PATH="${RUST_LIB_PATH}:${MKL_PATH}:${LD_LIBRARY_PATH:-}"

# 4. Preload MKL RT when present
if [ -f "$MKL_PATH/libmkl_rt.so" ]; then
  export LD_PRELOAD="${MKL_PATH}/libmkl_rt.so${LD_PRELOAD:+:$LD_PRELOAD}"
fi

# Software rendering — prevents OpenGL compositor crash
export ENABLE_SKIA_SOFTWARE=1
export FLUTTER_ENGINE_SWITCHES="--enable-software-rendering"

# Camera and proactive off by default to prevent YOLO/camera spam.
export AURA_CAMERA_OFF="${AURA_CAMERA_OFF:-1}"
export AURA_PROACTIVE_OFF="${AURA_PROACTIVE_OFF:-1}"

# Flutter/CMake install requires this even when empty.
mkdir -p build/native_assets/linux

# 5. Stage Aura-Aria GGUF + mmproj into release bundle assets
ARIA_DIR="aura-aria-gguf"
ARIA_MODEL="LFM2.5-VL-450M.Q4_K_M.gguf"
ARIA_MMPROJ="LFM2.5-VL-450M.F16-mmproj.gguf"
BUNDLE_ASSETS="build/linux/x64/release/bundle/data/flutter_assets/assets"
SRC_ARIA="assets/${ARIA_DIR}"

stage_file() {
  local src="$1" dest="$2"
  if [ -f "$src" ] && [ ! -f "$dest" ]; then
    mkdir -p "$(dirname "$dest")"
    echo "[launch_aura.sh] staging $(basename "$src") into bundle assets..."
    cp -n "$src" "$dest"
  fi
}

if [ -d "$BUNDLE_ASSETS" ]; then
  stage_file "${SRC_ARIA}/${ARIA_MODEL}" "${BUNDLE_ASSETS}/${ARIA_DIR}/${ARIA_MODEL}"
  stage_file "${SRC_ARIA}/${ARIA_MMPROJ}" "${BUNDLE_ASSETS}/${ARIA_DIR}/${ARIA_MMPROJ}"
  stage_file "assets/embedder/model_quantized.onnx" "${BUNDLE_ASSETS}/embedder/model_quantized.onnx"
  stage_file "assets/embedder/tokenizer.json" "${BUNDLE_ASSETS}/embedder/tokenizer.json"
fi

export AURA_VLM_MODEL_PATH="${AURA_VLM_MODEL_PATH:-$(pwd)/assets/${ARIA_DIR}/${ARIA_MODEL}}"
export AURA_VLM_MMPROJ_PATH="${AURA_VLM_MMPROJ_PATH:-$(pwd)/assets/${ARIA_DIR}/${ARIA_MMPROJ}}"

# 6. Build if needed, then run
BIN="build/linux/x64/release/bundle/aura_notebook"
if [ ! -x "$BIN" ]; then
  echo "[launch_aura.sh] release bundle missing — building (flutter build linux --release)..."
  mkdir -p build/native_assets/linux
  flutter build linux --release
fi

if [ -d "$BUNDLE_ASSETS" ]; then
  stage_file "${SRC_ARIA}/${ARIA_MODEL}" "${BUNDLE_ASSETS}/${ARIA_DIR}/${ARIA_MODEL}"
  stage_file "${SRC_ARIA}/${ARIA_MMPROJ}" "${BUNDLE_ASSETS}/${ARIA_DIR}/${ARIA_MMPROJ}"
  stage_file "assets/embedder/model_quantized.onnx" "${BUNDLE_ASSETS}/embedder/model_quantized.onnx"
  stage_file "assets/embedder/tokenizer.json" "${BUNDLE_ASSETS}/embedder/tokenizer.json"
fi
export AURA_TTS_MODEL_DIR="${AURA_TTS_MODEL_DIR:-$(pwd)/assets/piper}"

if [ -f linux_libs/libaura_lnn.so ] && [ -d "build/linux/x64/release/bundle/lib" ]; then
  cp -f linux_libs/libaura_lnn.so build/linux/x64/release/bundle/lib/libaura_lnn.so
fi

exec "./$BIN"
