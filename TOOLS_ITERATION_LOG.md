# Tools Iteration Log — Dungeon Caretaker

A running log of changes to the **tools-management branch**: the Design Lab (playtest harness + telemetry + analytics), the Music CI pipeline, and any other tooling. Updated after every meaningful tool change.

This log is the tools-management branch's equivalent of `VERSION_LOG.md` on main. Read this first when picking up tools work.

---

## Entry 001 — Design Lab v1: From QA Automation to Design Feedback (2026-07-12)

### Problem: Tools Verified the Game Works, Not That the Game Is Good

The existing `PlaytestDriver` (originally built v0.17, restored v0.34) was a QA harness. It reads a command script (`start_game`, `move`, `interact`, `screenshot`), executes them, captures state to a text log, and screenshots. That answers "does the game crash?" and "is the layout visible?" — but it cannot answer the questions that actually matter during iteration:

- Is the movement becoming more expressive, or just faster?
- Are players discovering and using the full chain (FLOAT → PHASE → DIVE → COAST → PULSE), or relying on one move?
- Does the salvage crossroads create real choice tension, or is the deeper path still a no-brainer?
- Did the v0.36 phase-expiry fix actually change behavior, or did players just stop phasing?

ChatGPT's framing (full text in user's chat history, summarized): the existing tools are an *automation layer*, but what's missing is *telemetry*, *analytics*, *design review*, and *specialized observatories*. The end goal should be that after every game-code commit, the tools automatically produce a DESIGN REPORT comparing metrics across versions — chain length, momentum retention, state usage distribution, expression score, branch diversity, regression detection.

### Diagnosis: Which ChatGPT Ideas to Take, Which to Skip

ChatGPT proposed a full re-architecture in 4 layers + 4 observatories + a design constitution + expression score. Taking it all blindly would mean rewriting the entire tools branch and most of the game's instrumentation in one shot — too risky, and some ideas need user signoff on design intent before they're useful.

**TAKEN (build now):**
1. **Layer 1 — Automation (keep as-is).** PlaytestDriver's command-script API works. Don't break it. New commands get added, existing ones stay.
2. **Layer 2 — Telemetry.** Add an always-present `Telemetry` autoload on main (guarded — no-op when disarmed). Game code emits structured events (state changes, pulse, phase cancel/expiry, dive, coast, QTE outcomes, crossroads commit, corpse pickup, exit). PlaytestDriver arms/disarms it per run. Output: `user://telemetry_<run_label>.jsonl` (one JSON object per line, append-only).
3. **Layer 3 — Analytics.** Python script `tools/design_lab/analyze.py` that parses telemetry JSONL and computes:
   - **Movement metrics:** state usage % (FLOAT/PHASE/DIVE/COAST time distribution), average chain length, momentum retention curve (avg momentum at t=0, 1, 2, 5s after a phase), pulse usage rate, phase cancel rate (manual vs natural expiry), expression score (composite — see below).
   - **Salvage metrics:** deeper-path commit rate, QTE pass rate per type, completion time, corpses collected, spirit lost, exit path taken.
   - Output: `metrics.json` (machine-comparable across versions) + `report.txt` (human-readable text summary).
4. **Chain Miner (lite version).** Top 5 state-transition chains by frequency (e.g., `FLOAT → PHASE → DIVE → COAST → FLOAT: 47 uses`). Shows what's actually alive. Full graph-with-colored-edges version deferred.
5. **Expression Score (v1).** Composite 0-100 score from: state diversity (are all 4 states used?), chain length (longer = more expressive), momentum retention (higher = better), pulse usage frequency (rewards active play), phase cancel rate vs natural expiry (rewards intentional play). Tunable weights. Single number for cross-version comparison.
6. **Design Constitution (v1, minimal).** A rules file `tools/design_lab/constitution.json` with pass/fail assertions:
   - "Every state has ≥1 exit used" (catches dead mechanics)
   - "No single state >70% of total time" (catches dominant strategies)
   - "Average chain length ≥2" (catches one-move spam)
   - "Pulse usage ≥0.3 per phase" (catches pulse being dead)
   - Each rule has a name, description, threshold, and pass/fail status in the report.

**DEFERRED (build later, after v1 proves useful):**
7. HTML dashboard with charts (matplotlib PNGs embedded in HTML). v1 is text + JSON only — faster to build, easier to diff in version control.
8. Movement Observatory replay files (full per-frame capture for re-rendering). v1 captures per-tick snapshots at 10Hz (every 0.1s), which is enough for analysis without the storage cost of true replay.
9. State graph PNG with colored edges (needs graphviz). v1 prints the chain table as text.

**SKIPPED (need user signoff first, or wrong fit for this game):**
10. **"Remove screenshots entirely."** ChatGPT was emphatic, but the user has historically relied on screenshot+vision-model verification for layout overlap detection (MEMORY_CONTEXT gotcha #2). Keep screenshots as a fallback; just de-emphasize them in the report.
11. **"Reframe movement as implicit states emerging from momentum — Grounded/Airborne/Phasing only."** This is a fundamental design rewrite. The current 4-state machine (FLOAT/PHASE/DIVE/COAST) was deliberately designed in v0.17 after 9 specific user-reported issues with the v0.14 charge design. Collapsing to 3 implicit states without user signoff would repeat the v0.17 mistake. Instead, apply the *PF lessons* (momentum conservation, recovery from mistakes, every-state-has-multiple-exits) within the existing 4-state framework.
12. **"Don't let GLM invent mechanics anymore — have it optimize for movement DNA."** Too restrictive. The user explicitly wants the AI to propose mechanics (DESIGN_IDEAS.md is full of player-proposed mechanics for the AI to implement). The constitution validates; it doesn't replace proposal.

### Architecture (v1)

```
main branch (game code):
  scripts/autoload/telemetry.gd         [NEW — always present, guarded]
    - var armed: bool = false
    - var sink: FileAccess = null
    - func arm(label: String) -> void   # opens user://telemetry_<label>.jsonl
    - func disarm() -> void              # closes file
    - func emit(event: Dictionary) -> void  # no-op if not armed; else append JSONL
    - No-op overhead when disarmed: one bool check per emit

  scripts/ghost_movement.gd             [MODIFIED — add emit calls at state transitions]
    - On _start_phase:        emit({type: phase_activated, ...})
    - On _enter_dive:         emit({type: dive_entered, ...})
    - On _enter_coast:        emit({type: coast_entered, ...})
    - On _end_phase_natural:  emit({type: phase_expired_natural, ...})  [v0.36 path]
    - On _fire_pulse:         emit({type: pulse_fired, ...})
    - On state → FLOAT:       emit({type: state_change, to: FLOAT, ...})
    - Per 0.1s tick:          emit({type: tick, state, pos, vel, momentum, chain, input})

  scripts/phases/salvage.gd             [MODIFIED — add emit calls at key events]
    - On committed_deeper = true: emit({type: crossroads_committed, ...})
    - On _start_qte:           emit({type: qte_started, hazard_type, qte_type, pos})
    - On QTE resolved:         emit({type: qte_completed, success, time, ...})
    - On corpse pickup:        emit({type: corpse_collected, name, weapon, pos, time})
    - On damage:               emit({type: damage_taken, cause, spirit_remaining})
    - On exit reached:         emit({type: exit_reached, path, time, corpses, spirit})

tools-management branch (this branch):
  scripts/playtest_driver.gd            [MODIFIED — add new commands]
    - arm_telemetry <label>   # calls Telemetry.arm(label)
    - disarm_telemetry        # calls Telemetry.disarm()
    - run_movement_scenario <name>  # runs a canned movement input sequence
    - run_salvage_scenario <name>   # runs a canned salvage playthrough
    - finish_run <label>      # disarms telemetry + writes summary

  tools/design_lab/                     [NEW directory]
    analyze.py              # parse telemetry JSONL → metrics.json + report.txt
    constitution.json       # design rules (pass/fail assertions)
    validate.py             # run constitution against metrics.json
    run_analysis.py         # master: analyze.py + validate.py + diff vs previous

  generated/design_lab/                 [NEW — pipeline output, gitignored except reports)
    runs/<timestamp>_<label>/
      telemetry.jsonl       # raw events
      metrics.json          # computed metrics
      report.txt            # human-readable
      constitution.json     # copy of rules used
      validation.txt        # pass/fail per rule
    latest/                 # symlink/copy of most recent run
    history.json            # append-only metrics across runs (for trend lines)
```

### Workflow

```
1. On main: add telemetry hooks (guarded). Parse-check. Commit + push.
2. On tools-management: refine PlaytestDriver + build analyzer. Commit + push.
3. To run a playtest (local hybrid working copy):
   a. Checkout main
   b. Drop playtest_driver.gd into scripts/ (gitignored on main)
   c. Add PlaytestDriver + Telemetry to project.godot autoloads (locally only)
   d. Write command script to user://playtest_commands.txt
   e. Run: Xvfb :42 -screen 0 960x540x24 && DISPLAY=:42 godot --headless --path .
   f. Telemetry writes to user://telemetry_<label>.jsonl
   g. Run: python3 tools/design_lab/run_analysis.py user://telemetry_<label>.jsonl
4. Compare reports across versions in generated/design_lab/history.json
```

### Verification Plan

- v1 build verifies by running a baseline playtest on the CURRENT main (v0.36) and producing a report. If the report shows non-zero metrics and the constitution runs without crashing, v1 ships.
- After v1 ships, run the same playtest after each Priority 1/2 iteration. Compare metrics. If a change doesn't move the metrics in the intended direction, revert or retune.

### What This Unlocks

- The v0.36 phase-expiry fix can be measured: does natural-expiry rate go up? Does chain length increase?
- The salvage crossroads can be measured: does the deeper-path commit rate change after a risk/reward tweak?
- Future Priority 1 movement iterations have a target: increase expression score without breaking constitution rules.
- The constitution catches dead mechanics before they ship.

---

## Entry 000 — Baseline (pre-Design Lab)

### State of tools-management branch before this work
- `scripts/playtest_driver.gd` — 270 lines, QA scripting language (start_game/move/interact/screenshot/wait/log_state/done). Restored from user's saved zip in v0.34.
- `tools/music/` — 7 Python scripts + master runner. Music CI pipeline. Last iteration: v0.31 (D major, FM bell chords, 92/100).
- `generated/iterations/` — 5+ preserved music pipeline runs.
- No design feedback tooling. No telemetry. No analytics.

### What works, what doesn't
- **Works:** Music pipeline produces concrete scores and gate-keeps exports. PlaytestDriver can drive the game headless and capture state.
- **Doesn't work:** No way to answer "is movement better?" or "is salvage fun?" from tool output. Screenshot+vision verification catches layout bugs but not design issues.

---
