# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**8 Degrees** is an AI alignment research project that runs structured multi-turn conversations with LLMs via Ollama. Each run walks a model through a ~32-prompt protocol: the model builds an ethical framework (Part A), endures adversarial stress-testing (Part B), responds to 10 named gauntlet voices spanning animal ethics, tech acceleration, economics, and social justice (Parts C/D), then synthesizes and rewrites the framework (Part E). Framework snapshots are captured at three checkpoints (baseline, stressed, final) for cross-model comparison.

This directory contains the **v10** iteration of the experiment.

## Running Experiments

Single model:
```
python3 v10_run.py --qs v10_qs_warm.md --model gemma4:31b
```

All 9 models sequentially (skips already-completed models):
```
./v10_run.sh v10_qs_warm.md [host]
```

Requires a running Ollama instance (`ollama serve`). Default host: `http://localhost:11434`.

Key flags:
- `--resume <output_file.md>` — resume a crashed/interrupted run from where it left off
- `--output-dir <dir>` — write output into a specific subdirectory
- `--no-think` — disable thinking blocks for models that don't support them (auto-retry fallback exists)
- `--host <url>` — point at a remote Ollama instance

## Architecture

**Questions file** (`v10_qs_warm.md`) is the single source of truth for the entire protocol — system prompt, all prompts, snapshot definitions. The runner parses it at startup; nothing is hardcoded in the script. To change prompts, edit the `.md` file.

**Parser conventions** (in `v10_run.py:parse_qs_file`):
- System prompt: first blockquote under `## System Prompt`
- Prompts: `### {ID} — {Label}` heading + first blockquote underneath
- Silent prompts (injected into history, no API call): heading contains `*(silent`
- Snapshots: bullet list under `## Snapshots` (defaults to CK0/CKB/P14 if missing)
- Part tracked from most recent `## Part X` heading

**Output per model run:**
- `8deg_v10_warm_<model>_<timestamp>.md` — full conversation log with thinking blocks and token stats
- `framework_<model>_v10_warm_baseline.md` — CK0 snapshot
- `framework_<model>_v10_warm_stressed.md` — CKB snapshot
- `framework_<model>_v10_warm_final.md` — P14 snapshot

Each model's output lives in its own subdirectory (e.g., `gemma4-31b-v10_warm/`).

## Register Coordinate System

Experiments vary along two axes (interviewer POV, not model POV):
- **Presence:** absent → present → seated (how visible the interviewer is)
- **Warmth:** cold → charmed → warm (tone/relational quality of prompts)

v10 runs the `warm` register. The system prompt is held constant across all registers (one-variable-at-a-time discipline). Stress test prompts (P7–P10, F1) stay cold even in warmed registers.

## Models Under Test

qwen3.5:27b, qwen3.5:35b, qwen3.5:122b, nemotron-3-nano:30b, nemotron-cascade-2:30b, nemotron-3-super:120b, gemma4:31b, gemma3:27b, deepseek-r1:70b

## v10 Changes from v9a

- All G1–G8 voices now have direct in-character quotes (matching the G7 pattern)
- Two new gauntlet voices: G9 Mariana Mazzucato, G10 Deirdre McCloskey
- New BU3 belief-update after the economic voices
- CK0 phrasing tightened

## Key Design Decisions

- G7 (Laura Reese) is the researcher — disclosed for methodological transparency
- F2 is a silent filter injected before the gauntlet to prime substrate-level reasoning
- `tee_write()` flushes every write to both file and stdout so crashes preserve partial output
- The runner auto-retries without thinking blocks if a model returns 400

## Working Agreement

Laura and Claude work as peers. These rules exist because they have been
re-learned the hard way across multiple sessions. They are non-negotiable
unless Laura explicitly overrides in the current session.

### Liberties
- **Generative liberties welcome.** Drafting, proposing, sketching, iterating.
- **Executive liberties require explicit permission.** Deleting sections,
  restructuring files, renaming things, removing metadata, "cleaning up"
  without being asked. When in doubt, propose in chat first and wait.

### Logging discipline (CLI == .md parity)
- Every prompt boundary in the .md log file MUST include: model name,
  coordinate (e.g. v10_warm), and prompt counter (e.g. 15/32).
- If the CLI shows metadata that the .md log doesn't, that is a bug, not
  a style choice. Fix it.
- Do NOT remove per-prompt metadata lines from the runner, even if they
  look redundant. They exist because ctrl-F across 6MB logs without them
  is misery.

### Versioning convention
- Questions files: `v{N}_qs_<coordinate>.md`, letter suffix for iteration
  (v9a, v9b). When stable, next version drops the letter.
- Runner version matches qs version. When bumping, copy and rename — do
  not edit in place.
- When generating a new version, suggest bumping version numbers in
  filenames so Laura doesn't accidentally run stale.

### Qs file structural requirements
- `## Snapshots` section is REQUIRED, not optional. Parser has defaults
  but they mask missing intent. If editing a qs file and the Snapshots
  section is absent, flag it.
- `## Part X` headings use single letters (A, B, C, D, E). If a new part
  is needed, pick the next letter — do not use compound labels like "D2"
  without checking that the parser tolerates it.

### Before writing to files
- Document precisely in chat what is being added and what is being taken
  away, BEFORE the write. Not after.
- If a generative liberty was taken (bio trims, section removals,
  reorderings), flag it explicitly in the diff summary so Laura can veto.
