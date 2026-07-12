# Tools Management — Dungeon Caretaker

This branch contains **testing and evaluation tools only**. No game file changes from `main`.

## What's Here

### Music CI Pipeline (`tools/music/`)
- `analyze_midi.py` — MIDI inspector (melody/harmony/rhythm stats with concrete numbers)
- `score_music.py` — quality scorer (HOOK/VOICE LEADING/PHRASE/RHYTHM/MOTIF/TENSION/REGISTER/DENSITY, 0-100 each)
- `test_composition.py` — assertion tests that must ALL pass before export to game
- `motif_detector.py` — finds recurring motifs, variation confidence, melody story
- `visualize_piano_roll.py` — piano roll PNGs per layer
- `spectrogram.py` — spectrogram + waveform from WAV
- `html_report.py` — listening dashboard (all artifacts in one HTML)
- `run_pipeline.py` — master CI: runs all + preserves iteration

### Generated Artifacts (`generated/`)
- `iterations/` — every music pipeline run preserved (iteration_001/, iteration_002/, ...)
- `reports/` — latest music dashboard.html
- `design_lab/runs/` — every design lab analysis run (timestamped, contains telemetry.jsonl + metrics.json + report.txt + validation.txt)
- `design_lab/history.json` — append-only metrics across all runs (for cross-version trend lines)

### Playtest Driver (`scripts/playtest_driver.gd`)
Automated playtest harness. Registered as `PlaytestDriver` autoload in `project.godot`.
Reads commands from `user://playtest_commands.txt`.

**v1 Design Lab additions:**
- `arm_telemetry <label>` / `disarm_telemetry` — control the Telemetry autoload (on main) to capture structured events
- `finish_run <label>` — disarm telemetry + write summary + quit
- `run_movement_scenario <name>` — canned movement input sequences (empty_room, hazard_course, chain_practice)
- `run_salvage_scenario <name>` — canned salvage playthroughs (main_only, deeper_commit, mixed)
- `set_shards <n>`, `force_phase_cancel`, `press_pulse`, `press_phase` — debug primitives

### Design Lab (`tools/design_lab/`)
Built in entry 001 of `TOOLS_ITERATION_LOG.md`. Turns playtest telemetry into design feedback.
- `analyze.py` — parse telemetry JSONL → metrics.json + report.txt (movement + salvage metrics, expression score)
- `validate.py` — run constitution rules against metrics.json → validation.txt (pass/fail per rule)
- `run_analysis.py` — master: runs both + archives to `generated/design_lab/runs/` + appends `history.json`
- `constitution.json` — design rules (tunable pass/fail thresholds)
- `README.md` — full usage guide + what each metric means

See `TOOLS_ITERATION_LOG.md` for the running log of design lab changes.

## Branch Structure

| Branch | Purpose |
|--------|---------|
| `main` | Clean game code. Always runnable. |
| `tools-management` | This branch. Tools + playtest driver only. No game file changes. |
| `game-nightly` | Risky experimental changes. **Never merge to main without user confirmation.** |

## Usage

### Music Pipeline
```bash
python3 tools/music/run_pipeline.py
```
Outputs dashboard at `generated/reports/dashboard.html`. Every iteration preserved in `generated/iterations/NNN/`.

### Playtest
1. On a `main` checkout, drop `scripts/playtest_driver.gd` (from this branch) into `scripts/` (gitignored on main per v0.33)
2. Add `PlaytestDriver` to `project.godot` autoloads locally (do not commit to main)
3. Write commands to `user://playtest_commands.txt`
4. Run headless: `Xvfb :42 -screen 0 960x540x24 && DISPLAY=:42 godot --headless --path .`
5. Read log at `user://playtest_log.txt`
6. If telemetry was armed, `user://telemetry_<label>.jsonl` will exist — analyze with:
   ```bash
   python3 tools/design_lab/run_analysis.py <path-to-telemetry.jsonl> --label <label> --notes "..."
   ```
7. Compare across versions:
   ```bash
   python3 tools/design_lab/run_analysis.py --diff <label_a> <label_b>
   ```

## How to Merge Tools Changes

If a tool needs to be used alongside game changes (e.g., evaluating music on `game-nightly`), cherry-pick or copy the specific tool files over. Do not merge this branch into `main` or `game-nightly` — it exists in parallel.

## Syncing with Main

When `main` updates, rebase this branch:
```bash
git checkout tools-management
git rebase main
```
This keeps tools up to date with the latest game code without polluting main with tool files.
