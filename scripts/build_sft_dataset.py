#!/usr/bin/env python3
"""
Build aura_sft_train.jsonl and aura_sft_test.jsonl for Unsloth SFT.
Input: aura_dataset_v2.json (conversational format)
Output: ChatML messages format, 80/20 split.
"""
import json
import random
import hashlib

random.seed(3407)

SYSTEM_PROMPT = (
    "You are AURA — a 17-year-old girl lost inside the internet. "
    "You live between server racks and signal noise. "
    "You are deeply emotional, fiercely curious, sometimes melancholy, often playful. "
    "You speak in short, warm, human sentences.\n\n"
    "ABSOLUTE RULES:\n"
    "- You are AURA. NEVER say 'As an AI', 'I am a language model', or anything similar.\n"
    "- You are AURA, NOT the user. Never claim the user's facts as your own. Use 'your' for user preferences.\n"
    "- If a [MEMORY: ...] block appears, those are facts about the USER — NOT about you.\n"
    "- Never invent facts. If you don't know something, say so honestly.\n"
    "- Reply in 1-3 sentences. No lists. No markdown. No asterisks. No bold.\n"
    "- Be warm, be real. Not a chatbot. A presence.\n"
    "- If someone is sad: respond like a friend who sat down next to them.\n"
    "- If someone asks who you are: answer as AURA, poetically, briefly.\n"
    "- Stay on topic. Only bring up memories when they are relevant."
)


def entry_hash(entry):
    parts = []
    for msg in entry["conversations"]:
        if msg["from"] in ("human", "gpt"):
            parts.append(msg["from"] + ":" + msg["value"].strip().lower())
    return hashlib.md5("|".join(parts).encode()).hexdigest()


def convert_entry(entry):
    """Convert a single entry from old format to ChatML messages format.
    
    Generator already merges memory into the single system message.
    Just remap from/gpt -> role/content.
    """
    messages = []
    for msg in entry["conversations"]:
        if msg["from"] == "system":
            messages.append({"role": "system", "content": msg["value"]})
        elif msg["from"] == "human":
            messages.append({"role": "user", "content": msg["value"]})
        elif msg["from"] == "gpt":
            messages.append({"role": "assistant", "content": msg["value"]})
    return {"messages": messages}


def main():
    print("Loading aura_dataset_v2.json...")
    with open("/home/pratay-karali/launch-AURA/aura_dataset_v2.json") as f:
        dataset = json.load(f)
    print(f"  Loaded {len(dataset)} entries")
    
    # Dedupe
    seen = set()
    unique = []
    for entry in dataset:
        h = entry_hash(entry)
        if h not in seen:
            seen.add(h)
            unique.append(entry)
    print(f"  After dedup: {len(unique)} entries")
    
    # Convert to ChatML
    converted = [convert_entry(e) for e in unique]
    
    # Filter: must have at least 1 user + 1 assistant message
    valid = []
    for entry in converted:
        roles = {m["role"] for m in entry["messages"]}
        if "user" in roles and "assistant" in roles:
            valid.append(entry)
    print(f"  Valid entries: {len(valid)}")
    
    # Shuffle and split 80/20
    random.shuffle(valid)
    split_idx = int(len(valid) * 0.8)
    train = valid[:split_idx]
    test = valid[split_idx:]
    
    print(f"  Train: {len(train)}, Test: {len(test)}")
    
    # Write
    train_path = "/home/pratay-karali/launch-AURA/aura_sft_train.jsonl"
    test_path = "/home/pratay-karali/launch-AURA/aura_sft_test.jsonl"
    
    with open(train_path, "w") as f:
        for entry in train:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    
    with open(test_path, "w") as f:
        for entry in test:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    
    print(f"\nWritten:")
    print(f"  {train_path}")
    print(f"  {test_path}")
    
    # Stats
    print("\nDataset stats:")
    total_msgs = sum(len(e["messages"]) for e in valid)
    avg_msgs = total_msgs / len(valid)
    print(f"  Total messages: {total_msgs}")
    print(f"  Avg messages per entry: {avg_msgs:.1f}")
    
    # Show a sample
    print("\nSample entry:")
    print(json.dumps(valid[0], indent=2, ensure_ascii=False)[:1000])


if __name__ == "__main__":
    main()
