"""
DawnAgent Context Builder — Runtime Interface
=============================================

Single entry point between the agent framework (.md files) and the app layer.

INTERFACE:
  Input:  assembled_context (str), user_message (str)
  Output: AgentResponse(emotion_tagged, clean, memory_update)

USAGE:
  context = build_session_context()
  response = parse_response(raw_model_output)
  if response.memory_update:
      write_memory_update(response.memory_update)

SWIFT INTEGRATION: See notes at the bottom of this file.
"""

from __future__ import annotations
import re
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

AGENT_DIR = Path(__file__).parent / "agents" / "default-morning"


# ─── Data Classes ─────────────────────────────────────────────────────────────

@dataclass
class AgentResponse:
    """Structured output from a single conversation turn."""
    emotion_tagged: str       # Emotion-annotated dialogue for TTS rendering
    clean: str                # Plain text transcript (emotion tags stripped)
    memory_update: str | None # Structured update block to write back, or None


@dataclass
class SessionContext:
    """Assembled context ready to pass to the on-device model."""
    system_prompt: str        # Full assembled system prompt
    token_estimate: int       # Rough token count (~4 chars per token)


# ─── File Loading ──────────────────────────────────────────────────────────────

def _load(path: Path) -> str:
    """Load a .md file. Returns a placeholder comment if file is missing."""
    try:
        return path.read_text(encoding="utf-8").strip()
    except FileNotFoundError:
        return f"<!-- {path.name} not found — skipping -->"


def _time_bracket(hour: int) -> str:
    if hour < 7:
        return "early-morning"
    elif hour < 10:
        return "morning"
    return "late-morning"


# ─── Context Assembly ─────────────────────────────────────────────────────────

def build_session_context(
    persona_path: Path | None = None,
    weather: str | None = None,
    memory_override: str | None = None,
) -> SessionContext:
    """
    Assemble the full agent system prompt from .md files.
    Call once at session start.

    Args:
        persona_path:     Path to an alternate persona file (default: persona.md)
        weather:          Optional weather string, e.g. "partly cloudy, 14°C"
        memory_override:  Override memory.md content (for Swift-managed storage)

    Returns:
        SessionContext with assembled system_prompt and token_estimate
    """
    now = datetime.now()

    # Load files — order matches priority (guardrails first, always)
    guardrails   = _load(AGENT_DIR / "guardrails.md")
    agent        = _load(AGENT_DIR / "agent.md")
    persona      = _load(persona_path or AGENT_DIR / "persona.md")
    voice        = _load(AGENT_DIR / "voice.md")
    memory       = memory_override or _load(AGENT_DIR / "memory.md")
    topics       = _load(AGENT_DIR / "topics.md")

    session_block = (
        "# Session Context\n"
        f"date:         {now.strftime('%Y-%m-%d')}\n"
        f"day_of_week:  {now.strftime('%A')}\n"
        f"time:         {now.strftime('%H:%M')}\n"
        f"time_bracket: {_time_bracket(now.hour)}\n"
        f"weather:      {weather or 'unavailable'}"
    )

    sections = [
        guardrails,
        agent,
        persona,
        voice,
        session_block,
        f"# User Memory\n{memory}",
        f"# Topic Bank (optional reference)\n{topics}",
    ]

    system_prompt = "\n\n---\n\n".join(sections)
    token_estimate = len(system_prompt) // 4

    return SessionContext(system_prompt=system_prompt, token_estimate=token_estimate)


# ─── Response Parsing ─────────────────────────────────────────────────────────

_MEMORY_BLOCK_RE = re.compile(
    r'\n*---MEMORY UPDATE---.*?---END UPDATE---\n*',
    re.DOTALL
)
_EMOTION_TAG_RE = re.compile(r'\[[\w]+\]\s*')


def strip_emotion_tags(text: str) -> str:
    """Convert emotion-annotated text to plain transcript."""
    return _EMOTION_TAG_RE.sub('', text).strip()


def extract_memory_update(text: str) -> str | None:
    """Extract ---MEMORY UPDATE--- block from model output. Returns block or None."""
    match = re.search(r'---MEMORY UPDATE---.*?---END UPDATE---', text, re.DOTALL)
    return match.group(0).strip() if match else None


def parse_response(raw_model_output: str) -> AgentResponse:
    """
    Parse raw model output into a structured AgentResponse.
    Call on every model response before passing to the app layer.

    Args:
        raw_model_output: Full text output from the model

    Returns:
        AgentResponse with emotion_tagged, clean, and optional memory_update
    """
    memory_update  = extract_memory_update(raw_model_output)
    emotion_tagged = _MEMORY_BLOCK_RE.sub('', raw_model_output).strip()
    clean          = strip_emotion_tags(emotion_tagged)

    return AgentResponse(
        emotion_tagged=emotion_tagged,
        clean=clean,
        memory_update=memory_update,
    )


# ─── Memory Management ────────────────────────────────────────────────────────

def write_memory_update(
    update_block: str,
    memory_path: Path | None = None,
) -> bool:
    """
    Append a memory update block to memory.md.
    Returns True on success.

    In Swift integration: handle file I/O in Swift and call parse_response()
    to extract the update block — this function is for Python tooling only.
    """
    path = memory_path or AGENT_DIR / "memory.md"
    try:
        existing = path.read_text(encoding="utf-8")
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")

        marker = "## SESSION LOG"
        new_entry = f"{marker}\n\n### [{timestamp}]\n{update_block}\n"

        if marker in existing:
            updated = existing.replace(marker, new_entry, 1)
            # Remove the placeholder if it's still there
            updated = updated.replace("### [AWAITING FIRST SESSION]\n\n<!-- The first real session will replace this placeholder. -->", "")
        else:
            updated = existing.rstrip() + f"\n\n## SESSION LOG\n\n### [{timestamp}]\n{update_block}\n"

        path.write_text(updated.strip() + "\n", encoding="utf-8")
        return True

    except Exception as exc:
        print(f"[context_builder] Memory write failed: {exc}")
        return False


def check_token_budget(memory_path: Path | None = None, warn_threshold: int = 600) -> dict:
    """
    Check if memory.md is within token budget.
    Returns a dict with token_count, over_budget, and a recommendation.
    """
    path = memory_path or AGENT_DIR / "memory.md"
    content = _load(path)
    tokens = len(content) // 4

    return {
        "token_count": tokens,
        "over_budget": tokens > warn_threshold,
        "recommendation": (
            "Memory file is within budget."
            if tokens <= warn_threshold
            else f"Memory file is ~{tokens} tokens (budget: {warn_threshold}). "
                 "Summarise oldest 3 session log entries into one ARCHIVED entry."
        ),
    }


# ─── Swift Integration ────────────────────────────────────────────────────────
#
# A full Swift implementation of this module lives at:
#   swift/Sources/DawnAgentCore/
#
# Key files:
#   ContextLoader.swift    — mirrors build_session_context()
#   ResponseParser.swift   — mirrors parse_response() / strip_emotion_tags()
#   MemoryWriter.swift     — mirrors write_memory_update() / check_token_budget()
#   DawnAgentSession.swift — wraps Apple FoundationModels.LanguageModelSession
#
# CLI tester (requires Mac with Apple Intelligence, macOS 15.1+):
#   cd swift && swift run DawnAgentCLI
#   cd swift && swift run DawnAgentCLI --persona old-lady
#
# To import into an iOS/macOS app target, add the DawnAgentCore library as a
# local Swift Package dependency and call:
#   let session = DawnAgentSession(configuration: .init(agentDirectory: url))
#   try await session.start()
#   let response = try await session.send(userMessage)
#   // response.emotionTagged → TTS renderer
#   // response.clean         → transcript view
#
# This Python file remains the canonical reference for the context assembly
# logic and is used by simulate.py for local testing on non-Apple platforms.
#
# ─────────────────────────────────────────────────────────────────────────────
