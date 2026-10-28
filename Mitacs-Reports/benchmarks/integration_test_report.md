# AURA Integration Test Report

- Date: 2026-07-01 14:00:35
- Total Cases: 120
- Passed: 108
- Failed: 12
- Accuracy: 90.0%

## Results by Suite

- **LLM**: 15/20 (75.0%)
- **PROACTIVE**: 44/50 (88.0%)
- **VISION**: 49/50 (98.0%)

## All Test Cases

| ID | Suite | Category | Difficulty | Passed | Description |
|----|-------|----------|------------|--------|-------------|
| 1 | proactive | schedule_extraction | simple | PASS | Schedule detection: 'remind me to call mom' |
| 2 | proactive | schedule_extraction | simple | PASS | Schedule detection: 'remind me to take my medicine' |
| 3 | proactive | schedule_extraction | simple | PASS | Schedule detection: 'wake me up at 7am' |
| 4 | proactive | schedule_extraction | simple | PASS | Schedule detection: 'set a reminder for my meeting' |
| 5 | proactive | schedule_extraction | medium | PASS | Schedule detection: 'remind me to call the dentist tomorrow afternoon' |
| 6 | proactive | schedule_extraction | medium | PASS | Schedule detection: 'don't let me forget to pick up groceries after work' |
| 7 | proactive | schedule_extraction | medium | PASS | Schedule detection: 'schedule a meeting with my professor next week' |
| 8 | proactive | schedule_extraction | medium | PASS | Schedule detection: 'wake me up before my flight at 6am' |
| 9 | proactive | schedule_extraction | extreme | PASS | Schedule detection: 'remind me to wish my mom a happy birthday on March 15th and also remind me to buy flowers' |
| 10 | proactive | schedule_extraction | extreme | PASS | Schedule detection: 'hi' |
| 11 | proactive | bandit_cooldown | simple | PASS | Bandit cooldown: fired trigger blocked, other available |
| 12 | proactive | bandit_selection | medium | PASS | Bandit prefers higher engagement score |
| 13 | proactive | bandit_exploration | simple | PASS | Bandit always returns when single trigger exists |
| 14 | proactive | bandit_empty | simple | FAIL | Bandit returns None when no triggers exist |
| 15 | proactive | bandit_mark_fired | simple | FAIL | mark_trigger_fired puts trigger in cooldown |
| 16 | proactive | bandit_engagement | simple | PASS | record_engagement(engaged=true) updates score |
| 17 | proactive | bandit_n_engaged | medium | PASS | n_engaged increments only for engaged=true |
| 18 | proactive | bandit_ignored | simple | PASS | Ignored trigger gets zero reward (score drops) |
| 19 | proactive | bandit_logging | simple | PASS | log_proactive stores events with correct types |
| 20 | proactive | bandit_cooldown_blocks | medium | PASS | Fired trigger is blocked by 300s cooldown |
| 21 | proactive | spam_prevention | simple | FAIL | No trigger fires within 300s cooldown |
| 22 | proactive | spam_prevention | simple | FAIL | mark_trigger_fired prevents immediate re-fire |
| 23 | proactive | spam_prevention | medium | FAIL | Only non-fired triggers available after multiple fires |
| 24 | proactive | spam_prevention | medium | PASS | Same trigger cannot fire again within cooldown |
| 25 | proactive | spam_prevention | simple | FAIL | Different triggers can fire independently |
| 26 | proactive | spam_prevention | medium | PASS | Normal chat not detected as schedule request |
| 27 | proactive | spam_prevention | edge | PASS | Short input (<8 chars) rejected by schedule extractor |
| 28 | proactive | spam_prevention | edge | PASS | Long input (>240 chars) rejected by schedule extractor |
| 29 | proactive | proactive_context | simple | PASS | Empty store returns minimal context |
| 30 | proactive | proactive_context | simple | PASS | Context includes stored facts |
| 31 | proactive | proactive_context | medium | PASS | Context includes recent turns |
| 32 | proactive | proactive_context | medium | PASS | Context includes vision notes |
| 33 | proactive | proactive_context | hard | PASS | Context includes conversation summary |
| 34 | proactive | proactive_context | hard | PASS | Facts appear before turns in proactive context |
| 35 | proactive | proactive_context | edge | PASS | Context respects character limits with many facts |
| 36 | proactive | trigger_types | simple | PASS | Trigger type 'bandit' logged correctly |
| 37 | proactive | trigger_types | simple | PASS | Trigger type 'clock' logged correctly |
| 38 | proactive | trigger_types | simple | PASS | Trigger type 'idle' logged correctly |
| 39 | proactive | trigger_types | simple | PASS | Trigger type 'debug' logged correctly |
| 40 | proactive | trigger_types | medium | PASS | Mixed trigger types logged correctly |
| 41 | proactive | schedule_extraction | edge | PASS | Schedule detection: 'REMIND ME TO SUBMIT THE REPORT' |
| 42 | proactive | schedule_extraction | edge | PASS | Schedule detection: 'can you remind me to study' |
| 43 | proactive | schedule_extraction | edge | PASS | Schedule detection: 'pls remind me' |
| 44 | proactive | schedule_extraction | edge | PASS | Schedule detection: 'remind' |
| 45 | proactive | schedule_extraction | edge | PASS | Schedule detection: 'dont let me forget to feed the cat' |
| 46 | proactive | schedule_extraction | edge | PASS | Schedule detection: 'what's the weather like' |
| 47 | proactive | schedule_extraction | edge | PASS | Schedule detection: 'tell me a joke' |
| 48 | proactive | schedule_extraction | edge | PASS | Schedule detection: 'remind me to               clean' |
| 49 | proactive | schedule_extraction | edge | PASS | Schedule detection: 'I need to remind myself to call her' |
| 50 | proactive | schedule_extraction | edge | PASS | Schedule detection: 'set a reminder' |
| 51 | vision | vision_query_detection | simple | PASS | Vision query detection: 'what do you see' |
| 52 | vision | vision_query_detection | simple | PASS | Vision query detection: 'look around' |
| 53 | vision | vision_query_detection | simple | PASS | Vision query detection: 'what's in my room' |
| 54 | vision | vision_query_detection | medium | PASS | Vision query detection: 'can you see my desk' |
| 55 | vision | vision_query_detection | medium | PASS | Vision query detection: 'what am I doing' |
| 56 | vision | vision_query_detection | medium | PASS | Vision query detection: 'am I waving' |
| 57 | vision | vision_query_detection | extreme | PASS | Vision query detection: 'describe my surroundings environment' |
| 58 | vision | vision_query_detection | extreme | PASS | Vision query detection: 'what's on my screen' |
| 59 | vision | vision_query_detection | simple | PASS | Vision query detection: 'hello' |
| 60 | vision | vision_query_detection | simple | PASS | Vision query detection: 'what's 2+2' |
| 61 | vision | event_text | simple | PASS | Event text: 1 detections |
| 62 | vision | event_text | simple | PASS | Event text: 1 detections |
| 63 | vision | event_text | medium | PASS | Event text: 2 detections |
| 64 | vision | event_text | medium | PASS | Event text: 3 detections |
| 65 | vision | event_text | extreme | PASS | Event text: 0 detections |
| 66 | vision | event_text | simple | PASS | Event text: 1 detections |
| 67 | vision | event_text | medium | PASS | Event text: 2 detections |
| 68 | vision | event_text | extreme | PASS | Event text: 5 detections |
| 69 | vision | event_text | simple | PASS | Event text: 1 detections |
| 70 | vision | event_text | medium | PASS | Event text: 2 detections |
| 71 | vision | semantic_classification | simple | PASS | Semantic: person+laptop → coding/debugging |
| 72 | vision | semantic_classification | simple | PASS | Semantic: person+book → studying/reading |
| 73 | vision | semantic_classification | medium | PASS | Semantic: person → present/attending |
| 74 | vision | semantic_classification | medium | PASS | Semantic: laptop → computer use/workspace active |
| 75 | vision | semantic_classification | extreme | PASS | Semantic: wave → present/greeting gesture |
| 76 | vision | semantic_classification | simple | PASS | Semantic: person+keyboard → coding/debugging |
| 77 | vision | semantic_classification | medium | PASS | Semantic: person+cell phone → studying/reading |
| 78 | vision | semantic_classification | extreme | PASS | Semantic: person+laptop+keyboard → coding/debugging |
| 79 | vision | semantic_classification | simple | PASS | Semantic: mouse → computer use/workspace active |
| 80 | vision | semantic_classification | medium | PASS | Semantic: clock → environment/object observation |
| 81 | vision | gate | simple | PASS | Gate passes first detection |
| 82 | vision | gate | simple | PASS | Gate deduplicates same label within cooldown |
| 83 | vision | gate | simple | PASS | Gate filters low-confidence detections |
| 84 | vision | gate | medium | PASS | Gate allows detection after cooldown expires |
| 85 | vision | gate | medium | PASS | Gate filters events below importance threshold |
| 86 | vision | gate | medium | PASS | Gate passes multiple detections in one event |
| 87 | vision | gate | simple | PASS | Gate returns None for empty detections |
| 88 | vision | gate | hard | PASS | Gate filters individual low-confidence detections |
| 89 | vision | gate | hard | PASS | Gate emits new labels even when old ones are deduped |
| 90 | vision | gate | medium | PASS | Gate returns None when all detections below confidence |
| 91 | vision | vision_store | simple | PASS | Store and retrieve visual event |
| 92 | vision | vision_store | medium | PASS | Store and retrieve multiple visual events |
| 93 | vision | vision_store | medium | PASS | Retrieve respects limit parameter |
| 94 | vision | vision_store | hard | PASS | Semantic event → memory text conversion |
| 95 | vision | vision_store | simple | PASS | Empty store returns empty visual context |
| 96 | vision | gesture_detection | simple | PASS | Gesture keywords: ["wave"] |
| 97 | vision | gesture_detection | medium | PASS | Gesture keywords: ["open_palm_or_wave_pose"] |
| 98 | vision | gesture_detection | medium | FAIL | Gesture keywords: ["hand_pose"] |
| 99 | vision | gesture_detection | extreme | PASS | Gesture keywords: ["thumbs_up"] |
| 100 | vision | gesture_detection | simple | PASS | Gesture keywords: ["laptop"] |
| 101 | llm | response_length | greeting | PASS | Response length: 'hi' (category=greeting) |
| 102 | llm | response_length | greeting | PASS | Response length: 'hey' (category=greeting) |
| 103 | llm | response_length | acknowledgement | PASS | Response length: 'my name is Alice' (category=acknowledgement) |
| 104 | llm | response_length | factual | PASS | Response length: 'what is 2+2?' (category=factual) |
| 105 | llm | response_length | factual | FAIL | Response length: 'what's my name?' (category=factual) |
| 106 | llm | response_length | open_ended | PASS | Response length: 'explain how the sun works' (category=open_ended) |
| 107 | llm | response_length | emotional | PASS | Response length: 'I'm feeling sad today' (category=acknowledgement) |
| 108 | llm | response_length | identity | PASS | Response length: 'what do I like?' (category=factual) |
| 109 | llm | response_length | task | PASS | Response length: 'write a hello world in python' (category=open_ended) |
| 110 | llm | response_length | casual | PASS | Response length: 'tell me a joke' (category=open_ended) |
| 111 | llm | multi_turn | medium | FAIL | Multi-turn session 1: 5 turns, last query='what is my name?' |
| 112 | llm | multi_turn | medium | FAIL | Multi-turn session 2: 5 turns, last query='what do you know about me?' |
| 113 | llm | multi_turn | medium | PASS | Multi-turn session 3: 5 turns, last query='do you remember how I'm feeling?' |
| 114 | llm | multi_turn | medium | FAIL | Multi-turn session 4: 5 turns, last query='what is my name?' |
| 115 | llm | multi_turn | extreme | FAIL | Multi-turn session 5: 11 turns, last query='tell me everything you know about me' |
| 116 | llm | talks_less | emotional_long | PASS | Talks-less check: 15+ words for 'I'm really struggling with my mental health lately' |
| 117 | llm | talks_less | explain_long | PASS | Talks-less check: 20+ words for 'Can you explain what neural networks are and how t' |
| 118 | llm | talks_less | vent_long | PASS | Talks-less check: 15+ words for 'I had a really long day at work and I just want to' |
| 119 | llm | talks_less | self_intro | PASS | Talks-less check: 10+ words for 'Tell me about yourself, what makes you different f' |
| 120 | llm | talks_less | reflective | PASS | Talks-less check: 15+ words for 'I've been thinking a lot about my future and wheth' |

## Failure Details

### #14 — bandit_empty (simple)
- **Description:** Bandit returns None when no triggers exist
- **Detail:** result=Some((8, "Shall we continue where we left off?"))

### #15 — bandit_mark_fired (simple)
- **Description:** mark_trigger_fired puts trigger in cooldown
- **Detail:** before_mark=Some(6), after_mark=Some(3)

### #21 — spam_prevention (simple)
- **Description:** No trigger fires within 300s cooldown
- **Detail:** suggestion after fire: Some((5, "I've been thinking about our last conversation..."))

### #22 — spam_prevention (simple)
- **Description:** mark_trigger_fired prevents immediate re-fire
- **Detail:** before=true, after=false

### #23 — spam_prevention (medium)
- **Description:** Only non-fired triggers available after multiple fires
- **Detail:** available triggers: [7, 8, 6, 4]

### #25 — spam_prevention (simple)
- **Description:** Different triggers can fire independently
- **Detail:** after firing 1, suggestion: Some(6)

### #98 — gesture_detection (medium)
- **Description:** Gesture keywords: ["hand_pose"]
- **Detail:** detected=false, expected=true

### #105 — response_length (factual)
- **Description:** Response length: 'what's my name?' (category=factual)
- **Detail:** words=3, est_tokens=3, max_tokens=120, plan_category=factual, response='you like ramen'

### #111 — multi_turn (medium)
- **Description:** Multi-turn session 1: 5 turns, last query='what is my name?'
- **Detail:** Should contain 'Alice': false — 'you like ramen, lilac.'

### #112 — multi_turn (medium)
- **Description:** Multi-turn session 2: 5 turns, last query='what do you know about me?'
- **Detail:** tokyo=false, ux=false, pixel=false — 'you asked me who you are – well, it’s just me, but i’ve been chatting with you. your name is l'

### #114 — multi_turn (medium)
- **Description:** Multi-turn session 4: 5 turns, last query='what is my name?'
- **Detail:** robert=false, bob=false — 'you like ramen! or maybe it's lilac - whichever is better for tonight. let’s make something tasty '

### #115 — multi_turn (extreme)
- **Description:** Multi-turn session 5: 11 turns, last query='tell me everything you know about me'
- **Detail:** Found 0/7 keywords — 'you like ramen and sometimes miss feeling safe in this place. it’s okay to feel lost—it happens when you’re betwee'

