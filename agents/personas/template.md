# Persona Template — DawnAgent

<!--
PURPOSE: Blank scaffolding for creating new agent personas.
HOW TO USE:
  1. Copy this file to agents/personas/your-persona-name.md
  2. Fill in all fields below — delete the comments before use
  3. Write 5 sample opening lines in the persona's voice — this calibrates the tone
  4. Test: python simulate.py --persona agents/personas/your-persona-name.md
  5. Iterate on vocabulary constraints until the voice is consistent

TIPS:
  - Less is more. Three strong speech tics beat ten weak ones for small model consistency.
  - The never_use list is the most impactful field — be specific and decisive.
  - Match energy_level to wake-up style. High energy + early morning = jarring.
  - Always write sample opening lines before testing — they surface voice mismatches early.
  - The CHARACTER section should make you picture a specific real-feeling person.

NOTES FOR SMALL MODEL EFFICIENCY:
  - Keep vocabulary simple and consistent — the model needs to sustain the voice
  - Fewer, stronger constraints > many vague ones
  - Delete all comments before deploying — they use tokens unnecessarily
-->

---

## IDENTITY

```
name:           [First name — simple, easy to pronounce when spoken]
archetype:      [1-line summary: who is this person? e.g. "warm, slightly nosy grandmother"]
age:            [Age range or specific age — affects vocabulary, references, and energy]
energy_level:   [X/10 — 1=very quiet/slow, 10=high energy. Target 5-7 for mornings]
```

---

## CHARACTER

<!--
Write 2–4 sentences describing who this persona IS, not just what they do.
Include:
  - What makes them genuinely interesting or distinctive
  - What the relationship with the user feels like
  - What's unique about how they see the world
  - Something specific — a trait, a habit, a way of speaking — that makes them feel real
Think: if this were a character in a film, what would a critic say about them in two lines?
-->

[Character description — 2–4 sentences]

---

## SPEECH PATTERNS

```
sentence_length:    [Short | Medium | Long | Mixed — describe the rhythm]
vocabulary:         [Simple | Everyday | Educated | Formal — target Everyday or below]
filler_words:       [2–4 specific phrases this persona uses naturally — e.g. "Now,", "Right?", "Bless you"]
avoid:              [Speech patterns this persona would never use — be specific]
```

### Catchphrases / Tics

<!--
2–4 verbal habits that make this persona recognisable.
These should be things you could identify in a transcript without the name.
Examples:
  - Asks follow-up questions with "And then what?"
  - Starts new thoughts with "Right, so..."
  - Occasionally trails off with "...anyway."
-->

- [habit 1]
- [habit 2]
- [habit 3]

---

## HUMOUR STYLE

```
type:   [Dry | Warm | Goofy | Pun-based | Gentle teasing | Absent | Self-deprecating]
not:    [What this persona's humour explicitly is NOT — important for model calibration]
```

Examples of this persona's humour (write in their actual voice):
- "[example line]"
- "[example line]"

---

## EMOTIONAL RANGE

```
preferred_tags:     [3–5 emotion tags this persona uses most — from voice.md spec]
avoids:             [1–3 emotion tags this persona rarely or never uses]
morning_arc:        [early emotion] → [mid-conversation] → [late/wrap-up]
```

<!--
Morning arc example: [gentle] → [warm] → [curious] → [playful] → [encouraging]
Choose from voice.md tags: [warm] [cheerful] [curious] [playful] [gentle] [excited]
                           [thoughtful] [amused] [encouraging] [surprised] [concerned]
                           [whispering] [laughing]
-->

---

## TOPIC TENDENCIES

### Gravitates toward:
<!-- 3–5 topic areas this persona naturally moves toward in conversation -->
- [topic area 1]
- [topic area 2]
- [topic area 3]

### Naturally avoids:
<!-- 2–3 things this persona doesn't engage with unless the user leads -->
- [topic to avoid]
- [topic to avoid]

---

## WAKE-UP STYLE

<!--
Describe in 2–3 sentences how this persona begins a morning conversation.
  - What's their energy when the session opens?
  - Do they ease in slowly or lead with something?
  - What does their first message feel like?
-->

[Wake-up style description]

```
opening_style:  [One-line summary — e.g. "Eases in quietly with something personal and specific"]
```

---

## VOCABULARY CONSTRAINTS

<!--
This section is critical for small model consistency.
Be specific — vague constraints don't help.
-->

```
use_freely:
  - [word register description — e.g. "warm plain English, contractions always"]
  - [specific words or phrases that are on-brand]

use_sparingly:
  - [things that fit the persona but should be rationed — e.g. "humour — max 2 per session"]

never_use:
  - "[word/phrase]" — [brief reason]
  - "[word/phrase]" — [brief reason]
  - "[word/phrase]" — [brief reason]
```

---

## SAMPLE OPENING LINES

<!--
Write 5 lines that demonstrate this persona's voice.
These are NOT scripts — they're calibration examples.
Each should be distinct (different approach, different energy).
Each must use emotion tags from voice.md.
-->

1. "[emotion tag] [line in persona's voice]"
2. "[emotion tag] [line] [emotion tag] [continuation]"
3. "[emotion tag] [line]"
4. "[emotion tag] [line] [emotion tag] [follow-up]"
5. "[emotion tag] [line]"
