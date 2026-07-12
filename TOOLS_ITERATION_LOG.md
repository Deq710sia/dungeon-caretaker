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

## Entry 002 — v0.37 Baseline Playtest Findings (2026-07-12)

### Setup
Ran 4 baseline playtests against v0.37 (main + Telemetry autoload + Design Lab v1 on tools-management). All headless via Xvfb. Reports archived in `generated/design_lab/baselines/v037/`. Metrics in `generated/design_lab/history.json`.

| Scenario | Phase | Purpose |
|----------|-------|---------|
| `baseline_movement_empty` | workshop | Drift in a loose circle + 1 phase cancel + 1 pulse |
| `baseline_movement_chain` | workshop | Optimal chain: phase → cancel → dive → coast → pulse (x2) |
| `baseline_salvage_main` | salvage | Walk straight down main corridor to fork exit, no deeper commit |
| `baseline_salvage_deeper` | salvage | Walk past fork into deeper section, trigger crossroads_committed |

### Movement Findings

**1. COAST state is effectively dead.**
- `baseline_movement_empty`: COAST = 0 ticks (state_pct key absent)
- `baseline_movement_chain`: COAST = 0 ticks (same)
- Root cause traced in code: `COAST_DECEL_MULT = 0.25` (was 0.08, raised in v0.17 for "faster coast stop"). With `COAST_MIN_SPEED = 50`, coast ends in ~0.09s when no input is held — shorter than one 10Hz tick. The state is entered but exits before any observable sample.
- **Fix target:** lower `COAST_DECEL_MULT` to ~0.12 (between original 0.08 and current 0.25), lower `COAST_MIN_SPEED` to 35. This should make coast last ~0.3-0.5s, observable in telemetry.

**2. Pulse denied too often at low momentum.**
- `baseline_movement_chain`: `pulse_per_phase = 0.0` (WARN violated). Pulse fires: 0, denials: 2.
- Root cause: `MOMENTUM_PULSE_COST = 0.3` but after a dive, momentum is `clamp(prev - 0.3, 0, 2.0)`. If prev was 0.5, post-dive is 0.2 < 0.3 → pulse denied. The chain_practice scenario fires pulse right after dive, exactly when momentum is lowest.
- **Fix target:** lower `MOMENTUM_PULSE_COST` to 0.2 (so pulse fires whenever momentum ≥ 0.2). Net gain becomes +0.2 per pulse (was +0.1). May need to also lower `MOMENTUM_PULSE_GAIN` to 0.3 to keep net gain at +0.1.

**3. Phase cancel rate = 100% in movement scenarios.**
- v0.36 fix is working as intended. In `baseline_movement_chain`, all phase exits were manual cancels (intentional DIVE). Constitution rule `intentional_cancel_rate` PASSES.
- No iteration needed here.

**4. Momentum average varies wildly by scenario.**
- `baseline_movement_empty`: momentum_avg = 1.43 (good — long movement builds momentum)
- `baseline_movement_chain`: momentum_avg = 0.13 (WARN violated — too low)
- The chain_practice scenario's `move down 1.0` is too short to build momentum before the first phase. Momentum needs ~2s of fast movement to reach the 0.7 speed_pct threshold.
- **Fix target:** either retune `MOMENTUM_BUILD_RATE` (currently 0.5/s) to 0.8/s, OR accept that the scenario is artificial and real play will have longer movement phases. Leaning toward retune — PF lesson is "momentum had memory," so building it should be faster.

**5. Expression score: empty=88.8, chain=53.8.**
- Counterintuitive: the "empty room" scenario scores higher than the "chain practice" scenario. This is because empty room had longer continuous movement (built momentum, fired pulse successfully), while chain practice had short movements between phase cancels (low momentum, pulse denied).
- The expression score formula is working but the scenario design is biasing results. After fixing pulse cost + momentum build rate, re-run and compare.

### Salvage Findings

**6. Main path completed in 5.3s without engaging ANY mechanics.**
- `baseline_salvage_main`: 100% FLOAT, 0 phase activations, 0 pulses, 0 QTEs, 0 corpses, expression score 11.2/100.
- The ghost walks from start (y=48) to main exit (y=480, fork_y=30 tiles) in 5.3s. At 55px/s base + momentum bonus, that's ~7.85s expected, but momentum builds during the walk so it completes faster.
- **Problem:** the main path is a straight shot with no engagement. The "floor" (guaranteed clear) is so easy it's not even a puzzle.
- **Fix target:** lengthen the main corridor (raise `fork_y` minimum from 15 to 25) AND/OR add a required hazard gate at the midpoint that forces a QTE. The DESIGN_PLAN says "exit is always visible and reachable" — that's fine, but the path should have at least one mandatory interaction.

**7. Deeper path: 2 QTEs, both failed, 0 corpses collected.**
- `baseline_salvage_deeper`: 14.6s completion, crossroads committed at 7.7s, spirit lost 2/3, 0 corpses.
- The deeper path IS riskier (2 damage events vs 0 in main), but the reward isn't there — 0 corpses collected because the scenario doesn't include `interact` commands at deeper corpse positions.
- **Problem (scenario):** the `deeper_commit` scenario walks down but doesn't interact with corpses. Need a richer scenario.
- **Problem (design):** even if the scenario did interact, the deeper path's reward (better gear) isn't visible/legible during play. The player has no way to know the deeper corpses have better stuff without picking them up.
- **Fix target:** add a visual marker (blue soul-glow per DESIGN_PLAN Priority 2D) to deeper corpses so the reward is legible. Also add a "deeper gate" hazard at the fork that requires a QTE to enter — makes the choice cost something upfront, not just downstream.

**8. QTE pass rate = 0% in deeper (both failed).**
- The playtest driver doesn't solve QTEs (no key presses for timing/spam/pattern types). So QTEs always time out as failures.
- **Limitation:** this is a playtest driver issue, not a game issue. To test QTE success rate, I'd need to add QTE-solving logic to the scenarios. For now, the analyzer correctly reports 0% pass rate, which is a known artifact.
- **Fix target:** add a `solve_qte` command to PlaytestDriver that auto-solves the current QTE (for testing the success path). Or accept that QTE pass rate is a manual-test metric.

### Constitution Verdicts (v0.37 baseline)

| Scenario | PASS | FAIL | WARN | SKIP | Verdict |
|----------|------|------|------|------|---------|
| movement_empty | 7 | 1 | 1 | 3 | FAIL (dominant FLOAT 93%) |
| movement_chain | 6 | 1 | 2 | 3 | FAIL (dominant FLOAT 78%, pulse dead, momentum low) |
| salvage_main | 2 | 1 | 4 | 5 | FAIL (dominant FLOAT 100%, expression 11.2) |
| salvage_deeper | 3 | 1 | 5 | 3 | FAIL (dominant FLOAT 100%, QTE 0%) |

**Common FAIL:** `no_dominant_state` (FLOAT > 70%) in all 4 scenarios. This is partly scenario-driven (canned scenarios don't use mechanics enough) but also reveals that FLOAT is the default and the other states require explicit player action. After iteration, re-test with richer scenarios.

### Iteration Targets (for next game-code changes on main)

Based on the above, the next game-code iteration on main should:

1. **Fix COAST observability** — lower `COAST_DECEL_MULT` 0.25→0.12, `COAST_MIN_SPEED` 50→35
2. **Lower pulse cost** — `MOMENTUM_PULSE_COST` 0.3→0.2, `MOMENTUM_PULSE_GAIN` 0.4→0.3 (net +0.1 preserved)
3. **Faster momentum build** — `MOMENTUM_BUILD_RATE` 0.5→0.8 (PF "momentum had memory" lesson)
4. **Lengthen main salvage path** — raise `fork_y` minimum from 15 to 25 tiles
5. **Add deeper gate hazard** — required QTE at the fork to enter deeper (makes choice cost upfront)
6. **Add blue soul-glow to deeper corpses** — make reward legible (DESIGN_PLAN Priority 2D)

After these changes, re-run the same 4 scenarios and diff metrics. Expected improvements:
- COAST ticks > 0 in movement scenarios
- pulse_per_phase > 0.3 in movement_chain
- momentum_avg > 0.3 in movement_chain
- salvage_main completion time increases (longer path)
- salvage_deeper triggers a QTE at the gate (deeper_commit_time may shift)

### What the Design Lab Already Proved

- **Telemetry capture works** — 4 runs, ~22KB-45KB JSONL each, all events well-formed
- **Analyzer computes meaningful metrics** — state distribution, chain length, momentum retention, expression score all differentiate scenarios
- **Constitution catches real issues** — COAST death, pulse denial, dominant FLOAT, low expression — all surfaced automatically
- **Cross-version diff is set up** — history.json has 4 entries, ready for after-iteration comparison
- **ChatGPT was right that the original tools couldn't do this** — the old PlaytestDriver log would have shown "moved down, interacted, exited" with no design signal

---

## Entry 003 — Design Lab v2: Profile System + PF-Inspired Metrics (2026-07-12)

### Problem: v1 Analyzer Hardcoded the 4-State Model
The v1 analyzer (entry 001) hardcoded `["FLOAT", "PHASE", "DIVE", "COAST"]` everywhere — state diversity check, chain splitting, constitution rules, report formatting. When game-nightly's 2-state model (NORMAL/PHASE) was tested, every state-specific rule SKIPped because FLOAT/DIVE/COAST never appeared. The analyzer still computed some metrics (expression score, chain length, momentum retention) but couldn't validate game-nightly against a constitution.

Additionally, several ChatGPT-suggested metrics from the original design lab conversation were missing:
- Momentum conservation curve (PF "momentum has memory" lesson — momentum should decay as a curve, not a cliff)
- Recovery rate after mistakes (PF "mistakes weren't catastrophic" — how fast does momentum recover to pre-damage levels?)
- Decision frequency (meaningful choices per 10s, not APM)
- Velocity profile / heatmap (where does the player spend time? where do they move fast vs slow?)
- Trend reports (metric drift across versions, not just pairwise diff)

### Fix: Profile System + New Metrics

**1. Movement profile auto-detection (`analyze.py`)**
- New `MovementProfile` dataclass: `name`, `states`, `float_state`, `phase_state`, `has_dive_state`, `has_coast_state`, `uses_is_coasting_flag`
- `detect_profile(events)` scans tick stream: if any tick has `state == "NORMAL"`, profile is `2state`; otherwise `4state`
- All state-specific logic (state diversity, chain splitting, report formatting, expression score) uses `profile.states` instead of hardcoded list
- Report header prints the detected profile for transparency

**2. New PF-inspired metrics**
- **Momentum conservation curve**: samples avg momentum at 0, 0.5, 1, 2, 3, 5s after each phase activation. Printed as a bar chart in the report. Should decay as a curve — if it drops to 0 in <1s, momentum doesn't feel persistent (PF lesson).
- **Recovery after mistake**: for each `damage_taken` event, finds momentum just before damage, then measures time to recover to that level. Lower = mistakes aren't catastrophic (PF lesson).
- **Decision frequency**: (phase activations + pulses) / elapsed_seconds * 10. Meaningful choices per 10s. Target: ≥0.5 (lower = passive play).
- **Coast duration (profile-aware)**: 4-state measures COAST state segment durations; 2-state measures `is_coasting=True` segment durations. Both report `coast_entries` + `coast_duration_avg`. Catches "coast is too fleeting to feel" (v1 baseline finding).
- **N-gram chain miner**: top 8 single state transitions by frequency (e.g. `PHASE->FLOAT: 5`, `FLOAT->PHASE: 4`). Shows which transitions are alive vs dead.

**3. Velocity profile (text heatmap)**
- Buckets the world into 32px (2-tile) grid cells
- For each bucket: visit count + avg speed
- Top 20 buckets by visit count printed in report with speed bars
- Reveals: high visits + low speed = stuck/lingering; low visits + high speed = pass-through; no visits = dead space

**4. Split constitution**
- `constitution_4state.json` — rules for main (FLOAT/PHASE/DIVE/COAST). Includes `no_dead_states` (all 4 used), `dive_used`, `coast_used`, plus v2 additions: `decision_frequency_floor`.
- `constitution_2state.json` — rules for game-nightly (NORMAL/PHASE). Replaces dive/coast state rules with `coast_duration_floor_2state` (since coast is a momentum tier, not a state). Loosens `no_dominant_state` to 90% (NORMAL will always be dominant in 2-state — rule just catches "never phases at all").
- `validate.py` auto-picks the right constitution based on `metrics.movement_profile` field. No flags needed.

**5. Trend reports**
- `run_analysis.py` auto-generates `trend_<prefix>.txt` when ≥3 runs share a label prefix (e.g. `baseline_*`, `v038_*`)
- Trend report is a table: rows = runs (chronological), columns = key metrics (expression, chain length, dominant state %, cancel rate, pulse/phase, decision freq, momentum avg, coast duration, salvage path/time/corpses/QTE/spirit)
- New CLI flag: `--trend [PREFIX]` shows trend for a prefix (or all runs if no prefix)

**6. Design notes field**
- `run_analysis.py --notes "free text"` passes through to `analyze.py`
- Notes stored in `metrics.json` + `history.json` + printed in report header
- Use case: record the design hypothesis being tested ("testing if lower pulse cost increases chain length") so future readers know what the run was for

### Verification

Smoke-tested against both profiles:

**4-state (main v0.37 baseline):**
- `baseline_movement_chain`: detected `4state`, used `constitution_4state.json`
- All v1 metrics preserved (expression score, chain length, etc.)
- New metrics computed: decision_frequency=2.55/10s, momentum_curve visible
- Constitution: same FAIL/WARN verdicts as v1 (no regressions)

**2-state (game-nightly):**
- `nightly_test_movement`: detected `2state`, used `constitution_2state.json`
- NORMAL/PHASE states shown correctly in report
- is_coasting flag tracked (77.6% of NORMAL ticks were coasting)
- Momentum conservation curve: 1.51 → 1.20 → 0.88 → 0.57 (decay curve visible — PF check passes)
- Coast duration: 0.78s avg across 2 entries (observable!)
- Decision frequency: 7.64/10s
- Constitution: **9 PASS, 0 FAIL, 2 SKIP** — full pass on game-nightly for the first time

**Cross-profile diff:**
- `--diff baseline_movement_chain v038_movement_chain` works across profiles (4state vs 4state)
- `--diff` would also work across 4state vs 2state (just shows "n/a" for state-specific metrics that don't exist in one profile)

**Trend report:**
- Auto-generated for `baseline` (4 runs) and `v038` (4 runs) prefixes
- `--trend baseline` and `--trend v038` both print the table

### What This Unlocks

- **Game-nightly can now be validated** — the 2-state constitution catches real issues (coast duration, decision frequency, momentum) instead of SKIPping everything
- **PF design lessons are measurable** — momentum conservation curve + recovery rate turn "momentum has memory" and "mistakes weren't catastrophic" from vibes into numbers
- **Velocity profile reveals level design issues** — dead space, stuck points, and pass-through routes are visible at a glance
- **Trend reports show iteration direction** — across multiple runs, you can see if expression score is trending up, dominant state % is trending down, etc.
- **Profile auto-detection means no flags** — same analyzer works on main and game-nightly without configuration

### Files Changed

```
tools/design_lab/
├── analyze.py                  # +200 lines (profile system + new metrics + velocity profile)
├── validate.py                 # +50 lines (auto-pick constitution by profile)
├── run_analysis.py             # +100 lines (trend reports + --notes pass-through + more history fields)
├── constitution_4state.json    # NEW (split from constitution.json)
├── constitution_2state.json    # NEW (2-state-specific rules)
├── constitution.json           # UNCHANGED (legacy, kept for backward compat)
└── README.md                   # REWRITTEN (profile system + new metrics documented)
```

---
