#!/usr/bin/env python3
"""
Build separated AURA training files from aura_dataset_v2.json.

Outputs:
  training_data/aura_chat_sft_{train,test}.jsonl
  training_data/aura_memory_sft_{train,test}.jsonl
  training_data/aura_nomemory_sft_{train,test}.jsonl
  training_data/aura_command_intent_{train,test}.jsonl
  training_data/aura_proactive_sft_{train,test}.jsonl
  training_data/aura_vision_sft_{train,test}.jsonl
  training_data/manifest.json

ponytail: one source dataset, simple deterministic split. No frameworks.
"""

import hashlib
import json
import random
from pathlib import Path

ROOT = Path("/home/pratay-karali/launch-AURA")
SOURCE = ROOT / "aura_dataset_v2.json"
OUT = ROOT / "training_data"
SEED = 3407
TRAIN_RATIO = 0.8

AURA_SYSTEM = """You are AURA, a warm local companion. Reply briefly and naturally.
Rules:
- Use only the provided context.
- Do not invent names, facts, screen text, reminders, or memories.
- Do not say "I remember" unless the user directly asks about memory.
- For proactive prompts, say SILENT when interrupting would not help.
- For vision prompts, answer from the VISION block only."""


def entry_hash(entry):
    parts = []
    for msg in entry.get("conversations", []):
        if msg.get("from") in ("human", "gpt"):
            parts.append(msg["from"] + ":" + msg.get("value", "").strip().lower())
    return hashlib.md5("|".join(parts).encode()).hexdigest()


def convert_entry(entry):
    messages = []
    for msg in entry.get("conversations", []):
        role = {"system": "system", "human": "user", "gpt": "assistant"}.get(msg.get("from"))
        if role:
            messages.append({"role": role, "content": msg.get("value", "")})
    return {"messages": messages}


def is_aura_entry(entry):
    system_text = "\n".join(
        msg.get("value", "")
        for msg in entry.get("conversations", [])
        if msg.get("from") == "system"
    )
    return "You are AURA" in system_text and "You are ARIA" not in system_text


def has_memory(entry):
    for msg in entry["messages"]:
        content = msg.get("content", "")
        if content.lstrip().startswith("[MEMORY:") or "\n\n[MEMORY:" in content:
            return True
    return False


def valid_chat(entry):
    roles = {msg["role"] for msg in entry["messages"]}
    return "user" in roles and "assistant" in roles


def split(rows):
    rows = list(rows)
    random.Random(SEED).shuffle(rows)
    pivot = int(len(rows) * TRAIN_RATIO)
    return rows[:pivot], rows[pivot:]


def write_jsonl(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")


def make_command_intents():
    see_prefixes = [
        "/see",
        "/see screen",
        "/see what is on my screen",
        "/see this",
        "/see current window",
        "read my screen",
        "what is on my screen",
        "can you see my screen",
        "look at my screen",
        "what am i looking at",
        "tell me what is visible",
        "read the error on screen",
        "what does the page say",
        "summarize this screen",
        "scan my screen",
        "what text is visible",
        "can you read this window",
    ]
    reminder_prefixes = [
        "/reminder 5m drink water",
        "/reminder 20s check build",
        "/reminder in 10 minutes stretch",
        "/reminder at 7pm call mom",
        "/reminder tomorrow morning pack bag",
        "/reminder tonight take medicine",
        "/reminder noon standup",
        "remind me to drink water in 5 minutes",
        "set a reminder to submit the form at 6pm",
        "dont let me forget to email Alex tomorrow",
        "don't let me forget to pay rent tomorrow",
        "wake me up at 8am",
        "ping me in 15 minutes",
        "timer for 30 seconds",
        "make sure I call dad at 9 pm",
        "nudge me to leave in an hour",
    ]
    chat_prefixes = [
        "hi",
        "hey aura",
        "how are you",
        "what is my name",
        "do you know what I like",
        "tell me a joke",
        "help me debug this code",
        "i feel sad today",
        "what should i cook",
        "explain embeddings simply",
        "write a short caption",
        "what did we talk about",
        "i like coffee",
        "my brother is visiting",
        "can you help me plan today",
        "why is my rust build failing",
        "make this sentence cleaner",
        "what is the difference between http and websocket",
    ]

    see_templates = [
        "{}",
        "{} please",
        "aura, {}",
    ]
    reminder_templates = [
        "{}",
        "{} please",
        "aura, {}",
    ]
    chat_templates = [
        "{}",
        "aura, {}",
    ]

    rows = []
    rows += [
        {"text": template.format(text), "label": "see"}
        for text in see_prefixes
        for template in see_templates
    ]
    rows += [
        {"text": template.format(text), "label": "reminder"}
        for text in reminder_prefixes
        for template in reminder_templates
    ]
    rows += [
        {"text": template.format(text), "label": "chat"}
        for text in chat_prefixes
        for template in chat_templates
    ]
    return rows


def chat_row(user, assistant):
    return {
        "messages": [
            {"role": "system", "content": AURA_SYSTEM},
            {"role": "user", "content": user},
            {"role": "assistant", "content": assistant},
        ]
    }


def make_proactive_sft():
    useful = [
        (
            "PROACTIVE:\nkind=reminder\nsummary=Reminder: drink water",
            "Drink water when you can. Tiny reset, real benefit.",
        ),
        (
            "PROACTIVE:\nkind=reminder\nsummary=Reminder: call mom at 7 PM",
            "Quick reminder: call your mom at 7 PM.",
        ),
        (
            "PROACTIVE:\nkind=build_done\ncontext=Terminal shows tests passed",
            "Looks like the tests passed. Good moment to commit or ship the small fix.",
        ),
        (
            "PROACTIVE:\nkind=error_seen\ncontext=Terminal shows SyntaxError on line 42",
            "I see a SyntaxError around line 42. Want me to help trace it?",
        ),
        (
            "PROACTIVE:\nkind=idle\ncontext=User has been writing for 45 minutes",
            "You have been at this for a while. Quick stretch, then back in?",
        ),
        (
            "PROACTIVE:\nkind=stuck_screen\ncontext=Same error visible for 12 minutes",
            "That error has been sitting there a bit. I can help narrow it down.",
        ),
        (
            "PROACTIVE:\nkind=meeting\ncontext=Calendar says meeting starts in 5 minutes",
            "Meeting in five minutes. Good time to wrap the current thought.",
        ),
        (
            "PROACTIVE:\nkind=low_battery\ncontext=Laptop battery is low",
            "Battery looks low. Plug in before it steals your flow.",
        ),
    ]
    silent = [
        "PROACTIVE:\nkind=idle\ncontext=User just typed 20 seconds ago",
        "PROACTIVE:\nkind=vision\ncontext=Screen text is empty",
        "PROACTIVE:\nkind=bandit\ncontext=No recent useful signal",
        "PROACTIVE:\nkind=idle\ncontext=User is watching a video",
        "PROACTIVE:\nkind=stuck_screen\ncontext=Same browser home page visible",
        "PROACTIVE:\nkind=chat\ncontext=User is currently speaking",
        "PROACTIVE:\nkind=typing\ncontext=User is actively typing",
        "PROACTIVE:\nkind=memory\ncontext=Only known fact is user's name",
    ]
    rows = [chat_row(user, assistant) for user, assistant in useful]
    rows += [chat_row(user, "SILENT") for user in silent]

    contexts = [
        ("tests failed", "The tests failed. I can help inspect the first failure."),
        ("build is still running", "SILENT"),
        ("screen shows login page", "SILENT"),
        ("terminal asks for sudo password", "Terminal is waiting for a password. I will stay out of that."),
        ("calendar says class starts in 10 minutes", "Class starts in ten minutes."),
        ("download completed", "Download finished."),
        ("same TODO file open for 30 minutes", "Still on the TODO file. Want to pick one item and move?"),
    ]
    for context, answer in contexts:
        rows.append(chat_row(f"PROACTIVE:\nkind=context\ncontext={context}", answer))
    return rows


def make_vision_sft():
    cases = [
        (
            "VISION:\nscreen_text=SyntaxError: invalid syntax at main.py line 42\nobjects=terminal, editor\nUSER: /see",
            "Your screen shows a Python SyntaxError in main.py around line 42.",
        ),
        (
            "VISION:\nscreen_text=All tests passed. 18 passed in 2.4s\nobjects=terminal\nUSER: what is on my screen",
            "The terminal says all tests passed: 18 passed in 2.4 seconds.",
        ),
        (
            "VISION:\nscreen_text=No Internet connection\nobjects=browser\nUSER: read this",
            "It says there is no internet connection.",
        ),
        (
            "VISION:\nscreen_text=\nobjects=laptop, desk\nUSER: /see",
            "I can see a laptop and desk, but I cannot read any screen text.",
        ),
        (
            "VISION:\nscreen_text=Meeting starts at 3:00 PM\nobjects=calendar\nUSER: what does it say",
            "It says the meeting starts at 3:00 PM.",
        ),
        (
            "VISION:\nscreen_text=Permission denied\nobjects=terminal\nUSER: what error is visible",
            "The visible error is Permission denied.",
        ),
        (
            "VISION:\nscreen_text=Pull request checks: failing\nobjects=browser\nUSER: summarize this screen",
            "The page shows pull request checks failing.",
        ),
        (
            "VISION:\nscreen_text=README.md\nobjects=editor, markdown file\nUSER: what am i looking at",
            "You are looking at README.md in an editor.",
        ),
    ]
    rows = [chat_row(user, assistant) for user, assistant in cases]
    screen_texts = [
        ("Disk almost full", "The screen says the disk is almost full."),
        ("Update available", "The screen says an update is available."),
        ("Compilation finished with 3 warnings", "Compilation finished with three warnings."),
        ("Invoice total: $42.19", "The invoice total shown is $42.19."),
        ("404 Not Found", "The page shows 404 Not Found."),
        ("Battery: 8%", "Battery is at 8 percent."),
        ("No text detected", "The screen says no text detected."),
    ]
    for text, answer in screen_texts:
        rows.append(chat_row(f"VISION:\nscreen_text={text}\nobjects=screen\nUSER: /see", answer))
    return rows


def main():
    random.seed(SEED)
    raw = json.loads(SOURCE.read_text(encoding="utf-8"))

    seen = set()
    aura_entries = []
    for entry in raw:
        if not is_aura_entry(entry):
            continue
        h = entry_hash(entry)
        if h in seen:
            continue
        seen.add(h)
        converted = convert_entry(entry)
        if valid_chat(converted):
            aura_entries.append(converted)

    memory_entries = [e for e in aura_entries if has_memory(e)]
    nomemory_entries = [e for e in aura_entries if not has_memory(e)]
    command_intents = make_command_intents()
    proactive_entries = make_proactive_sft()
    vision_entries = make_vision_sft()

    outputs = {
        "aura_chat_sft": aura_entries,
        "aura_memory_sft": memory_entries,
        "aura_nomemory_sft": nomemory_entries,
        "aura_command_intent": command_intents,
        "aura_proactive_sft": proactive_entries,
        "aura_vision_sft": vision_entries,
    }

    manifest = {
        "source": str(SOURCE),
        "seed": SEED,
        "train_ratio": TRAIN_RATIO,
        "files": {},
    }

    for name, rows in outputs.items():
        train, test = split(rows)
        train_path = OUT / f"{name}_train.jsonl"
        test_path = OUT / f"{name}_test.jsonl"
        write_jsonl(train_path, train)
        write_jsonl(test_path, test)
        manifest["files"][name] = {
            "train": str(train_path),
            "test": str(test_path),
            "train_rows": len(train),
            "test_rows": len(test),
        }

    (OUT / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    print(json.dumps(manifest["files"], indent=2))


if __name__ == "__main__":
    main()
