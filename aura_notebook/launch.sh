#!/bin/bash
# Launch AURA notebook (debug bundle) with Aura-Aria (LFM2.5-VL-450M).
set -euo pipefail
cd "$(dirname "$0")"

export MKL_PATH="${MKL_PATH:-/usr/lib/x86_64-linux-gnu}"
export LD_LIBRARY_PATH="$(pwd)/linux_libs:${MKL_PATH}:${LD_LIBRARY_PATH:-}"
if [ -f "$MKL_PATH/libmkl_rt.so" ]; then
  export LD_PRELOAD="${MKL_PATH}/libmkl_rt.so${LD_PRELOAD:+:$LD_PRELOAD}"
  # GNU OpenMP layer when available (Debian/Ubuntu oneAPI runtime layout).
  if [ -f "$MKL_PATH/libmkl_gnu_thread.so" ]; then
    export LD_PRELOAD="${MKL_PATH}/libmkl_gnu_thread.so:${MKL_PATH}/libmkl_core.so:${LD_PRELOAD}"
    export MKL_THREADING_LAYER=GNU
  fi
fi

# Software rendering — prevents OpenGL compositor crash on headless/servers
export ENABLE_SKIA_SOFTWARE=1
export FLUTTER_ENGINE_SWITCHES="--enable-software-rendering"

# Camera and proactive off by default to prevent YOLO/camera spam.
# Set AURA_CAMERA_OFF=0 to re-enable, AURA_PROACTIVE_OFF=0 for proactive.
export AURA_CAMERA_OFF="${AURA_CAMERA_OFF:-1}"
export AURA_PROACTIVE_OFF="${AURA_PROACTIVE_OFF:-1}"

# Flutter/CMake install requires this even when empty.
mkdir -p build/native_assets/linux

# Aura-Aria chat model + VLM mmproj (not bundled in APK/pubspec).
ARIA_DIR="aura-aria-gguf"
ARIA_MODEL="LFM2.5-VL-450M.Q4_K_M.gguf"
ARIA_MMPROJ="LFM2.5-VL-450M.F16-mmproj.gguf"
BUNDLE_ASSETS="build/linux/x64/debug/bundle/data/flutter_assets/assets"
SRC_ARIA="assets/${ARIA_DIR}"

stage_file() {
  local src="$1" dest="$2"
  if [ -f "$src" ] && [ ! -f "$dest" ]; then
    mkdir -p "$(dirname "$dest")"
    echo "[launch.sh] staging $(basename "$src") into bundle assets..."
    cp -n "$src" "$dest"
  fi
}

if [ -d "$BUNDLE_ASSETS" ]; then
  stage_file "${SRC_ARIA}/${ARIA_MODEL}" "${BUNDLE_ASSETS}/${ARIA_DIR}/${ARIA_MODEL}"
  stage_file "${SRC_ARIA}/${ARIA_MMPROJ}" "${BUNDLE_ASSETS}/${ARIA_DIR}/${ARIA_MMPROJ}"
  # Embedder (semantic memory) if missing from bundle
  stage_file "assets/embedder/model_quantized.onnx" "${BUNDLE_ASSETS}/embedder/model_quantized.onnx"
  stage_file "assets/embedder/tokenizer.json" "${BUNDLE_ASSETS}/embedder/tokenizer.json"
fi

# Point VLM at Aria weights when camera is on (optional env override still wins).
export AURA_VLM_MODEL_PATH="${AURA_VLM_MODEL_PATH:-$(pwd)/assets/${ARIA_DIR}/${ARIA_MODEL}}"
export AURA_VLM_MMPROJ_PATH="${AURA_VLM_MMPROJ_PATH:-$(pwd)/assets/${ARIA_DIR}/${ARIA_MMPROJ}}"

BIN="build/linux/x64/debug/bundle/aura_notebook"
if [ ! -x "$BIN" ]; then
  echo "[launch.sh] debug bundle missing — building (flutter build linux --debug)..."
  # CMake install requires this dir even when empty (Flutter native assets).
  mkdir -p build/native_assets/linux
  flutter build linux --debug
fi

# Always stage after build in case this is first successful build
if [ -d "$BUNDLE_ASSETS" ]; then
  stage_file "${SRC_ARIA}/${ARIA_MODEL}" "${BUNDLE_ASSETS}/${ARIA_DIR}/${ARIA_MODEL}"
  stage_file "${SRC_ARIA}/${ARIA_MMPROJ}" "${BUNDLE_ASSETS}/${ARIA_DIR}/${ARIA_MMPROJ}"
  stage_file "assets/embedder/model_quantized.onnx" "${BUNDLE_ASSETS}/embedder/model_quantized.onnx"
  stage_file "assets/embedder/tokenizer.json" "${BUNDLE_ASSETS}/embedder/tokenizer.json"
fi
# Prefer piper TTS from source assets (model lives under aura-aria-gguf/)
export AURA_TTS_MODEL_DIR="${AURA_TTS_MODEL_DIR:-$(pwd)/assets/piper}"

# Keep lib in sync with latest rust build when present
if [ -f linux_libs/libaura_lnn.so ] && [ -d "build/linux/x64/debug/bundle/lib" ]; then
  cp -f linux_libs/libaura_lnn.so build/linux/x64/debug/bundle/lib/libaura_lnn.so
fi

exec "./$BIN"
