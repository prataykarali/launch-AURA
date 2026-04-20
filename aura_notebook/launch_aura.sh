#!/bin/bash

# 1. Path to Intel MKL libraries
export MKL_PATH=/opt/intel/oneapi/mkl/latest/lib/intel64

# 2. Path to your compiled Rust library (based on your error log)
export RUST_LIB_PATH=/home/pratay-karali/launch-AURA/AURA-Proj/candle_LNN/aura_lnn/target/release

# 3. Add both to the Library Path
export LD_LIBRARY_PATH=$RUST_LIB_PATH:$MKL_PATH:$LD_LIBRARY_PATH

# 4. Preload MKL RT (This often fixes 'undefined symbol' issues with MKL)
export LD_PRELOAD=$MKL_PATH/libmkl_rt.so

# 5. Run the app
./build/linux/x64/release/bundle/aura_notebook
