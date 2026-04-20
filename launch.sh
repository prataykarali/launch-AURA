#!/bin/bash
export MKL_PATH=/usr/lib/x86_64-linux-gnu
export LD_LIBRARY_PATH=$MKL_PATH:$LD_LIBRARY_PATH
export LD_PRELOAD="$MKL_PATH/libmkl_rt.so:$MKL_PATH/libmkl_gnu_thread.so:$MKL_PATH/libmkl_core.so"
export MKL_THREADING_LAYER=GNU
./build/linux/x64/release/bundle/aura_notebook
