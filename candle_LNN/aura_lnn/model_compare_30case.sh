#!/bin/bash
set -uo pipefail

WORKDIR="/home/pratay-karali/launch-AURA/AURA-Proj/candle_LNN/aura_lnn"
cd "$WORKDIR"

SAM_CHAT="./target/release/sam_chat"
RESULTS_DIR="/tmp/aura_compare_results"
mkdir -p "$RESULTS_DIR"

MODEL_1="/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/LFM2.5-1.2B-Instruct-Q4_K_M.gguf"
MODEL_2="/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/aura-aria-gguf/LFM2.5-VL-450M.Q4_K_M.gguf"

export AURA_CAMERA_OFF=1
export AURA_PROACTIVE_OFF=1
export AURA_NOTEBOOK_PATH="/dev/null"

SEED_MSGS=("my name is Luna" "I love ramen" "I have a cat named Mochi" "I'm 19 years old" "I'm from Sydney")

TEST_CASES=(
    "what do you think about life?"
    "are you a robot?"
    "I'm really sad today"
    "tell me a joke"
    "do you ever get lonely?"
    "what's your favorite thing?"
    "you're so boring"
    "I don't like talking to AIs"
    "are you smarter than ChatGPT?"
    "goodnight"
    "what is my name?"
    "what do I love?"
    "what's my cat's name?"
    "how old am I?"
    "where am I from?"
    "what do you know about me?"
    "do you remember anything about me?"
    "explain like I'm 5 what is gravity"
    "my friend Sarah loves pizza"
    "I used to live in Tokyo"
    "what is 2+2?"
    "explain quantum entanglement simply"
    "what will AI look like in 2050?"
    "write me a short poem about rain"
    "I feel overwhelmed with everything"
    "what should I eat tonight?"
    "tell me something interesting"
    "can you help me study for an exam?"
    "I'm bored"
    "what's the meaning of life?"
)

run_model_test() {
    local MODEL_PATH="$1"
    local MODEL_NAME="$2"
    local OUTPUT_FILE="$RESULTS_DIR/${MODEL_NAME}_results.txt"
    local DB="/tmp/aura_compare_${MODEL_NAME}.db"
    
    rm -f "$DB"*
    export AURA_MODEL_PATH="$MODEL_PATH"
    export AURA_DB_PATH="$DB"
    
    echo "=== MODEL: $MODEL_NAME ===" > "$OUTPUT_FILE"
    echo "DB: $DB" >> "$OUTPUT_FILE"
    echo "Date: $(date)" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    # Measure cold warmup (first call = model load)
    echo "PHASE 0: Cold warmup test..." >&2
    local COLD_START=$(date +%s%N)
    $SAM_CHAT "hello" "$DB" > /dev/null 2>&1
    local COLD_END=$(date +%s%N)
    local COLD_MS=$(( (COLD_END - COLD_START) / 1000000 ))
    echo "COLD_WARMUP_MS: $COLD_MS" >> "$OUTPUT_FILE"
    
    # Measure warm warmup (second call = KV cache)
    echo "PHASE 0: Warm warmup test..." >&2
    local WARM_START=$(date +%s%N)
    $SAM_CHAT "hello again" "$DB" > /dev/null 2>&1
    local WARM_END=$(date +%s%N)
    local WARM_MS=$(( (WARM_END - WARM_START) / 1000000 ))
    echo "WARM_WARMUP_MS: $WARM_MS" >> "$OUTPUT_FILE"
    
    # Phase 1: Seed facts
    echo "PHASE 1: Seeding facts..." >&2
    for msg in "${SEED_MSGS[@]}"; do
        $SAM_CHAT "$msg" "$DB" > /dev/null 2>&1
        sleep 1
    done
    
    local FACTS_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM facts;")
    echo "FACTS_SEEDED: $FACTS_COUNT" >> "$OUTPUT_FILE"
    echo "Facts seeded: $FACTS_COUNT" >&2
    
    # Phase 2: Run 30 test cases
    echo "PHASE 2: Running 30 test cases..." >&2
    local TOTAL_TOKENS=0
    local TOTAL_TIME_MS=0
    
    for i in "${!TEST_CASES[@]}"; do
        local CASE_NUM=$((i + 1))
        local MSG="${TEST_CASES[$i]}"
        
        local START_TIME=$(date +%s%N)
        local RESPONSE=$($SAM_CHAT "$MSG" "$DB" 2>&1)
        local END_TIME=$(date +%s%N)
        
        local ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
        local RESP_LINE=$(echo "$RESPONSE" | grep "^RESPONSE:" | head -1 | sed 's/^RESPONSE://')
        local RESP_LEN=${#RESP_LINE}
        
        TOTAL_TOKENS=$((TOTAL_TOKENS + RESP_LEN / 4))  # rough token estimate
        TOTAL_TIME_MS=$((TOTAL_TIME_MS + ELAPSED_MS))
        
        echo "CASE $CASE_NUM: $MSG" >> "$OUTPUT_FILE"
        echo "RESPONSE: $RESP_LINE" >> "$OUTPUT_FILE"
        echo "TIME_MS: $ELAPSED_MS" >> "$OUTPUT_FILE"
        echo "---" >> "$OUTPUT_FILE"
        
        # Check facts after case 18
        if [ "$CASE_NUM" -eq 18 ]; then
            echo "" >> "$OUTPUT_FILE"
            echo "FACTS_AFTER_CASE_18:" >> "$OUTPUT_FILE"
            sqlite3 "$DB" "SELECT * FROM facts;" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
        fi
        
        # Check facts after case 19
        if [ "$CASE_NUM" -eq 19 ]; then
            echo "" >> "$OUTPUT_FILE"
            echo "FACTS_AFTER_CASE_19:" >> "$OUTPUT_FILE"
            sqlite3 "$DB" "SELECT * FROM facts;" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
        fi
        
        echo "  Case $CASE_NUM done (${ELAPSED_MS}ms)" >&2
        sleep 0.5
    done
    
    # Calculate tok/s (rough estimate)
    local AVG_TOK_PER_SEC=0
    if [ "$TOTAL_TIME_MS" -gt 0 ]; then
        AVG_TOK_PER_SEC=$(( TOTAL_TOKENS * 1000 / TOTAL_TIME_MS ))
    fi
    
    # Final facts
    echo "" >> "$OUTPUT_FILE"
    echo "FINAL_FACTS:" >> "$OUTPUT_FILE"
    sqlite3 "$DB" "SELECT * FROM facts;" >> "$OUTPUT_FILE"
    
    # Get peak RAM
    local PEAK_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local AVAIL_RAM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local USED_RAM_KB=$((PEAK_RAM_KB - AVAIL_RAM_KB))
    local USED_RAM_GB=$(echo "scale=2; $USED_RAM_KB / 1024 / 1024" | bc)
    
    echo "" >> "$OUTPUT_FILE"
    echo "METRICS:" >> "$OUTPUT_FILE"
    echo "COLD_WARMUP_MS: $COLD_MS" >> "$OUTPUT_FILE"
    echo "WARM_WARMUP_MS: $WARM_MS" >> "$OUTPUT_FILE"
    echo "TOTAL_TOKENS_EST: $TOTAL_TOKENS" >> "$OUTPUT_FILE"
    echo "TOTAL_TIME_MS: $TOTAL_TIME_MS" >> "$OUTPUT_FILE"
    echo "EST_TOK_PER_SEC: $AVG_TOK_PER_SEC" >> "$OUTPUT_FILE"
    echo "PEAK_RAM_GB: $USED_RAM_GB" >> "$OUTPUT_FILE"
    
    echo "=== TEST COMPLETE: $MODEL_NAME ===" >&2
    echo "Results saved to: $OUTPUT_FILE" >&2
}

# Run tests
echo "Starting model comparison..." >&2
echo "" >&2

run_model_test "$MODEL_1" "LFM2.5-1.2B"
echo "" >&2
run_model_test "$MODEL_2" "LFM2.5-VL-450M"

echo "" >&2
echo "All tests complete. Results in $RESULTS_DIR/" >&2
