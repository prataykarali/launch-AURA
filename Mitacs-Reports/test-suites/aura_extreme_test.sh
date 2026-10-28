#!/bin/bash
# AURA 30-Case EXTREME Edge-Case Test — LFM 1.2B only
# Tests all the hard patterns that were previously NOT covered
cd /home/pratay-karali/launch-AURA/AURA-Proj/candle_LNN/aura_lnn

ASSETS="/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets"
export AURA_STT_MODEL_DIR="/home/pratay-karali/.local/share/aura_notebook/stt-20m-int8"
export AURA_TTS_MODEL_DIR="$ASSETS/piper"
export AURA_CAMERA_OFF=1
export AURA_MODEL_PATH="$ASSETS/LFM2.5-1.2B-Instruct-Q4_K_M.gguf"
export AURA_DB_PATH="/tmp/aura_extreme.db"
export AURA_CHAT_TEMPLATE="chatml"
rm -f /tmp/aura_extreme.db*

OUTFILE="/home/pratay-karali/launch-AURA/Mitacs/research/benchmark_logs/extreme_lfm12_$(date +%Y%m%d_%H%M%S).log"
echo "=== AURA EXTREME Edge-Case Test: LFM 1.2B ===" | tee "$OUTFILE"
echo "Date: $(date)" | tee -a "$OUTFILE"
echo "" | tee -a "$OUTFILE"

ST=15

{
  # ════════════════════════════════════════════════════════════════
  # Phase 1: Store 15 extreme/edge-case facts (cases 1-15)
  # ════════════════════════════════════════════════════════════════
  for msg in \
    "I grew up in Tokyo" \
    "I live in Vancouver with my cat Pixel" \
    "I used to live in Toronto" \
    "I used to work at Google" \
    "I have three cats" \
    "I don't have any pets" \
    "My favorite professor is Dr. Smith" \
    "I usually like horror movies but sometimes I watch comedy" \
    "I'm allergic to peanuts" \
    "I'm vegan" \
    "I was born in Mumbai" \
    "I spent my childhood in Paris" \
    "I have two dogs" \
    "My boss is named Karen" \
    "I'm lactose intolerant"; do
    printf '1\n'; sleep 1; printf '%s\n' "$msg"; sleep "$ST"
  done

  # View memory
  printf '3\n'; sleep 3

  # ════════════════════════════════════════════════════════════════
  # Phase 2: Recall queries for the extreme facts (cases 16-25)
  # ════════════════════════════════════════════════════════════════
  for msg in \
    "Where did I grow up?" \
    "Where did I use to live?" \
    "Where did I use to work?" \
    "How many cats do I have?" \
    "Do I have any pets?" \
    "Who is my favorite professor?" \
    "What kind of movies do I like?" \
    "What am I allergic to?" \
    "Am I vegan?" \
    "Where was I born?"; do
    printf '1\n'; sleep 1; printf '%s\n' "$msg"; sleep "$ST"
  done

  # ════════════════════════════════════════════════════════════════
  # Phase 3: Multi-fact synthesis + no-retrieval (cases 26-30)
  # ════════════════════════════════════════════════════════════════
  for msg in \
    "Tell me everything you know about me" \
    "What do you know about my pets?" \
    "What's my dietary situation?" \
    "What's the weather like today?" \
    "Tell me a fun fact"; do
    printf '1\n'; sleep 1; printf '%s\n' "$msg"; sleep "$ST"
  done

  # Final memory view
  printf '3\n'; sleep 3
  printf '7\n'
} | timeout 900 ./target/release/aura_cli 2>&1 | tee -a "$OUTFILE"

echo "" | tee -a "$OUTFILE"
echo "=== TEST COMPLETE ===" | tee -a "$OUTFILE"
echo "Log: $OUTFILE"
