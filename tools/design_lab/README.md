# Design Lab — Dungeon Caretaker

Tools for turning playtests into **design feedback**, not just crash reports.

This is the v1 implementation described in `TOOLS_ITERATION_LOG.md` entry 001. Built to take ChatGPT's "Design Lab" advice (telemetry → analytics → design review → constitution) without blindly copying the parts that need user signoff first (full movement reframe, removing screenshots, etc.).

## What's Here

```
tools/design_lab/
├── analyze.py           # Parse telemetry JSONL → metrics.json + report.txt
├── validate.py          # Run constitution rules against metrics.json → validation.txt
├── run_analysis.py      # Master: runs both + archives to generated/design_lab/runs/ + history.json
├── constitution.json    # Design rules (pass/fail assertions, tunable)
└── README.md            # This file
```

## Quick Start

### 1. Capture telemetry from a playtest

On a main checkout with `playtest_driver.gd` dropped into `scripts/` and added to project.godot autoloads, write a command file:

```
# user://playtest_commands.txt  (Linux: ~/.local/share/godot/app_userdata/Dungeon Caretaker/playtest_commands.txt)
start_game
set_phase salvage
arm_telemetry baseline_salvage_main
run_salvage_scenario main_only
disarm_telemetry
done
```

Run headless:
```bash
Xvfb :42 -screen 0 960x540x24 &
DISPLAY=:42 godot --headless --path .
```

This produces `user://telemetry_baseline_salvage_main.jsonl`.

### 2. Analyze

```bash
python3 tools/design_lab/run_analysis.py ~/.local/share/godot/app_userdata/Dungeon\ Caretaker/telemetry_baseline_salvage_main.jsonl --label baseline_salvage_main --notes "v0.36 baseline, main path only"
```

Outputs:
- `generated/design_lab/runs/<timestamp>_baseline_salvage_main/`
  - `telemetry.jsonl` (archived copy)
  - `metrics.json` (machine-comparable)
  - `report.txt` (human-readable)
  - `validation.txt` (constitution pass/fail)
- `generated/design_lab/history.json` (appended — source of truth for trend lines)

### 3. Compare across versions

After iterating on the game code, run another playtest with a different label (e.g. `v037_salvage_main`), then:

```bash
python3 tools/design_lab/run_analysis.py --diff baseline_salvage_main v037_salvage_main
```

Prints a delta table showing whether each metric went up or down.

## What the Metrics Mean

### Movement metrics
- **State distribution** — % of time in FLOAT/PHASE/DIVE/COAST. Healthy play uses all 4. FLOAT dominance = no skill expression. COAST absence = players cancel dive too early.
- **Avg chain length** — how many state transitions happen per "chain" (sequence ending in FLOAT). Higher = more expressive combo play. Target: ≥3.
- **Phase cancel rate** — % of phase exits that were manual SPACE-press cancels (intentional DIVE) vs natural expiries. Higher = players engaging with the skill move. Target: ≥30%.
- **Pulse per phase** — pulse fires per phase activation. Target: ≥0.3. Zero = pulse is dead.
- **Momentum retention** — avg momentum 1s and 3s after a phase activation. Higher = players are preserving speed through the chain, not just bursting.
- **Expression score** — composite 0-100: state diversity (25) + chain length (25) + momentum retention (20) + pulse usage (15) + intentional cancel rate (15).

### Salvage metrics
- **Path taken** — main vs deeper. Compared across scenarios, tells you if the deeper path is being chosen.
- **Completion time** — total time in salvage phase.
- **QTE pass rate** — per type and overall. <40% = too hard, >90% = too easy.
- **Spirit lost** — damage taken. Higher in deeper path = risk is real.
- **Corpses from deeper** — count of deeper-section pickups. If 0 with high deeper commits, the deeper path isn't delivering rewards.

## Constitution Rules

The constitution (`constitution.json`) is the design-health rule set. Each rule has:
- `name` — short identifier
- `description` — what the rule checks and why
- `metric` — dotted path into `metrics.json` (e.g. `movement.state_pct.PHASE`)
- `comparator` — one of `<`, `<=`, `>`, `>=`, `==`, `!=`
- `threshold` — numeric threshold
- `severity` — `FAIL` (blocks ship) or `WARN` (flag for review)
- `skip_if` (optional) — condition to skip the rule (e.g. `salvage.qte_total == 0`)

Tune the constitution when design intent changes — the rules encode what "healthy" looks like for the current design.

## ChatGPT Ideas Taken vs Skipped

See `TOOLS_ITERATION_LOG.md` entry 001 for the full rationale.

**Taken:** telemetry layer, analytics layer, chain miner (lite), expression score, design constitution, 10Hz tick observatory.

**Deferred:** HTML dashboard with charts (v1 is text+JSON), full per-frame replay files, state graph PNG.

**Skipped (need user signoff):** removing screenshots entirely, reframing movement as implicit states emerging from momentum (Grounded/Airborne/Phasing only), "don't let GLM invent mechanics anymore."
