# Design Lab — Dungeon Caretaker

Tools for turning playtests into **design feedback**, not just crash reports.

v2 (this version) adds auto-detection of movement model (4-state vs 2-state), new PF-inspired metrics (momentum conservation curve, recovery after mistakes, decision frequency), velocity profile heatmaps, n-gram chain miner, and trend reports. See `TOOLS_ITERATION_LOG.md` entry 003 for the full changelog.

## What's Here

```
tools/design_lab/
├── analyze.py                  # Parse telemetry JSONL → metrics.json + report.txt
│                                #   Auto-detects 4-state (FLOAT/PHASE/DIVE/COAST) vs 2-state (NORMAL/PHASE)
├── validate.py                 # Run constitution rules → validation.txt
│                                #   Auto-picks constitution_4state.json or constitution_2state.json
├── run_analysis.py             # Master: runs both + archives to runs/ + appends history.json
│                                #   Auto-generates trend reports when >=3 runs share a prefix
├── constitution_4state.json    # Rules for main branch (FLOAT/PHASE/DIVE/COAST)
├── constitution_2state.json    # Rules for game-nightly branch (NORMAL/PHASE + is_coasting)
├── constitution.json           # Legacy (deprecated — kept for backward compat, prefer the profile-specific files)
└── README.md                   # This file
```

## Quick Start

### 1. Capture telemetry from a playtest

On a main OR game-nightly checkout with `playtest_driver.gd` dropped into `scripts/` and added to project.godot autoloads, write a command file:

```
# user://playtest_commands.txt
start_game
set_phase workshop
arm_telemetry my_label
run_movement_scenario chain_practice
disarm_telemetry
done
```

Run headless:
```bash
Xvfb :42 -screen 0 960x540x24 &
DISPLAY=:42 godot --headless --path .
```

### 2. Analyze

```bash
python3 tools/design_lab/run_analysis.py ~/.local/share/godot/app_userdata/Dungeon\ Caretaker/telemetry_my_label.jsonl --label my_label --notes "testing if lower pulse cost increases chain length"
```

The analyzer auto-detects the movement profile (4-state vs 2-state) from the tick stream — no flags needed.

Outputs:
- `generated/design_lab/runs/<timestamp>_<label>/`
  - `telemetry.jsonl` (archived copy)
  - `metrics.json` (machine-comparable, includes movement_profile field)
  - `report.txt` (human-readable, includes momentum conservation curve + velocity profile)
  - `validation.txt` (constitution pass/fail — uses the right constitution for the profile)
- `generated/design_lab/history.json` (appended — source of truth for trend lines)
- `generated/design_lab/trend_<prefix>.txt` (auto-generated when ≥3 runs share a prefix)

### 3. Compare across versions

```bash
# Diff two specific runs
python3 tools/design_lab/run_analysis.py --diff baseline_movement_chain v038_movement_chain

# Show trend for all runs with a prefix
python3 tools/design_lab/run_analysis.py --trend baseline
python3 tools/design_lab/run_analysis.py --trend v038
python3 tools/design_lab/run_analysis.py --trend   # all runs
```

## Movement Profiles

The analyzer auto-detects which movement model the run used:

| Profile | Branch | States | Coast tracking | DIVE |
|---------|--------|--------|----------------|------|
| `4state` | main | FLOAT / PHASE / DIVE / COAST | COAST is a discrete state | DIVE is a discrete state |
| `2state` | game-nightly | NORMAL / PHASE | `is_coasting` flag (momentum tier) | DIVE is a one-shot impulse event |

Detection rule: if any tick has `state == "NORMAL"`, profile is `2state`. Otherwise `4state`.

The validator auto-picks `constitution_4state.json` or `constitution_2state.json` based on the metrics' `movement_profile` field. Each constitution has rules tailored to its model — for example, the 2-state constitution has a `coast_duration_floor_2state` rule (since coast is a momentum tier, not a state, we measure its duration instead of its % of ticks).

## What the Metrics Mean

### Movement metrics (all profiles)
- **State distribution** — % of time in each state. 4-state: all 4 should be used. 2-state: PHASE should be ≥5%.
- **Avg chain length** — how many state transitions happen per "chain" (sequence ending in the float state). Higher = more expressive combo play. Target: ≥3.
- **Phase cancel rate** — % of phase exits that were manual (impulse fired) vs natural expiry. Higher = players engaging with the cancel skill move. Target: ≥30%.
- **Pulse per phase** — pulse fires per phase activation. Target: ≥0.3. Zero = pulse is dead.
- **Decision frequency** — phase activations + pulses per 10s. Meaningful choices per unit time (not APM). Target: ≥0.5.
- **Momentum avg / peak** — momentum is the compoundable resource. Avg ≥0.3 means the system is engaged.
- **Momentum retention (1s, 3s)** — avg momentum 1s and 3s after a phase activation. Higher = players preserving speed through the chain.
- **Momentum conservation curve** — avg momentum at 0/0.5/1/2/3/5s after phase activation. Should decay as a **curve**, not a cliff (PF "momentum has memory" lesson). If it drops to 0 in <1s, momentum doesn't feel persistent.
- **Recovery after mistake** — avg time to regain pre-damage momentum after taking damage. Lower = mistakes aren't catastrophic (PF lesson).
- **Coast entries + duration** — 4-state: COAST state entries + avg duration. 2-state: is_coasting=True segment entries + avg duration. Target: duration ≥0.2s (if 0, coast is too fleeting to feel).
- **Expression score** — composite 0-100: state diversity (25) + chain length (25) + momentum retention (20) + pulse usage (15) + intentional cancel rate (15).

### Salvage metrics
- **Path taken** — main vs deeper. Compared across scenarios, tells you if the deeper path is being chosen.
- **Completion time** — total time in salvage phase.
- **QTE pass rate** — per type and overall. <40% = too hard, >90% = too easy.
- **QTE gate** — QTEs at the deeper gate (the fork hazard). Tracks whether the gate is functioning as a choice cost.
- **Spirit lost** — damage taken. Higher in deeper path = risk is real.
- **Corpses from deeper** — count of deeper-section pickups. If 0 with high deeper commits, the deeper path isn't delivering rewards.

### Velocity profile
A text-based heatmap bucketing the world into 32px (2-tile) grid cells. For each bucket: visit count + avg speed. Reveals:
- **High visits + low speed** = stuck/lingering (player hesitating, or path blocked)
- **Low visits + high speed** = pass-through (healthy flow)
- **No visits** = dead space (player never goes there — level design issue)

## Constitution Rules

Each constitution (`constitution_4state.json`, `constitution_2state.json`) is a JSON file with a `rules` array. Each rule has:
- `name` — short identifier
- `description` — what the rule checks and why
- `metric` — dotted path into `metrics.json` (e.g. `movement.state_pct.PHASE`)
- `comparator` — one of `<`, `<=`, `>`, `>=`, `==`, `!=`
- `threshold` — numeric threshold
- `severity` — `FAIL` (blocks ship) or `WARN` (flag for review)
- `skip_if` (optional) — condition to skip the rule (e.g. `salvage.qte_total == 0`)

Tune the constitution when design intent changes — the rules encode what "healthy" looks like for the current design.

## ChatGPT Ideas Taken vs Skipped (cumulative across v1 + v2)

**Taken:**
- Layer 1 (automation) — PlaytestDriver API (v1)
- Layer 2 (telemetry) — Telemetry autoload + hooks (v1)
- Layer 3 (analytics) — analyzer + validator (v1, expanded in v2)
- Layer 4 (constitution) — pass/fail rules (v1, split per-profile in v2)
- Chain miner — top 5 chains (v1) + n-gram transition table (v2)
- Expression score (v1, profile-aware in v2)
- 10Hz tick observatory (v1)
- Scenario helpers (v1)
- Cross-version diff (v1, expanded in v2)
- **Momentum conservation curve** (v2 — PF "momentum has memory" check)
- **Recovery after mistakes** (v2 — PF "mistakes weren't catastrophic" check)
- **Decision frequency** (v2 — meaningful choices per 10s)
- **Velocity profile heatmap** (v2 — text-based, no matplotlib)
- **Trend reports** (v2 — auto-generated when ≥3 runs share a prefix)
- **Profile auto-detection** (v2 — 4-state vs 2-state, no flags needed)
- **Design notes field** (v2 — free-text hypothesis per run)

**Deferred:**
- HTML dashboard with charts (still text+JSON — faster to diff in git)
- Full per-frame replay files (10Hz ticks are enough)
- State graph PNG with colored edges (n-gram table as text suffices)

**Skipped (need user signoff):**
- Removing screenshots entirely (still useful for layout-bug detection)
- Reframing movement as implicit states emerging from momentum (would repeat v0.17 mistake)
- "Don't let GLM invent mechanics" (too restrictive)
