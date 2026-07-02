#!/bin/bash

# 1. Path to Intel MKL libraries
export MKL_PATH=/opt/intel/oneapi/mkl/latest/lib/intel64

# 2. Path to your compiled Rust library
export RUST_LIB_PATH="$(pwd)/linux_libs"
if [ ! -d "$RUST_LIB_PATH" ]; then
  export RUST_LIB_PATH="$(pwd)/build/linux/x64/release/bundle/lib"
fi

# 3. Add both to the Library Path
export LD_LIBRARY_PATH=$RUST_LIB_PATH:$MKL_PATH:$LD_LIBRARY_PATH

# 4. Preload MKL RT
export LD_PRELOAD=$MKL_PATH/libmkl_rt.so

# Software rendering — prevents OpenGL compositor crash
export ENABLE_SKIA Software=1
export FLUTTER_ENGINE_SWITCHES="--enable-software-rendering"

# Camera and proactive off by default to prevent YOLO/camera spam.
export AURA_CAMERA_OFF="${AURA_CAMERA_OFF:-1}"
export AURA_PROACTIVE_OFF="${AURA_PROACTIVE_OFF:-1}"

# 5. Stage the GGUF chat model into the bundle's flutter_assets dir if it
# isn't already there. The model is intentionally NOT bundled by `flutter build`
# (keeping it out of the Android APK that shares this pubspec), so a packaged
# Linux run needs it copied in once.
BUNDLE_ASSETS="build/linux/x64/release/bundle/data/flutter_assets/assets"
SRC_MODEL="assets/LFM2.5-230M-Q4_K_M.gguf"
DEST_MODEL="$BUNDLE_ASSETS/LFM2.5-230M-Q4_K_M.gguf"
if [ ! -f "$DEST_MODEL" ] && [ -f "$SRC_MODEL" ]; then
  echo "[launch_aura.sh] staging GGUF into bundle assets..."
  cp -n "$SRC_MODEL" "$DEST_MODEL"
fi

# 6. Run the app
./build/linux/x64/release/bundle/aura_notebook
