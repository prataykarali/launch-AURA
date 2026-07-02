#!/bin/bash
export MKL_PATH=/usr/lib/x86_64-linux-gnu
export LD_LIBRARY_PATH="$(pwd)/linux_libs:$MKL_PATH:$LD_LIBRARY_PATH"
export LD_PRELOAD="$MKL_PATH/libmkl_rt.so:$MKL_PATH/libmkl_gnu_thread.so:$MKL_PATH/libmkl_core.so"
export MKL_THREADING_LAYER=GNU

# Software rendering — prevents OpenGL compositor crash on headless/servers
export ENABLE_SKIA Software=1
export FLUTTER_ENGINE_SWITCHES="--enable-software-rendering"

# Camera and proactive off by default to prevent YOLO/camera spam.
# Set AURA_CAMERA_OFF=0 to re-enable, AURA_PROACTIVE_OFF=0 for proactive.
export AURA_CAMERA_OFF="${AURA_CAMERA_OFF:-1}"
export AURA_PROACTIVE_OFF="${AURA_PROACTIVE_OFF:-1}"

# Ensure GGUF is in bundle assets if missing (local dev convenience)
BUNDLE_ASSETS="build/linux/x64/debug/bundle/data/flutter_assets/assets"
SRC_MODEL="assets/LFM2.5-1.2B-Instruct-Q4_K_M.gguf"
DEST_MODEL="$BUNDLE_ASSETS/LFM2.5-1.2B-Instruct-Q4_K_M.gguf"

if [ ! -f "$DEST_MODEL" ]; then
    echo "[launch.sh] staging GGUF into bundle assets..."
    cp -n "$SRC_MODEL" "$BUNDLE_ASSETS/"
fi

./build/linux/x64/debug/bundle/aura_notebook
