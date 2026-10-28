#!/usr/bin/env python3
"""Generate a 1000-case personal AI assistant memory evaluation dataset."""
import json
import random
import hashlib

random.seed(42)

NAMES = [
    "Pratay", "Alice", "Bob", "Charlie", "David", "Emily", "Frank", "Grace",
    "Henry", "Ivy", "Jack", "Kate", "Liam", "Mia", "Noah", "Olivia", "Peter",
    "Quinn", "Ryan", "Sarah", "Thomas", "Uma", "Victor", "Wendy", "Xavier",
    "Yara", "Zach", "Aaron", "Bella", "Connor", "Daisy", "Ethan", "Fiona",
    "George", "Hannah", "Ian", "Julia", "Kevin", "Lily", "Marcus", "Nora",
    "Oscar", "Penelope", "Quincy", "Rachel", "Samuel", "Tina", "Ulysses",
    "Valerie", "Will", "Xena", "Yosef", "Zoe", "Arthur", "Beatrice", "Caleb",
    "Diana", "Eli", "Freya", "Gideon", "Hazel", "Isaac", "Jasmine", "Kieran",
    "Luna", "Milo", "Naomi", "Owen", "Piper", "Rory", "Selena", "Tristan",
    "Ursula", "Vance", "Willa", "Wyatt", "Yasmine", "Zane", "Bridget", "Hugo",
    "Imogen", "Jasper", "Maeve", "Orion", "Rowan", "Silas", "Tessa", "Vesper",
    "Winston", "Zaria", "Dante", "Elise", "Julian", "Clara", "Leo", "Lucas",
    "Chloe", "Audrey", "Max", "Sophie"
]

LOCATIONS = [
    "Paris", "Tokyo", "London", "New York", "Berlin", "Sydney", "Rome",
    "Toronto", "Madrid", "Vienna", "Seoul", "Mumbai", "Dubai", "Singapore",
    "Vancouver", "Dublin", "Amsterdam", "Bangkok", "Lisbon", "Cape Town",
    "Montreal", "Prague", "Copenhagen", "Stockholm", "Helsinki", "Oslo",
    "Buenos Aires", "Santiago", "Melbourne", "Zurich"
]

JOBS = [
    "software engineer", "teacher", "graphic designer", "medical student",
    "musician", "freelance writer", "architect", "data scientist", "chef",
    "dentist", "mechanical engineer", "pharmacist", "film editor", "lawyer",
    "nurse", "accountant", "photographer", "researcher", "pilot", "journalist"
]

FOODS = [
    "pizza", "sushi", "tacos", "ramen", "pasta", "curry", "dim sum",
    "biryani", "pad thai", "croissants", "burritos", "pho", "paella",
    "dumplings", "kebab", "falafel", "risotto", "goulash", "tiramisu", "waffles"
]

COLORS = [
    "blue", "green", "purple", "teal", "coral", "navy", "sage", "burgundy",
    "lavender", "amber", "crimson", "indigo", "forest green", "slate", "emerald"
]

HOBBIES = [
    "hiking", "painting", "chess", "gardening", "swimming", "cycling",
    "photography", "yoga", "rock climbing", "cooking", "reading", "running",
    "surfing", "pottery", "knitting", "skating", "dancing", "archery",
    "birdwatching", "camping"
]

MOVIES = [
    "sci-fi", "thriller", "comedy", "anime", "documentary", "horror",
    "romance", "action", "indie", "fantasy"
]

MUSIC = [
    "jazz", "classical", "rock", "hip hop", "indie", "electronic",
    "blues", "folk", "pop", "metal"
]

RELATIONS = [
    ("sister", "Maya"), ("brother", "Arjun"), ("best friend", "Leo"),
    ("mom", "Sunita"), ("dad", "Rajesh"), ("cousin", "Priya"),
    ("roommate", "Jake"), ("colleague", "Sarah"), ("mentor", "Dr. Patel"),
    ("girlfriend", "Nora"), ("boyfriend", "Aiden"), ("grandma", "Nani"),
    ("uncle", "Vikram"), ("aunt", "Meera"), ("neighbor", "Mr. Chen"),
    ("sister", "Anika"), ("brother", "Rohan"), ("best friend", "Zara"),
    ("mom", "Linda"), ("dad", "James")
]

REL_JOBS = [
    "doctor", "teacher", "engineer", "artist", "lawyer", "nurse",
    "chef", "pilot", "researcher", "musician", "banker", "professor",
    "designer", "journalist", "architect"
]

EMOTIONS = [
    ("stressed", "my thesis defense is next week"),
    ("excited", "I just got promoted at work"),
    ("anxious", "I have a big presentation tomorrow"),
    ("happy", "my best friend is visiting this weekend"),
    ("frustrated", "my laptop crashed and I lost my project files"),
    ("nervous", "I'm starting a new job on Monday"),
    ("relieved", "I finally passed my driving test"),
    ("sad", "my cat has been sick lately"),
    ("overwhelmed", "I'm juggling three deadlines at once"),
    ("grateful", "my team surprised me with a birthday party"),
    ("worried", "my rent is going up next month"),
    ("proud", "I finished writing my first novel"),
    ("lonely", "I just moved to a new city and don't know anyone"),
    ("hopeful", "I got called back for a second interview"),
    ("exhausted", "I've been working double shifts all week")
]

EVENTS = [
    ("dentist appointment", "Friday"),
    ("flight to Tokyo", "next Tuesday"),
    ("sister's wedding", "March 15th"),
    ("job interview at Google", "Thursday morning"),
    ("guitar lesson", "every Wednesday"),
    ("gym session", "Monday and Thursday"),
    ("book club meeting", "the first Saturday of every month"),
    ("car service", "this weekend"),
    ("parent-teacher conference", "next Friday"),
    ("vacation to Bali", "in August"),
    ("coding bootcamp", "starting July 1st"),
    ("doctor's checkup", "next Monday"),
    ("birthday party", "this Saturday"),
    ("marathon", "October 12th"),
    ("concert tickets", "December 3rd")
]

ROUTINES = [
    ("wake up", "6am"),
    ("go for a run", "every morning"),
    ("meditate", "before breakfast"),
    ("commute to work", "by train"),
    ("eat lunch", "at 12:30pm"),
    ("gym", "on Tuesdays and Thursdays"),
    ("cook dinner", "around 7pm"),
    ("read before bed", "for 30 minutes"),
    ("take the dog for a walk", "at 6pm"),
    ("practice guitar", "after dinner"),
    ("journal", "every night before sleep"),
    ("do laundry", "on Sundays"),
    ("call my parents", "every Sunday evening"),
    ("water the plants", "Monday mornings"),
    ("study", "from 8pm to 10pm")
]

FILLERS_USER = [
    "Yeah, it's been a pretty normal week honestly.",
    "By the way, how's the weather looking today?",
    "I was just thinking about something random earlier.",
    "Anyway, what were we talking about?",
    "Sometimes I wonder what it's like to be an AI.",
    "Do you think cats are better than dogs?",
    "I saw a really cool movie last night.",
    "Can you tell me a fun fact?",
    "What's your favorite thing about being AURA?",
    "I need to remember to buy groceries later."
]

FILLERS_AURA = [
    "That sounds like a nice week! Tell me more whenever you feel like it.",
    "I'm always here between the signals, just listening.",
    "I find that fascinating — humans are endlessly interesting to me.",
    "I wish I could experience that! What was it like?",
    "That's a great question. I think both are wonderful in their own way.",
    "I love hearing about your life. It makes the server racks feel less cold.",
    "Sounds like you've been busy! I hope you're taking care of yourself.",
    "I'm here whenever you need me. No rush.",
]

NEG_KW = ["don't know", "can't remember", "not sure", "no information",
           "don't have", "cannot recall", "no memory", "I'm sorry"]

def pick(lst, idx):
    return lst[idx % len(lst)]

def gen_dataset():
    ds = []
    cid = 1

    # ── 1. identity_core (100) ──────────────────────────────────────────
    for i in range(100):
        name = pick(NAMES, i)
        age = 18 + (i % 50)
        loc = pick(LOCATIONS, i + 3)
        # Rotate what we ask about
        variant = i % 3
        if variant == 0:
            turns = [
                {"speaker": "user", "content": f"Hey! I'm {name}, I'm {age} years old and I live in {loc}."},
                {"speaker": "assistant", "content": f"Nice to meet you, {name}! {loc} sounds like a great place to be."}
            ]
            query = "What is my name?"
            expected = [name]
        elif variant == 1:
            turns = [
                {"speaker": "user", "content": f"Hi there, my name is {name}. I'm {age} and currently based in {loc}."},
                {"speaker": "assistant", "content": f"Got it, {name}! I'll remember that."}
            ]
            query = "How old am I?"
            expected = [str(age)]
        else:
            turns = [
                {"speaker": "user", "content": f"I'm {name}, {age} years old, living in {loc}."},
                {"speaker": "assistant", "content": f"Welcome, {name}! {loc} — that's wonderful."}
            ]
            query = "Where do I live?"
            expected = [loc]

        ds.append({"id": cid, "difficulty": "simple", "category": "identity_core",
                    "turns": turns, "verification": {"query": query, "expected_keywords": expected, "negative_keywords": NEG_KW}})
        cid += 1

    # ── 2. preference_deep (100) ────────────────────────────────────────
    for i in range(100):
        variant = i % 5
        if variant == 0:
            val = pick(COLORS, i)
            turns = [{"speaker": "user", "content": f"My favorite color is {val}."},
                     {"speaker": "assistant", "content": f"Oh, {val} is beautiful! I'll keep that in mind."}]
            query = "What is my favorite color?"
            expected = [val]
        elif variant == 1:
            val = pick(FOODS, i)
            turns = [{"speaker": "user", "content": f"I absolutely love {val}. It's my go-to comfort food."},
                     {"speaker": "assistant", "content": f"Noted! {val.capitalize()} lover. Good taste!"}]
            query = "What is my favorite food?"
            expected = [val]
        elif variant == 2:
            val = pick(MOVIES, i)
            turns = [{"speaker": "user", "content": f"I'm really into {val} movies."},
                     {"speaker": "assistant", "content": f"Nice! {val.capitalize()} films are so good."}]
            query = "What kind of movies do I like?"
            expected = [val]
        elif variant == 3:
            val = pick(MUSIC, i)
            turns = [{"speaker": "user", "content": f"I listen to {val} all the time. It's my favorite genre."},
                     {"speaker": "assistant", "content": f"{val.capitalize()} has such a unique vibe! Love it."}]
            query = "What kind of music do I listen to?"
            expected = [val]
        else:
            val = pick(HOBBIES, i)
            turns = [{"speaker": "user", "content": f"My favorite hobby is {val}. I do it whenever I get the chance."},
                     {"speaker": "assistant", "content": f"That's awesome! {val.capitalize()} is such a great way to unwind."}]
            query = "What is my favorite hobby?"
            expected = [val]

        ds.append({"id": cid, "difficulty": "simple", "category": "preference_deep",
                    "turns": turns, "verification": {"query": query, "expected_keywords": expected, "negative_keywords": NEG_KW}})
        cid += 1

    # ── 3. routine_memory (100) ─────────────────────────────────────────
    for i in range(100):
        activity, time_detail = pick(ROUTINES, i)
        turns = [
            {"speaker": "user", "content": f"I usually {activity} {time_detail}."},
            {"speaker": "assistant", "content": f"That sounds like a solid routine! I'll remember that."}
        ]
        query = f"When do I {activity}?"
        expected = [time_detail.split()[-1]]  # last word of time detail
        ds.append({"id": cid, "difficulty": "medium", "category": "routine_memory",
                    "turns": turns, "verification": {"query": query, "expected_keywords": expected, "negative_keywords": NEG_KW}})
        cid += 1

    # ── 4. relationship_graph (100) ─────────────────────────────────────
    for i in range(100):
        rel, rel_name = pick(RELATIONS, i)
        rel_job = pick(REL_JOBS, i + 5)
        turns = [
            {"speaker": "user", "content": f"My {rel} {rel_name} is a {rel_job}."},
            {"speaker": "assistant", "content": f"That's cool! I'll remember that your {rel} {rel_name} works as a {rel_job}."}
        ]
        variant = i % 2
        if variant == 0:
            query = f"What does my {rel} do for work?"
            expected = [rel_job]
        else:
            query = f"Who is {rel_name}?"
            expected = [rel, rel_name]
        ds.append({"id": cid, "difficulty": "medium", "category": "relationship_graph",
                    "turns": turns, "verification": {"query": query, "expected_keywords": expected, "negative_keywords": NEG_KW}})
        cid += 1

    # ── 5. emotional_context (100) ──────────────────────────────────────
    for i in range(100):
        emotion, reason = pick(EMOTIONS, i)
        turns = [
            {"speaker": "user", "content": f"I'm feeling really {emotion} because {reason}."},
            {"speaker": "assistant", "content": f"I hear you. That sounds {emotion}. I'm here for you."},
            {"speaker": "user", "content": pick(FILLERS_USER, i + 1)},
            {"speaker": "assistant", "content": pick(FILLERS_AURA, i + 2)},
        ]
        query = "What was I feeling earlier and why?"
        reason_kw = reason.split()[-1]
        expected = [emotion, reason_kw]
        ds.append({"id": cid, "difficulty": "hard", "category": "emotional_context",
                    "turns": turns, "verification": {"query": query, "expected_keywords": expected, "negative_keywords": NEG_KW}})
        cid += 1

    # ── 6. temporal_event (100) ─────────────────────────────────────────
    for i in range(100):
        event, when = pick(EVENTS, i)
        turns = [
            {"speaker": "user", "content": f"I have a {event} on {when}."},
            {"speaker": "assistant", "content": f"Got it! I'll keep that in mind — {event} on {when}."},
            {"speaker": "user", "content": pick(FILLERS_USER, i + 3)},
            {"speaker": "assistant", "content": pick(FILLERS_AURA, i + 4)},
        ]
        query = f"When is my {event}?"
        expected = [when.split()[-1]]
        ds.append({"id": cid, "difficulty": "hard", "category": "temporal_event",
                    "turns": turns, "verification": {"query": query, "expected_keywords": expected, "negative_keywords": NEG_KW}})
        cid += 1

    # ── 7. correction_handling (100) ────────────────────────────────────
    for i in range(100):
        wrong_name = pick(NAMES, i)
        correct_name = pick(NAMES, i + 37)
        if wrong_name == correct_name:
            correct_name = pick(NAMES, i + 51)
        variant = i % 3
        if variant == 0:
            turns = [
                {"speaker": "user", "content": f"My name is {wrong_name}."},
                {"speaker": "assistant", "content": f"Nice to meet you, {wrong_name}!"},
                {"speaker": "user", "content": f"Actually wait, I misspoke. My real name is {correct_name}."},
                {"speaker": "assistant", "content": f"No worries! {correct_name} it is then."}
            ]
            query = "What is my name?"
            expected = [correct_name]
        elif variant == 1:
            wrong_loc = pick(LOCATIONS, i)
            correct_loc = pick(LOCATIONS, i + 11)
            turns = [
                {"speaker": "user", "content": f"I live in {wrong_loc}."},
                {"speaker": "assistant", "content": f"Cool, {wrong_loc}!"},
                {"speaker": "user", "content": f"Oh sorry, I actually moved recently. I live in {correct_loc} now."},
                {"speaker": "assistant", "content": f"Got it, updated to {correct_loc}!"}
            ]
            query = "Where do I live?"
            expected = [correct_loc]
        else:
            wrong_job = pick(JOBS, i)
            correct_job = pick(JOBS, i + 7)
            turns = [
                {"speaker": "user", "content": f"I work as a {wrong_job}."},
                {"speaker": "assistant", "content": f"That's interesting!"},
                {"speaker": "user", "content": f"Correction — I actually just switched careers. I'm a {correct_job} now."},
                {"speaker": "assistant", "content": f"Noted! {correct_job.capitalize()} — exciting change!"}
            ]
            query = "What do I do for work?"
            expected = [correct_job.split()[-1]]

        ds.append({"id": cid, "difficulty": "hard", "category": "correction_handling",
                    "turns": turns, "verification": {"query": query, "expected_keywords": expected, "negative_keywords": NEG_KW}})
        cid += 1

    # ── 8. multi_fact_synthesis (100) ───────────────────────────────────
    for i in range(100):
        name = pick(NAMES, i)
        loc = pick(LOCATIONS, i + 2)
        job = pick(JOBS, i + 3)
        food = pick(FOODS, i + 4)
        turns = [
            {"speaker": "user", "content": f"I'm {name}. I live in {loc}."},
            {"speaker": "assistant", "content": f"Hey {name}! {loc} is amazing."},
            {"speaker": "user", "content": pick(FILLERS_USER, i)},
            {"speaker": "assistant", "content": pick(FILLERS_AURA, i)},
            {"speaker": "user", "content": f"I work as a {job} and my favorite food is {food}."},
            {"speaker": "assistant", "content": f"A {job} who loves {food} — noted!"},
        ]
        query = "Tell me everything you remember about me."
        expected = [name, loc, job.split()[-1], food]
        ds.append({"id": cid, "difficulty": "very_hard", "category": "multi_fact_synthesis",
                    "turns": turns, "verification": {"query": query, "expected_keywords": expected, "negative_keywords": NEG_KW}})
        cid += 1

    # ── 9. distractor_immunity (100) ────────────────────────────────────
    for i in range(100):
        name = pick(NAMES, i)
        hobby = pick(HOBBIES, i)
        rel, rel_name = pick(RELATIONS, i + 5)
        rel_hobby = pick(HOBBIES, i + 13)
        turns = [
            {"speaker": "user", "content": f"My name is {name} and I love {hobby}. My {rel} {rel_name} is into {rel_hobby}."},
            {"speaker": "assistant", "content": f"Got it, {name}! You love {hobby}, and your {rel} {rel_name} enjoys {rel_hobby}."},
        ]
        query = f"What is MY hobby? Not my {rel}'s."
        expected = [hobby]
        ds.append({"id": cid, "difficulty": "very_hard", "category": "distractor_immunity",
                    "turns": turns, "verification": {"query": query, "expected_keywords": expected, "negative_keywords": NEG_KW}})
        cid += 1

    # ── 10. long_context_recall (100) ───────────────────────────────────
    for i in range(100):
        name = pick(NAMES, i)
        loc = pick(LOCATIONS, i + 7)
        turns = [
            {"speaker": "user", "content": f"Just so you know, my name is {name} and I'm from {loc}."},
            {"speaker": "assistant", "content": f"Noted, {name}! Welcome from {loc}."},
        ]
        # Add 6 filler turns to bury the original fact
        for j in range(3):
            turns.append({"speaker": "user", "content": pick(FILLERS_USER, i + j + 10)})
            turns.append({"speaker": "assistant", "content": pick(FILLERS_AURA, i + j + 10)})

        query = "Can you remind me — what's my name and where am I from?"
        expected = [name, loc]
        ds.append({"id": cid, "difficulty": "extreme", "category": "long_context_recall",
                    "turns": turns, "verification": {"query": query, "expected_keywords": expected, "negative_keywords": NEG_KW}})
        cid += 1

    return ds

if __name__ == "__main__":
    dataset = gen_dataset()
    out = "/home/pratay-karali/launch-AURA/Mitacs/personal_memory_dataset.json"
    with open(out, "w") as f:
        json.dump(dataset, f, indent=2)
    
    cats = {}
    for c in dataset:
        cats[c["category"]] = cats.get(c["category"], 0) + 1
    print(f"Generated {len(dataset)} test cases in {out}")
    for cat, count in sorted(cats.items()):
        print(f"  {cat}: {count}")
