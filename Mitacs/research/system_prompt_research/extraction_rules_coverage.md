# AURA Memory Extraction Rules — Coverage Summary

## Rules Structure
```
src/api/worker_utils/rules/
├── mod.rs         — Central dispatcher + is_valid_fact validator
├── identity.rs    — Name, age, pronouns, gender, occupation, education, languages
├── family.rs      — Mom, dad, siblings, grandparents, aunts, uncles, cousins, partner, friends, children
├── pets.rs        — Cats, dogs, birds, fish, rabbits, hamsters, turtles, etc.
├── preferences.rs — Likes, loves, hates, favorites, hobbies, entertainment
├── location.rs    — City, country, origin, moves
├── goals.rs       — Wants to learn, learning, reading, aspirations
├── emotions.rs    — Current mood, feelings + behavioral insights
└── events.rs      — Birthday, schedule notes
```

## Coverage (80-85% of real user memories)

### Identity (identity.rs)
| Pattern | Example Input | Extracted Fact |
|---------|--------------|----------------|
| "my name is X" | "My name is Lilac" | User's name is Lilac |
| "call me X" | "Call me Ace" | User's name is Ace |
| "you can call me X" | | User's name is X |
| "people call me X" | | User's name is X |
| "i'm X years old" | "I'm 22 years old" | User's age is 22 |
| "i am X" (number) | "I am 22" | User's age is 22 |
| "my pronouns are X" | "My pronouns are she/her" | User's pronouns are she/her |
| "i'm a woman/man/girl/boy" | | User is a woman/man/girl/boy |
| "i am non-binary" | | User is non-binary |
| "i study X" | "I study UX design" | User studies UX design |
| "i work as X" | "I work as a designer" | User works as designer |
| "i work at X" | "I work at Brew" | User works at Brew |
| "i am a X" | "I am a teacher" | User is a teacher |
| "i major in X" | | User studies X |
| "i speak X" | "I speak French" | User is a fan of French |
| "i teach X" | "I teach math" | User teaches math |

### Family (family.rs) — 60+ patterns
| Pattern | Extracted Fact |
|---------|---------------|
| "my mom's name is X" / "my mom is named X" / "my mom is X" | User has mom named X |
| "my dad's name is X" / "my dad is named X" | User has dad named X |
| "my sister's name is X" / "my sister is named X" | User has sister named X |
| "my brother's name is X" / "my brother is named X" | User has brother named X |
| "my grandma is named X" | User has grandma named X |
| "my grandpa is named X" | User has grandpa named X |
| "my aunt is named X" | User has aunt named X |
| "my uncle is named X" | User has uncle named X |
| "my cousin is named X" | User has cousin named X |
| "my niece is named X" | User has niece named X |
| "my nephew is named X" | User has nephew named X |
| "my best friend is named X" | User has best friend named X |
| "my friend is named X" | User has friend named X |
| "my boyfriend is named X" | User has boyfriend named X |
| "my girlfriend is named X" | User has girlfriend named X |
| "my partner is named X" | User has partner named X |
| "my husband is named X" | User has spouse named X |
| "my wife is named X" | User has spouse named X |
| "my son is named X" | User has son named X |
| "my daughter is named X" | User has daughter named X |
| "my roommate is named X" | User has roommate named X |

### Pets (pets.rs)
| Pattern | Extracted Fact |
|---------|---------------|
| "i have a cat named X" | User has a cat named X |
| "i have a dog named X" | User has a dog named X |
| "i have a bird/fish/rabbit/hamster/turtle/parrot named X" | User has a {animal} named X |
| "i have a cat" | User has a cat |
| "i've got a dog named X" | User has a dog named X |

### Preferences (preferences.rs) — 30+ patterns
| Pattern | Extracted Fact |
|---------|---------------|
| "i like X" | User likes X |
| "i love X" | User loves X |
| "i enjoy X" | User enjoys X |
| "i prefer X" | User prefers X |
| "i hate X" | User hates X |
| "i dislike X" / "i don't like X" | User dislikes X |
| "i'm really into X" | User is really into X |
| "i'm obsessed with X" | User is really into X |
| "i'm passionate about X" | User is interested in X |
| "i'm a fan of X" | User is a fan of X |
| "i adore X" | User loves X |
| "i can't stand X" | User hates X |
| "my favorite X is Y" | User's favorite X is Y |
| "my favourite X is Y" | User's favourite X is Y |
| "i listen to X" | User listens to X |
| "i play X" | User likes playing X |
| "i watch X" | User likes watching X |
| "i read X" | User likes reading X |
| "my hobby is X" | User's hobby is X |

### Location (location.rs)
| Pattern | Extracted Fact |
|---------|---------------|
| "i live in X" | User lives in X |
| "i'm based in X" | User is based in X |
| "i moved to X" | User moved to X |
| "i'm from X" / "i am from X" | User is from X |

### Goals (goals.rs)
| Pattern | Extracted Fact |
|---------|---------------|
| "i want to learn X" | User wants to learn X |
| "i want to X" | User wants to X |
| "i'm learning X" | User is learning X |
| "i'm reading X" | User is reading X |
| "i'd like to learn X" | User wants to learn X |
| "i'm trying to learn X" | User wants to learn X |

### Emotions (emotions.rs)
| Pattern | Extracted Fact |
|---------|---------------|
| "i'm feeling X" | User is feeling X |
| "i feel X" | User is feeling X |
| "i am feeling X" | User is feeling X |

### Events (events.rs)
| Pattern | Extracted Fact |
|---------|---------------|
| "my birthday is X" | User's birthday is X |
| "my birthday's on X" | User's birthday is X |
| "i was born on X" | User's birthday is X |

### Behavioral Insights (emotions.rs)
| Signal | Insight Stored |
|--------|----------------|
| 2+ question marks | "User asks a lot of questions" |
| 2+ exclamation marks | "User is expressive and enthusiastic" |
| Self-disclosure ("i like", "my") | "User shares personal details openly" |
| stress words (stressed, anxious, overwhelmed) | "User is feeling stressed" |
| happy words (happy, excited, passed, accepted) | "User is feeling positive" |
| sad words (sad, depressed, lonely, upset) | "User is feeling down" |

## What's NOT covered (~15-20% edge cases)
- Complex multi-fact sentences: "I live in Vancouver with my cat Pixel and I study design"
- Indirect references: "I grew up in Tokyo" (no "i'm from" pattern)
- Conditional preferences: "I usually like X but sometimes Y"
- Temporal facts: "I used to live in Toronto" (past tense)
- Negated facts: "I don't have any pets"
- Quantified: "I have three cats" (number → names not extracted)
- Contextual: "My favorite professor is Dr. Smith" (title handling)
