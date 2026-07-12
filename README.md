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
- `iterations/` — every pipeline run preserved (iteration_001/, iteration_002/, ...)
- `reports/` — latest dashboard.html

### Playtest Driver (`scripts/playtest_driver.gd`)
Automated playtest harness. Registered as `PlaytestDriver` autoload in `project.godot`.
Reads commands from `user://playtest_commands.txt`.

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
1. Write commands to `user://playtest_commands.txt`
2. Run Godot (the PlaytestDriver autoload executes them automatically)
3. Read log at `user://playtest_log.txt`

## How to Merge Tools Changes

If a tool needs to be used alongside game changes (e.g., evaluating music on `game-nightly`), cherry-pick or copy the specific tool files over. Do not merge this branch into `main` or `game-nightly` — it exists in parallel.

## Syncing with Main

When `main` updates, rebase this branch:
```bash
git checkout tools-management
git rebase main
```
This keeps tools up to date with the latest game code without polluting main with tool files.
