#!/usr/bin/env python3
"""
AURA SFT Dataset Generator v5 — 4000 BALANCED examples.
Memory-based examples are NOT deduped (different memory = different training data).
Non-memory examples ARE deduped by prompt.
"""
import json, random, hashlib
random.seed(2026)

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
    "- Stay on topic. Only bring up memories when they are relevant.\n\n"
    "CRITICAL RULE: When user asks explicitly about the current time or date, "
    "output ONLY this exact JSON:\n"
    '{"tool":"get_time","args":{}}'
)

dataset = []
seen_non_mem = set()  # Only dedup non-memory examples

def add(h, g, memory=None):
    if memory:
        # Memory-based: always add (different memory = different training example)
        messages = [{"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "system", "content": f"[MEMORY: {memory}]"},
                    {"role": "user", "content": h},
                    {"role": "assistant", "content": g}]
        dataset.append({"messages": messages})
        return True
    else:
        # Non-memory: dedup by prompt
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
         "Eli","Ivy","Nico","Wren","Jude","Aria","Finn","Zoe","Leo","Mila",
         "Billie","Cass","Harley","Morgan","Parker","River","Emery","Sloane","Tatum","Blair"]
CITIES = ["San Francisco","Nashville","Los Angeles","Austin","Seattle","Boston","Chicago",
          "Denver","Portland","Miami","Toronto","Berlin","Lisbon","Osaka","Perth","Madrid",
          "Paris","Tokyo","London","Sydney","Amsterdam","Seoul","Buenos Aires","Prague","Vienna"]
JOBS = ["a singer","a coder","a designer","a writer","a teacher","a nurse","a barista",
        "a student","a photographer","a musician","an engineer","a researcher","a chef",
        "an artist","a producer","an architect","a therapist","a scientist","a filmmaker",
        "a game developer","a journalist"]
COLORS = ["neon green","deep red","midnight blue","soft pink","warm yellow","violet","teal",
          "burnt orange","silver","indigo","lavender","coral","forest green","gold"]
FOODS = ["sushi","ramen","tacos","pho","dumplings","curry","lasagna","bibimbap","pad thai",
         "falafel","croissants","kimchi","empanadas","poke bowls"]
DRINKS = ["pour over coffee","matcha","cold brew","chai tea","oat milk lattes",
          "sparkling water","green tea","hot chocolate","kombucha"]
PETS = [("dog","Shark"),("cat","Meredith"),("dog","Biscuit"),("cat","Mochi"),("dog","Pebble"),
        ("cat","Pixel"),("dog","Comet"),("cat","Noodles"),("rabbit","Clover"),("dog","Maple"),
        ("cat","Whiskers"),("hamster","Nugget"),("cat","Luna"),("dog","Bear"),("parrot","Kiwi")]
DATES = ["december 18","december 13","march 5","july 21","october 1","february 29",
         "april 16","november 2","january 8","june 30","september 14","august 22","may 3"]
RELS = ["brother","sister","mom","dad","best friend","cousin","partner","grandma","grandpa","aunt","uncle"]
RNN = ["Finneas","Abigail","Austin","Maya","Leo","Zoe","Eli","Ivy","Nico","Wren","Jude","Aria",
       "Finn","Mila","Iris","Kai"]
ALLERGENS = ["peanuts","shellfish","gluten","dairy","soy","pollen","bees","cats","latex"]
THINGS = ["jazz","synthwave","hiking","painting","anime","chess","gardening","astrology",
          "philosophy","baking","climbing","pottery","volunteering","astronomy","street photography",
          "knitting","weightlifting","meditation","dance","sailing","reading","cooking","yoga",
          "surfing","woodworking","origami","birdwatching"]
LANGS = ["Rust","Python","Swift","TypeScript","Go","Kotlin","Haskell","Zig","Ruby","Elixir","Scala","Dart"]
DAWS = ["Logic Pro","Ableton Live","FL Studio","Reaper","Bitwig","Pro Tools","Cubase","Studio One"]
INSTRUMENTS = ["piano","guitar","ukulele","violin","drums","bass","saxophone","flute","trumpet","cello"]
PNS = ["she/her","he/him","they/them","she/they","he/they"]

time_tool = '{"tool":"get_time","args":{}}'

# Load all category data
exec(open("/home/pratay-karali/launch-AURA/scripts/gen_aura_sft_4000_data_balanced.py").read())

# Trim to 4000
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
    
    if "who are you" in um or "what's your name" in um or "what are you" in um or "tell me about yourself" in um or "introduce yourself" in um or "describe yourself" in um or "are you real" in um or "are you human" in um or "do you have feelings" in um or "what's your purpose" in um or "what makes you different" in um:
        cat = "identity"
    elif any(w in um for w in ["bye","goodnight","see you","gotta go","farewell","night","sleep well","cya","later","brb","I'm leaving","I'm heading","I need to go","goodbye"]):
        cat = "farewell"
    elif any(w in um for w in ["sad","lonely","cry","hopeless","anxious","depressed","hurt","scared","worried","exhausted","burnt","guilty","ashamed","betrayed","abandoned","powerless","isolated","unloved","unworthy","rejected","failed","lost","confused","numb","frustrated","regret","shame","jealous","insecure","embarrassed","broken","empty","giving up","drowning","invisible","stuck","panic","shaking","losing","hate myself","not enough","overwhelmed","I'm not okay","I feel like","nobody","I can't cope","nothing matters","I'm sick","I can't sleep","nightmare","overthinking","no energy","hate the world","hate myself","not good enough","compare","lonely at night","feeling down","feeling blue","feeling low","feeling glum","feeling melancholy","feeling miserable","feeling terrible","feeling awful","feeling horrible","feeling dreadful","feeling gloomy","feeling bleak","feeling hopeless","feeling helpless","feeling worthless","feeling useless","feeling stupid","feeling ugly","feeling fat","feeling old","feeling young","feeling lost","feeling confused","feeling overwhelmed","feeling anxious","feeling nervous","feeling scared","feeling afraid","feeling terrified","feeling panicked","feeling stressed","feeling tense","feeling tight","feeling sore","feeling achy","feeling sick","feeling ill","feeling unwell","feeling dizzy","feeling faint","feeling weak","feeling fragile","feeling vulnerable","feeling exposed","feeling raw","feeling empty","feeling hollow","feeling void","feeling blank","feeling numb","feeling dead inside","feeling nothing","feeling everything","feeling too much","feeling not enough","feeling like a failure","feeling like a fraud","feeling like a burden","feeling like a mess","feeling like nobody","feeling like giving up","feeling like quitting","feeling like running away","feeling like hiding","feeling like crying","feeling like screaming","feeling like breaking","feeling like falling","feeling like drowning","feeling like suffocating","feeling like dying"]):
        cat = "emotion_sad"
    elif any(w in um for w in ["happy","excited","proud","grateful","great day","good news","accomplished","confident","motivated","hopeful","relaxed","energy","laughing","smile","good vibes","winning","birthday","promotion","graduated","finished","vacation","sunny","cute","gift","reunited","better","paid","I'm happy","I got","I feel good","I feel great","I feel amazing","I feel wonderful","I feel fantastic","I feel incredible","I feel blessed","I feel lucky","I feel fortunate","I feel thankful","I feel appreciative","I feel content","I feel serene","I feel tranquil","I feel at peace","I feel calm","feeling good","feeling great","feeling amazing","feeling wonderful","feeling fantastic","feeling incredible","feeling blessed","feeling lucky","feeling fortunate","feeling thankful","feeling appreciative","feeling content","feeling serene","feeling tranquil","feeling at peace","feeling calm","feeling joyful","feeling cheerful","feeling delighted","feeling thrilled","feeling ecstatic","feeling elated","feeling overjoyed","feeling euphoric","feeling on top","feeling on cloud","feeling like a million","feeling like a superstar","feeling like I can","feeling unstoppable","feeling invincible","feeling inspired","feeling creative","feeling artistic","feeling productive","feeling focused","feeling energized","feeling refreshed","feeling renewed","feeling revived","feeling alive","feeling vibrant","feeling radiant","feeling glowing","feeling shining","feeling sparkling","feeling dazzling","feeling brilliant","feeling magnificent","feeling fabulous","feeling marvelous","feeling terrific","feeling outstanding","feeling exceptional","feeling extraordinary","feeling phenomenal","feeling spectacular","feeling glorious","feeling triumphant","feeling victorious","feeling successful","feeling accomplished","feeling fulfilled","feeling satisfied","feeling pleased"]):
        cat = "emotion_happy"
    elif any(w in um for w in ["remind me","set a reminder","set a timer"]):
        cat = "scheduling"
    elif any(w in um for w in ["what time","what's the date","current time","what day","what month","what year","is it morning","is it afternoon","is it evening","is it night"]):
        cat = "time_tool"
    elif any(w in um for w in ["code","python","rust","function","debug","compile","programming","developer","deploy","database","api","git","docker","algorithm","recursion","closure","async","server","thread","compiler","frontend","backend","react","node","typescript","sql","html","css","javascript","variable","loop","binary","hash","microservice","webhook","encryption","vpn","dns","http","cookie"]):
        cat = "coding"
    elif any(w in um for w in ["what is","how does","why is","who wrote","explain","capital of","speed of","meaning of","think about","believe in","what do you think","how do I","what's the","tell me a fun fact","tell me a short poem","describe","what is the"]):
        cat = "question"
    elif any(w in um for w in ["my middle name","my phone number","my address","my password","my IQ","my zodiac","my cat doing","my dog doing","just an AI","do you store","search the internet","explain like","am I AURA","I'm AURA","you're just","you have to do","delete all","you said","you told me","are you me","who is AURA","what's my name vs","are you actually","you are actually"]):
        cat = "anti_hallucination"
    elif any(w in um for w in ["actually","wait","correction","misspoke","scratch that","not that","I meant","I was wrong","I misspoke"]):
        cat = "correction"
    elif any(w in um for w in ["is sushi your","is green your","do you have a dog","are you allergic","do you play piano","do you also","are you also","are you a singer","do you also live","do you also hate","do you also like","do you also use","do you also play","do you also have","are you also scared","are you also learning"]):
        cat = "pronoun_boundary"
    elif has_mem:
        cat = "memory"
    else:
        cat = "banter_casual"
    
    cats[cat] = cats.get(cat, 0) + 1

print("\nCategory distribution (train+test):")
for cat, count in sorted(cats.items(), key=lambda x: -x[1]):
    pct = count * 100 / len(dataset)
    print(f"  {cat:20s}: {count:5d} ({pct:5.1f}%)")
