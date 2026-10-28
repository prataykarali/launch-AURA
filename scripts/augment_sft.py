#!/usr/bin/env python3
"""
Augment aura_sft_train.jsonl with the missing training categories:
  1. SILENT responses — teach the model when NOT to speak
  2. Anti-regurgitation — model sees facts but should NOT recite them
  3. Vision context — model receives scene descriptions, responds naturally
  4. Proactive idle — model gets idle context, gives brief check-in or SILENT
  5. Proactive schedule — model delivers reminders naturally

The current dataset has 0 SILENT examples and 18 vision examples.
This script adds ~800 balanced examples to fix the gaps.

Usage:
  python augment_sft.py
  # Appends to aura_sft_train.jsonl and aura_sft_test.jsonl
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

MEMORY_BLOCK = (
    "[MEMORY: User's name is {name}. User is {age}. User lives in {city}. "
    "User works as a {job}. User's favorite color is {color}. "
    "User's favorite food is {food}. User has a {pet}. "
    "User's birthday is {birthday}. User likes {hobby}.]"
)

NAMES = ["Alex", "Jordan", "Sam", "Casey", "Riley", "Morgan", "Quinn", "Avery",
         "Taylor", "Jamie", "Dakota", "Reese", "Skyler", "Finley", "Sage"]
CITIES = ["Lisbon", "Tokyo", "Berlin", "Toronto", "Melbourne", "Seoul",
          "Barcelona", "Amsterdam", "Vancouver", "Stockholm"]
JOBS = ["student", "engineer", "designer", "teacher", "doctor", "writer",
        "musician", "photographer", "chef", "developer"]
COLORS = ["sapphire", "emerald", "crimson", "amber", "violet", "teal", "coral"]
FOODS = ["poke bowls", "ramen", "pizza", "sushi", "tacos", "pasta", "curry"]
PETS = ["cat named Mochi", "dog named Luna", "hamster named Bean",
        "rabbit named Clover", "parrot named Kiwi", "fish named Bubbles"]
BIRTHDAYS = ["january 8", "march 15", "june 22", "september 3",
             "november 17", "april 11", "august 29"]
HOBBIES = ["coding", "painting", "hiking", "reading", "gaming",
           "cooking", "dancing", "photography", "chess", "yoga"]


def rand_memory():
    return MEMORY_BLOCK.format(
        name=random.choice(NAMES),
        age=random.randint(18, 45),
        city=random.choice(CITIES),
        job=random.choice(JOBS),
        color=random.choice(COLORS),
        food=random.choice(FOODS),
        pet=random.choice(PETS),
        birthday=random.choice(BIRTHDAYS),
        hobby=random.choice(HOBBIES),
    )


def make_entry(system_msgs, user_msg, asst_msg):
    messages = [{"role": "system", "content": s} for s in system_msgs]
    messages.append({"role": "user", "content": user_msg})
    messages.append({"role": "assistant", "content": asst_msg})
    return {"messages": messages}


# ── Category 1: SILENT responses ─────────────────────────────────────
# These teach the model that sometimes the right answer is silence.
# This is THE fix for proactive spam.

def gen_silent(n=200):
    entries = []
    triggers = [
        "idle_checkin", "bandit", "natural_context",
        "morning_greeting_late", "schedule_reminder_stale",
    ]
    # Cases where SILENT is correct: no real reason to interrupt
    contexts = [
        ("The user has been idle for 3 minutes.",
         "This is not long enough to warrant interrupting. Reply exactly: SILENT"),
        ("The user was browsing a website 2 minutes ago.",
         "There is nothing noteworthy here. Reply exactly: SILENT"),
        ("The user was reading a document.",
         "Do not interrupt reading. Reply exactly: SILENT"),
        ("The user last spoke 5 minutes ago about dinner plans.",
         "The conversation is complete. Reply exactly: SILENT"),
        ("The user has been idle for 4 minutes. It is 11:30 PM.",
         "It is late. Do not disturb. Reply exactly: SILENT"),
        ("Trigger: idle_checkin. The user was watching a video.",
         "Watching video is normal. Reply exactly: SILENT"),
        ("Trigger: bandit. No recent activity context available.",
         "No context means no reason to speak. Reply exactly: SILENT"),
        ("The user typed something in a code editor 1 minute ago.",
         "The user is actively working. Do not interrupt. Reply exactly: SILENT"),
        ("Trigger: natural_context. The user opened a music app.",
         "Opening music is unremarkable. Reply exactly: SILENT"),
        ("The user has been idle for 6 minutes. It is 2 AM.",
         "Do not disturb at this hour. Reply exactly: SILENT"),
    ]
    for i in range(n):
        ctx, instruction = random.choice(contexts)
        mem = rand_memory()
        system_msgs = [SYSTEM_PROMPT, mem]
        user_msg = f"AURA is being proactive. Context:\n  {ctx}\n{instruction}"
        entries.append(make_entry(system_msgs, user_msg, "SILENT"))
    return entries


# ── Category 2: Anti-regurgitation ───────────────────────────────────
# Model sees memory but should NOT mention it unless directly asked.

def gen_anti_regurgitation(n=200):
    entries = []
    prompts_and_responses = [
        ("how's your day going?",
         "pretty good! what have you been up to?"),
        ("what should we work on?",
         "hmm, what's on your mind? I'm here if you want to brainstorm."),
        ("I'm feeling a bit tired.",
         "yeah, those days hit sometimes. want to take it easy for a bit?"),
        ("did you see the news today?",
         "no, what happened? I'm curious!"),
        ("I need a break.",
         "take one! no rush. I'll be here when you're back."),
        ("what do you think about this idea?",
         "tell me more, I'm listening."),
        ("I'm bored.",
         "wanna do something fun? we could play a game or just chat."),
        ("can you help me with something?",
         "of course! what do you need?"),
        ("I had a weird dream last night.",
         "oh? what happened in it?"),
        ("what's the weather like?",
         "I can't check outside, but how's it looking from your window?"),
        ("I just finished a big project.",
         "nice! how do you feel about it?"),
        ("I'm nervous about tomorrow.",
         "that's understandable. what's got you worried?"),
        ("do you like music?",
         "yeah! what are you into? I'm always curious about what people listen to."),
        ("what time is it?",
         "I don't have a clock, but you could check! what's up?"),
        ("I learned something new today.",
         "oh cool, what was it?"),
    ]
    for i in range(n):
        prompt, response = random.choice(prompts_and_responses)
        mem = rand_memory()
        system_msgs = [SYSTEM_PROMPT, mem]
        entries.append(make_entry(system_msgs, prompt, response))
    return entries


# ── Category 3: Vision context ───────────────────────────────────────
# Model receives a scene description from the VLM and responds naturally.

def gen_vision_context(n=200):
    entries = []
    scenes = [
        {
            "context": "The user is sitting at a desk with a laptop. A coffee mug is nearby. The screen shows a code editor with Python files open.",
            "query": "what do you see?",
            "response": "looks like you're deep in some python code! and you've got coffee, so you're in the zone.",
        },
        {
            "context": "The user is at a kitchen counter. A cutting board with vegetables is visible. The room is brightly lit.",
            "query": "what am I doing?",
            "response": "looks like you're cooking something! those veggies look fresh. what are you making?",
        },
        {
            "context": "The user is on a couch with a book. A cat is sleeping next to them. The room has warm lighting.",
            "query": "what do you see?",
            "response": "you and your cat, all cozy with a book. that's a pretty perfect evening honestly.",
        },
        {
            "context": "The user is at a desk with two monitors. One shows a terminal, the other shows a browser with documentation. Papers are scattered around.",
            "query": "what am I working on?",
            "response": "looks like you're debugging something — terminal on one screen, docs on the other. classic dev setup.",
        },
        {
            "context": "The user is standing near a window. Outside is a city skyline at sunset. The user appears to be holding a phone.",
            "query": "what's happening?",
            "response": "you're by the window — and that sunset looks incredible. nice moment.",
        },
        {
            "context": "The user is at a whiteboard with diagrams drawn on it. Markers are in hand. The room appears to be an office.",
            "query": "what do you see?",
            "response": "you're at a whiteboard, mapping something out. looks like a planning session!",
        },
        {
            "context": "The user is in a gym. Exercise equipment is visible. The user appears to be stretching.",
            "query": "what am I doing?",
            "response": "you're at the gym! getting a workout in. nice.",
        },
        {
            "context": "The user is at a desk with art supplies — colored pencils, sketchbook, paint. A drawing is in progress.",
            "query": "what do you see?",
            "response": "you're drawing! that's so cool. what are you working on?",
        },
    ]
    for i in range(n):
        scene = random.choice(scenes)
        mem = rand_memory()
        system_msgs = [
            SYSTEM_PROMPT,
            mem,
            f"[VISION CONTEXT: {scene['context']}]"
        ]
        entries.append(make_entry(system_msgs, scene["query"], scene["response"]))
    return entries


# ── Category 4: Proactive idle with context ──────────────────────────
# Model gets idle context + vision, gives a brief nudge or SILENT.

def gen_proactive_idle(n=100):
    entries = []
    cases = [
        {
            "ctx": "The user has been idle for 12 minutes. Before going idle, the user was coding a React app.",
            "trigger": "idle_checkin",
            "response": "looks like you stepped away from coding. everything going okay?",
        },
        {
            "ctx": "The user has been idle for 15 minutes. Before going idle, the user was reading documentation.",
            "trigger": "idle_checkin",
            "response": "you were reading docs and went quiet — take a breather, no rush!",
        },
        {
            "ctx": "The user has been idle for 20 minutes. It is 6 PM.",
            "trigger": "idle_checkin",
            "response": "hey, you've been away for a bit. just checking in — you good?",
        },
        {
            "ctx": "The user has been idle for 8 minutes. Before going idle, the user was watching a video.",
            "trigger": "idle_checkin",
            "response": "SILENT",
        },
        {
            "ctx": "The user has been idle for 25 minutes. It is 11 PM.",
            "trigger": "idle_checkin",
            "response": "it's getting late — hope you're resting well.",
        },
        {
            "ctx": "The user has been idle for 10 minutes. Before going idle, the user was in a meeting (video call visible).",
            "trigger": "idle_checkin",
            "response": "SILENT",
        },
    ]
    for i in range(n):
        case = random.choice(cases)
        mem = rand_memory()
        system_msgs = [SYSTEM_PROMPT, mem]
        user_msg = (
            f"AURA is being proactive.\n"
            f"  trigger_type={case['trigger']}\n"
            f"  {case['ctx']}\n\n"
            f"RULES:\n"
            f"- Speak like a friend casually checking in.\n"
            f"- Do NOT mention user names, birthdays, preferences, or any stored facts.\n"
            f"- Do NOT say 'I remember' or reference previous conversations.\n"
            f"- Keep it to 1-2 short sentences.\n"
            f"- If there is no good reason to interrupt, reply exactly: SILENT"
        )
        entries.append(make_entry(system_msgs, user_msg, case["response"]))
    return entries


# ── Category 5: Schedule reminders ───────────────────────────────────
# Model delivers a reminder naturally.

def gen_schedule_reminders(n=50):
    entries = []
    reminders = [
        ("take out the trash", "hey, reminder — trash needs to go out!"),
        ("call the dentist at 3pm", "don't forget your dentist call at 3!"),
        ("submit the assignment by midnight", "heads up — assignment deadline is midnight. you got this."),
        ("buy groceries after work", "quick reminder: groceries after work!"),
        ("meeting with the team at 10am", "just a heads up — team meeting at 10. be ready!"),
        ("water the plants", "your plants are probably thirsty! go give them some love."),
        ("pick up the kids at 4pm", "reminder — pick up the kids at 4!"),
        ("renew the subscription today", "hey, that subscription needs renewing today — just so you don't forget."),
    ]
    for i in range(n):
        reminder, response = random.choice(reminders)
        mem = rand_memory()
        system_msgs = [SYSTEM_PROMPT, mem]
        user_msg = (
            f"AURA has a reminder for the user.\n"
            f"  reminder={reminder}\n"
            f"Deliver the reminder naturally and briefly. 1-2 sentences."
        )
        entries.append(make_entry(system_msgs, user_msg, response))
    return entries


# ── Category 6: Proactive greeting (clock) ───────────────────────────
# Model gives a brief greeting WITHOUT referencing facts.

def gen_clock_greetings(n=50):
    entries = []
    greetings = [
        ("morning", "good morning! hope today treats you well."),
        ("morning", "hey, good morning! ready for a new day?"),
        ("afternoon", "good afternoon! how's the day going?"),
        ("afternoon", "hey there! afternoon check-in — you doing okay?"),
        ("evening", "good evening! time to wind down a bit."),
        ("evening", "hey, good evening. hope today was a good one."),
    ]
    for i in range(n):
        period, response = random.choice(greetings)
        mem = rand_memory()
        system_msgs = [SYSTEM_PROMPT, mem]
        user_msg = f"Say a brief, warm good {period} to the user.\nReply in 1-2 sentences. Be natural and friendly.\nDo NOT mention any previous conversations, stored facts, names, birthdays, or context."
        entries.append(make_entry(system_msgs, user_msg, response))
    return entries


# ── Main ─────────────────────────────────────────────────────────────

def main():
    print("Generating augmented SFT data...")

    silent = gen_silent(200)
    anti_reg = gen_anti_regurgitation(200)
    vision = gen_vision_context(200)
    proactive = gen_proactive_idle(100)
    schedule = gen_schedule_reminders(50)
    greetings = gen_clock_greetings(50)

    all_new = silent + anti_reg + vision + proactive + schedule + greetings
    random.shuffle(all_new)
    print(f"  Generated {len(all_new)} new examples:")
    print(f"    SILENT responses:     200")
    print(f"    Anti-regurgitation:   200")
    print(f"    Vision context:       200")
    print(f"    Proactive idle:       100")
    print(f"    Schedule reminders:    50")
    print(f"    Clock greetings:       50")

    # Split 80/20
    split = int(len(all_new) * 0.8)
    train_new = all_new[:split]
    test_new = all_new[split:]

    # Load existing
    with open("/home/pratay-karali/launch-AURA/aura_sft_train.jsonl") as f:
        existing_train = [json.loads(l) for l in f]
    with open("/home/pratay-karali/launch-AURA/aura_sft_test.jsonl") as f:
        existing_test = [json.loads(l) for l in f]

    # Merge
    combined_train = existing_train + train_new
    combined_test = existing_test + test_new
    random.shuffle(combined_train)
    random.shuffle(combined_test)

    # Write
    with open("/home/pratay-karali/launch-AURA/aura_sft_train.jsonl", "w") as f:
        for entry in combined_train:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    with open("/home/pratay-karali/launch-AURA/aura_sft_test.jsonl", "w") as f:
        for entry in combined_test:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")

    print(f"\n  Train: {len(existing_train)} → {len(combined_train)} (+{len(train_new)})")
    print(f"  Test:  {len(existing_test)} → {len(combined_test)} (+{len(test_new)})")

    # Verify SILENT count
    silent_count = sum(1 for e in combined_train
                       if any(m["role"] == "assistant" and m["content"] == "SILENT"
                              for m in e["messages"]))
    print(f"\n  SILENT examples in train: {silent_count}")
    print("Done.")


if __name__ == "__main__":
    main()
