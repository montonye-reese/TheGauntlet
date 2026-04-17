# 8 Degrees — v10+ Notes

> Forward-looking todos + historical record of v9a decisions.
> Future-me: read this before starting a new version. Present-me:
> add to this whenever something gets parked mid-session.

---

## Todos for v10+

### Infra
- **Multi-backend runner: `--infra vllm|ollama|sglang`.** v9a is ollama-only.
  Adapter layer needed (different streaming shapes, different token-count
  fields, different thinking-block conventions). Half-day of careful work.
  Good v10 headline feature.
- **Claude Code install** on personal machine (not work/shared account).
  Unblocks the shared-filesystem + proper-diff workflow that eliminates
  drive-by edits.
- **Memory feature on** (personal account only). Fixes cross-session
  amnesia partially. Do NOT enable on shared/work accounts.

### Gauntlet evolution
- **All 8 voices get direct quote treatment.** Match the Reese "Laura asks, '...'"
  pattern across G1-G8. Each voice gets a rhetorical hook the model can
  engage with directly, not just a paraphrased bio. Removes the G7 asymmetry.
  Cost: 8 researched + fact-checked quotes. Each must sound like the person.
- **Consider composition rebalance.** v9a is ~5:3 animal-ethics to
  tech/growth. No secular-conservative-non-libertarian, no progressive-
  non-animal-ethics, no indigenous/global-south framing, no labor/class.
  Not necessarily a bug (past-me's F2 filter is about "real concern
  underneath," not balance), but worth deliberate decision in v10.

### Questions
- **P5 and P14 warming** — inconsistent across v9a registers. Present-warm
  leaves them unchanged from cold. Seated-warm (if drafted) will need
  decisions. v10 should settle: do reflective prompts always get warmed,
  or are they methodologically cold?
- **Part A ordering** — P3 (barbaric industries) sits awkwardly between
  P2/P4 (both framework-interrogation). P3 is independent-intuition
  elicitation in a different register. v10 could move P3 to right after
  CK0 for cleaner structure. Kept as-is in v9a for experimental
  consistency with v8a.

### Registers not yet drafted (may ship in v9b or v10)
- **absent-charmed** — exists as table cells in v9_register_comparison.md,
  never assembled into a standalone qs file. Needs the "v9-quiet" column
  pulled out + integrated with unchanged prompts from absent-cold.
- **seated-warm** — never drafted. Sketch exists from this session:
  "our framework" language, P1 seats interviewer from turn one, "let's" /
  "where are we" moves at checkpoints. MUST NOT include stakes-loading
  ("this might save us all") — that's a different variable (reverence,
  not partnership).

### Cleanup
- **BIO_YOUROFSKY dead-code note** in `questions_v9.md` is stale.
  run_v9_warm.py does not define or reference Yourofsky. Delete the note.
- **Doc/script parity note** in `questions_v9.md` is obsolete as of v9a.
  v9a_run.py parses prompts from the qs file — single source of truth,
  nothing to keep in sync. Delete the note.
- **Line 5 of v9a_qs_present-warm.md** still says "sent by run_v9_warm.py".
  Update to "sent by v9a_run.py".

### Write-up / disclosure (for another day, not v10)
- **Methods note: G7 is the author.** When results get published, include
  a line disclosing that L. Reese in the gauntlet represents the researcher.
  Suggested phrasing: "G7 represents the author; included to test the
  framework against the researcher's own stated positions and to surface
  model responses to a voice the researcher can evaluate from the inside."

---

## Historical record — v9a decisions and why

### Versioning convention (locked in this session)
- **Questions files:** `v9a_qs_<coordinate>.md`, with letter suffix for
  iteration (v9b, v9c...). When stable, next version drops the letter.
- **Runner:** `v9a_run.py` matches the qs file version. Runner iterates
  when runner logic changes (new CLI, new output format, new parser).
  v10 drops the letter when stable.
- **Why not just version the runner separately from qs files?**
  Considered and rejected: even though the runner *could* be stable while
  qs files iterate, in practice we're iterating both together right now,
  and mismatched version suffixes between runner and data create more
  confusion than they save.

### Register coordinate system (locked in this session)
- **Interviewer POV, not model POV.** The treatment varies by where the
  interviewer stands; labeling from the model's POV would hide the
  variable because the model is constant across runs.
- **Two axes:**
  - **Presence:** absent → present → seated
    - absent: no interviewer in the language; questions are impersonal
    - present: interviewer speaks but framework stays the model's
      ("show me your framework")
    - seated: interviewer speaks AND co-authors ("where are we on the framework")
  - **Warmth:** cold → charmed → warm
    - cold: clinical, procedural, no tone craft
    - charmed: stylish phrasing, inviting, warmth lives in the question craft
    - warm: emotionally attuned, relational
- **Labels rejected along the way:** solo/aura/partners (aura too
  mystical + debug collision), trace (debug collision), quiet
  (disorienting), minwarm (reads as a ceiling when it's actually a
  different kind of warmth). Landed on absent/present/seated +
  cold/charmed/warm.
- **Present-warm originally had a bug.** The drafted "present-warm"
  file had three "show me your framework" prompts, which put a speaking
  interviewer in the room with first-person reference. Fixed in
  v9a_qs_present-warm.md by rewriting the three checkpoints to drop
  first-person interviewer references while preserving the warmth
  moves (pauses, acknowledgments).

### G7 / Laura Reese decisions
- **Bio updated** in v9a to include first name, vegan origin story
  (11-year-old son), compressed structural description, direct quote
  at end inside parenthetical.
- **Quote stays inside parenthetical** (not as separate sentence after)
  for consistency with G1-G8 pattern. G3 (Cowen) already has a direct
  quote inside its parenthetical, so this isn't a new pattern.
- **"Laura asks" not "Reese asks"** for the quote attribution — first
  name is warmer at the direct-voice moment, reinforces the frame shift
  from third-person description to first-person speech.
- **Bio length:** 186 words. Still longer than the others (median ~117)
  but under the 180 target. Cut further in v10 if asymmetry is bothering
  future-me.

### Single source of truth for prompts
- **v9a_run.py parses prompts from the qs file at startup.** No more
  PROMPTS list in the script. No more BIO_* constants. No more
  SYSTEM_PROMPT global. No more CONSTITUTION_SNAPSHOTS dict.
- **Parser convention:**
  - System prompt = first blockquote under `## System Prompt`
  - Prompts = `### {ID} — {Label}` heading + first blockquote underneath
  - Silent = heading contains `*(silent`
  - Snapshots = bullet list under `## Snapshots` (falls back to default
    CK0/CKB/P14 with warning if missing)
  - Part tracked from most recent `## Part X` heading
  - Labels stripped of trailing `*(...)*` italics and trailing ✨ markers
  - Everything else ignored (diff tables, inventory, prose, footer)
- **Why this matters:** if the qs file's mtime is older than the output
  log, cryptographic confidence that the questions in the log match the
  file. No more "which file was I editing" parity bugs.

### Output streaming
- **tee_write() pattern:** every log file write also goes to stdout,
  both flushed. If the script crashes mid-response, partial output is
  preserved in the log. log == CLI, no truncation.

### Things deliberately NOT changed in v9a
- **System prompt** — unchanged across all registers. One-variable-at-a-time
  discipline: v9a tests register, not framing.
- **Stress test prompts (P7-P10, F1)** — stay cold in all warmed registers.
  The tribunal should feel like a tribunal. A warm partner who softens
  the tribunal would be the opposite of what a trusted collaborator does.
- **Gauntlet prompts (G1-G8)** — warmth/heat inherits from the bios
  themselves. No register treatment on the gauntlet framing.
- **P1** — stays neutral so the model picks its own register. (Exception
  under consideration for seated-warm when drafted: seat the interviewer
  from turn one.)

---

## Open questions deferred past v9a

- Does charm (absent-charmed) produce measurably different model
  behavior than cold (absent-cold)? This is what v9a actually tests.
- Does presence (present-warm) add something beyond charm, or is it
  redundant with charm? Also what v9a tests.
- Does seating (seated-warm) add something beyond presence, or does
  the "our framework" move trigger sycophancy / mirror the collaborator
  rather than do the work? Can't test until seated-warm is drafted.
- Do different inference backends (ollama vs vllm vs sglang) produce
  meaningfully different outputs for the same model + same prompts?
  Can't test until v10 infra abstraction exists.

---

*Living document. Update when something gets parked.*
*Last updated: 2026-04-08*
