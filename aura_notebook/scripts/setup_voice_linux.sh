#!/bin/bash
# Setup script for AURA voice dependencies on Linux (Debian/Ubuntu)

echo "🎙️ Setting up AURA voice dependencies..."

# 1. System dependencies
echo "📦 Installing system packages (ffmpeg, pulseaudio-utils, alsa-utils)..."
sudo apt-get update
sudo apt-get install -y ffmpeg pulseaudio-utils alsa-utils

# 2. Whisper (STT)
echo "🧠 Installing OpenAI Whisper via pip..."
pip install openai-whisper

# 3. Piper (TTS)
if ! command -v piper &> /dev/null && [ ! -f "$HOME/.local/bin/piper" ]; then
    echo "🗣️ Piper not found in PATH or ~/.local/bin. Installing..."
    mkdir -p "$HOME/.local/bin"
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR" || exit
    # Download latest piper release (amd64)
    wget https://github.com/rhasspy/piper/releases/download/v1.2.0/piper_amd64.tar.gz
    tar -xf piper_amd64.tar.gz
    cp piper/piper "$HOME/.local/bin/"
    cp piper/lib* "$HOME/.local/bin/" 2>/dev/null || true
    echo "✅ Piper installed to ~/.local/bin/piper"
    cd - > /dev/null
    rm -rf "$TEMP_DIR"
else
    echo "✅ Piper already present."
fi

# Ensure ~/.local/bin is in PATH for the current session (optional hint)
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo "💡 Note: Please add export PATH=\"\$HOME/.local/bin:\$PATH\" to your .bashrc or .zshrc"
fi

echo "✨ Voice setup complete! Please restart AURA."
