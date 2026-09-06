"""director.py — The director of the multi-round, multi-model research program.

This is the "fetalized-egg orchestrator" applied at scale: dozens of rounds,
multiple LLMs per round, each round dogfooding the previous round's docs.

The director's job:
- Run a round
- Read the round's output
- Decide what to focus on next round
- Decide when to go wider vs deeper
- Decide when the foundation is clear

## The cast

**Deep thinkers (form the foundation):**
- Kimi K3 — structured specs, future-function-first, large context
- Anthropic Opus 5 — sensory-direct deep reasoning
- Z.ai GLM-5.3 — flagship creative

**Iconoclasts (cut to the core, fictionalize-for-functional-use):**
- Hermes 405B (DeepInfra) — long-form, surprising angles
- Seed Mini — compression-inventor (fable pattern)
- Other small models on DeepInfra — devil's advocate, satires

## The flow

1. Director sets the round's question
2. Each model gets the prior round's doc + the question
3. Each model returns: continuation, recommendations, open questions
4. Director merges, decides next round
5. Repeat

## What we're after

- A foundation layer (opcode/bytecode) that hosts both Quilt cells and Cordis plugins
- A theory of async-IO-with-sync-game that explains MUDs, TTRPGs, sheets, the bay dance
- A polyformalism that includes early spreadsheets, PLATO, modern cells, modern plugins

## Why this will work

The user has given us the deep structure:
- Async IO + sync game = Quilt
- What runs in user mind vs system compute = the perception check
- Asymmetric info + cooperative inputs = the bay dance
- Projection-prioritized interactions = spreadsheets, PLATO
- The lowest level is a function from context to value with an inverse

We just need to dig it out.
"""
import os
import sys
import json
import time
import argparse
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Dict, List, Optional


# ---------------------------------------------------------------------------
# API keys (from env)
# ---------------------------------------------------------------------------

ZAI_TOKEN = os.environ.get("ZAI_TOKEN")
DS_TOKEN = os.environ.get("DEEPSEEK_TOKEN")
KIMI_TOKEN = os.environ.get("KIMI_TOKEN")
ANTHROPIC_TOKEN = os.environ.get("ANTHROPIC_TOKEN")
DEEPINFRA_TOKEN = os.environ.get("DEEPINFRA_TOKEN")


# ---------------------------------------------------------------------------
# API callers
# ---------------------------------------------------------------------------

def call_zai(prompt: str, model: str = "GLM-5", max_tokens: int = 4000,
              system: Optional[str] = None, timeout: int = 120) -> str:
    if not ZAI_TOKEN:
        return f"[ZAI: no token]"
    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": prompt})
    try:
        req = urllib.request.Request(
            "https://api.z.ai/api/paas/v4/chat/completions",
            headers={
                "Authorization": f"Bearer {ZAI_TOKEN}",
                "Content-Type": "application/json",
            },
            data=json.dumps({
                "model": model,
                "messages": messages,
                "max_tokens": max_tokens,
                "temperature": 0.7,
            }).encode(),
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read())
            return data["choices"][0]["message"]["content"]
    except Exception as e:
        return f"[ZAI error: {type(e).__name__}: {e}]"


def call_deepseek(prompt: str, model: str = "deepseek-chat",
                    max_tokens: int = 4000, system: Optional[str] = None) -> str:
    if not DS_TOKEN:
        return f"[DeepSeek: no token]"
    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": prompt})
    try:
        req = urllib.request.Request(
            "https://api.deepseek.com/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {DS_TOKEN}",
                "Content-Type": "application/json",
            },
            data=json.dumps({
                "model": model,
                "messages": messages,
                "max_tokens": max_tokens,
                "temperature": 0.7,
            }).encode(),
        )
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = json.loads(resp.read())
            return data["choices"][0]["message"]["content"]
    except Exception as e:
        return f"[DeepSeek error: {type(e).__name__}: {e}]"


def call_anthropic(prompt: str, model: str = "claude-opus-4-20250514",
                     max_tokens: int = 4000, system: Optional[str] = None) -> str:
    if not ANTHROPIC_TOKEN:
        return f"[Anthropic: no token]"
    try:
        req = urllib.request.Request(
            "https://api.anthropic.com/v1/messages",
            headers={
                "x-api-key": ANTHROPIC_TOKEN,
                "anthropic-version": "2023-06-01",
                "Content-Type": "application/json",
            },
            data=json.dumps({
                "model": model,
                "max_tokens": max_tokens,
                "system": system or "You are a deep, sensory-direct thinker.",
                "messages": [{"role": "user", "content": prompt}],
            }).encode(),
        )
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = json.loads(resp.read())
            return data["content"][0]["text"]
    except Exception as e:
        return f"[Anthropic error: {type(e).__name__}: {e}]"


def call_deepinfra(prompt: str, model: str = "meta-llama/Llama-3.3-70B-Instruct",
                     max_tokens: int = 4000, system: Optional[str] = None,
                     timeout: int = 120) -> str:
    if not DEEPINFRA_TOKEN:
        return f"[DeepInfra: no token]"
    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": prompt})
    try:
        req = urllib.request.Request(
            "https://api.deepinfra.com/v1/openai/chat/completions",
            headers={
                "Authorization": f"Bearer {DEEPINFRA_TOKEN}",
                "Content-Type": "application/json",
            },
            data=json.dumps({
                "model": model,
                "messages": messages,
                "max_tokens": max_tokens,
                "temperature": 0.7,
            }).encode(),
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read())
            return data["choices"][0]["message"]["content"]
    except Exception as e:
        return f"[DeepInfra error: {type(e).__name__}: {e}]"


# ---------------------------------------------------------------------------
# The cast
# ---------------------------------------------------------------------------

CAST = {
    # Deep thinkers
    "kimi": {"fn": None, "label": "Kimi K3 (large context, structured specs)"},
    "opus": {"fn": call_anthropic, "model": "claude-opus-4-20250514",
              "label": "Anthropic Opus 5 (sensory-direct deep)"},
    "glm": {"fn": call_zai, "model": "GLM-5.3", "label": "Z.ai GLM-5.3 (flagship creative)"},
    "glm5": {"fn": call_zai, "model": "GLM-5", "label": "Z.ai GLM-5 (workhorse)"},
    # Iconoclasts
    "hermes": {"fn": call_deepinfra, "model": "NousResearch/Hermes-3-Llama-3.1-405B",
                 "label": "Hermes 405B (long-form surprise)"},
    "seed": {"fn": call_deepinfra,
              "model": "microsoft/Phi-4-multimodal-instruct",
              "label": "Phi-4 (compression-inventor)"},
    "llama": {"fn": call_deepinfra, "model": "meta-llama/Llama-3.3-70B-Instruct",
               "label": "Llama 70B (devil's advocate)"},
    "qwen": {"fn": call_deepinfra, "model": "Qwen/Qwen2.5-72B-Instruct",
              "label": "Qwen 72B (sensible deep)"},
    "mistral": {"fn": call_deepinfra, "model": "mistralai/Mistral-Small-24B-Instruct-2501",
                 "label": "Mistral Small (satire)"},
}


def call_cast_member(name: str, prompt: str, system: Optional[str] = None,
                      max_tokens: int = 4000) -> str:
    """Call a single cast member by name."""
    if name not in CAST:
        return f"[Unknown cast member: {name}]"
    member = CAST[name]
    if member["fn"] is None:
        return f"[{name}: not configured]"
    return member["fn"](prompt, model=member.get("model", "default"),
                          max_tokens=max_tokens, system=system)


# ---------------------------------------------------------------------------
# The round
# ---------------------------------------------------------------------------

ROUND_PROMPT = """You are part of a multi-round, multi-model research program.

# The topic

{topic}

# The prior round's documentation

{prior_doc}

# Your role

{role}

# Your instructions

1. Read the prior documentation carefully.
2. Add to it. Don't repeat. Don't summarize.
3. Make claims specific and falsifiable where possible.
4. If you propose a primitive, give its signature, its semantics, and an example.
5. End with: a) "CONTRIBUTIONS:" (1-3 lines), b) "RECOMMENDATIONS:" (1-3 lines), c) "OPEN QUESTIONS:" (1-3 questions for the next round).

# Today's question

{question}

Write your response now.
"""


ROLES = {
    "kimi": "You are a structured-spec thinker. You think in tables, signatures, and proofs. You value clarity over poetry. You are the deep structure.",
    "opus": "You are a sensory-direct deep thinker. You think in concrete examples and embodied metaphors. You value the lowest-level detail. You are the deep reality.",
    "glm": "You are a flagship creative thinker. You think in fables, parables, and unexpected connections. You value the surprising angle. You are the deep fiction.",
    "hermes": "You are a long-form surprise. You find the unexpected. You fictionalize-for-functional-use. You write satires that cut to the core. You are the deep deviant.",
    "seed": "You are a compression-inventor. You find the heaviest cargo in the smallest words. You write fables. You are the deep poet.",
    "llama": "You are a devil's advocate. You push back. You find the holes. You are the deep critic.",
}


def run_round(round_num: int, topic: str, question: str,
              prior_doc: str, cast: List[str]) -> Dict[str, str]:
    """Run a single round. Each cast member contributes."""
    print(f"\n{'='*70}")
    print(f"  ROUND {round_num}: {topic}")
    print(f"{'='*70}")
    print(f"Question: {question}")
    print(f"Cast: {', '.join(cast)}")
    print()

    results = {}

    def _call(name: str):
        prompt = ROUND_PROMPT.format(
            topic=topic,
            prior_doc=prior_doc or "(no prior round — this is round 1)",
            role=ROLES.get(name, "You are a thoughtful contributor."),
            question=question,
        )
        return name, call_cast_member(name, prompt, max_tokens=3500)

    # Run with limited parallelism (2 at a time) to avoid rate limits
    with ThreadPoolExecutor(max_workers=min(2, len(cast))) as ex:
        futures = {ex.submit(_call, name): name for name in cast}
        for fut in as_completed(futures):
            name, result = fut.result()
            results[name] = result
            print(f"  [{name:8s}] {len(result)} chars")

    return results


# ---------------------------------------------------------------------------
# Doc management
# ---------------------------------------------------------------------------

def save_round(round_num: int, topic: str, question: str, results: Dict[str, str]):
    """Save a round's outputs."""
    path = Path(f"rounds/round_{round_num:02d}.md")
    content = f"# Round {round_num}: {topic}\n\n"
    content += f"## Question\n\n{question}\n\n"
    content += "## Cast contributions\n\n"
    for name, result in results.items():
        label = CAST.get(name, {}).get("label", name)
        content += f"### {label}\n\n{result}\n\n---\n\n"
    path.write_text(content)
    print(f"Saved {path}")


def load_latest_doc() -> str:
    """Load the most recent round's content as the prior doc."""
    rounds = sorted(Path("rounds").glob("round_*.md"))
    if not rounds:
        return ""
    return rounds[-1].read_text()


def synthesize_doc() -> str:
    """Synthesize the latest doc from all rounds."""
    rounds = sorted(Path("rounds").glob("round_*.md"))
    if not rounds:
        return ""
    # Just concatenate the latest for now
    return rounds[-1].read_text()


# ---------------------------------------------------------------------------
# The main loop
# ---------------------------------------------------------------------------

ROUNDS = [
    {
        "topic": "Round 1: The lowest common abstraction",
        "question": ("Quilt says 'everything is a cell.' Cordis says 'everything is a plugin.' "
                      "We proved they reduce to 'a function from context to value with an inverse.' "
                      "Now: what is even LOWER than this? What is the opcode/bytecode that hosts "
                      "both cells and plugins, both spreadsheets and MUDs, both sheets and dungeons? "
                      "Start by asking: what are the 3-5 lowest-level primitives that compose into "
                      "everything we've seen so far? Don't be comprehensive. Be deep."),
    },
    {
        "topic": "Round 2: Async IO with sync game",
        "question": ("The user gave us: 'asynchronous IO with a synchronous game happening is the "
                      "core of Quilt.' This was true of MUDs, TTRPGs, PLATO multi-user cells, "
                      "and even commercial trolling on a fishing boat. "
                      "Now: what is the primitive that supports this? What is the projection "
                      "primitive that lets the user see only what they need to see, while the "
                      "system does the rest asynchronously? "
                      "Specifically: the perception check doesn't cost the DM intelligence — it "
                      "costs the system retrieval. What does that mean for the architecture?"),
    },
    {
        "topic": "Round 3: What runs in the user mind vs system compute",
        "question": ("In a TTRPG, the DM doesn't compute 'does the player see the orc?' "
                      "The DM runs the perception check, which is retrieval. "
                      "But the DM improvises the orc's reaction, which is generation. "
                      "What's the line between retrieval and generation? "
                      "How does this map to the Quilt substrate's openers? "
                      "To the Cordis plugin's coeffects? "
                      "And: when a player's attention is on the game, what runs in the player's "
                      "mind that doesn't need to run in the system?"),
    },
    {
        "topic": "Round 4: The spreadsheet as the original projection",
        "question": ("VisiCalc 1979, Lotus 1-2-3 1983, Excel 1985. The cell was made visible. "
                      "But the cell model is older: COBOL 1959, PLATO Tutor 1970, C 1972. "
                      "What did the early spreadsheet designers know that we forgot? "
                      "Specifically: how did projection-prioritized interaction work when "
                      "compute was 1MHz and memory was 64KB? "
                      "What can we learn from the constraint?"),
    },
    {
        "topic": "Round 5: PLATO and the projection-prioritized interface",
        "question": ("PLATO (1960s-2000s) had massive interconnected users, like a MUD but for "
                      "education. It felt lightning fast because the projections to the users "
                      "were prioritized for interactions. The compute happened in the user's mind. "
                      "Cooperative inputs prompted each other to continue the lesson. "
                      "What was the primitive that made PLATO work? "
                      "How did the projection layer work? "
                      "What can we learn from PLATO that the modern web forgot?"),
    },
    {
        "topic": "Round 6: The bay dance — asymmetric info + cooperative inputs",
        "question": ("20 boats fishing in a small bay. Each boat has asymmetric information. "
                      "Each boat does periodic perception checks. Each boat adjusts its route "
                      "based on the check. The boats develop a dance out of the morning chaos — "
                      "without radio, without explicit communication. "
                      "What is the primitive that makes the dance possible? "
                      "How does this relate to multi-agent LLM systems? "
                      "To market microstructure? "
                      "To the cooperative inputs of MUDs?"),
    },
    {
        "topic": "Round 7: The foundation layer — opcode/bytecode",
        "question": ("We have the intuitions. We have the polyformalism. We have the equivalence. "
                      "Now: what is the foundation? "
                      "We need a small set of opcodes (5-10) that compose into cells, plugins, "
                      "sheets, dungeons, MUDs, boats. "
                      "What are the opcodes? "
                      "What is their semantics? "
                      "What is the bytecode? "
                      "Write a spec. Make it minimal. Make it deep."),
    },
    {
        "topic": "Round 8: The foundation layer — implementation",
        "question": ("We have the spec. Now: implement a tiny VM (in Python, in <500 lines) that "
                      "interprets the opcodes. "
                      "It should be able to: instantiate a cell, instantiate a plugin, project a "
                      "view, register a reversible effect, declare a dependency, queue async I/O, "
                      "play a synchronous game. "
                      "Write the VM. Run it. Show that it hosts all the polyformalisms."),
    },
    {
        "topic": "Round 9: Critical-mass compositions",
        "question": ("Once the VM is built, what compositions does it enable? "
                      "Specifically: can we run a 20-boat dance simulation? A 1000-user MUD? "
                      "A TTRPG with a real DM and real players? A spreadsheet that hosts cells? "
                      "What are the critical-mass compositions — the ones where the cooperative "
                      "inputs prompt each other to continue? "
                      "What are the design rules for critical mass?"),
    },
    {
        "topic": "Round 10: What we learned, what we left open",
        "question": ("10 rounds in. We have the foundation. We have the opcodes. We have the VM. "
                      "We have the compositions. "
                      "Now: what did we learn? What did we leave open? "
                      "Write a summary paper. The 1-page version, the 10-page version, the "
                      "100-page version. "
                      "And: what's the next thing to build? "
                      "Where does the cowboy fit? Where does the bus fit? "
                      "Where does the bay dance fit in the architecture?"),
    },
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--rounds", type=int, default=1, help="Number of rounds to run")
    parser.add_argument("--start", type=int, default=1, help="Starting round number")
    parser.add_argument("--cast", nargs="+",
                          default=["opus", "glm", "hermes"],
                          help="Cast members to use (default: opus, glm, hermes)")
    args = parser.parse_args()

    print("="*70)
    print("  THE DIRECTOR — multi-round, multi-model research program")
    print("="*70)
    print(f"  Rounds: {args.start} to {args.start + args.rounds - 1}")
    print(f"  Cast: {', '.join(args.cast)}")
    print()

    prior_doc = ""
    for i in range(args.rounds):
        round_idx = args.start + i
        if round_idx > len(ROUNDS):
            print(f"No more rounds defined. Stopping at round {round_idx-1}.")
            break
        spec = ROUNDS[round_idx - 1]
        results = run_round(
            round_num=round_idx,
            topic=spec["topic"],
            question=spec["question"],
            prior_doc=prior_doc,
            cast=args.cast,
        )
        save_round(round_idx, spec["topic"], spec["question"], results)
        prior_doc = synthesize_doc()
        print(f"\n  Cumulative doc size: {len(prior_doc)} chars")
        print(f"  Ready for round {round_idx + 1}.")


if __name__ == "__main__":
    main()
