# Agent Instructions — Dungeon Caretaker

This file is for AI agents (GLM, Claude, etc.) working on this codebase.
Read this BEFORE touching any code.

## Documentation Maintenance Rule (CRITICAL)

**After every commit/push that changes game behavior, update docs in this order:**

1. **VERSION_LOG.md** — ALWAYS. Add a new entry at the top with:
   - Version number + date
   - Problem/Diagnosis (what was wrong)
   - Fix (what you changed)
   - Verification (how you confirmed it works)

2. **MEMORY_CONTEXT.md** — If you changed any of:
   - Architecture (new/removed autoloads, new systems)
   - Movement constants (ACCEL, DECEL, speeds, etc.)
   - Input map (added/removed/changed key bindings)
   - File map (added/removed/renamed files)
   - Known bugs (fixed old ones, introduced new ones)
   - "What's NOT Built Yet" list

3. **DESIGN_PLAN.md** — If you completed a priority or changed scope:
   - Update the BUILD STATUS checklist
   - Mark partial completions as "PARTIAL" with what's done vs not

4. **README.md** — If you changed player-facing info:
   - Controls table
   - Game loop description
   - Tech specs (SFX count, music info, etc.)

**When in doubt, check VERSION_LOG.md first** — it's the most current doc. If the other three are stale relative to VERSION_LOG, update them before starting work.

## Code Style

- **Indentation is inconsistent across files** — `ghost_movement.gd` uses SPACES (verified v0.36; was previously misdocumented as tabs), `planning.gd`/`battle.gd`/`weapon.gd` use tabs, `salvage.gd`/`workshop.gd`/`gate.gd`/`results.gd` use spaces. **Match the file you're editing.** Don't convert. When in doubt, run `sed -n '100p' <file> | od -c | head -1` to verify what the file actually uses — doc claims have been wrong before.
- Use explicit types (`var x: float = 0.0` not `var x := 0.0`) — Godot 4 type inference can fail on Dictionary access.
- Integer-snap all draw positions (`int(x)`) — sub-pixel jitter at 480×270.
- Never use font_size other than 8 or 16 (Press Start 2P only crisp at those).

## Testing

- **Parse check after every change:** `/tmp/godot4 --headless --quit` (download Godot 4.3 if missing)
- **Unit tests for movement:** write a temp TestRunner autoload, run, then remove before commit (see VERSION_LOG v0.17 for example)
- **Render music preview:** temp SFXRenderer autoload, export WAV, then remove before commit
- **Playtest:** checkout `tools-management` branch, use PlaytestDriver

## Common Pitfalls

1. **Edit tool converts tabs to spaces** — if editing a tab-indented file, run `unexpand -t 8 --first-only` after, or use a Python patcher with explicit `\t` in heredocs.
2. **`Input.is_action_just_pressed` unreliable in manual tick** — use `_pulse_was_pressed` manual edge detection pattern (see ghost_movement.gd).
3. **`clampf(pos)` doesn't zero velocity** — wall collision must zero the clamped axis of velocity or momentum builds against walls (v0.23 fix).
4. **Music render takes ~9s** in GDScript at first boot. Disk cache (`user://music_cache.bin`, version 10) fixes subsequent boots. Bump `CACHE_VERSION` constant in music.gd when music data changes to invalidate.
5. **`store_bool` doesn't exist in Godot 4.3** — use `store_32(1 if bool else 0)` and `get_32() != 0`.
6. **gate.gd uses hand-copied movement** — if you change GhostMovement constants, update gate.gd too (or refactor it to use real GhostMovement).
7. **Music CI pipeline** is in `tools/music/` — completely separate from game code. Run `python3 tools/music/run_pipeline.py` after any music change. ALL TESTS must pass before export. Every iteration preserved in `generated/iterations/NNN/`. The pipeline measures composition quality (notes/rhythm/harmony), NOT timbre — changing instruments requires ear-testing the WAV.
8. **17 SFX** (was 18 — pulse_charge deleted in v0.27 as dead code).

## Git Workflow

**Three branches:**
- **main** — Clean game code. Always runnable. No tools, no playtest driver, no risky changes.
- **tools-management** — Music CI pipeline (`tools/music/`), generated artifacts, PlaytestDriver autoload. No game file changes from main. For testing and music evaluation.
- **game-nightly** — Risky changes not yet ready for main. **NEVER merge game-nightly to main without explicit user confirmation.** Currently contains Claude's movement rewrite.

**Rules:**
- Commit with descriptive messages including version number (e.g. "v0.25: fix X")
- Push to the appropriate branch after each meaningful change
- Don't commit temp test files (TestRunner, SFXRenderer, timing_test) — remove before staging
- Don't commit .godot/ import changes unless intentional — `git checkout HEAD -- <file>` to restore
- **game-nightly → main requires user confirmation. No exceptions.**
