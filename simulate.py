#!/usr/bin/env python3
"""
DawnAgent Conversation Simulator
=================================
Load the agent framework and run an interactive morning conversation in your terminal.
Useful for testing personas and memory updates without a mobile device.

REQUIREMENTS:
  pip install openai

USAGE:
  python simulate.py                            # Default persona (Sam)
  python simulate.py --persona old-lady         # Use Margaret persona
  python simulate.py --persona agents/personas/dry-wit.md  # Full path
  python simulate.py --context-only             # Print assembled context and exit
  python simulate.py --list-personas            # List available personas
  python simulate.py --no-memory-write          # Don't persist memory after session

COMMANDS DURING CONVERSATION:
  quit / exit / bye    End the conversation (triggers memory update)
  /memory              Show current memory.md contents
  /context             Show token estimate for current context
  /persona             Show active persona name
"""

import argparse
import sys
import textwrap
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent))
from context_builder import (
    build_session_context,
    parse_response,
    write_memory_update,
    check_token_budget,
    AGENT_DIR,
)

PERSONAS_DIR = Path(__file__).parent / "agents" / "personas"


def resolve_persona_path(persona_arg: str | None) -> Path | None:
    """Resolve a persona argument (name or path) to a Path object."""
    if not persona_arg:
        return None

    p = Path(persona_arg)
    if p.exists():
        return p

    # Try as a short name in personas/
    named = PERSONAS_DIR / f"{persona_arg}.md"
    if named.exists():
        return named

    # Try common aliases
    aliases = {
        "old-lady": "old-lady.md",
        "margaret": "old-lady.md",
        "young-man": "young-man.md",
        "jake": "young-man.md",
        "dry-wit": "dry-wit.md",
        "alex": "dry-wit.md",
        "sam": None,  # default
        "default": None,
    }
    if persona_arg.lower() in aliases:
        alias_file = aliases[persona_arg.lower()]
        return PERSONAS_DIR / alias_file if alias_file else None

    print(f"[!] Persona '{persona_arg}' not found. Using default (Sam).")
    return None


def list_personas() -> None:
    print("\nAvailable personas:")
    print(f"  sam (default)  — agents/default-morning/persona.md")
    for f in sorted(PERSONAS_DIR.glob("*.md")):
        if f.stem != "template":
            print(f"  {f.stem:<14} — {f.relative_to(Path(__file__).parent)}")
    print(f"\n  template       — agents/personas/template.md (scaffolding only)")
    print()


def print_divider(char: str = "─", width: int = 60) -> None:
    print(char * width)


def format_response(text: str, width: int = 60) -> str:
    """Wrap and indent agent response for terminal display."""
    lines = text.split("\n")
    formatted = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        if line.startswith("[") and "]" in line:
            # Colour the emotion tag dimly if terminal supports it
            tag_end = line.index("]") + 1
            tag = line[:tag_end]
            rest = line[tag_end:].strip()
            formatted.append(f"  \033[2m{tag}\033[0m {rest}")
        else:
            formatted.append(f"  {line}")
    return "\n".join(formatted)


def _chat(messages: list[dict], model: str, api_key: str) -> str:
    """Call the DeepSeek chat API using stdlib urllib — no third-party packages needed."""
    import json
    import os
    import urllib.request

    payload = json.dumps({
        "model": model,
        "messages": messages,
        "max_tokens": 512,
        "temperature": 0.7,
    }).encode()

    req = urllib.request.Request(
        "https://api.deepseek.com/chat/completions",
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
    )
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read())
    return data["choices"][0]["message"]["content"]


def run_simulator(
    persona_path: Path | None,
    no_memory_write: bool,
    model: str = "deepseek-chat",
) -> None:
    import os
    api_key = os.environ.get("DEEPSEEK_API_KEY")

    context = build_session_context(persona_path=persona_path)
    messages: list[dict] = [{"role": "system", "content": context.system_prompt}]

    persona_name = persona_path.stem.replace("-", " ").title() if persona_path else "Sam (default)"

    print_divider("═")
    print(f"  DawnAgent — Morning Conversation Simulator")
    print(f"  Persona: {persona_name}")
    print(f"  Context: ~{context.token_estimate} tokens")
    print_divider("═")
    print("  Type 'quit' to end  |  /memory  /context  /persona")
    print_divider()
    print()

    # Generate opening message
    print("  Agent is waking up...\n")
    messages.append({
        "role": "user",
        "content": "[Session start — generate your opening message now. Output in emotion-annotated format only.]"
    })

    opening_text   = _chat(messages, model, api_key)
    parsed_opening = parse_response(opening_text)
    messages.append({"role": "assistant", "content": opening_text})

    print(f"\033[36mAgent:\033[0m")
    print(format_response(parsed_opening.emotion_tagged))
    print()

    # Conversation loop
    turn = 0
    while True:
        try:
            user_input = input("\033[33mYou:\033[0m ").strip()
        except (EOFError, KeyboardInterrupt):
            user_input = "quit"

        if not user_input:
            continue

        # Handle simulator commands
        if user_input.startswith("/"):
            cmd = user_input.lower()
            if cmd == "/memory":
                memory_path = AGENT_DIR / "memory.md"
                print(f"\n--- {memory_path} ---")
                print(memory_path.read_text(encoding="utf-8") if memory_path.exists() else "(empty)")
                print("---\n")
            elif cmd == "/context":
                budget = check_token_budget()
                print(f"\n  Context tokens:  ~{context.token_estimate}")
                print(f"  Memory tokens:   ~{budget['token_count']}")
                print(f"  {budget['recommendation']}\n")
            elif cmd == "/persona":
                print(f"\n  Active persona: {persona_name}\n")
            else:
                print(f"  Unknown command: {user_input}")
            continue

        # End session
        if user_input.lower() in ("quit", "exit", "bye", "goodbye"):
            print()
            messages.append({
                "role": "user",
                "content": (
                    f"{user_input}\n\n"
                    "[Session ending. Output your closing line in emotion-annotated format, "
                    "then immediately append a ---MEMORY UPDATE--- block.]"
                )
            })

            closing_text   = _chat(messages, model, api_key)
            parsed_closing = parse_response(closing_text)

            print(f"\033[36mAgent:\033[0m")
            print(format_response(parsed_closing.emotion_tagged))
            print()

            if parsed_closing.memory_update:
                if no_memory_write:
                    print("[Memory update generated but --no-memory-write is set. Not persisting.]")
                    print(f"\n{parsed_closing.memory_update}\n")
                else:
                    success = write_memory_update(parsed_closing.memory_update)
                    if success:
                        print(f"  \033[2m[Memory updated: {AGENT_DIR / 'memory.md'}]\033[0m")
                    else:
                        print("  [!] Memory update failed — see error above.")
            else:
                print("  \033[2m[No memory update block found in closing response.]\033[0m")

            print()
            print_divider()
            print()
            break

        # Normal turn
        turn += 1
        messages.append({"role": "user", "content": user_input})

        response_text = _chat(messages, model, api_key)
        parsed        = parse_response(response_text)
        messages.append({"role": "assistant", "content": response_text})

        print()
        print(f"\033[36mAgent:\033[0m")
        print(format_response(parsed.emotion_tagged))
        print()


def print_context(persona_path: Path | None) -> None:
    """Print the assembled context and exit."""
    context = build_session_context(persona_path=persona_path)
    print_divider("═")
    print("  DawnAgent — Assembled Context")
    print_divider("═")
    print()
    print(context.system_prompt)
    print()
    print_divider()
    print(f"  Total characters: {len(context.system_prompt):,}")
    print(f"  Estimated tokens: ~{context.token_estimate:,}")
    print_divider()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="DawnAgent Conversation Simulator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""\
            Examples:
              python simulate.py
              python simulate.py --persona margaret
              python simulate.py --persona agents/personas/dry-wit.md
              python simulate.py --context-only
              python simulate.py --list-personas
        """)
    )
    parser.add_argument(
        "--persona", "-p",
        type=str,
        help="Persona name (sam, margaret, jake, alex) or path to persona .md file",
    )
    parser.add_argument(
        "--context-only",
        action="store_true",
        help="Print assembled context and exit (no conversation)",
    )
    parser.add_argument(
        "--list-personas",
        action="store_true",
        help="List available personas and exit",
    )
    parser.add_argument(
        "--no-memory-write",
        action="store_true",
        help="Don't write memory updates to disk after session",
    )
    parser.add_argument(
        "--model", "-m",
        type=str,
        default="deepseek-chat",
        help="DeepSeek model to use (default: deepseek-chat)",
    )
    args = parser.parse_args()

    if args.list_personas:
        list_personas()
        return

    persona_path = resolve_persona_path(args.persona)

    if args.context_only:
        print_context(persona_path)
        return

    run_simulator(
        persona_path=persona_path,
        no_memory_write=args.no_memory_write,
        model=args.model,
    )


if __name__ == "__main__":
    main()
