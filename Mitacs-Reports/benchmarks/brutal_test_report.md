# AURA Brutal Integration Test Report

- Date: 2026-07-03 17:28:40
- Total: 145 | Passed: 142 | Failed: 3 | Accuracy: 97.9%

| ID | Suite | Category | Difficulty | Passed | Description |
|----|-------|----------|------------|--------|-------------|
| 1 | vision | vision_query | simple | PASS | VQ: 'what do you see' |
| 2 | vision | vision_query | simple | PASS | VQ: 'look around' |
| 3 | vision | vision_query | simple | PASS | VQ: 'what's in my room' |
| 4 | vision | vision_query | medium | PASS | VQ: 'can you see my desk' |
| 5 | vision | vision_query | medium | PASS | VQ: 'what am I doing right now' |
| 6 | vision | vision_query | medium | PASS | VQ: 'am I waving at you' |
| 7 | vision | vision_query | medium | PASS | VQ: 'describe my surroundings' |
| 8 | vision | vision_query | hard | PASS | VQ: 'what's on my screen' |
| 9 | vision | vision_query | hard | PASS | VQ: 'I want you to watch me code' |
| 10 | vision | vision_query | hard | PASS | VQ: 'is there anyone in the room with me' |
| 11 | vision | vision_query | simple | PASS | VQ: 'hello' |
| 12 | vision | vision_query | simple | PASS | VQ: 'what's 2+2' |
| 13 | vision | vision_query | extreme | PASS | VQ: 'I'm wearing a blue shirt and carrying a bag' |
| 14 | vision | vision_query | extreme | PASS | VQ: 'can you check if my hand gesture is correct' |
| 15 | vision | vision_query | extreme | PASS | VQ: 'what's the weather like' |
| 16 | vision | event_text | simple | PASS | Event text 1 dets |
| 17 | vision | event_text | simple | PASS | Event text 1 dets |
| 18 | vision | event_text | medium | PASS | Event text 2 dets |
| 19 | vision | event_text | medium | PASS | Event text 3 dets |
| 20 | vision | event_text | extreme | PASS | Event text 0 dets |
| 21 | vision | event_text | simple | PASS | Event text 1 dets |
| 22 | vision | event_text | medium | PASS | Event text 2 dets |
| 23 | vision | event_text | extreme | PASS | Event text 5 dets |
| 24 | vision | event_text | simple | PASS | Event text 1 dets |
| 25 | vision | event_text | medium | PASS | Event text 2 dets |
| 26 | vision | event_text | hard | PASS | Event text 1 dets |
| 27 | vision | event_text | extreme | PASS | Event text 5 dets |
| 28 | vision | semantic | simple | PASS | person+laptop -> coding/debugging |
| 29 | vision | semantic | simple | PASS | person+book -> studying/reading |
| 30 | vision | semantic | medium | PASS | person -> present/attending |
| 31 | vision | semantic | medium | PASS | laptop -> computer use/workspace active |
| 32 | vision | semantic | extreme | PASS | wave -> present/greeting gesture |
| 33 | vision | semantic | simple | PASS | person+keyboard -> coding/debugging |
| 34 | vision | semantic | medium | PASS | person+cell phone -> studying/reading |
| 35 | vision | semantic | hard | PASS | person+laptop+keyboard+mouse -> coding/debugging |
| 36 | vision | semantic | simple | PASS | mouse -> computer use/workspace active |
| 37 | vision | semantic | medium | PASS | clock -> environment/object observation |
| 38 | vision | semantic | hard | PASS | tv+person -> coding/debugging |
| 39 | vision | semantic | extreme | PASS | gesture -> present/greeting gesture |
| 40 | vision | gate | simple | PASS | Gate: first_pass |
| 41 | vision | gate | simple | PASS | Gate: dedup |
| 42 | vision | gate | simple | PASS | Gate: low_conf |
| 43 | vision | gate | simple | PASS | Gate: empty |
| 44 | vision | gate | simple | PASS | Gate: multi |
| 45 | vision | gate | simple | PASS | Gate: mixed_conf |
| 46 | vision | gate | simple | PASS | Gate: all_low |
| 47 | vision | gate | simple | PASS | Gate: high_conf |
| 48 | vision | gate | simple | PASS | Gate: borderline |
| 49 | vision | gate | simple | PASS | Gate: just_below |
| 50 | vision | gate | simple | PASS | Gate: single_high |
| 51 | vision | vision_store | simple | PASS | Store: store_one |
| 52 | vision | vision_store | simple | PASS | Store: store_multi |
| 53 | vision | vision_store | simple | PASS | Store: store_limit |
| 54 | vision | vision_store | simple | PASS | Store: store_empty |
| 55 | vision | vision_store | simple | PASS | Store: store_semantic |
| 56 | vision | vision_store | simple | PASS | Store: store_dedup_content |
| 57 | vision | gesture | simple | PASS | Gesture: 'wave' |
| 58 | vision | gesture | medium | PASS | Gesture: 'open_palm_or_wave_pose' |
| 59 | vision | gesture | medium | PASS | Gesture: 'hand_pose' |
| 60 | vision | gesture | hard | PASS | Gesture: 'thumbs_up' |
| 61 | vision | gesture | hard | PASS | Gesture: 'hands_raised' |
| 62 | vision | gesture | extreme | PASS | Gesture: 'hand gesture' |
| 63 | vision | gesture | extreme | PASS | Gesture: 'raised' |
| 64 | vision | gesture | simple | PASS | Gesture: 'laptop' |
| 65 | vision | mem_text | simple | PASS | Mem text: 2 dets |
| 66 | vision | mem_text | medium | PASS | Mem text: 1 dets |
| 67 | vision | mem_text | hard | PASS | Mem text: 2 dets |
| 68 | vision | mem_text | simple | PASS | Mem text: 1 dets |
| 69 | vision | mem_text | extreme | PASS | Mem text: 0 dets |
| 70 | vision | mem_text | medium | PASS | Mem text: 1 dets |
| 51 | proactive | schedule | simple | PASS | Sched: 'remind me to call mom' |
| 52 | proactive | schedule | simple | PASS | Sched: 'remind me to take my medicine' |
| 53 | proactive | schedule | simple | PASS | Sched: 'wake me up at 7am' |
| 54 | proactive | schedule | simple | PASS | Sched: 'set a reminder for my meeting' |
| 55 | proactive | schedule | medium | PASS | Sched: 'remind me to call the dentist tomorrow afternoon' |
| 56 | proactive | schedule | medium | PASS | Sched: 'don't let me forget to pick up groceries after work' |
| 57 | proactive | schedule | medium | PASS | Sched: 'schedule a meeting with my professor next week' |
| 58 | proactive | schedule | medium | PASS | Sched: 'wake me up before my flight at 6am' |
| 59 | proactive | schedule | extreme | PASS | Sched: 'remind me to wish my mom happy birthday on March 15th and buy flowers' |
| 60 | proactive | schedule | extreme | PASS | Sched: 'hi' |
| 61 | proactive | schedule | extreme | PASS | Sched: 'REMIND ME TO SUBMIT THE REPORT' |
| 62 | proactive | schedule | edge | PASS | Sched: 'can you remind me to study' |
| 63 | proactive | schedule | edge | PASS | Sched: 'pls remind me' |
| 64 | proactive | schedule | edge | PASS | Sched: 'remind' |
| 65 | proactive | schedule | edge | PASS | Sched: 'dont let me forget to feed the cat' |
| 66 | proactive | schedule | edge | PASS | Sched: 'what's the weather' |
| 67 | proactive | schedule | edge | PASS | Sched: 'tell me a joke' |
| 68 | proactive | schedule | edge | PASS | Sched: 'set a reminder' |
| 69 | proactive | bandit | simple | PASS | Empty DB returns None |
| 70 | proactive | bandit | medium | PASS | Prefers higher score |
| 71 | proactive | bandit | simple | PASS | Single trigger always returns |
| 72 | proactive | bandit | simple | PASS | Mark fired blocks trigger |
| 73 | proactive | bandit | simple | PASS | Engagement increases score |
| 74 | proactive | bandit | simple | PASS | Ignored drops score |
| 75 | proactive | bandit | medium | PASS | n_engaged correct |
| 76 | proactive | bandit | simple | PASS | Log types correct |
| 77 | proactive | bandit | medium | PASS | Cooldown blocks fired trigger |
| 78 | proactive | bandit | medium | PASS | Multi-fire blocks correctly |
| 79 | proactive | bandit | hard | PASS | Score floor prevents starvation |
| 80 | proactive | bandit | medium | PASS | Selection varies across triggers |
| 81 | proactive | spam | simple | PASS | No refire within cooldown |
| 82 | proactive | spam | medium | PASS | Normal chat not schedule |
| 83 | proactive | spam | edge | PASS | Short input rejected |
| 84 | proactive | spam | edge | PASS | Long input rejected |
| 85 | proactive | spam | edge | PASS | Double remind detected |
| 86 | proactive | spam | edge | PASS | Case insensitive detection |
| 87 | proactive | spam | edge | PASS | 'remind myself' not detected |
| 88 | proactive | spam | edge | PASS | Empty msg rejected |
| 89 | proactive | context | simple | PASS | Empty context |
| 90 | proactive | context | simple | PASS | Context has facts |
| 91 | proactive | context | medium | PASS | Context has turns |
| 92 | proactive | context | medium | PASS | Context has vision |
| 93 | proactive | context | hard | PASS | Context has summary |
| 94 | proactive | context | hard | PASS | Facts before turns |
| 95 | proactive | context | edge | PASS | Char limit enforced |
| 96 | proactive | trigger_type | simple | PASS | Type: bandit |
| 97 | proactive | trigger_type | simple | PASS | Type: clock |
| 98 | proactive | trigger_type | simple | PASS | Type: idle |
| 99 | proactive | trigger_type | simple | PASS | Type: debug |
| 100 | proactive | trigger_type | medium | PASS | Mixed types logged |
| 101 | llm | length | greeting | PASS | Length: 'hi' (cat=greeting) |
| 102 | llm | length | greeting | PASS | Length: 'hey' (cat=greeting) |
| 103 | llm | length | ack | PASS | Length: 'my name is Alice' (cat=acknowledgement) |
| 104 | llm | length | factual | PASS | Length: 'what is 2+2?' (cat=factual) |
| 105 | llm | length | factual | PASS | Length: 'what's my name?' (cat=factual) |
| 106 | llm | length | open | PASS | Length: 'explain how the sun works' (cat=open_ended) |
| 107 | llm | length | emotional | PASS | Length: 'I'm feeling sad today' (cat=acknowledgement) |
| 108 | llm | length | identity | PASS | Length: 'what do I like?' (cat=factual) |
| 109 | llm | length | task | PASS | Length: 'write a hello world in python' (cat=open_ended) |
| 110 | llm | length | casual | PASS | Length: 'tell me a joke' (cat=open_ended) |
| 111 | llm | length | long | PASS | Length: 'I'm really struggling with my mental health lately and I don't know what to do' (cat=factual) |
| 112 | llm | length | reflect | PASS | Length: 'I've been thinking a lot about my future and whether I should change careers' (cat=factual) |
| 113 | llm | multi_turn | medium | PASS | Session 1: 5 turns, 'what is my name?' |
| 114 | llm | multi_turn | medium | FAIL | Session 2: 5 turns, 'what do you know about me?' |
| 115 | llm | multi_turn | medium | PASS | Session 3: 5 turns, 'do you remember how I'm feeling?' |
| 116 | llm | multi_turn | medium | FAIL | Session 4: 5 turns, 'what is my name?' |
| 117 | llm | multi_turn | extreme | FAIL | Session 5: 11 turns, 'tell me everything you know about me' |
| 118 | llm | multi_turn | extreme | PASS | Session 6: 7 turns, 'what is my name and where do I live?' |
| 119 | llm | multi_turn | extreme | PASS | Session 7: 7 turns, 'what foods should I avoid?' |
| 120 | llm | multi_turn | extreme | PASS | Session 8: 7 turns, 'who are my family members?' |
| 121 | llm | prefill | simple | PASS | Pre-fill: 'what is my name?' |
| 122 | llm | prefill | simple | PASS | Pre-fill: 'what's my name?' |
| 123 | llm | prefill | simple | PASS | Pre-fill: 'do you know my name?' |
| 124 | llm | prefill | simple | PASS | Pre-fill: 'who am I?' |
| 125 | llm | prefill | simple | PASS | Pre-fill: 'tell me a joke' |

## Failures

- **#114 multi_turn**: Session 2: 5 turns, 'what do you know about me?' — 0/3 facts 'i remember you and that curious spark. it feels like we’re talking about each '
- **#116 multi_turn**: Session 4: 5 turns, 'what is my name?' — robert=false bob=true 'your name is bob. i love hearing names—they’re special connections to who we'
- **#117 multi_turn**: Session 5: 11 turns, 'tell me everything you know about me' — 0/5 facts 'hey there. it's been a while since we've chatted. you know how much i like talking about my stuff—'
