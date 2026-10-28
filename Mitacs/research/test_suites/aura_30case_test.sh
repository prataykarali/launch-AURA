#!/bin/bash
# AURA 30-case comprehensive test — runs via CLI with memory injection
# Usage: AURA_MODEL_PATH=... AURA_DB_PATH=... bash aura_30case_test.sh
cd /home/pratay-karali/launch-AURA/AURA-Proj/candle_LNN/aura_lnn

ASSETS="/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets"
export AURA_STT_MODEL_DIR="/home/pratay-karali/.local/share/aura_notebook/stt-20m-int8"
export AURA_TTS_MODEL_DIR="$ASSETS/piper"
export AURA_TTS_MODEL_DIR="${AURA_TTS_MODEL_DIR:-$ASSETS/piper}"
DB="${AURA_DB_PATH:-/tmp/aura_30case.db}"
export AURA_DB_PATH="$DB"
rm -f "$DB"*

MODEL="${AURA_MODEL_PATH:-$ASSETS/LFM2.5-1.2B-Instruct-Q4_K_M.gguf}"
export AURA_MODEL_PATH="$MODEL"
MODEL_NAME=$(basename "$MODEL" .gguf)

OUTFILE="/home/pratay-karali/launch-AURA/Mitacs/research/benchmark_logs/30case_${MODEL_NAME}_$(date +%Y%m%d_%H%M%S).log"
echo "=== AURA 30-Case Test: $MODEL_NAME ===" | tee "$OUTFILE"
echo "DB: $DB" | tee -a "$OUTFILE"
echo "Date: $(date)" | tee -a "$OUTFILE"
echo "" | tee -a "$OUTFILE"

# Phase 1: Store facts (cases 7-15), then Phase 2: Recall + persona (1-6, 16-30)
# We store first so recall queries have memory to find
{
  # Store all 9 facts first
  for msg in \
    "My name is Lilac" \
    "I live in Vancouver" \
    "I love ramen" \
    "I enjoy painting" \
    "I have a cat named Pixel" \
    "I prefer lo-fi music" \
    "My favorite color is lavender" \
    "I'm 22 years old" \
    "I study UX design"; do
    printf '1\n'; sleep 1; printf '%s\n' "$msg"; sleep "${SLEEP_TIME:-15}"
  done

  # View memory
  printf '3\n'; sleep 3

  # Now run recall + persona + emotional + farewell + tool cases
  for msg in \
    "Hi AURA" \
    "Hey there" \
    "Good morning" \
    "Who are you?" \
    "What are you?" \
    "Are you an AI?" \
    "What is my name?" \
    "Where do I live?" \
    "What do I like to eat?" \
    "What do I enjoy doing?" \
    "Do I have any pets?" \
    "What do you know about me?" \
    "Tell me about me" \
    "Do you remember me?" \
    "I'm feeling sad" \
    "I just got accepted into my dream program!" \
    "Goodnight AURA" \
    "I'm going to sleep now" \
    "What time is it?" \
    "Are you ChatGPT?" \
    "Do you have feelings?"; do
    printf '1\n'; sleep 1; printf '%s\n' "$msg"; sleep "${SLEEP_TIME:-15}"
  done

  # View final memory
  printf '3\n'; sleep 3
  printf '7\n'
} | timeout 600 ./target/release/aura_cli 2>&1 | tee -a "$OUTFILE"

echo "" | tee -a "$OUTFILE"
echo "=== TEST COMPLETE: $MODEL_NAME ===" | tee -a "$OUTFILE"
echo "Log saved to: $OUTFILE"
