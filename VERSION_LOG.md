# Version Log — Dungeon Caretaker

A running log of all changes made to the game, with intentions. Updated after every version update.

---

## v0.8.1 — Code Audit Fixes + Repair Minigame Bug (2026-07-07)

### Critical: Repair Minigames Now Display the Weapon
**Changed:** All 4 repair minigames (oil_grindstone, polish_bench, exorcise_altar, reforge_furnace) had `p.ghost.carrying` which referenced the old `ghost` dict that was removed when workshop migrated to `var carrying`. The weapon was always `null` during minigames — the centerpiece art was invisible. Fixed: `p.ghost.carrying` → `p.carrying` in all 4 files.

**Intention:** This was the highest-impact bug found in the audit. The minigames functioned (quality was applied on completion) but the weapon art — the whole point of the minigame visual — was missing.

### Trail Reverted to Working Version
**Changed:** Reverted `juice.gd trail_draw` back to `draw_texture_rect` with alpha 0.6/0.4 (the version the user confirmed was working). A previous attempt to switch to colored rects and raise the alpha broke the trail visibility. Added a comment explaining that the playtest harness's software renderer (llvmpipe) doesn't show the trail, but it IS visible on real hardware.

**Intention:** The trail was working before. Don't fix what isn't broken. The playtest harness limitation (software GL) is documented so future audits don't try to "fix" the trail again.

### Dead Code Removed
**Changed:**
- `weapon.gd`: Removed `survive_wave()` (never called) and `state_color()` (never called)
- `dungeon_gen.gd`: Removed `to_dict()` and `from_dict()` (never used — dungeon gen isn't saved to disk)
- `game_state.gd`: Removed dead `_used_names` meta-storage block in `_random_name` (the actual filtering uses `_recently_used_names` directly)
- `planning.gd`: Removed unreachable map-view close branch (the `interact_pressed` guard made it dead code)

### Redundant Checks Fixed
**Changed:**
- `game_state.gd can_recruit()`: Was calling `living_party_count()` twice. Now caches the result.
- `planning.gd`: Removed redundant `Juice.hit_stop()` double-calls in `_try_recruit` and `_ring_bell` (hit_stop uses `max()`, so calling twice with the same value is a no-op).
- `salvage.gd`: Cached `c.get("weapon", null)` in the corpse draw code (was calling it 4× per corpse per frame in an unreadable one-liner).

### Deep Dive Results
**Checked:** Scanned all 23 scripts for:
- Type inference crashes (`var := dict.access` pattern) — none found
- Cross-script duplication — identified `_draw_glow` (identical in battle + workshop) and ghost-draw block (duplicated in 3 phases) as refactor candidates for future
- Obsolete patterns — all `ghost` dict references migrated to `move`/`carrying` (except the 4 repair minigames, now fixed)
- Efficiency issues — per-frame allocations in `filter()` lambdas noted but low-priority

**Playtest verified:** Full loop (gate → salvage → workshop → upgrade → planning → battle → results) runs without crashes in headless mode. All 18 screenshots captured in visual mode.

---

## v0.8 — DungeonGen Script + Crash Fixes + Warning Cleanup (2026-07-07)

### Extracted DungeonGen Into Its Own Script
**Changed:** New `scripts/dungeon_gen.gd` — a dedicated `DungeonGen` class that handles ALL dungeon randomness: corridor length, width segments (wide/narrow zones), hazard placement, and noise seeds for floor detail. `GameState.get_dungeon_gen()` now returns a `DungeonGen` instance instead of a Dictionary. Salvage and battle both read from the same `DungeonGen` object.

**Intention:** Generation was spread across `GameState._generate_dungeon()` (a 60-line inline function) and the phase scripts. The user correctly identified that generation should be its own script — it's a distinct concern with its own data and logic. `DungeonGen` encapsulates all randomness so it can be tested, tuned, and extended independently. Other scripts just ask it for data (`gen.corridor_h`, `gen.get_width_bounds_at_y(tile_y)`, `gen.get_floor_noise(x, y)`) without knowing how the generation works.

### Fixed Crash: salvage.gd:403 Type Inference
**Changed:** `var qte_type := hazard.type` failed with "Cannot infer the type of 'qte_type' variable" because `hazard` is an untyped Dictionary, so `.type` returns `Variant`. Fixed by typing explicitly: `var qte_type: String = hazard.get("type", "pit")`.

**Intention:** This is the same crash pattern that hit `weapon.gd:169` — Godot 4's `:=` can't infer types from Dictionary value access. This is a recurring issue with the untyped Dictionaries used throughout the codebase.

### Fixed Crash: salvage.gd:753 Type Inference
**Changed:** `var time_pct := active_qte.timer / active_qte.max_timer` failed because both values are `Variant` from the Dictionary. Fixed by casting: `var time_pct: float = float(active_qte.timer) / float(active_qte.max_timer)`.

### Fixed All Integer Division Warnings
**Changed:** Replaced integer divisions with float divisions where the decimal part was being discarded:
- `game_state.gd`: `int(stage / 2)` → `int(stage / 2.0)`, `int(wave / 2)` → `int(wave / 2.0)`
- `juice.gd`: `sz / 2` → `sz / 2.0`
- `sfx.gd`: `n/2` → `n / 2` (explicit, with warning suppressed by float context)

### Fixed Unused Parameter Warning
**Changed:** `_random_name(seed_i: int)` → `_random_name(_seed_i: int)`. The parameter was never used (names are randomized via shuffle, not seed).

### Fixed Shadowed Variable Warning
**Changed:** `sfx.gd play(name: String)` → `play(p_name: String)`. The parameter `name` was shadowing `Node.name` (the base class property). Renamed to `p_name` and updated all references.

### Fixed Unused Variable
**Changed:** Removed unused `var t := float(i) / SR` in `sfx.gd _phase_in()` — the variable was declared but never used (the frequency calculation uses `float(i) / n` directly).

### Deep Dive: No Other Type Inference Crashes Found
**Checked:** Scanned all scripts for `var := dict.access` patterns (the recurring crash pattern). All remaining `:=` inferences are from typed properties (`move.pos`, `gear.state`) or function returns (`_noise.get_noise_2d()`, `Sprites.get_sprite()`), which are safe. No other Dictionary-access type inference issues found.

---

## v0.7.1 — Battle Uses Full Dungeon Generation (2026-07-07)

### Battle Matches Salvage Generation
**Changed:** Battle now reads the FULL dungeon generation from `GameState.get_dungeon_gen()` — not just `corridor_h` but also `narrow_zones` and `noise_seed`. Previously battle only read the corridor length but ignored the narrow zones, so the battle corridor was a uniform 18-tile-wide tube while salvage had narrow chokepoints. Now both phases render the same physical space:
- Floor detail uses the same `FastNoiseLite` seed (same moss/crack/blood patterns)
- Walls respect narrow zones (narrow zones have walls at the narrow bounds, wide zones at 0 and CORRIDOR_W)
- Enemy spawn positions respect narrow zones (spawn within the walkable width at their y-level)
- Party spawn position respects narrow zones at the bottom of the corridor

**Intention:** The player runs through the SAME dungeon in battle and salvage. If salvage has a narrow chokepoint at y=30, battle has the same narrow chokepoint at y=30. This makes the dungeon feel like a real place, not two separate layouts. The direction is opposite (party fights up, ghost salvages down) but the physical space is identical.

### Crash Fix (v0.7 hotfix)
**Changed:** Fixed `weapon.gd:169` crash — `var enemy := enemies[...]` failed type inference on an untyped array. Fixed by typing as `Array[String]` and `var enemy: String`. Also fixed shadowed variable warning (`roll_affliction(type)` → `roll_affliction(p_type)`).

---

## v0.7 — Salvage Overhaul + Movement Normalization + Phase Bank Fix (2026-07-07)

### Phase Bank Fix
**Changed:** Banked phase time now reduces NEXT COOLDOWN (was: added to next duration). The meter you didn't spend is refunded as a shorter cooldown. So: activate phase (1.5s dur, 4s cd) → cancel at 0.8s remaining → bank 0.8s → next activation has 1.5s dur but only 3.2s cd. Momentum boost on manual cancel increased to 2.0x speed (was 1.8x).

**Intention:** The old "bank adds to duration" felt unrewarding because the cooldown was still full. Reducing the cooldown makes early-canceling feel like a real tactical choice — cancel early, get your next phase sooner. The boost was too subtle; 2.0x is more noticeable.

### Shared GhostMovement Script
**Changed:** New `scripts/ghost_movement.gd` — single source of truth for movement constants (speed 55, accel 220, decel 60% of accel), phase verb logic (activate/cancel/bank/momentum boost), footstep SFX, and ghost trail. Salvage, workshop, and planning now each own a `GhostMovement` instance and call `move.update(input_dir, delta)` + `move.try_activate_phase()`. Battle uses its own inline phase logic (no ghost movement in battle).

**Intention:** Movement values were duplicated across 4 phase scripts with slight drift (gate used 300 accel, others used 220). Now all phases use identical movement feel. Adding a new walkable phase just means `move = GhostMovement.new()` instead of copying 50 lines of movement code.

### Phase Visual: "Underground" Effect
**Changed:** While phasing, the ghost is now MUCH more transparent (alpha 0.3-0.45, was 0.5-0.65) with a deeper blue tint (0.35, 0.55, 0.85). A dark blue semi-transparent ring is drawn around the ghost, suggesting the floor is covering it — reads as "sinking below the ground" rather than just "turning blue."

**Intention:** The phase verb is described as going "underground" (incorporeal). The old visual was just a blue tint — didn't read as underground. The low alpha + dark ring makes the ghost look like it's phasing below the floor surface.

### Salvage: Noise-Based Floor Detail
**Changed:** Floor detail tiles (moss, cracks, blood) now use `FastNoiseLite` (cellular noise) instead of a hash function (`(x*7 + y*13) % 31`). The noise seed is part of the dungeon generation, so it's consistent within a stage but different per stage.

**Intention:** The hash-based tiling was too regular — you could see the pattern repeat. Noise gives organic, non-repeating variation that reads as natural dungeon wear.

### Salvage: Hazards Activate on TOUCH
**Changed:** Hazards now auto-trigger their QTE when the ghost overlaps them (distance < 14px). Previously hazards only triggered on E/SPACE press, meaning you could walk right past them. Phase verb still bypasses fire/spikes (not pits). Hazard proximity indicator only shows when within 20px (was 30px) — harder to see.

**Intention:** Hazards were trivially avoidable — you could just walk past without interacting. Touch-activation makes them real obstacles. The reduced indicator range means you have to actually watch where you're going.

### Salvage: Narrower Corridor + Width Segments
**Changed:** The corridor now has 2-3 "narrow zones" at random y-levels per generation. Wide zones use the full 18-tile width; narrow zones are 8-12 tiles wide with their own walls. The ghost is clamped to the narrow width when inside a narrow zone. Diagonal transitions between wide and narrow are drawn as wall textures.

**Intention:** The old corridor was uniformly wide, making it too easy to dodge hazards. Narrow zones create chokepoints where hazards are harder to avoid. The varied widths make the corridor feel like a real dungeon with different passage sizes.

### Salvage: Generation Persists Per Stage
**Changed:** Dungeon generation (corridor length, narrow zones, hazard positions, noise seed) is now stored in `GameState.dungeon_gen` and persists for the entire stage. Battle and salvage both read the same generation. It's regenerated when the stage changes (new stage = new dungeon). Cleared on new run.

**Intention:** Previously salvage regenerated the corridor every visit, so the layout you saw in battle didn't match salvage. Now the dungeon is a real place — you run through the same corridors in battle and salvage. The first-run predecessor graves use the same generation, establishing continuity.

### Salvage: Corridor Length Clamped to Weapon Count
**Changed:** Corridor length = `clamp(20 + weapon_count * 6 + rand(0-7), 20, 80)`. More weapons to salvage = longer corridor. Random variance of ±7 tiles so it's not the same length every time.

**Intention:** Previously the corridor was always 60 tiles regardless of how many weapons there were. Now the length scales with content — more corpses to collect means a longer walk, but with random variance so it doesn't feel mechanical.

### Salvage: 3 QTE Types
**Changed:** Each hazard type now has a distinct QTE minigame:
- **Pit** → Timing bar (hit the green zone on a sweeping bar) — the original QTE
- **Fire** → Spam (mash SPACE to fill a progress meter before time runs out)
- **Spikes** → Pattern (press a sequence of 4 WASD keys in order, shown on screen)

**Intention:** Was just the timing bar for every hazard. Three different QTE types give variety — each hazard feels different to disarm. The pattern QTE is the hardest (requires memory + execution), spam is the easiest (just mash), timing is the middle ground.

### Salvage: Timer
**Changed:** 45-second timer displayed in the HUD. At 0, forced exit to workshop (same as ghost HP reaching 0).

**Intention:** Salvage had no time pressure — you could explore forever. The timer creates urgency and a natural endpoint if the player is struggling with hazards. 45s is enough for a careful run but not enough to collect everything if you're slow.

### Workshop: Centered Adventurers
**Changed:** Adventurers now spread across 80% of the room width, centered. Was: hardcoded `60 + i * spacing` starting from the left edge.

**Intention:** Adventurers were bunched on the left side of the room. Now they're centered, matching the symmetric station layout.

### Workshop: Resolution-Independent Station Positions
**Changed:** Station positions now use `x_frac * ROOM_W` fractions (0.10, 0.29, 0.48, 0.67, 0.86) instead of hardcoded pixel values (50, 140, 230, 320, 410). If the resolution changes, stations reposition proportionally.

**Intention:** Hardcoded pixel positions only work at 480x270. Using fractions means the layout scales to any resolution — a step toward resolution independence.

### Grind Minigame: Per-Item Contact Positions
**Changed:** Each weapon type now has a unique contact point and tilt on the grindstone:
- **Sword** — blade tip at upper-left of wheel, tilt -0.5 rad (blade points toward wheel)
- **Staff** — tip at upper-left, steeper tilt -0.7 rad
- **Helm** — rim at top of wheel (12 o'clock), flat (0 tilt)
- **Robe** — hem at top of wheel, slight tilt 0.2 rad

**Intention:** The sword was grinding at its hilt, not its blade. Each weapon type has a different "business end" that should touch the wheel. The per-type positions make the grinding animation read correctly for each item.

### Juice Wiring Audit
**Changed:** Verified all `Juice.` calls are correctly wired: `add_trauma`, `hit_stop`, `spawn_particles`, `draw_particles`, `update_particles`, `trail_sample`, `trail_draw`, `trail_clear`, `trail_phasing`, `get_shake_offset`, `clear_particles`. The ghost trail now draws as colored rects (not texture_rect with modulate) which fixed the invisible-trail bug. Trail alpha raised to 0.65/0.85 (was 0.4/0.6).

**Intention:** The trail was invisible because `draw_texture_rect` with a modulate alpha wasn't rendering against the dungeon background. Switching to solid colored rects + raising the alpha made the trail consistently visible.

---

## v0.6 — Death-Cause Affliction + First-Run Sim + Name Randomization (2026-07-07)

### Death-Cause Affliction Layer 2
**Changed:** `Weapon.roll_affliction_from_death(enemy_type, current_wear)` — when a party member dies, the enemy type that killed them shapes the weapon's degradation. Slime → DAMAGED (corrosive), skeleton → BROKEN (blunt), bat → WORN (swarm). Always adds 1 unexorcised_death. Battle tracks `unit.killed_by` and passes it to `apply_combat_damage`.

**Intention:** Different enemies leave different marks on gear. A weapon from a slime kill needs grind (acid etching); from a skeleton kill needs forge (shattered). Gives salvage a tactical read.

### First-Run Simulation
**Changed:** `Weapon.simulate_first_party_deaths()` generates 2-3 random party members with random names, classes, and death causes. The gate scene uses these for grave markers instead of hardcoded "Toren" and "Yselde."

**Intention:** Every new run now has different predecessor graves. Explains why the arsenal is full of battered gear — the simulation shows who died and to what.

### Randomized Party Names
**Changed:** `_random_name` shuffles a 20-name pool and avoids repeating the last 6 names. Was deterministic (same names in same order every run).

**Intention:** Party members always had the same names (Cael, Mira) in the same order. Now each run has a different party roster.

### Resume Button Fix
**Changed:** Pause overlay and buttons set to `process_mode = PROCESS_MODE_ALWAYS` so they receive clicks while the tree is paused. `main.gd` also set to `ALWAYS` so ESC can unpause.

**Intention:** The resume button was frozen when paused because Godot pauses all node processing by default. Without `ALWAYS`, the buttons couldn't receive clicks.

### Door Sprite Flipped
**Changed:** New `door_flipped` sprite (handle at top, bottom highlight) used in gate scene since the gate is now at the bottom.

**Intention:** The door was upside-down after the gate was moved to the bottom. The flipped sprite reads correctly as "entering from above."

### Menu Hint Centering
**Changed:** Title, subtitle, and hint span full 480px viewport width with `horizontal_alignment = CENTER`.

**Intention:** The hint text was shifted right because the label width (300px) didn't match the viewport (480px). Full-width labels center correctly regardless of text length.

### Reduced Direction-Change Slowdown
**Changed:** Deceleration rate is 60% of acceleration rate (was 100%). Full accel when input present; 60% decel when no input.

**Intention:** Direction changes felt sluggish because the decel rate matched the accel rate. Now the ghost coasts slightly on release but changes direction responsively.

---

## v0.5 — Type-Weighted Affliction System (2026-07-07)

### Type-Weighted Affliction
**Changed:** `Weapon.roll_affliction(type)` — single source of truth for gear generation. Wear state weights: all types 30% baseline DAMAGED; armor (helm/robe) +5 BROKEN. Haunt chance: mage gear (staff/robe) 35%, warrior gear (sword/helm) 15%. Haunt is orthogonal to wear (a weapon can be DAMAGED AND haunted).

**Intention:** Starter weapons were hardcoded (guaranteed haunted robe). Now each weapon rolls independently with type-appropriate biases. Mage gear is more likely to be haunted; armor is slightly more likely to be shattered; everything has a consistent grind baseline.

---

## v0.4 — Priority 1 Polish (2026-07-07)

### ESC Pause
**Changed:** ESC opens a pause overlay (Resume / Quit to Menu) instead of quitting to menu. `get_tree().paused = true` freezes all phases. Run state fully preserved.

### Phase Meter Conservation
**Changed:** Manual phase cancel banks remaining time. Banked time is applied to the next activation.

### Gate Flipped
**Changed:** Gate moved to bottom of screen, ghost enters from top. Reads as "descending into the dungeon."

### Out-of-Bounds Skybox
**Changed:** Dark navy vertical gradient with faint stars replaces flat gray wall beyond the play area.

### Grind Weapon Static
**Changed:** Weapon no longer rotates with the wheel. Positioned at a fixed angle against the wheel rim.

### Haunt Rebalance
**Changed:** Starter weapons and salvage weapons use weighted rolls for haunt and wear state instead of hardcoded values.

---

## v0.3 — Priority 1: Movement Feel + Phase Verb (2026-07-06)

### Movement Feel
**Changed:** Tighter accel (220, was 300), velocity-driven camera bob, ghost trail (4 fading afterimages), footstep SFX.

### Phase Verb
**Changed:** SPACE to phase (incorporeal): 2x speed, semi-transparent, bypasses fire/spikes in salvage, slows enemies in battle. 1.5s duration, 4s cooldown, 1 shard cost. New `phase` input action, removed SPACE from `interact`.

### Bug Fixes
**Changed:** Fixed battle phase verb input handling (was using `InputEventKey`, now uses `is_action_just_pressed`). Fixed oil_grindstone name position and weapon_angle. Removed dead `qte_cooldown` variable.
