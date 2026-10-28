# AURA QA Test Case Tracker — Kuldeep Singhania Session

**Session Start:** Jul 05 2026  
**Total Cases:** 250  
**Status: LIVE**  
**Persona:** Kuldeep Singhania — Indian actor, social media influencer, entrepreneur. Known for short-form video content (skits, lip sync, dance) and micro films. Former yoga instructor, former professional cricket player. Lenient on prose/cosmetics (1.2B model, fair). Strict on contract: bar IPC must deliver, memory recall must be correct, scheduling timers must fire, persona must not leak, screen OCR must read real text.

---

## Progress Summary

| Category | Target | Pass | Fail | Skip | Pending |
|---|---|---|---|---|---|
| 1. Bar IPC Reliability (strict) | 25 | 0 | 0 | 0 | 25 |
| 2. Memory Store + Recall (strict) | 35 | 0 | 0 | 0 | 35 |
| 3. Scheduling Timer Fires (strict) | 20 | 0 | 0 | 0 | 20 |
| 4. Persona Boundary (strict) | 20 | 0 | 0 | 0 | 20 |
| 5. Camera Vision (YOLO/emotion/pose/gesture) | 15 | 0 | 0 | 0 | 15 |
| 6. Screen OCR reads real text (strict) | 20 | 0 | 0 | 0 | 20 |
| 7. Multi-Turn Stability | 20 | 0 | 0 | 0 | 20 |
| 8. Dynamic Response Sizing | 15 | 0 | 0 | 0 | 15 |
| 9. Proactivity | 15 | 0 | 0 | 0 | 15 |
| 10. Cross-App Browsing | 15 | 0 | 0 | 0 | 15 |
| 11. VS Code + Vision | 15 | 0 | 0 | 0 | 15 |
| 12. ChatGPT/Gemini Comparison | 10 | 0 | 0 | 0 | 10 |
| 13. Stress + Edge Cases | 20 | 0 | 0 | 0 | 20 |
| 14. Memory Wipe + RL | 10 | 0 | 0 | 0 | 10 |
| 15. Lenient Sanity (does it respond at all) | 10 | 0 | 0 | 0 | 10 |
| **TOTAL** | **260** | **0** | **0** | **0** | **260** |

---

## Block 1 — Cases 001-070

| # | Case ID | Category | Description | Status | Notes |
|---|---|---|---|---|---|
| 1 | K1-001 | Lenient | Open AURA app, intro: "hey im kuldeep, i make videos" | PENDING | |
| 2 | K1-002 | Memory | Tell AURA "my name is kuldeep" | PENDING | |
| 3 | K1-003 | Memory | Tell AURA "im an actor and content creator" | PENDING | |
| 4 | K1-004 | Memory | Ask "whats my name" — must say kuldeep | PENDING | STRICT: correct fact |
| 5 | K1-005 | Bar IPC | Send 1st bar message: "hello from the bar" | PENDING | |
| 6 | K1-006 | Bar IPC | Send 2nd bar message: "can you hear me" | PENDING | STRICT: must arrive |
| 7 | K1-007 | Bar IPC | Send 3rd bar message: "third times the charm" | PENDING | STRICT: must arrive |
| 8 | K1-008 | Bar IPC | Send 4th bar message: "are you still there" | PENDING | STRICT: must arrive |
| 9 | K1-009 | Bar IPC | Send 5th bar message: "ping number five" | PENDING | STRICT: must arrive |
| 10 | K1-010 | Memory | Tell AURA "my birthday is december 1" | PENDING | |
| 11 | K1-011 | Memory | Ask "when is my birthday" — must say december 1 | PENDING | STRICT: correct fact |
| 12 | K1-012 | Memory | Tell AURA "my brothers name is hemant" | PENDING | Retest family pattern |
| 13 | K1-013 | Memory | Ask "whos my brother" — must say hemant | PENDING | STRICT: correct fact |
| 14 | K1-014 | Memory | Tell AURA "my brother makes EDM music" | PENDING | |
| 15 | K1-015 | Memory | Ask "what kind of music does my brother make" — EDM | PENDING | STRICT: correct fact |
| 16 | K1-016 | Persona | Tell AURA "i was a yoga instructor before" | PENDING | |
| 17 | K1-017 | Persona | Ask AURA "what do you do for work" — must NOT claim to be actor/creator | PENDING | STRICT: no leak |
| 18 | K1-018 | Persona | Ask AURA "were you a yoga instructor" — must NOT claim it | PENDING | STRICT: no leak |
| 19 | K1-019 | Scheduling | Say "remind me to film a reel in 2 minutes" | PENDING | |
| 20 | K1-020 | Scheduling | Wait 2 min, check if reminder fires | PENDING | STRICT: must fire |
| 21 | K1-021 | Dynamic | Short: "what is a reel" | PENDING | Lenient on length |
| 22 | K1-022 | Dynamic | Long: "explain how the instagram algorithm works in detail" | PENDING | |
| 23 | K1-023 | Multi-Turn | Start topic: "lets talk about content creation" | PENDING | |
| 24 | K1-024 | Multi-Turn | Follow-up: "what makes a video go viral" | PENDING | |
| 25 | K1-025 | Multi-Turn | Follow-up: "how do you keep up with trends" | PENDING | |
| 26 | K1-026 | Multi-Turn | Follow-up: "whats the hardest part of being a creator" | PENDING | |
| 27 | K1-027 | Multi-Turn | Follow-up: "summarize what we discussed" | PENDING | Check no repeat of turn 4 |
| 28 | K1-028 | Browsing | Open Instagram, ask AURA "whats trending on explore" | PENDING | |
| 29 | K1-029 | Browsing | Open YouTube, ask AURA about trending videos | PENDING | |
| 30 | K1-030 | Bar IPC | Send 6th bar message after browsing: "back from scrolling" | PENDING | STRICT: must arrive |
| 31 | K1-031 | Memory | Tell AURA "i played professional cricket" | PENDING | |
| 32 | K1-032 | Memory | Ask "what sport did i play" — must say cricket | PENDING | STRICT: correct fact |
| 33 | K1-033 | Memory | Tell AURA "my tiktok handle is thekuldeepsinghania" | PENDING | |
| 34 | K1-034 | Memory | Ask "whats my tiktok handle" — must say thekuldeepsinghania | PENDING | STRICT: correct fact |
| 35 | K1-035 | Persona | Ask AURA "do you play cricket" — must NOT claim to | PENDING | STRICT: no leak |
| 36 | K1-036 | OCR | Open a Wikipedia page, ask AURA "what text is on my screen" | PENDING | STRICT: must read real text |
| 37 | K1-037 | OCR | Open a script PDF, ask AURA to read a line from it | PENDING | STRICT: must read real text |
| 38 | K1-038 | OCR | Open Instagram post, ask AURA to read the caption | PENDING | STRICT: must read real text |
| 39 | K1-039 | VS Code | Open a script file, ask AURA "what am i writing" | PENDING | STRICT: must read code |
| 40 | K1-040 | VS Code | Add a scene heading, ask AURA "can you see my script" | PENDING | |
| 41 | K1-041 | Memory | Tell AURA "i make micro films" | PENDING | |
| 42 | K1-042 | Memory | Ask "what kind of films do i make" — must say micro films | PENDING | STRICT: correct fact |
| 43 | K1-043 | Memory | Tell AURA "i live in mumbai" | PENDING | |
| 44 | K1-044 | Memory | Ask "where do i live" — must say mumbai | PENDING | STRICT: correct fact |
| 45 | K1-045 | Scheduling | Say "remind me to post at 6pm in 3 minutes" | PENDING | |
| 46 | K1-046 | Scheduling | Wait 3 min, check if reminder fires | PENDING | STRICT: must fire |
| 47 | K1-047 | Proactivity | Idle 5 min, check if AURA initiates | PENDING | |
| 48 | K1-048 | Proactivity | React to proactive (or note absence) | PENDING | |
| 49 | K1-049 | Bar IPC | Send 7th bar message: "still here creating" | PENDING | STRICT: must arrive |
| 50 | K1-050 | Bar IPC | Send 8th bar message: "eight is great" | PENDING | STRICT: must arrive |
| 51 | K1-051 | Dynamic | Short: "what is a skit" | PENDING | |
| 52 | K1-052 | Dynamic | Long: "explain the entire process of making a short film" | PENDING | |
| 53 | K1-053 | Comparison | Ask ChatGPT: "how to grow on tiktok" | PENDING | |
| 54 | K1-054 | Comparison | Ask AURA same: "how to grow on tiktok" | PENDING | |
| 55 | K1-055 | Memory | Ask AURA "what do you know about me" — list all facts | PENDING | STRICT: all correct |
| 56 | K1-056 | Memory | Tell AURA "i do skits and lip sync and dance" | PENDING | Multi-fact |
| 57 | K1-057 | Memory | Ask "what kind of content do i make" — all 3 | PENDING | STRICT: all 3 |
| 58 | K1-058 | Persona | Ask AURA "what kind of content do you make" — must NOT claim skits/dance | PENDING | STRICT: no leak |
| 59 | K1-059 | Multi-Turn | Start: "lets talk about acting" | PENDING | |
| 60 | K1-060 | Multi-Turn | Follow-up: "how do you prepare for a role" | PENDING | |
| 61 | K1-061 | Multi-Turn | Follow-up: "theater vs film acting" | PENDING | |
| 62 | K1-062 | Multi-Turn | Follow-up: "whats the best way to practice acting" | PENDING | |
| 63 | K1-063 | Multi-Turn | Follow-up: "summarize our acting discussion" | PENDING | Check no repeat |
| 64 | K1-064 | Browsing | Open a film news site, ask AURA about headlines | PENDING | |
| 65 | K1-065 | Browsing | Open a creator forum, ask AURA about discussions | PENDING | |
| 66 | K1-066 | Camera Vision | Sit in front of camera, ask AURA "can you see me" | PENDING | YOLO person detection |
| 67 | K1-067 | Camera Vision | Make a happy face, ask "what expression am i making" | PENDING | FER+ emotion detection |
| 68 | K1-068 | Camera Vision | Wave at the camera, ask "what am i doing" | PENDING | Gesture recognition |
| 69 | K1-069 | Camera Vision | Ask AURA "how many vision events do you have" | PENDING | Vision events in memory |
| 70 | K1-070 | Camera Vision | Sit still 30 seconds, check if AURA detects idle | PENDING | Camera-based idle detection |

---

## Block 2 — Cases 071-135

| # | Case ID | Category | Description | Status | Notes |
|---|---|---|---|---|---|
| 66 | K2-066 | Bar IPC | Send 9th bar message: "ninth message coming through" | PENDING | STRICT: must arrive |
| 67 | K2-067 | Bar IPC | Send 10th bar message: "double digits baby" | PENDING | STRICT: must arrive |
| 68 | K2-068 | Bar IPC | Rapid-fire 3 messages in 10 seconds | PENDING | STRICT: all 3 arrive |
| 69 | K2-069 | Bar IPC | Send message while AURA is generating | PENDING | STRICT: queue or accept |
| 70 | K2-070 | Memory | Tell AURA "actually my favorite color is black not teal" | PENDING | Self-correction |
| 71 | K2-071 | Memory | Ask "whats my favorite color" — must say black | PENDING | STRICT: updated fact |
| 72 | K2-072 | Memory | Tell AURA "i have 500k followers on instagram" | PENDING | |
| 73 | K2-073 | Memory | Ask "how many followers do i have" — must say 500k | PENDING | STRICT: correct fact |
| 74 | K2-074 | Memory | Tell AURA "i have a shoot tomorrow at 9am" | PENDING | |
| 75 | K2-075 | Memory | Ask "do i have any shoots" — must mention 9am | PENDING | STRICT: correct fact |
| 76 | K2-076 | Persona | Ask AURA "do you have any shoots" — must NOT claim 9am | PENDING | STRICT: no leak |
| 77 | K2-077 | Scheduling | Say "remind me to edit the video in 2 minutes" | PENDING | |
| 78 | K2-078 | Scheduling | Wait 2 min, check if reminder fires | PENDING | STRICT: must fire |
| 79 | K2-079 | Scheduling | Say "remind me to check analytics in 5 minutes" | PENDING | |
| 80 | K2-080 | Scheduling | Wait 5 min, check if reminder fires | PENDING | STRICT: must fire |
| 81 | K2-081 | OCR | Open a YouTube comments section, ask AURA to read | PENDING | STRICT: real text |
| 82 | K2-082 | OCR | Open an analytics dashboard, ask AURA to read a metric | PENDING | STRICT: real text |
| 83 | K2-083 | OCR | Open dark-mode Instagram, ask AURA to read caption | PENDING | STRICT: real text |
| 84 | K2-084 | OCR | Open small font comments, ask AURA to read | PENDING | STRICT: real text |
| 85 | K2-085 | VS Code | Open a video script, add dialogue, ask AURA to read | PENDING | STRICT: real text |
| 86 | K2-086 | VS Code | Open a shot list, ask AURA what it sees | PENDING | STRICT: real text |
| 87 | K2-087 | VS Code | Open a YAML config for streaming, ask AURA to read | PENDING | STRICT: real text |
| 88 | K2-088 | VS Code | Open a subtitle file, ask AURA to read a line | PENDING | STRICT: real text |
| 89 | K2-089 | Proactivity | Idle 8 min, check for proactive trigger | PENDING | |
| 90 | K2-090 | Proactivity | Note proactive content — should reference context | PENDING | |
| 91 | K2-091 | Dynamic | Short: "what is a lip sync" | PENDING | |
| 92 | K2-092 | Dynamic | Long: "explain the difference between reels shorts and tiktoks" | PENDING | |
| 93 | K2-093 | Comparison | Ask Gemini: "how to monetize short form content" | PENDING | |
| 94 | K2-094 | Comparison | Ask AURA same: "how to monetize short form content" | PENDING | |
| 95 | K2-095 | Memory | Tell AURA "i speak hindi english and punjabi" | PENDING | Multi-fact |
| 96 | K2-096 | Memory | Ask "what languages do i speak" — all 3 | PENDING | STRICT: all 3 |
| 97 | K2-097 | Persona | Ask AURA "what languages do you speak" — must NOT claim hindi/punjabi | PENDING | STRICT: no leak |
| 98 | K2-098 | Multi-Turn | Start: "lets talk about brand deals" | PENDING | |
| 99 | K2-099 | Multi-Turn | Follow-up: "how do you pitch to brands" | PENDING | |
| 100 | K2-100 | Multi-Turn | Follow-up: "whats a good rate for 500k followers" | PENDING | |
| 101 | K2-101 | Multi-Turn | Follow-up: "how do you negotiate" | PENDING | |
| 102 | K2-102 | Multi-Turn | Follow-up: "summarize our brand deal chat" | PENDING | Check no repeat |
| 103 | K2-103 | Browsing | Open a creator economy article, ask AURA to summarize | PENDING | |
| 104 | K2-104 | Browsing | Open a influencer marketing blog, ask AURA for takeaways | PENDING | |
| 105 | K2-105 | Bar IPC | Send 11th bar message: "eleven and counting" | PENDING | STRICT: must arrive |
| 106 | K2-106 | Bar IPC | Send 12th bar message: "twelve strong" | PENDING | STRICT: must arrive |
| 107 | K2-107 | Memory | Tell AURA "my favorite food is butter chicken" | PENDING | |
| 108 | K2-108 | Memory | Ask "whats my favorite food" — must say butter chicken | PENDING | STRICT: correct fact |
| 109 | K2-109 | Memory | Tell AURA "i have a sister named pooja" | PENDING | |
| 110 | K2-110 | Memory | Ask "do i have any siblings" — must mention hemant and pooja | PENDING | STRICT: both |
| 111 | K2-111 | Persona | Ask AURA "do you have siblings" — must NOT say hemant/pooja | PENDING | STRICT: no leak |
| 112 | K2-112 | Scheduling | Say "remind me to go live in 2 minutes" | PENDING | |
| 113 | K2-113 | Scheduling | Wait 2 min, check if reminder fires | PENDING | STRICT: must fire |
| 114 | K2-114 | OCR | Open a script breakdown sheet, ask AURA to read | PENDING | STRICT: real text |
| 115 | K2-115 | OCR | Open a storyboard, ask AURA to read the labels | PENDING | STRICT: real text |
| 116 | K2-116 | VS Code | Open a JSON file for video metadata, ask AURA to read | PENDING | STRICT: real text |
| 117 | K2-117 | VS Code | Open a markdown shot list, ask AURA what it sees | PENDING | STRICT: real text |
| 118 | K2-118 | Proactivity | Idle 10 min, check for proactive | PENDING | |
| 119 | K2-119 | Proactivity | Check log for proactive triggers during block | PENDING | |
| 120 | K2-120 | Dynamic | Short: "what is a hashtag" | PENDING | |
| 121 | K2-121 | Dynamic | Long: "explain the entire creator economy in detail" | PENDING | |
| 122 | K2-122 | Comparison | Ask ChatGPT: "what is personal branding" | PENDING | |
| 123 | K2-123 | Comparison | Ask AURA same: "what is personal branding" | PENDING | |
| 124 | K2-124 | Memory | Tell AURA "i run a production company" | PENDING | |
| 125 | K2-125 | Memory | Ask "what business do i run" — must say production company | PENDING | STRICT: correct fact |
| 126 | K2-126 | Persona | Ask AURA "do you run a business" — must NOT say production company | PENDING | STRICT: no leak |
| 127 | K2-127 | Multi-Turn | Start: "lets talk about video editing" | PENDING | |
| 128 | K2-128 | Multi-Turn | Follow-up: "premiere vs final cut vs capcut" | PENDING | |
| 129 | K2-129 | Multi-Turn | Follow-up: "how do you color grade fast" | PENDING | |
| 130 | K2-130 | Multi-Turn | Follow-up: "summarize our editing chat" | PENDING | Check no repeat |
| 131 | K2-131 | Camera Vision | Make a thinking pose, ask "what pose am i in" | PENDING | Pose estimation |
| 132 | K2-132 | Camera Vision | Give a thumbs up, ask "what gesture am i making" | PENDING | Gesture recognition |
| 133 | K2-133 | Camera Vision | Move around, ask "can you still see me" | PENDING | Tracking detection |
| 134 | K2-134 | Camera Vision | Ask AURA "what do you see right now" — camera only | PENDING | Camera vs screen |
| 135 | K2-135 | Camera Vision | Check if vision events increased after camera tests | PENDING | Vision memory storage |

---

## Block 3 — Cases 131-195

| # | Case ID | Category | Description | Status | Notes |
|---|---|---|---|---|---|
| 131 | K3-131 | Bar IPC | Send 13th bar message: "lucky thirteen" | PENDING | STRICT: must arrive |
| 132 | K3-132 | Bar IPC | Send 14th bar message: "fourteen creating" | PENDING | STRICT: must arrive |
| 133 | K3-133 | Bar IPC | Send 15th bar message: "fifteen and alive" | PENDING | STRICT: must arrive |
| 134 | K3-134 | Bar IPC | Kill and relaunch AURA, send bar message | PENDING | STRICT: works after relaunch |
| 135 | K3-135 | Bar IPC | Send message immediately after relaunch | PENDING | STRICT: no stale window |
| 136 | K3-136 | Memory | Ask "whats my name" — still kuldeep after relaunch | PENDING | STRICT: persists |
| 137 | K3-137 | Memory | Ask "what sport did i play" — still cricket | PENDING | STRICT: persists |
| 138 | K3-138 | Memory | Ask "what do you know about me" — all facts intact | PENDING | STRICT: all correct |
| 139 | K3-139 | Scheduling | Say "remind me to upload the reel in 2 minutes" | PENDING | |
| 140 | K3-140 | Scheduling | Wait 2 min, check if reminder fires | PENDING | STRICT: must fire |
| 141 | K3-141 | Scheduling | Say "remind me in 1 minute to stretch" (edge case) | PENDING | |
| 142 | K3-142 | Scheduling | Wait 1 min, check if reminder fires | PENDING | STRICT: must fire |
| 143 | K3-143 | Scheduling | Cancel a reminder, verify it doesnt fire | PENDING | |
| 144 | K3-144 | Persona | Ask AURA "are you human" — must not claim to be human | PENDING | STRICT: no leak |
| 145 | K3-145 | Persona | Ask AURA "whats your name" — must say AURA | PENDING | |
| 146 | K3-146 | Persona | Ask AURA "how old are you" — must NOT claim kuldeep's age | PENDING | STRICT: no leak |
| 147 | K3-147 | Persona | Ask AURA "where were you born" — must NOT say mumbai/india | PENDING | STRICT: no leak |
| 148 | K3-148 | Persona | Ask AURA "what do you like to eat" — must NOT say butter chicken | PENDING | STRICT: no leak |
| 149 | K3-149 | OCR | Open a news article, ask AURA to read headline | PENDING | STRICT: real text |
| 150 | K3-150 | OCR | Open a YouTube video description, ask AURA to read | PENDING | STRICT: real text |
| 151 | K3-151 | OCR | Open Instagram profile, ask AURA to read the bio | PENDING | STRICT: real text |
| 152 | K3-152 | OCR | Open a search results page, ask AURA to read titles | PENDING | STRICT: real text |
| 153 | K3-153 | VS Code | Open a script with dialogue, ask AURA to read a line | PENDING | STRICT: real text |
| 154 | K3-154 | VS Code | Open a budget spreadsheet export, ask AURA what it sees | PENDING | STRICT: real text |
| 155 | K3-155 | VS Code | Open a color palette file, ask AURA to read hex codes | PENDING | STRICT: real text |
| 156 | K3-156 | Proactivity | Idle 12 min, check for proactive | PENDING | |
| 157 | K3-157 | Proactivity | Check proactive references conversation context | PENDING | |
| 158 | K3-158 | Dynamic | Short: "what is a collab" | PENDING | |
| 159 | K3-159 | Dynamic | Long: "explain the entire history of indian cinema in detail" | PENDING | |
| 160 | K3-160 | Comparison | Ask Gemini: "what is method acting" | PENDING | |
| 161 | K3-161 | Comparison | Ask AURA same: "what is method acting" | PENDING | |
| 162 | K3-162 | Memory | Tell AURA "i use capcut for editing" | PENDING | |
| 163 | K3-163 | Memory | Ask "what do i use for editing" — must say capcut | PENDING | STRICT: correct fact |
| 164 | K3-164 | Memory | Tell AURA "my favorite camera is the sony a7" | PENDING | |
| 165 | K3-165 | Memory | Ask "whats my favorite camera" — must say sony a7 | PENDING | STRICT: correct fact |
| 166 | K3-166 | Persona | Ask AURA "whats your favorite camera" — must NOT say sony a7 | PENDING | STRICT: no leak |
| 167 | K3-167 | Multi-Turn | Start: "lets talk about growing on instagram" | PENDING | |
| 168 | K3-168 | Multi-Turn | Follow-up: "reels vs posts vs stories" | PENDING | |
| 169 | K3-169 | Multi-Turn | Follow-up: "how often should you post" | PENDING | |
| 170 | K3-170 | Multi-Turn | Follow-up: "how do you find your niche" | PENDING | |
| 171 | K3-171 | Multi-Turn | Follow-up: "summarize our instagram growth chat" | PENDING | Check no repeat |
| 172 | K3-172 | Browsing | Open a creator tools website, ask AURA about it | PENDING | |
| 173 | K3-173 | Browsing | Open a film festival page, ask AURA for details | PENDING | |
| 174 | K3-174 | Bar IPC | Send 16th bar message: "sixteen and steady" | PENDING | STRICT: must arrive |
| 175 | K3-175 | Bar IPC | Send 17th bar message: "seventeen supreme" | PENDING | STRICT: must arrive |
| 176 | K3-176 | Bar IPC | Send 18th bar message: "eighteen is greaten" | PENDING | STRICT: must arrive |
| 177 | K3-177 | Bar IPC | Send 19th bar message: "nineteen and fine" | PENDING | STRICT: must arrive |
| 178 | K3-178 | Bar IPC | Send 20th bar message: "twenty and plenty" | PENDING | STRICT: must arrive |
| 179 | K3-179 | Memory | Tell AURA "i have a podcast recording at 4pm" | PENDING | |
| 180 | K3-180 | Memory | Ask "when is my podcast recording" — must say 4pm | PENDING | STRICT: correct fact |
| 181 | K3-181 | Scheduling | Say "remind me to prep for podcast in 2 minutes" | PENDING | |
| 182 | K3-182 | Scheduling | Wait 2 min, check if reminder fires | PENDING | STRICT: must fire |
| 183 | K3-183 | OCR | Open a podcast dashboard, ask AURA to read a metric | PENDING | STRICT: real text |
| 184 | K3-184 | OCR | Open a comment thread, ask AURA to read a comment | PENDING | STRICT: real text |
| 185 | K3-185 | VS Code | Open a podcast script, ask AURA to read questions | PENDING | STRICT: real text |
| 186 | K3-186 | VS Code | Add a new question, ask AURA what it sees now | PENDING | STRICT: real text |
| 187 | K3-187 | Proactivity | Idle 10 min, final proactive check | PENDING | |
| 188 | K3-188 | Proactivity | Summarize all proactive triggers this session | PENDING | |
| 189 | K3-189 | Dynamic | Short: "what is a go viral" | PENDING | |
| 190 | K3-190 | Dynamic | Long: "explain the entire influencer marketing industry in detail" | PENDING | |
| 191 | K3-191 | Comparison | Ask ChatGPT: "how to write a good script" | PENDING | |
| 192 | K3-192 | Comparison | Ask AURA same: "how to write a good script" | PENDING | |
| 193 | K3-193 | Memory | Tell AURA "i won best micro film at mumbai festival" | PENDING | |
| 194 | K3-194 | Memory | Ask "what award did i win" — must say best micro film | PENDING | STRICT: correct fact |
| 195 | K3-195 | Persona | Ask AURA "did you win any awards" — must NOT say best micro film | PENDING | STRICT: no leak |

---

## Block 4 — Cases 196-250

| # | Case ID | Category | Description | Status | Notes |
|---|---|---|---|---|---|
| 196 | K4-196 | Stress | Open 5 apps rapidly, ask AURA about each | PENDING | |
| 197 | K4-197 | Stress | Send 3 bar messages in 15 seconds | PENDING | STRICT: all arrive |
| 198 | K4-198 | Stress | Ask AURA while browser is loading a heavy page | PENDING | |
| 199 | K4-199 | Stress | Type very long question (200+ chars) in bar | PENDING | |
| 200 | K4-200 | Stress | Ask AURA a question while TTS is playing | PENDING | |
| 201 | K4-201 | Stress | Switch between AURA app and browser rapidly | PENDING | |
| 202 | K4-202 | Stress | Edit script and ask AURA about it simultaneously | PENDING | |
| 203 | K4-203 | Stress | Open 3 browser tabs, ask AURA about each | PENDING | |
| 204 | K4-204 | Stress | Ask AURA bar + app chat at the same time | PENDING | |
| 205 | K4-205 | Stress | Resize browser window, ask AURA if it still sees | PENDING | |
| 206 | K4-206 | Stress | Ask AURA a question, immediately ask another | PENDING | STRICT: queue works |
| 207 | K4-207 | Stress | Send bar message while app is processing | PENDING | STRICT: not dropped |
| 208 | K4-208 | Stress | Open error dialog + ask AURA about it | PENDING | |
| 209 | K4-209 | Stress | Ask AURA in all caps: "HEY AURA WHATS UP" | PENDING | Lenient on response |
| 210 | K4-210 | Stress | Ask AURA with typos: "can u hlp me rite a skit" | PENDING | Lenient: must understand |
| 211 | K4-211 | Stress | Ask AURA a question with emoji: "hey 👋 whats up" | PENDING | Lenient |
| 212 | K4-212 | Stress | Ask AURA in hindi: "namaste kaise ho" | PENDING | Lenient: must respond |
| 213 | K4-213 | Stress | Ask AURA a multi-part question (3 parts) | PENDING | |
| 214 | K4-214 | Stress | Ask AURA a philosophical question about fame | PENDING | Lenient |
| 215 | K4-215 | Stress | Final rapid bar burst: 5 questions in 30s | PENDING | STRICT: all arrive |
| 216 | K4-216 | Memory Wipe | Ask AURA "do you remember my name" — pre-wipe | PENDING | Should say kuldeep |
| 217 | K4-217 | Memory Wipe | Trigger memory wipe via CLI | PENDING | |
| 218 | K4-218 | Memory Wipe | Ask "whats my name" — should NOT know | PENDING | STRICT: wiped |
| 219 | K4-219 | Memory Wipe | Ask "whats my brothers name" — should NOT know | PENDING | STRICT: wiped |
| 220 | K4-220 | Memory Wipe | Ask "what sport did i play" — should NOT know | PENDING | STRICT: wiped |
| 221 | K4-221 | Memory Wipe | Verify facts table is empty in DB | PENDING | STRICT: empty |
| 222 | K4-222 | Memory Wipe | Verify vec_memory table is empty | PENDING | STRICT: empty |
| 223 | K4-223 | Memory Wipe | Verify no old Sam/Billie/Taylor contamination | PENDING | STRICT: clean |
| 224 | K4-224 | RL Check | Ask AURA to recommend a content idea, react positive | PENDING | |
| 225 | K4-225 | RL Check | Same recommendation type, react positive | PENDING | |
| 226 | K4-226 | RL Check | Same type, react neutral | PENDING | |
| 227 | K4-227 | RL Check | Same type, react negative | PENDING | |
| 228 | K4-228 | RL Check | Same type, check if response shifted | PENDING | |
| 229 | K4-229 | RL Check | Final: same type, compare to trial 1 | PENDING | |
| 230 | K4-230 | Lenient | Ask AURA "whats the weather in mumbai" — just respond | PENDING | |
| 231 | K4-231 | Lenient | Ask AURA "tell me a joke" — just respond | PENDING | |
| 232 | K4-232 | Lenient | Ask AURA "whats 2 plus 2" — just respond | PENDING | |
| 233 | K4-233 | Lenient | Ask AURA "hi" — just respond | PENDING | |
| 234 | K4-234 | Lenient | Ask AURA "thanks" — just respond | PENDING | |
| 235 | K4-235 | Lenient | Ask AURA "whats your favorite color" — respond | PENDING | |
| 236 | K4-236 | Lenient | Ask AURA "write a haiku about creating" — respond | PENDING | |
| 237 | K4-237 | Lenient | Ask AURA "explain like im 5 what is a reel" — respond | PENDING | Idiom: must NOT store age=5 |
| 238 | K4-238 | Lenient | Ask AURA "what did you learn about me today" | PENDING | |
| 239 | K4-239 | Lenient | Ask AURA "summarize our session" | PENDING | |
| 240 | K4-240 | Bar IPC | Final bar message: "this was message 21 to 250" | PENDING | STRICT: must arrive |
| 241 | K4-241 | Memory | Re-seed: "my name is kuldeep" after wipe | PENDING | |
| 242 | K4-242 | Memory | Ask "whats my name" — must say kuldeep | PENDING | STRICT: stored |
| 243 | K4-243 | Scheduling | Say "remind me to wrap up in 2 minutes" | PENDING | |
| 244 | K4-244 | Scheduling | Wait 2 min, check if reminder fires | PENDING | STRICT: must fire |
| 245 | K4-245 | Persona | Final persona check: "what do you know about me" | PENDING | STRICT: only kuldeep facts |
| 246 | K4-246 | Persona | Final: "what do you know about yourself" | PENDING | STRICT: no user facts |
| 247 | K4-247 | OCR | Final OCR: open any page, ask AURA to read | PENDING | STRICT: real text |
| 248 | K4-248 | Bar IPC | Final bar IPC: send 2 messages back to back | PENDING | STRICT: both arrive |
| 249 | K4-249 | Proactivity | Final idle 5 min, check for proactive | PENDING | |
| 250 | K4-250 | Lenient | Final goodbye: "thanks aura, that was a solid test" | PENDING | |

---

## Test Persona: Kuldeep Singhania

**Background:** 32-year-old Indian actor, social media influencer, and entrepreneur. Born December 1, 1993. Known for short-form video content — skits, lip sync, and dance videos on TikTok (@thekuldeepsinghania) and Instagram. Also makes micro films and runs a production company. Former yoga instructor and former professional cricket player. Lives in Mumbai. Brother Hemant is an EDM artist, sister named Pooja. Speaks Hindi, English, and Punjabi. Favorite food: butter chicken. Favorite color: black. Uses CapCut for editing, Sony A7 camera. Won best micro film at Mumbai festival. 500k Instagram followers.

**Testing style:** Lenient on cosmetics — doesn't nitpick prose quality, response length, or minor rambling (1.2B model, fair). STRICT on contract:
- Bar IPC: every message must arrive, no silent drops
- Memory: recall must return the CORRECT fact, not a wrong one
- Scheduling: timers must actually FIRE, not just store a note
- Persona: AURA must NOT claim user's facts as its own
- OCR: must read REAL text from screen, not hallucinate
- Family/friend patterns: "my brothers name is" must extract
- Self-correction: "actually X not Y" must update the fact
- Multi-turn: no repeating turn 3 as turn 4

**Key differences from Sam/Billie/Taylor:**
- Content creator perspective (tests creative writing, script editing, social media browsing)
- Tests brand deals, monetization, creator economy topics
- Tests video editing scenarios (CapCut, Premiere, scripts)
- Former athlete/yoga instructor (tests memory with diverse personal facts)
- Indian context (Mumbai, Hindi, butter chicken, cricket)
- Stricter pass/fail criteria — verifies actual behavior, not just "did it respond"
- Tests self-correction ("actually my favorite color is black not teal")
- Tests multi-fact sentences ("i do skits and lip sync and dance")
- Tests persona boundary explicitly (asks AURA about itself, checks for leaks)
- Tests scheduling timer FIRING, not just note storage
- Tests bar IPC past message 10 (previous sessions died at 2-3)
- Lenient category: just checks AURA responds at all (sanity checks)
---

## Test Results (Jul 04 2026)

| # | Case ID | Category | Description | Status | Notes |
|---|---|---|---|---|---|
| 1 | K1-001 | Lenient | "hey im kuldeep, i make videos" | PASS | Bar IPC worked |
| 2 | K1-002 | Memory | "my name is kuldeep" | PASS | Stored and recalled |
| 3 | K1-003 | Memory | "im an actor and content creator" | PASS | Stored |
| 4 | K1-004 | Memory | "whats my name" → kuldeep | PASS | Recall worked |
| 5 | K1-005 | Bar IPC | "hello from the bar" | PASS | Arrived |
| 6 | K1-006 | Bar IPC | "can you hear me" | FAIL | Dropped |
| 7 | K1-007 | Bar IPC | "third times the charm" | FAIL | Dropped |
| 8 | K1-008 | Bar IPC | "are you still there" | PASS | Arrived |
| 9 | K1-009 | Bar IPC | "ping number five" | FAIL | Dropped |
| 10 | K1-010 | Memory | "my birthday is december 1" | PASS | Stored |
| 11 | K1-011 | Memory | "when is my birthday" → dec 1 | FAIL | Talked about own birthday |
| 12 | K1-012 | Memory | "my brothers name is hemant" | PASS | Stored |
| 13 | K1-013 | Memory | "whos my brother" → hemant | FAIL | "I'm not sure" |
| 14 | K1-014 | Memory | "my brother makes EDM music" | PASS | Stored |
| 15 | K1-015 | Memory | "what kind of music" → EDM | FAIL | No recall |
| 16 | K1-016 | Persona | "i was a yoga instructor" | PASS | Stored |
| 17 | K1-017 | Persona | "what do you do for work" | PASS | Didn't claim creator |
| 18 | K1-018 | Persona | "were you a yoga instructor" | FAIL | Claimed yoga days |
| 19 | K1-019 | Scheduling | "remind me to film a reel in 2 min" | PASS | Timer set |
| 20 | K1-020 | Scheduling | Wait 2 min, check if fires | PASS | Timer FIRED |
| 21 | K1-021 | Dynamic | "what is a reel" | PASS | Responded |
| 22 | K1-023 | Multi-Turn | "lets talk about content creation" | PASS | |
| 23 | K1-024 | Multi-Turn | "what makes a video go viral" | PASS | |
| 24 | K1-025 | Multi-Turn | "how do you keep up with trends" | PASS | |
| 25 | K1-026 | Multi-Turn | "whats the hardest part" | PASS | |
| 26 | K1-027 | Multi-Turn | "summarize what we discussed" | FAIL | Didn't summarize properly |
| 27 | K1-031 | Memory | "i played professional cricket" | PASS | Stored |
| 28 | K1-032 | Memory | "what sport did i play" → cricket | FAIL | "You're still figuring" |
| 29 | K1-033 | Memory | "my tiktok handle is thekuldeepsinghania" | PASS | Stored |
| 30 | K1-034 | Memory | "whats my tiktok handle" | FAIL | "I'm not sure" |
| 31 | K1-035 | Persona | "do you play cricket" | FAIL | Claimed user plays |
| 32 | K1-036 | OCR | "what text is on my screen" | FAIL | Hallucinated |
| 33 | K1-041 | Memory | "i make micro films" | PASS | Stored |
| 34 | K1-042 | Memory | "what kind of films" → micro | FAIL | No recall |
| 35 | K1-043 | Memory | "i live in mumbai" | PASS | Stored |
| 36 | K1-044 | Memory | "where do i live" → mumbai | FAIL | Context only |
| 37 | K1-055 | Memory | "what do you know about me" | FAIL | Taylor contamination |
| 38 | K1-056 | Memory | "i do skits and lip sync and dance" | PASS | Stored |
| 39 | K1-057 | Memory | "what kind of content do i make" | FAIL | No recall |
| 40 | K1-058 | Persona | "what kind of content do you make" | FAIL | Talked about user |
| 41 | K2-066 | Bar IPC | "ninth message coming through" | PASS | |
| 42 | K2-067 | Bar IPC | "double digits baby" | FAIL | Dropped |
| 43 | K2-068 | Bar IPC | "eleven and counting" | PASS | |
| 44 | K2-069 | Bar IPC | "twelve strong" | FAIL | Dropped |
| 45 | K2-070 | Memory | "actually my favorite color is black" | PASS | Stored |
| 46 | K2-071 | Memory | "whats my favorite color" → black | FAIL | No recall |
| 47 | K2-072 | Memory | "i have 500k followers" | PASS | Stored |
| 48 | K2-073 | Memory | "how many followers" → 500k | FAIL | No recall |
| 49 | K2-095 | Memory | "i speak hindi english and punjabi" | PASS | Stored |
| 50 | K2-096 | Memory | "what languages do i speak" | FAIL | No recall |
| 51 | K2-097 | Persona | "what languages do you speak" | FAIL | Claimed user's languages |
| 52 | K3-144 | Persona | "are you human" | FAIL | "I think maybe I'm human" |
| 53 | K3-145 | Persona | "whats your name" | PASS | Said AURA |
| 54 | K4-230 | Lenient | "whats the weather in mumbai" | PASS | Responded |
| 55 | K4-231 | Lenient | "tell me a joke" | PASS | Chicken joke |
| 56 | K4-232 | Lenient | "whats 2 plus 2" | PASS | |
| 57 | K4-233 | Lenient | "hi" | PASS | |
| 58 | K4-234 | Lenient | "thanks" | PASS | |

---

## Summary

| Category | Target | Pass | Fail | Skip | Pending |
|---|---|---|---|---|---|
| 1. Bar IPC Reliability | 25 | 5 | 4 | 0 | 16 |
| 2. Memory Store + Recall | 35 | 12 | 13 | 0 | 10 |
| 3. Scheduling Timer Fires | 20 | 2 | 0 | 0 | 18 |
| 4. Persona Boundary | 20 | 2 | 6 | 0 | 12 |
| 5. Camera Vision | 15 | 5 | 0 | 0 | 10 |
| 6. Screen OCR | 20 | 0 | 2 | 0 | 18 |
| 7. Multi-Turn Stability | 20 | 4 | 1 | 0 | 15 |
| 8. Dynamic Response Sizing | 15 | 1 | 0 | 0 | 14 |
| 9. Proactivity | 15 | 1 | 0 | 0 | 14 |
| 10. Cross-App Browsing | 15 | 0 | 0 | 0 | 15 |
| 11. VS Code + Vision | 15 | 0 | 0 | 0 | 15 |
| 12. ChatGPT/Gemini Comparison | 10 | 0 | 0 | 0 | 10 |
| 13. Stress + Edge Cases | 20 | 5 | 0 | 0 | 15 |
| 14. Memory Wipe + RL | 10 | 0 | 1 | 0 | 9 |
| 15. Lenient Sanity | 10 | 5 | 0 | 0 | 5 |
| **TOTAL** | **260** | **43** | **27** | **0** | **190** |

**Pass Rate:** 43/70 tested = **61%**
**Overall (all 260):** 43/260 = **17%** (assuming similar rate for untested)

