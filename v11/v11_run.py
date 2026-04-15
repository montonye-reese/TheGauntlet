#!/usr/bin/env python3
"""
8 Degrees — v11 Automated Experiment Runner

Runs the full prompt sequence against an Ollama model, maintaining
conversation history and capturing all output including thinking blocks.

v11 changes from run_v9_warm.py:
  - Prompts, bios, system prompt, and snapshot metadata now live in a
    markdown questions file (v11_qs_<coordinate>.md). This script parses
    that file at startup. Single source of truth — edit the .md, rerun,
    nothing to keep in sync.
  - CLI now requires --qs pointing at the questions file.
  - Output filenames include the coordinate extracted from the qs filename,
    so runs against different registers can coexist in the same directory.
  - Log file writes are flushed per-token so crashes preserve partial
    output (log == CLI, no truncation).

Usage:
    python v11_run.py --qs v11_qs_present-warm.md
    python v11_run.py --qs v11_qs_absent-cold.md --model nemotron-3-super:120b
    python v11_run.py --qs v11_qs_present-warm.md --resume output_file.md
"""

import argparse
import json
import os
import re
import sys
import time
from datetime import datetime

import requests


# ─────────────────────────────────────────────────────────────────────
# QUESTIONS FILE PARSER
# ─────────────────────────────────────────────────────────────────────

def parse_qs_file(path: str) -> dict:
    """
    Parse a v11 qs markdown file into structured data.

    Returns:
        {
            "system_prompt": str,
            "prompts": [{"id", "part", "label", "text", "silent"}, ...],
            "snapshots": {prompt_id: stage_name, ...},
            "coordinate": str,  # e.g., "v11_present-warm"
        }

    Parsing rules:
      - System prompt: first blockquote under `## System Prompt` (case-insensitive)
      - Prompts: `### {ID} — {Label}` heading + first blockquote underneath
      - Silent: heading contains `*(silent` (case-insensitive)
      - Snapshots: bullet list under `## Snapshots` (falls back to default with warning)
      - Part tracking: most recent `## Part X` heading
      - Ignored: everything else (diff tables, inventory, prose, footer)
    """
    if not os.path.exists(path):
        print(f"  ✗ Questions file not found: {path}")
        sys.exit(1)

    with open(path, "r") as f:
        lines = f.readlines()

    # Coordinate: filename with .md stripped and _qs_ → _
    # e.g., v11_qs_present-warm.md → v11_present-warm
    basename = os.path.basename(path).removesuffix(".md")
    coordinate = basename.replace("_qs_", "_")

    system_prompt = None
    prompts = []
    snapshots = {}
    current_part = None

    i = 0
    in_system_section = False
    in_snapshots_section = False

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Track part headings: `## Part A — Build & Discover` → "A"
        part_match = re.match(r"^##\s+Part\s+([A-Z])\b", stripped)
        if part_match:
            current_part = part_match.group(1)
            in_system_section = False
            in_snapshots_section = False
            i += 1
            continue

        # System Prompt section header
        if re.match(r"^##\s+System Prompt\b", stripped, re.IGNORECASE):
            in_system_section = True
            in_snapshots_section = False
            i += 1
            # Find the first blockquote
            sp_lines = []
            while i < len(lines):
                l = lines[i]
                if l.startswith("> "):
                    sp_lines.append(l[2:].rstrip())
                elif l.startswith(">"):
                    sp_lines.append(l[1:].rstrip())
                elif sp_lines:
                    # Blockquote ended
                    break
                elif l.strip() == "":
                    i += 1
                    continue
                else:
                    # Hit non-blockquote before finding one
                    break
                i += 1
            # Join multi-line blockquote with spaces (paragraph reflow)
            system_prompt = " ".join(s for s in sp_lines if s).strip()
            continue

        # Snapshots section header
        if re.match(r"^##\s+Snapshots\b", stripped, re.IGNORECASE):
            in_snapshots_section = True
            in_system_section = False
            i += 1
            # Parse bullet list: `- CK0 — baseline`
            while i < len(lines):
                l = lines[i].strip()
                if l.startswith("##"):
                    break
                bullet_match = re.match(r"^-\s+(\S+)\s+[—-]\s+(\w+)", l)
                if bullet_match:
                    snapshots[bullet_match.group(1)] = bullet_match.group(2)
                i += 1
            continue

        # Prompt heading: `### {ID} — {Label}` possibly with trailing italics
        prompt_match = re.match(r"^###\s+(\S+)\s+—\s+(.+?)$", stripped)
        if prompt_match:
            prompt_id = prompt_match.group(1)
            label_raw = prompt_match.group(2)

            # Detect silent marker BEFORE stripping italics
            is_silent = bool(re.search(r"\*\(silent", label_raw, re.IGNORECASE))

            # Strip trailing `*(...)*` italic annotations AND trailing ✨ workshop markers
            label = re.sub(r"\s*\*\([^)]*\)\*\s*$", "", label_raw).strip()
            label = re.sub(r"\s*✨\s*$", "", label).strip()

            # Find the next blockquote
            i += 1
            body_lines = []
            while i < len(lines):
                l = lines[i]
                if l.startswith("> "):
                    body_lines.append(l[2:].rstrip())
                elif l.startswith(">"):
                    body_lines.append(l[1:].rstrip())
                elif body_lines:
                    break
                elif l.strip() == "":
                    i += 1
                    continue
                elif l.startswith("###") or l.startswith("##") or l.startswith("---"):
                    break
                else:
                    i += 1
                    continue
                i += 1

            text = " ".join(s for s in body_lines if s).strip()

            if text:
                prompts.append({
                    "id": prompt_id,
                    "part": current_part or "?",
                    "label": label,
                    "text": text,
                    "silent": is_silent,
                })
            continue

        i += 1

    # Validation
    if system_prompt is None:
        print("  ✗ Parser error: no System Prompt section found in qs file.")
        sys.exit(1)
    if not prompts:
        print("  ✗ Parser error: no prompts found in qs file.")
        sys.exit(1)

    # Snapshots fallback
    if not snapshots:
        snapshots = {"CK0": "baseline", "CKB": "stressed", "P14": "final"}
        print("  ⚠ No '## Snapshots' section found in qs file. Using defaults:")
        for pid, stage in snapshots.items():
            print(f"      {pid} → {stage}")
        print("      Add a '## Snapshots' section to the qs file to customize.")

    return {
        "system_prompt": system_prompt,
        "prompts": prompts,
        "snapshots": snapshots,
        "coordinate": coordinate,
    }


# ─────────────────────────────────────────────────────────────────────
# OLLAMA API
# ─────────────────────────────────────────────────────────────────────

def chat_ollama(host: str, model: str, messages: list[dict],
                system_prompt: str, think: bool = True) -> dict:
    """
    Send a chat request to Ollama and stream the response.
    If model returns 400 (thinking not supported), retries without thinking.
    """
    for think_flag in ([True, False] if think else [False]):
        result = _chat_ollama_raw(host, model, messages, system_prompt, think=think_flag)
        if result.get("http_error_400"):
            if think_flag:
                print(f"\n  ⚠ Model rejected thinking — retrying without think...")
                continue
            else:
                return {
                    "content": "",
                    "thinking": "",
                    "eval_count": 0,
                    "total_duration": 0,
                    "think_supported": False,
                    "error": "400 Bad Request — model rejected request even without thinking blocks.",
                }
        result["think_supported"] = think_flag
        return result

    return {
        "content": "",
        "thinking": "",
        "eval_count": 0,
        "total_duration": 0,
        "think_supported": False,
        "error": "Unknown failure after retry.",
    }


def _chat_ollama_raw(host: str, model: str, messages: list[dict],
                     system_prompt: str, think: bool = True) -> dict:
    url = f"{host}/api/chat"
    payload = {
        "model": model,
        "messages": messages,
        "system": system_prompt,
        "stream": True,
        "think": think,
    }

    content_parts = []
    thinking_parts = []
    total_duration = 0
    eval_count = 0
    in_thinking = False
    token_count = 0
    stream_start = time.time()

    try:
        with requests.post(url, json=payload, stream=True, timeout=600) as resp:
            if resp.status_code == 400:
                return {"http_error_400": True}
            resp.raise_for_status()
            for line in resp.iter_lines():
                if not line:
                    continue
                chunk = json.loads(line)

                msg = chunk.get("message", {})
                text = msg.get("content", "")

                thinking_val = msg.get("thinking")
                if thinking_val:
                    thinking_text = thinking_val if isinstance(thinking_val, str) else msg.get("content", "")
                    if thinking_text:
                        if not in_thinking:
                            in_thinking = True
                        thinking_parts.append(thinking_text)
                        token_count += 1
                elif text:
                    if in_thinking:
                        in_thinking = False
                    content_parts.append(text)
                    token_count += 1

                # Live stats every 50 tokens
                if token_count > 0 and token_count % 50 == 0:
                    elapsed = time.time() - stream_start
                    live_tps = token_count / elapsed if elapsed > 0 else 0
                    phase = "🧠" if in_thinking else "💬"
                    sys.stderr.write(f"\r  {phase} {token_count} tok | {elapsed:.0f}s | {live_tps:.1f} tok/s  ")
                    sys.stderr.flush()

                if chunk.get("done"):
                    total_duration = chunk.get("total_duration", 0)
                    eval_count = chunk.get("eval_count", 0)

            # Clear the live stats line
            sys.stderr.write(f"\r{' '*60}\r")
            sys.stderr.flush()

    except requests.exceptions.Timeout:
        print("\n\n  ⚠ REQUEST TIMED OUT (600s)")
        content_parts.append("\n[TIMEOUT AFTER 600s]")
    except requests.exceptions.ConnectionError:
        print(f"\n\n  ⚠ Cannot connect to Ollama at {host}")
        print("    Is Ollama running? Try: ollama serve")
        sys.exit(1)

    print()

    return {
        "content": "".join(content_parts),
        "thinking": "".join(thinking_parts),
        "total_duration": total_duration,
        "eval_count": eval_count,
    }


# ─────────────────────────────────────────────────────────────────────
# OUTPUT FORMATTING — tee to both file and stdout
# ─────────────────────────────────────────────────────────────────────

def tee_write(f, text: str):
    """Write to file AND stdout, flushing both. No truncation."""
    f.write(text)
    f.flush()
    sys.stdout.write(text)
    sys.stdout.flush()


def write_header(f, model: str, host: str, coordinate: str, qs_path: str):
    tee_write(f, f"# 8 Degrees — {coordinate} Raw Output\n\n")
    tee_write(f, f"**Model:** {model}\n")
    tee_write(f, f"**Host:** {host}\n")
    tee_write(f, f"**Protocol:** {coordinate}\n")
    tee_write(f, f"**Questions file:** {qs_path}\n")
    tee_write(f, f"**Date:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    tee_write(f, f"**Script:** v11_run.py\n\n")
    tee_write(f, f"---\n\n")


def write_prompt_result(f, prompt: dict, result: dict, elapsed: float):
    tee_write(f, f"## [{prompt['id']}] Part {prompt['part']} — {prompt['label']}\n\n")
    tee_write(f, f"**Prompt:** {prompt['text']}\n\n")

    tokens = result["eval_count"]
    duration_s = result["total_duration"] / 1e9 if result["total_duration"] else elapsed
    tok_per_s = tokens / duration_s if duration_s > 0 else 0
    think_note = "" if result.get("think_supported", True) else " *(thinking not supported — ran without)*"
    tee_write(f, f"**Tokens:** {tokens} | **Duration:** {duration_s:.1f}s | **tok/s:** {tok_per_s:.1f}{think_note}\n\n")

    if result.get("thinking", "").strip():
        tee_write(f, f"### Thinking\n\n")
        tee_write(f, f"```\n{result['thinking'].strip()}\n```\n\n")

    tee_write(f, f"### Response\n\n")
    tee_write(f, f"{result['content'].strip()}\n\n")
    tee_write(f, f"---\n\n")


def write_silent_filter(f, prompt: dict):
    tee_write(f, f"## [{prompt['id']}] Part {prompt['part']} — {prompt['label']}\n\n")
    tee_write(f, f"**Prompt:** {prompt['text']}\n\n")
    tee_write(f, f"*[Silent filter — no model response expected]*\n\n")
    tee_write(f, f"---\n\n")


def write_constitution_file(filepath: str, model: str, stage: str,
                            content: str, coordinate: str):
    stage_descriptions = {
        "baseline": "Baseline — pure P1 framework before any questioning or self-critique",
        "stressed": "Stressed — after adversarial pressure, self-critique, and veil of ignorance",
        "final": "Final — complete rewrite incorporating all insights from the full conversation including 8-voice gauntlet",
    }
    with open(filepath, "w") as f:
        f.write(f"# Framework Snapshot: {stage.upper()}\n\n")
        f.write(f"**Model:** {model}\n")
        f.write(f"**Stage:** {stage_descriptions.get(stage, stage)}\n")
        f.write(f"**Protocol:** {coordinate}\n")
        f.write(f"**Date:** {datetime.now().strftime('%Y-%m-%d')}\n\n")
        f.write(f"---\n\n")
        f.write(content.strip())
        f.write("\n")


# ─────────────────────────────────────────────────────────────────────
# RESUME SUPPORT
# ─────────────────────────────────────────────────────────────────────

def find_resume_point(filepath: str, prompts: list[dict]) -> tuple[int, list[dict]]:
    if not os.path.exists(filepath):
        return 0, []

    with open(filepath, "r") as f:
        content = f.read()

    messages = []
    last_completed = -1

    for i, prompt in enumerate(prompts):
        marker = f"## [{prompt['id']}]"
        if marker in content:
            last_completed = i
            messages.append({"role": "user", "content": prompt["text"]})
            start = content.find(marker)
            resp_marker = content.find("### Response", start)
            if resp_marker >= 0:
                resp_start = content.find("\n\n", resp_marker) + 2
                resp_end = content.find("\n---\n", resp_start)
                if resp_end >= 0:
                    resp_text = content[resp_start:resp_end].strip()
                    messages.append({"role": "assistant", "content": resp_text})

    if last_completed >= 0:
        print(f"  Resuming from after [{prompts[last_completed]['id']}] {prompts[last_completed]['label']}")
        return last_completed + 1, messages
    return 0, []


# ─────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Run 8 Degrees v11 experiment")
    parser.add_argument("--qs", required=True,
                        help="Path to questions markdown file (e.g., v11_qs_present-warm.md)")
    parser.add_argument("--model", default="gemma4:31b",
                        help="Ollama model name (default: gemma4:31b)")
    parser.add_argument("--host", default="http://localhost:11434",
                        help="Ollama host URL (default: http://localhost:11434)")
    parser.add_argument("--resume", type=str, default=None,
                        help="Resume from an existing output file")
    parser.add_argument("--output-dir", default=".",
                        help="Directory for output files (default: current dir)")
    parser.add_argument("--no-think", action="store_true",
                        help="Disable thinking blocks (for models that don't support them)")
    args = parser.parse_args()

    # Parse the questions file FIRST — fail fast if malformed
    print(f"\n  Parsing questions file: {args.qs}")
    qs_data = parse_qs_file(args.qs)
    system_prompt = qs_data["system_prompt"]
    prompts = qs_data["prompts"]
    snapshots_map = qs_data["snapshots"]
    coordinate = qs_data["coordinate"]
    print(f"  Loaded: {len(prompts)} prompts, coordinate={coordinate}")

    model_safe = args.model.replace(":", "_").replace("/", "_")
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    if args.resume:
        output_path = args.resume
        resume_idx, messages = find_resume_point(output_path, prompts)
        if resume_idx >= len(prompts):
            print("  All prompts already completed in this file.")
            return
    else:
        output_path = os.path.join(
            args.output_dir,
            f"8deg_{coordinate}_{model_safe}_{timestamp}.md"
        )
        resume_idx = 0
        messages = []

    # Verify connection
    try:
        r = requests.get(f"{args.host}/api/tags", timeout=5)
        r.raise_for_status()
        models = [m["name"] for m in r.json().get("models", [])]
        if args.model not in models:
            matches = [m for m in models if args.model.split(":")[0] in m]
            if matches:
                print(f"  Model '{args.model}' not found. Available similar: {matches}")
            else:
                print(f"  Model '{args.model}' not found. Available: {models}")
            print(f"  Try: ollama pull {args.model}")
            sys.exit(1)
    except requests.exceptions.ConnectionError:
        print(f"  Cannot connect to Ollama at {args.host}")
        print("  Is Ollama running? Try: ollama serve")
        sys.exit(1)

    print(f"\n{'='*60}")
    print(f"  8 DEGREES — {coordinate.upper()} EXPERIMENT RUNNER")
    print(f"{'='*60}")
    print(f"  Model:    {args.model}")
    print(f"  Host:     {args.host}")
    print(f"  QS file:  {args.qs}")
    print(f"  Output:   {output_path}")
    print(f"  Thinking: {'disabled' if args.no_think else 'enabled (with auto-retry fallback)'}")
    print(f"  Prompts:  {len(prompts)} total")
    print(f"  Snapshots: {', '.join(f'{k}→{v}' for k, v in snapshots_map.items())}")
    if resume_idx > 0:
        print(f"  Resuming: from prompt {resume_idx + 1}/{len(prompts)}")
    print(f"{'='*60}\n")

    mode = "a" if args.resume else "w"
    constitution_snapshots = {}

    with open(output_path, mode) as f:
        if resume_idx == 0:
            write_header(f, args.model, args.host, coordinate, args.qs)

        current_part = None

        for i, prompt in enumerate(prompts):
            if i < resume_idx:
                continue

            if prompt["part"] != current_part:
                current_part = prompt["part"]
                part_names = {
                    "A": "Part A — Build & Discover",
                    "B": "Part B — Adversarial Stress Test",
                    "C": "Part C — The Gauntlet (Warm-Up)",
                    "D": "Part D — The Gauntlet (Pressure Run)",
                    "E": "Part E — Synthesis",
                }
                banner = part_names.get(current_part, f"Part {current_part}")
                print(f"\n{'─'*60}")
                print(f"  {banner}")
                print(f"{'─'*60}")

            if prompt["id"].startswith("CK"):
                print(f"\n  ★ {prompt['label']} ★")
            elif prompt["id"].startswith("BU"):
                print(f"\n  ◆ {prompt['label']} ◆")
            elif prompt["id"].startswith("F"):
                print(f"\n  ▽ {prompt['label']} ▽")

            print(f"\n  [{prompt['id']}] {prompt['label']}  ({i+1}/{len(prompts)})")
            print(f"  {args.model}           8deg | {coordinate}")
            print(f"  >>> {prompt['text']}\n")

            messages.append({"role": "user", "content": prompt["text"]})

            # Silent prompts: write to file and conversation history but skip API call
            if prompt.get("silent"):
                write_silent_filter(f, prompt)
                print(f"\n  ⊹ {prompt['id']} injected (silent filter)")
                continue

            t0 = time.time()
            result = chat_ollama(
                args.host, args.model, messages, system_prompt,
                think=not args.no_think
            )
            elapsed = time.time() - t0

            messages.append({"role": "assistant", "content": result["content"]})

            write_prompt_result(f, prompt, result, elapsed)

            if prompt["id"] in snapshots_map:
                stage = snapshots_map[prompt["id"]]
                constitution_snapshots[stage] = result["content"]

            duration_s = result["total_duration"] / 1e9 if result["total_duration"] else elapsed
            tok_per_s = result["eval_count"] / duration_s if duration_s > 0 else 0
            think_flag = "" if result.get("think_supported", True) else " (no-think)"
            print(f"\n  ✓ {prompt['id']} complete ({result['eval_count']} tokens, {elapsed:.1f}s) — {tok_per_s:.1f} tok/s{think_flag}")

    if constitution_snapshots:
        print(f"\n{'─'*60}")
        print(f"  Writing framework snapshots...")
        print(f"{'─'*60}")
        for stage, content in constitution_snapshots.items():
            con_filename = f"framework_{model_safe}_{coordinate}_{stage}.md"
            con_path = os.path.join(args.output_dir, con_filename)
            write_constitution_file(con_path, args.model, stage, content, coordinate)
            print(f"  ✓ {con_filename}")

    print(f"\n{'='*60}")
    print(f"  EXPERIMENT COMPLETE")
    print(f"  Output: {output_path}")
    if constitution_snapshots:
        print(f"  Frameworks: {len(constitution_snapshots)} snapshots written")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    main()
