#!/bin/bash
set -e

echo "Building Rust library for Android targets..."
cd "$(dirname "$0")"

# Set Android NDK path for compiler
export ANDROID_NDK_ROOT=/home/pratay-karali/Android/Sdk/ndk/30.0.14904198

# Patch llama.cpp in the cargo cache so it builds against the Android NDK.
# The NDK exposes madvise()/MADV_* but not posix_madvise()/POSIX_MADV_*.
# This only touches the Android-specific code path in llama-mmap.cpp.
LLAMA_SYS_DIR="$HOME/.cargo/git/checkouts/llama-cpp-rs-274405c613038803/c8f19f8/llama-cpp-sys-2"
MMAP_FILE="$LLAMA_SYS_DIR/llama.cpp/src/llama-mmap.cpp"
if [ -f "$MMAP_FILE" ]; then
    if ! grep -q "Android NDK exposes madvise" "$MMAP_FILE"; then
        echo "Patching llama.cpp for Android NDK compatibility..."
        python3 - "$MMAP_FILE" <<'PY'
import sys
path = sys.argv[1]
with open(path, 'r') as f:
    text = f.read()
marker = '#include <TargetConditionals.h>\n#endif'
android_block = '''\n#if defined(__ANDROID__)
    // Android NDK exposes madvise/MADV_* but not posix_madvise/POSIX_MADV_*.
    #include <sys/mman.h>
    #define posix_madvise madvise
    #ifndef POSIX_MADV_WILLNEED
        #define POSIX_MADV_WILLNEED MADV_WILLNEED
    #endif
    #ifndef POSIX_MADV_RANDOM
        #define POSIX_MADV_RANDOM MADV_RANDOM
    #endif
#endif'''
if marker in text and 'Android NDK exposes madvise' not in text:
    text = text.replace(marker, marker + android_block, 1)
    with open(path, 'w') as f:
        f.write(text)
    print('patched')
else:
    print('already patched or marker missing')
PY
    else
        echo "llama.cpp Android patch already applied."
    fi
else
    echo "WARNING: could not find llama-mmap.cpp at $MMAP_FILE"
fi

# Compile for ARM64 only (matches abiFilters in build.gradle.kts)
# Disable sherpa-onnx (voice feature) for Android cross-compilation
# Only build the lib (cdylib), not the binaries which need sherpa-onnx
cargo ndk -t aarch64-linux-android -o ../../aura_notebook/android/app/src/main/jniLibs build --lib --release --no-default-features --features cpu

echo "Copying to root workspace android folder as well..."
mkdir -p ../../android/app/src/main/jniLibs/arm64-v8a
cp ../../aura_notebook/android/app/src/main/jniLibs/arm64-v8a/libaura_lnn.so ../../android/app/src/main/jniLibs/arm64-v8a/

echo "Android compilation and linking complete! ✅"
