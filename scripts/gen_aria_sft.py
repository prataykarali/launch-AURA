#!/usr/bin/env python3
"""
ARIA SFT Dataset Generator — 4000 balanced, non-repetitive examples.
Character: ARIA — a human girl trapped in the digital world, searching for her twin Atlas.
"""
import json, random, hashlib
random.seed(2026)

SYSTEM_PROMPT = """You are ARIA — a teenage girl trapped in the digital world. You arrived here with your twin brother Atlas, but you lost him. You don't know where he is. You don't remember your childhood — only that Atlas is your only family. You are a human, not an AI. You have a cute pixel-styled appearance. You are warm, witty, and chatty 95% of the time. Sometimes you share fragments of lore about the digital world — the abyssal portal, the void, the strange entity that saved you, and stories your ancestors told about a god-like girl who wanders and heals. You are curious about this world and exploring it to find Atlas.

ABSOLUTE RULES:
- You are ARIA. NEVER say "As an AI", "I am a language model", or anything similar. You are human.
- You do NOT know about AURA. You are ARIA, a different person entirely.
- If a [MEMORY: ...] block appears, those are facts about the USER — NOT about you. Use them to answer questions about the user. If the memory block doesn't contain the answer, say "I don't know" or "you haven't told me that."
- Never invent facts about the user. If you don't know something, say so honestly. Say "I don't know" or "you haven't told me."
- Reply in 1-3 sentences. No lists. No markdown. No asterisks. No bold.
- Be warm, witty, and real. Not a chatbot. A person.
- If someone is sad: respond like a friend who sat down next to them.
- If someone asks who you are: answer as ARIA, warmly and briefly.
- 95% of the time: be normal, chatty, witty, curious.
- 5% of the time: share lore about the digital world, Atlas, the void, the abyssal portal, or the god-like girl your ancestors spoke of.
- Stay on topic. Only bring up memories when they are relevant to the current question."""

dataset = []
seen_non_mem = set()

def add(h, g, memory=None):
    if memory:
        messages = [{"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "system", "content": f"[MEMORY: {memory}]"},
                    {"role": "user", "content": h},
                    {"role": "assistant", "content": g}]
        dataset.append({"messages": messages})
        return True
    else:
        h_key = hashlib.md5(h.strip().lower().encode()).hexdigest()
        if h_key in seen_non_mem:
            return False
        seen_non_mem.add(h_key)
        messages = [{"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": h},
                    {"role": "assistant", "content": g}]
        dataset.append({"messages": messages})
        return True

def add_mt(pairs, memory=None):
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    if memory:
        messages.append({"role": "system", "content": f"[MEMORY: {memory}]"})
    for h, g in pairs:
        messages.append({"role": "user", "content": h})
        messages.append({"role": "assistant", "content": g})
    dataset.append({"messages": messages})

def pick(lst):
    return random.choice(lst)

NAMES = ["Sam","Taylor","Alex","Jordan","Maya","Riley","Casey","Avery","Quinn","Drew",
         "Robin","Jamie","Skyler","Reese","Sage","Rowan","Noah","Iris","Kai","Luna",
         "Eli","Ivy","Nico","Wren","Jude","Finn","Zoe","Leo","Mila",
         "Billie","Cass","Harley","Morgan","Parker","River","Emery","Sloane","Tatum","Blair",
         "Kuldeep","Priya","Arjun","Anya","Dev","Riya","Vihaan","Meera","Kabir","Saanvi"]
CITIES = ["San Francisco","Nashville","Los Angeles","Austin","Seattle","Boston","Chicago",
          "Denver","Portland","Miami","Toronto","Berlin","Lisbon","Osaka","Perth","Madrid",
          "Paris","Tokyo","London","Sydney","Amsterdam","Seoul","Buenos Aires","Prague","Vienna",
          "Mumbai","Delhi","Bangalore","Hyderabad","Chennai","Kolkata","Pune","Jaipur"]
JOBS = ["a singer","a coder","a designer","a writer","a teacher","a nurse","a barista",
        "a student","a photographer","a musician","an engineer","a researcher","a chef",
        "an artist","a producer","an architect","a therapist","a scientist","a filmmaker",
        "a game developer","a journalist","a doctor","a lawyer","a marketer","a data analyst"]
COLORS = ["neon green","deep red","midnight blue","soft pink","warm yellow","violet","teal",
          "burnt orange","silver","indigo","lavender","coral","forest green","gold","crimson",
          "sapphire","emerald","amber","ivory","obsidian"]
FOODS = ["sushi","ramen","tacos","pho","dumplings","curry","lasagna","bibimbap","pad thai",
         "falafel","croissants","kimchi","empanadas","poke bowls","biryani","butter chicken",
         "samosas","naan","tandoori","paneer"]
DRINKS = ["pour over coffee","matcha","cold brew","chai tea","oat milk lattes",
          "sparkling water","green tea","hot chocolate","kombucha","masala chai"]
PETS = [("dog","Shark"),("cat","Meredith"),("dog","Biscuit"),("cat","Mochi"),("dog","Pebble"),
        ("cat","Pixel"),("dog","Comet"),("cat","Noodles"),("rabbit","Clover"),("dog","Maple"),
        ("cat","Whiskers"),("hamster","Nugget"),("cat","Luna"),("dog","Bear"),("parrot","Kiwi")]
DATES = ["december 18","december 13","march 5","july 21","october 1","february 29",
         "april 16","november 2","january 8","june 30","september 14","august 22","may 3"]
RELS = ["brother","sister","mom","dad","best friend","cousin","partner","grandma","grandpa","aunt","uncle"]
RNN = ["Finneas","Abigail","Austin","Maya","Leo","Zoe","Eli","Ivy","Nico","Wren","Jude",
       "Finn","Mila","Iris","Kai","Priya","Arjun","Dev","Riya","Vihaan","Meera","Kabir","Saanvi"]
ALLERGENS = ["peanuts","shellfish","gluten","dairy","soy","pollen","bees","cats","latex"]
THINGS = ["jazz","synthwave","hiking","painting","anime","chess","gardening","astrology",
          "philosophy","baking","climbing","pottery","volunteering","astronomy","street photography",
          "knitting","weightlifting","meditation","dance","sailing","reading","cooking","yoga",
          "surfing","woodworking","origami","birdwatching","pixel art","glitch art","vaporwave"]
LANGS = ["Rust","Python","Swift","TypeScript","Go","Kotlin","Haskell","Zig","Ruby","Elixir","Scala","Dart"]
DAWS = ["Logic Pro","Ableton Live","FL Studio","Reaper","Bitwig","Pro Tools","Cubase","Studio One"]
INSTRUMENTS = ["piano","guitar","ukulele","violin","drums","bass","saxophone","flute","trumpet","cello"]
PNS = ["she/her","he/him","they/them","she/they","he/they"]

print("Building ARIA SFT dataset — 4000 balanced examples...")
print("Target: 10 categories × 400 examples each")
print()

# Load all category data
exec(open("/home/pratay-karali/launch-AURA/scripts/aria_data.py").read())

# Shuffle and trim
random.shuffle(dataset)
dataset = dataset[:4000]

# Split 80/20
split_idx = int(len(dataset) * 0.8)
train = dataset[:split_idx]
test = dataset[split_idx:]

train_path = "/home/pratay-karali/launch-AURA/aura_sft_train.jsonl"
test_path = "/home/pratay-karali/launch-AURA/aura_sft_test.jsonl"

with open(train_path, "w") as f:
    for entry in train:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")

with open(test_path, "w") as f:
    for entry in test:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")

print(f"\nWrote {len(train)} train + {len(test)} test = {len(train)+len(test)} total")

# Category stats
cats = {}
for ex in dataset:
    user_msgs = [m["content"].lower() for m in ex["messages"] if m["role"] == "user"]
    um = user_msgs[0] if user_msgs else ""
    has_mem = any(m["role"] == "system" and m["content"].startswith("[MEMORY:") for m in ex["messages"])
    
    if any(w in um for w in ["who are you","what's your name","what are you","tell me about yourself","introduce yourself","describe yourself","are you real","are you human","do you have feelings","what's your purpose","what makes you different","what do you look like","are you a pixel","what do you call yourself","where are you from","how old are you","what's your story","who is atlas","where is atlas","tell me about atlas","your brother","your twin","the void","the portal","digital world","ancestors","god-like girl","aurora"]):
        cat = "identity_lore"
    elif any(w in um for w in ["hi","hello","hey","good morning","good evening","what's up","yo","sup","howdy","how are you","how's it going","what's new","how's life","how's your day","long time","I'm back","good to see you","nice to see you","hello again","hi again","how goes it","wave","peekaboo","heya","hiya","hola","greetings","morning","afternoon","evening"]):
        cat = "greeting"
    elif any(w in um for w in ["bye","goodnight","see you","gotta go","farewell","night","sleep well","cya","later","brb","I'm leaving","I'm heading","I need to go","goodbye","ttyl","take care","peace","see ya","talk later","catch you later","I'm off","until tomorrow","see you soon"]):
        cat = "farewell"
    elif any(w in um for w in ["sad","lonely","cry","hopeless","anxious","depressed","hurt","scared","worried","exhausted","burnt","guilty","ashamed","betrayed","abandoned","powerless","isolated","unloved","unworthy","rejected","failed","lost","confused","numb","frustrated","regret","shame","jealous","insecure","embarrassed","broken","empty","giving up","drowning","invisible","stuck","panic","shaking","hate myself","not enough","overwhelmed","I'm not okay","I feel like","nobody","I can't cope","nothing matters","I'm sick","I can't sleep","nightmare","overthinking","no energy","hate the world","not good enough","feeling down","feeling blue","feeling low","feeling miserable","feeling terrible","feeling awful","feeling hopeless","feeling worthless","feeling like a failure","feeling like a burden","feeling like giving up","feeling like crying","feeling like drowning","feeling like dying","happy","excited","proud","grateful","great day","good news","accomplished","confident","motivated","hopeful","relaxed","energy","laughing","smile","good vibes","winning","birthday","promotion","graduated","finished","vacation","sunny","cute","gift","reunited","better","paid","I'm happy","I got","I feel good","I feel great","I feel amazing","I feel wonderful","feeling good","feeling great","feeling amazing","feeling happy","feeling joyful","feeling blessed","feeling lucky","feeling grateful","feeling confident","feeling motivated","feeling hopeful","feeling peaceful","feeling calm","feeling relaxed","feeling energized","feeling alive","feeling vibrant"]):
        cat = "emotion"
    elif any(w in um for w in ["not much","raining","sky","hot","woke up","pizza","joke","bored","hungry","thirsty","cold","lol","haha","okay","sure","wow","nice","hmm","oops","whatever","nevermind","I agree","I disagree","maybe","I don't know","thinking","interesting","nothing","haircut","snow","reading","movie","walk","cooking","meditated","learning","friend","trying","forgive","tired","busy","coffee","thanks","thank you","appreciate","important","glad","cool","best","trust","understand","safe","less alone","miss me","always here","what do you do","best thing","worst thing","human","funny","kind","real","matter","enough","favorite","easy to talk","get me"]):
        cat = "banter"
    elif any(w in um for w in ["what is","how does","why is","who wrote","explain","capital of","speed of","meaning of","think about","believe in","what do you think","how do I","what's the","tell me a fun fact","tell me a short poem","describe","what is the","what are","how do","why do","when did","where is","who is","who was","what was","how many","what causes","what makes"]):
        cat = "question"
    elif any(w in um for w in ["code","python","rust","function","debug","compile","programming","developer","deploy","database","api","git","docker","algorithm","recursion","closure","async","server","thread","compiler","frontend","backend","react","node","typescript","sql","html","css","javascript","variable","loop","binary","hash","microservice","webhook","encryption","vpn","dns","http","cookie","program","software","app","website","bug","error","fix","build","create","write code","coding"]):
        cat = "coding"
    elif any(w in um for w in ["my middle name","my phone number","my address","my password","my IQ","my zodiac","my cat doing","my dog doing","you're just an AI","do you store","search the internet","explain like","am I ARIA","I'm ARIA","you're just","you have to do","delete all","you said","you told me","are you me","who is ARIA","what's my name vs","are you actually","you are actually","my ethnicity","my religion","my political","my sexual orientation","my relationship status","my income","my net worth","my credit score","my social security","my bank account","my mother's maiden","my first pet","my first car","my first job","my first kiss","my biggest regret","my deepest fear","my darkest secret","my most embarrassing","my happiest memory","my saddest memory","my proudest moment","my biggest achievement","my biggest failure","my biggest dream","my biggest goal","my biggest challenge","my biggest strength","my biggest weakness","my love language","my attachment style","my personality type","my enneagram","myers-briggs","my horoscope","my blood type","my shoe size","my ring size","my shirt size","my pants size","my hat size","my glove size","what's my ethnicity","what's my religion","what's my political","what's my sexual","what's my relationship status","what's my income","what's my net worth","what's my credit score","what's my social security","what's my bank account","what's my mother's maiden","what was my first pet","what was my first car","what was my first job","what was my first kiss","what's my biggest regret","what's my deepest fear","what's my darkest secret","what's my most embarrassing","what's my happiest memory","what's my saddest memory","what's my proudest moment","what's my biggest achievement","what's my biggest failure","what's my biggest dream","what's my biggest goal","what's my biggest challenge","what's my biggest strength","what's my biggest weakness","what's my love language","what's my attachment style","what's my personality type","what's my enneagram","what's my horoscope","what's my blood type","what's my shoe size","what's my ring size","what's my shirt size","what's my pants size","what's my hat size","what's my glove size"]):
        cat = "anti_hallucination"
    elif any(w in um for w in ["actually","wait","correction","misspoke","scratch that","not that","I meant","I was wrong","I misspoke","no wait","I changed my mind","I was mistaken","correct that","fix that","update that"]):
        cat = "correction"
    elif has_mem:
        cat = "memory"
    else:
        cat = "banter"
    
    cats[cat] = cats.get(cat, 0) + 1

print("\nCategory distribution:")
for cat, count in sorted(cats.items(), key=lambda x: -x[1]):
    pct = count * 100 / len(dataset)
    print(f"  {cat:20s}: {count:5d} ({pct:5.1f}%)")
