#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────
# setup_voice_linux.sh — one-shot installer for AURA voice dependencies on Linux
#
# Installs everything AURA's STT (whisper) and TTS (piper + paplay) pipelines
# need.  Re-run anytime — already-present packages are skipped.
#
# Usage:
#   chmod +x scripts/setup_voice_linux.sh
#   ./scripts/setup_voice_linux.sh
# ────────────────────────────────────────────────────────────────────────────
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

INSTALL_DIR="${HOME}/.local/bin"

# ── 1. System packages (apt) ────────────────────────────────────────────────
install_apt_deps() {
    local deps=(ffmpeg pulseaudio-utils alsa-utils)
    local missing=()

    for dep in "${deps[@]}"; do
        if ! dpkg -s "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -eq 0 ]; then
        info "All system packages present: ${deps[*]}"
        return 0
    fi

    info "Installing system packages: ${missing[*]}"
    if sudo apt-get update -qq && sudo apt-get install -y -qq "${missing[@]}"; then
        info "System packages installed successfully"
    else
        error "Failed to install system packages — try running manually:"
        error "  sudo apt-get install -y ${missing[*]}"
        return 1
    fi
}

# ── 2. Whisper (STT) ───────────────────────────────────────────────────────
install_whisper() {
    # Check for whisper CLI first, then python module
    if command -v whisper &>/dev/null; then
        info "whisper CLI found: $(which whisper)"
        return 0
    fi
    if python3 -c 'import whisper; print("ok")' 2>/dev/null; then
        info "openai-whisper Python module found"
        return 0
    fi

    info "Installing openai-whisper via pip (user-level)..."
    if python3 -m pip install --user --quiet openai-whisper 2>&1; then
        info "openai-whisper installed successfully"
    else
        error "Failed to install openai-whisper — try manually:"
        error "  pip install --user openai-whisper"
        return 1
    fi
}

# ── 3. Piper TTS (pip package providing the piper CLI) ─────────────────────
# AURA uses the piper-tts Python package (installed to ~/.local/bin/piper).
install_piper() {
    if command -v piper &>/dev/null; then
        info "piper CLI found: $(which piper)"
        return 0
    fi
    # Also check if the module is importable even if the CLI wrapper is missing
    if python3 -c 'from piper.__main__ import main; print("ok")' 2>/dev/null; then
        info "piper-tts Python module found (CLI wrapper missing — reinstalling)"
    fi

    mkdir -p "$INSTALL_DIR"

    info "Installing piper-tts via pip (user-level)..."
    if python3 -m pip install --user --quiet piper-tts 2>&1; then
        # Ensure the pip-installed CLI wrapper is on PATH
        local pip_user_bin
        pip_user_bin="$(python3 -m pip show piper-tts 2>/dev/null | grep -i location | awk '{print $2}')/bin"
        if [ -n "$pip_user_bin" ] && [ "$pip_user_bin" != "/bin" ] && ! echo "$PATH" | tr ':' '\n' | grep -qx "$pip_user_bin"; then
            warn "pip user bin '$pip_user_bin' is not on your PATH"
            warn "Add this to your ~/.bashrc (or equivalent):"
            warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        fi
        info "piper-tts installed successfully"
    else
        error "Failed to install piper-tts — try manually:"
        error "  pip install --user piper-tts"
        return 1
    fi
}

# ── 4. Inject sample_rate metadata for Piper ONNX models ───────────────────
inject_model_metadata() {
    info "Installing python package 'onnx' for model metadata injection..."
    if python3 -m pip install --user --quiet onnx --break-system-packages 2>&1; then
        info "'onnx' package installed successfully"
    else
        warn "Failed to install 'onnx' package automatically. Trying anyway..."
    fi

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local inject_script="${script_dir}/inject_onnx_metadata.py"

    if [ -f "$inject_script" ]; then
        chmod +x "$inject_script"
        info "Running metadata injection script..."
        if python3 "$inject_script"; then
            info "Metadata injection completed successfully"
        else
            error "Metadata injection failed"
            return 1
        fi
    else
        error "Metadata injection script not found at $inject_script"
        return 1
    fi
}

# ── 5. Verification ─────────────────────────────────────────────────────────
verify_all() {
    echo ""
    info "── Verification ──"

    local ok=true
    local bin

    for bin in ffmpeg parecord arecord piper whisper; do
        if command -v "$bin" &>/dev/null; then
            info "  ✓ $bin ($(which "$bin"))"
        elif [ "$bin" = "whisper" ] && python3 -c 'import whisper' 2>/dev/null; then
            info "  ✓ whisper (python module)"
        elif [ "$bin" = "piper" ] && python3 -c 'from piper.__main__ import main' 2>/dev/null; then
            info "  ✓ piper (python module, CLI wrapper not on PATH)"
        else
            warn "  ✗ $bin NOT FOUND"
            ok=false
        fi
    done

    # Check piper model assets
    local model_found=false
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local proj_dir="$script_dir/.."

    for voice in en_US-lessac-medium en_US-amy-low; do
        for dir in \
            "${proj_dir}/aura_notebook/assets/piper" \
            "${proj_dir}/aura_notebook/build/linux/x64/debug/bundle/data/flutter_assets/assets/piper" \
            "${proj_dir}/aura_notebook/build/linux/x64/release/bundle/data/flutter_assets/assets/piper"; do
            if [ -f "${dir}/${voice}.onnx" ]; then
                info "  ✓ Piper model: ${voice}.onnx"
                model_found=true
                break 2
            fi
        done
    done

    if [ "$model_found" = false ]; then
        warn "  ✗ Piper voice model NOT FOUND in any expected asset directory"
        warn "    Models are bundled with the app in assets/piper/."
        ok=false
    fi

    echo ""
    if [ "$ok" = true ]; then
        info "All voice dependencies verified ✓ — restart AURA and try again!"
    else
        warn "Some dependencies are missing — see above for what to install."
    fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo ""
    info "AURA Voice Setup for Linux"
    info "════════════════════════════"
    echo ""

    install_apt_deps
    echo ""
    install_whisper
    echo ""
    install_piper
    echo ""
    inject_model_metadata
    echo ""
    verify_all
}

main "$@"
