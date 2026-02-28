# DawnAgent — Morning Conversation Agent Framework

A modular, local-first conversational agent framework that wakes users up through conversation — not alarms. Swap one file to get a warm grandmother, a dry-witted librarian, or an enthusiastic 25-year-old. The framework handles the rest.

---

## What It Is

DawnAgent is a prompt-engineering framework — a set of structured `.md` files that, when loaded into a small on-device language model, produce a natural morning conversation experience.

**Target runtime:** Apple on-device foundation model
**Designed for:** Offline, privacy-first, low-latency morning interaction
**Core principle:** The same framework produces wildly different experiences by swapping one file.

---

## Architecture

```
dawnagent/
├── README.md                    — This file
├── context_builder.py           — Runtime interface (Python reference impl)
├── simulate.py                  — Interactive conversation tester
│
└── agents/
    ├── default-morning/         — Active agent instance
    │   ├── agent.md             — Core conversation behaviour and logic
    │   ├── memory.md            — Persistent user context (updated each session)
    │   ├── guardrails.md        — Safety rules (highest priority — overrides everything)
    │   ├── conversation.md      — Session state (reset each session)
    │   ├── voice.md             — Emotion tag spec + TTS output formatting
    │   ├── persona.md           — Active persona (swap this file to change character)
    │   └── topics.md            — Curated conversation starter bank
    │
    └── personas/                — Swappable persona library
        ├── template.md          — Blank scaffolding for creating new personas
        ├── old-lady.md          — Margaret: warm, caring grandmother (70s)
        ├── young-man.md         — Jake: enthusiastic, curious 25-year-old
        └── dry-wit.md           — Alex: dry, precise, quietly warm (late 30s)
```

---

## How Files Are Assembled

At session start, `context_builder.py` loads and assembles the `.md` files into a single system prompt. **Priority order (highest first):**

1. `guardrails.md` — safety rules that override everything, always
2. `agent.md` — core conversation behaviour
3. `persona.md` — surface personality (swappable)
4. `voice.md` — output format specification
5. Session context — date, time, day of week, weather
6. `memory.md` — user context from previous sessions
7. `topics.md` — conversation starters (optional reference)

The model receives this as a system prompt plus the rolling conversation history.

---

## The Runtime Interface

**Input:**
- Assembled system prompt (from `build_session_context()`)
- Conversation history (managed by the app layer)
- User's latest message

**Output:**
- Emotion-tagged response (for TTS rendering)
- Clean transcript (for display)
- Memory update block (written back to `memory.md` at session end)

```python
from context_builder import build_session_context, parse_response, write_memory_update

# At session start
context = build_session_context(weather="cloudy, 12°C")
# context.system_prompt → pass to model as system parameter
# context.token_estimate → check against budget

# After each model response
response = parse_response(raw_model_output)
# response.emotion_tagged → feed to TTS renderer
# response.clean         → show in conversation transcript
# response.memory_update → write back if not None

# At session end, persist memory
if response.memory_update:
    write_memory_update(response.memory_update)
```

---

## Swapping Personas

To change who the user wakes up to, copy a persona file over the active one:

```bash
# Switch to Margaret (warm grandmother)
cp agents/personas/old-lady.md agents/default-morning/persona.md

# Switch to Jake (enthusiastic young guy)
cp agents/personas/young-man.md agents/default-morning/persona.md

# Switch to Alex (dry wit)
cp agents/personas/dry-wit.md agents/default-morning/persona.md

# Switch back to Sam (default)
cp agents/personas/sam-default.md agents/default-morning/persona.md
```

Or pass a path directly to the context builder:

```python
context = build_session_context(
    persona_path=Path("agents/personas/old-lady.md")
)
```

**The persona file is the only thing that changes.** Core behaviour, safety rules, memory, and voice formatting all remain identical.

---

## Creating New Personas

1. Copy `agents/personas/template.md` to `agents/personas/your-persona-name.md`
2. Fill in all fields — the template has comments explaining each
3. Write 5 sample opening lines in the persona's voice (the most important step)
4. Test: `python simulate.py --persona your-persona-name`
5. Iterate on vocabulary constraints until the voice is consistent

**Key tips:**
- The `never_use` vocabulary list is the most impactful field for small model consistency
- Match `energy_level` to wake-up style — high energy at 7am can feel jarring
- Three strong speech tics beat ten vague ones
- A persona should feel like a specific real person, not a type
- If you can't write 5 distinct opening lines in the persona's voice, the character isn't defined enough yet

---

## Memory Lifecycle

### How It Works

After each session, the agent outputs a `---MEMORY UPDATE---` block as part of its closing response. The app layer extracts this block and writes it back to `memory.md`. On the next session, the agent reads the updated file and uses it naturally in conversation.

### Memory Format

```
## USER PROFILE
  Known Interests    — topics confirmed across sessions
  Mood Patterns      — Monday morning groggy, weekend chatty, etc.
  Preferences        — likes/dislikes about morning conversation style

## OPEN THREADS
  Timestamped items to follow up on ("user mentioned job interview on Thursday")
  Deleted when resolved.

## AVOID LIST
  Topics or approaches that caused clear disengagement or discomfort.

## SESSION LOG
  Last 7 sessions in full, most recent at top.
  Older sessions get summarised when over limit.
```

### Retention Policy

The agent follows a simple retention policy defined in `memory.md`:

| Section | Policy |
|---------|---------|
| SESSION LOG | Keep last 7 full sessions. Summarise oldest 3 into one ARCHIVED entry when over limit. |
| USER PROFILE | Evergreen — update entries in place. No accumulation of duplicates. |
| OPEN THREADS | Delete when resolved. Keep list under 5–6 items. |
| AVOID LIST | Add slowly, only when clearly warranted. Review periodically — preferences change. |

**Token budget:** Keep `memory.md` under **600 tokens** for small model compatibility. Call `check_token_budget()` after each write to verify.

---

## Testing With the Simulator

```bash
# Basic conversation with default persona (Sam)
python simulate.py

# Use an alternate persona by name
python simulate.py --persona margaret
python simulate.py --persona jake
python simulate.py --persona alex

# Or by file path
python simulate.py --persona agents/personas/dry-wit.md

# Print the full assembled context and exit (useful for debugging)
python simulate.py --context-only

# List all available personas
python simulate.py --list-personas

# Run without writing memory back to disk
python simulate.py --no-memory-write
```

**Simulator commands during conversation:**

| Command | Action |
|---------|--------|
| `quit` / `exit` / `bye` | End session (triggers memory update) |
| `/memory` | Show current memory.md contents |
| `/context` | Show token estimates |
| `/persona` | Show active persona name |

**Requirements:**

```bash
pip install openai
export DEEPSEEK_API_KEY=your-key-here
```

Without an API key, use `--context-only` to inspect the assembled context and paste it into any model interface manually.

---

## Voice Output Format

Every agent response is emotion-annotated for TTS:

```
[whispering] Morning...
[gentle] How'd you sleep?
[curious] I was thinking about what you said — about wanting to try cooking more.
[playful] Have you actually looked at a recipe yet, or are we still in the "thinking about it" phase?
[amused] No judgement either way...
```

Supported emotion tags:
`[warm]` `[cheerful]` `[curious]` `[playful]` `[gentle]` `[excited]` `[thoughtful]` `[amused]` `[encouraging]` `[surprised]` `[concerned]` `[whispering]` `[laughing]`

The app layer strips tags for the clean transcript. TTS renderer uses tags to set voice affect.

---

## Swift Integration

See `context_builder.py` for full integration notes. Summary:

1. **Session start:** Call `build_session_context()` → pass `system_prompt` to on-device model
2. **Each turn:** Send `(system_prompt, history, user_message)` to model → call `parse_response()` on output
3. **TTS:** Feed `response.emotion_tagged` to your TTS renderer
4. **Display:** Show `response.clean` in transcript view
5. **Session end:** Write `response.memory_update` to storage if present

The framework is model-agnostic — any instruction-following model works. The `.md` files are the only runtime dependency.

---

## File Reference

| File | Purpose | Updated by |
|------|---------|-----------|
| `agent.md` | Core conversation logic | Developer (rarely) |
| `memory.md` | User context and history | App layer (each session) |
| `guardrails.md` | Safety rules | Developer (never at runtime) |
| `conversation.md` | Session state | App layer (each session, reset) |
| `voice.md` | Emotion tag spec | Developer (rarely) |
| `persona.md` | Active persona | Developer / user (on swap) |
| `topics.md` | Conversation starter bank | Developer (occasionally) |

---

## Design Principles

**Modular** — One file swap changes the entire personality. Nothing else touches.
**Local-first** — No external API calls at runtime. All state lives in `.md` files.
**Token-efficient** — Every file is written for a small context window. No redundancy.
**Safe by default** — Guardrails load first, override everything. Personas cannot patch them out.
**Offline-ready** — Memory, context, and state are all local files.
**Speakable** — All output is written for speech, not reading. Short sentences. Emotion-tagged.
