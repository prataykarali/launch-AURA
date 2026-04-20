# Aura Notebook 📒
Professional Flutter-based notebook environment with integrated LNN (Liquid Neural Network) logic.

## 🛠 Prerequisites
This project relies on high-performance mathematical routines. Ensure your Linux environment is prepared:
1. **Intel MKL:** Install the Intel Math Kernel Library runtime.
2. **Flutter SDK:** Ensure you have the latest stable Flutter version.
3. **Build Tools:** clang, cmake, and ninja-build.

## 🚀 Environment Setup
To run the application, you must link the pre-compiled native logic provided in the linux_libs folder.

### 1. Source Intel Variables
Run this to load the necessary MKL paths:
source /opt/intel/oneapi/setvars.sh

### 2. Export Library Paths
Tell the system where to find the custom .so binary:
export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$(pwd)/linux_libs

## 💻 How to Run
Once the environment variables are set, launch the app using:
flutter run -d linux

## 📂 Project Architecture
- lib/: Flutter source code.
- linux_libs/: Pre-compiled libaura_lnn.so.
- assets/: UI assets.
