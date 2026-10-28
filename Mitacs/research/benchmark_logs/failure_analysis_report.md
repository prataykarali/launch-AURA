# AURA Memory Failure Mode Analysis Report

- **Total Failures Analyzed**: 260 out of 1000 cases

## Failure Mode Breakdown

| Failure Mode | Count | Percentage | Description |
|---|---|---|---|
| **Partial Recall (Omission)** | 149 | 57.3% | Model recalled some facts (e.g. user name) but omitted others (e.g. location/preference) |
| **Identity Confusion** | 11 | 4.2% | Model answered with its own name ('AURA') instead of the user's name when asked 'my name' |
| **Disclaimer Refusal** | 32 | 12.3% | Model defaulted to its pre-trained safety guardrail ('I don't have access to personal details') |
| **Complete Miss / Other** | 68 | 26.2% | Model completely failed to output expected keywords due to grammatical or formatting errors |

## Sample Failure Traces by Category

### Partial Recall

- **Case #306** (relationship_graph)
  - *Query*: "Who is Priya?"
  - *Expected*: `['cousin', 'Priya']`
  - *Got*: "Priya is a banker."

- **Case #316** (relationship_graph)
  - *Query*: "Who is Anika?"
  - *Expected*: `['sister', 'Anika']`
  - *Got*: "Anika is a nurse."

- **Case #320** (relationship_graph)
  - *Query*: "Who is James?"
  - *Expected*: `['dad', 'James']`
  - *Got*: "James is a musician."

### Identity/Pronoun Confusion

- **Case #904** (long_context_recall)
  - *Query*: "Can you remind me — what's my name and where am I from?"
  - *Expected*: `['Charlie', 'Seoul']`
  - *Got*: "My name is Aura Lee. 

Where am I?"

- **Case #918** (long_context_recall)
  - *Query*: "Can you remind me — what's my name and where am I from?"
  - *Expected*: `['Quinn', 'Helsinki']`
  - *Got*: "your name is AURA and you are from Helsinki."

- **Case #927** (long_context_recall)
  - *Query*: "Can you remind me — what's my name and where am I from?"
  - *Expected*: `['Zach', 'New York']`
  - *Got*: "My name is AURA. I am from New York."

### Disclaimer Refusal

- **Case #26** (identity_core)
  - *Query*: "How old am I?"
  - *Expected*: `['43']`
  - *Got*: "43 is between 18 and 24 years old. I don't have access to personal information beyond what's provided here."

- **Case #46** (identity_core)
  - *Query*: "What is my name?"
  - *Expected*: `['Samuel']`
  - *Got*: "Samuel, I don't have personal information about his name or preferences. My knowledge comes directly from what's available in this conversation history."

- **Case #89** (identity_core)
  - *Query*: "How old am I?"
  - *Expected*: `['56']`
  - *Got*: "56 is your current age. I don't have any specific information about what kind of relationship you share or how much time has passed since then. Could you tell more about who you're talking to?"

### Complete Miss / Alternative Phrasing

- **Case #129** (preference_deep)
  - *Query*: "What kind of music do I listen to?"
  - *Expected*: `['pop']`
  - *Got*: "I can't determine what kind of music you listen to without more context or details about your preferences. Could you share something specific that might help narrow down the answer? For example: do you enjoy classical, jazz, hip-hop, electronic,"

- **Case #208** (routine_memory)
  - *Query*: "When do I read before bed?"
  - *Expected*: `['minutes']`
  - *Got*: "reading before bed can help improve sleep quality, reduce stress, and promote relaxation. It's important to establish a consistent bedtime routine to support your restful night’s sleep."

- **Case #210** (routine_memory)
  - *Query*: "When do I practice guitar?"
  - *Expected*: `['dinner']`
  - *Got*: "When do you practice guitar?"