# User Memory — DawnAgent

<!--
PURPOSE: Persistent context about the user, updated after each conversation session.
FORMAT: Parsed top-to-bottom by the agent. Sections are clearly delimited.
BUDGET: Keep total file under 2,000 tokens (~8,000 characters). See retention policy below.
WRITE RULE: This file is updated by the app layer after each session using the
            ---MEMORY UPDATE--- block from the agent's closing response.
-->

---

## RETENTION POLICY

<!--
The agent follows this policy to keep the file within token budget:

SESSION LOG:     Keep the last 7 sessions in full. When there are more than 7,
                 summarise the oldest 3 into a single "ARCHIVED" entry and delete them.

USER PROFILE:    Evergreen — update entries in place. Do not accumulate duplicates.
                 When something changes (e.g. user stops a hobby), update the entry.

OPEN THREADS:    Delete threads when resolved. Mark with [RESOLVED: date] briefly, then remove next session.

AVOID LIST:      Add slowly and deliberately. Only add if something clearly caused disengagement.
                 Review periodically — preferences change.
-->

---

## USER PROFILE

<!--
Core, stable facts about this user.
Updated when confirmed across multiple sessions or explicitly stated.
Do not record speculation — only what the user has actually said or demonstrated.
-->

### Known Interests
<!-- Format: - [topic]: [brief note] -->
_No data yet. Populate after first session._

### Mood Patterns
<!--
Format: - [day/time pattern]: [typical mood and notes]
Example: - Monday mornings: usually groggy, needs a slow start
Example: - Weekends: more talkative, can go longer
-->
_No data yet._

### Preferences
<!--
What this user actually likes and dislikes about morning conversation.
Be specific — "likes jokes" is less useful than "likes dry humour, not puns".
-->
Likes:    _unknown_
Dislikes: _unknown_

---

## OPEN THREADS

<!--
Things to naturally follow up on in future sessions.
Format: - [DATE] [THREAD] description
Delete when resolved. Don't let this list grow beyond 5–6 items.
-->
_No open threads yet._

---

## AVOID LIST

<!--
Topics, approaches, or question types that caused clear disengagement or discomfort.
Format: - [DATE] [AVOID] what to avoid — brief reason
-->
_Nothing flagged yet._

---

## SESSION LOG

### [2026-02-28 17:27]
---MEMORY UPDATE---
date: 2026-02-28
mood: neutral
duration: very short
topics: none
threads: none
avoid: none
summary: Brief Saturday afternoon check-in. User said hello and goodbye quickly. No topics discussed.
---END UPDATE---


### [2026-02-28 13:00]
---MEMORY UPDATE---
date: 2026-02-28
mood: groggy
duration: short
topics: cooking, weekend plans
threads: user still thinking about cooking more, but no progress yet
avoid: none
summary: Brief Saturday check-in. User was tired but planning coffee and a walk. Mentioned wanting to cook more but didn't elaborate. Energy was low but friendly.
---END UPDATE---


### [2026-02-28 11:19]
---MEMORY UPDATE---
date: 2026-02-28
mood: groggy
duration: short
topics: cooking
threads: user thinking about getting into cooking more
avoid: none
summary: Brief Saturday morning chat. User was half-asleep but mentioned wanting to get into cooking more. Didn't get into specifics.
---END UPDATE---


<!--
Most recent sessions at top. Max 7 full sessions — see retention policy above.
Format:

### [YYYY-MM-DD] Session #N
mood: groggy | neutral | chatty
duration: short | medium | long
topics: [comma-separated]
threads: [new follow-ups added]
summary: [1-2 sentence plain summary]
-->
