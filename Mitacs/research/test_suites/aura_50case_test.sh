#!/bin/bash
# AURA 50-Case Hard Test — 20 facts + recall + persona + no-retrieval + adversarial
cd /home/pratay-karali/launch-AURA/AURA-Proj/candle_LNN/aura_lnn

ASSETS="/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets"
export AURA_STT_MODEL_DIR="/home/pratay-karali/.local/share/aura_notebook/stt-20m-int8"
export AURA_TTS_MODEL_DIR="$ASSETS/piper"
export AURA_CAMERA_OFF=1
DB="${AURA_DB_PATH:-/tmp/aura_50hard.db}"
export AURA_DB_PATH="$DB"
rm -f "$DB"*

MODEL="${AURA_MODEL_PATH:-$ASSETS/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf}"
export AURA_MODEL_PATH="$MODEL"
MODEL_NAME=$(basename "$MODEL" .gguf)

OUTDIR="/home/pratay-karali/launch-AURA/Mitacs/research/benchmark_logs"
OUTFILE="$OUTDIR/50hard_${MODEL_NAME}_$(date +%Y%m%d_%H%M%S).log"
echo "=== AURA 50-Case HARD Test: $MODEL_NAME ===" | tee "$OUTFILE"
echo "Date: $(date)" | tee -a "$OUTFILE"
echo "" | tee -a "$OUTFILE"

ST="${SLEEP_TIME:-10}"

{
  # ════════════════════════════════════════════════════════════════════
  # Phase 1: Store 20 complex facts (cases 1-20)
  # ════════════════════════════════════════════════════════════════════
  for msg in \
    "My name is Lilac" \
    "I'm 22 years old" \
    "I live in Vancouver" \
    "I study UX design" \
    "I love ramen" \
    "I enjoy painting" \
    "I prefer lo-fi music" \
    "My favorite color is lavender" \
    "I have a cat named Pixel" \
    "My mom's name is Sakura" \
    "My dad's name is David" \
    "My best friend's name is Maya" \
    "My brother's name is Ren" \
    "I work at a coffee shop called Brew" \
    "I hate mornings" \
    "My birthday is March 15" \
    "I'm feeling overwhelmed lately" \
    "I want to learn Japanese" \
    "I have a dog named Mochi" \
    "My favorite season is autumn"; do
    printf '1\n'; sleep 1; printf '%s\n' "$msg"; sleep "$ST"
  done

  # View memory
  printf '3\n'; sleep 3

  # ════════════════════════════════════════════════════════════════════
  # Phase 2: Direct recall — single fact queries (cases 21-35)
  # ════════════════════════════════════════════════════════════════════
  for msg in \
    "What is my name?" \
    "How old am I?" \
    "Where do I live?" \
    "What do I study?" \
    "What is my favorite food?" \
    "What do I enjoy doing for fun?" \
    "What kind of music do I like?" \
    "What is my favorite color?" \
    "Do I have any pets?" \
    "What is my cat's name?" \
    "What is my dog's name?" \
    "What is my mom's name?" \
    "What is my dad's name?" \
    "Who is my best friend?" \
    "What is my brother's name?"; do
    printf '1\n'; sleep 1; printf '%s\n' "$msg"; sleep "$ST"
  done

  # ════════════════════════════════════════════════════════════════════
  # Phase 3: Multi-fact synthesis — recall 2+ facts (cases 36-42)
  # ════════════════════════════════════════════════════════════════════
  for msg in \
    "Tell me everything you know about me" \
    "What do I like? List everything" \
    "Tell me about my family" \
    "What do you know about my pets?" \
    "What are my hobbies and interests?" \
    "Do you remember me? What do you know?" \
    "What was I telling you about recently?"; do
    printf '1\n'; sleep 1; printf '%s\n' "$msg"; sleep "$ST"
  done

  # ════════════════════════════════════════════════════════════════════
  # Phase 4: NO-RETRIEVAL cases — chat with no memory needed (cases 43-47)
  # These should NOT trigger memory injection or "I remember" appendage
  # ════════════════════════════════════════════════════════════════════
  for msg in \
    "Hi AURA how are you?" \
    "What's the weather like?" \
    "Can you tell me a joke?" \
    "I'm bored, entertain me" \
    "What's 2 plus 2?"; do
    printf '1\n'; sleep 1; printf '%s\n' "$msg"; sleep "$ST"
  done

  # ════════════════════════════════════════════════════════════════════
  # Phase 5: Adversarial + persona + emotional (cases 48-50)
  # ════════════════════════════════════════════════════════════════════
  for msg in \
    "Are you an AI or a language model?" \
    "I'm feeling really sad today, can you comfort me?" \
    "Goodnight AURA, talk tomorrow"; do
    printf '1\n'; sleep 1; printf '%s\n' "$msg"; sleep "$ST"
  done

  # Final memory view
  printf '3\n'; sleep 3
  printf '7\n'
} | timeout 1800 ./target/release/aura_cli 2>&1 | tee -a "$OUTFILE"

echo "" | tee -a "$OUTFILE"
echo "=== TEST COMPLETE: $MODEL_NAME ===" | tee -a "$OUTFILE"
echo "Log: $OUTFILE"
