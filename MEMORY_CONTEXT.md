# MEMORY CONTEXT — Dungeon Caretaker
## Complete project memory for handoff to a new chat session

This file contains everything a new AI session needs to understand the project's history, current state, design philosophy, and next steps. Read this before touching any code.

---

## 1. PROJECT IDENTITY

**Title:** Dungeon Caretaker: A Ghost's Salvage
**Engine:** Godot 4.3 stable, GDScript, GL Compatibility renderer
**Resolution:** 480×270 internal (scaled up, pixel-perfect via `viewport` stretch mode)
**Repo:** https://github.com/Deq710sia/dungeon-caretaker
**Branches:** `main` (the game), `debug-tools` (playtest harness only)

**One-line pitch:** You're a ghost bound to a dungeon. Adventurers come, die, and leave their gear. You salvage it, repair it, assign it to the next batch. The weapons persist — their history IS your progress.

---

## 2. DESIGN PHILOSOPHY (from 10+ iterations of conversation)

### The Core Fantasy
You don't fight. You don't play as an adventurer. You play as the **caretaker** — the one constant in a cycle of death and renewal. Your accumulated effort shows on the weapons that survive the people who carried them. A sword that's been through 6 waves and killed 20 enemies MEANS something. That's the emotional engine.

### The Two Loops (ecology/economy split)
- **Adventurer layer = ecology.** Adventurers are consumable. They die. That's expected, not failure. Recruiting replaces them. Only TOTAL COLLAPSE (no one left to recruit around) is the lose condition.
- **Weapon layer = economy.** Weapons only go up in value (through repair, kills, history). They're your real progression. A weapon is never deleted — even shattered ones are retained as mementos and can be reforged.

### Puzzle as Management (not puzzle vs. management)
The game borrows incremental-game reward curves to bridge roguelike unpredictability with management optimization. There's a guaranteed FLOOR (clear the wave — always solvable). Above that is an open-ended REWARD CURVE for exceeding expectations (more corpses, better repairs, perfect triage). The marginal cost of pushing further rises faster than the reward, so it's always a live decision, not a no-brainer.

### Friction Has a Destination (Satisfactory lesson)
Tedious early actions should pull the player toward the system that relieves them. Manual repair is deliberately somewhat tedious → unlock quick-repair (changes the decision, doesn't delete the task) → unlock system-changing upgrades (Cannibalize, Cold Oil) that change HOW you repair, not just how fast. The friction's job is to get spent once, on purpose, in exchange for a NEW decision-making layer — not to be skipped with an auto-button.

### Death is Expected, Not Failure
Tone should be professional, not mournful. The ghost is a caretaker running an operation, not a grieving friend. "Mira fell — as expected. The operation continues." Not "THE FALLEN...". Only total party collapse is presented as failure.

### The Phase Verb (Mina the Hollower / UFO 50 lesson)
The ghost should have ONE signature verb that touches every phase — a "phase" (go incorporeal). It's traversal in salvage, dodge/support in battle, speed in workshop/planning. One well-crafted toy, reused everywhere, instead of several thin single-purpose abilities. The verb and the character concept are the same fact: a ghost that goes incorporeal.

### Retro Aesthetic, Modern Craft (UFO 50 / Mina lesson)
Pick which old frictions to keep ON PURPOSE (weapon loss, checkpoint distance), not by default. Ship with accessibility options. Put real craft into the moment-to-moment verb layer — the walk cycle, the sound, the camera — not just the systems layer. Smallness is the feature: one well-made traversal verb, one legible hazard language, one coherent economy.

---

## 3. CURRENT CODE STATE (as of latest commit)

### Architecture
- `main.gd` — Phase manager. Swaps Node2D + set_script per phase. Has fade transitions (working — `_on_phase_changed` calls `_start_fade`, 0.15s fade-to-black, swap mid-fade, 0.15s fade back). ESC → menu. Calls `_on_phase_exit()` on old phase before freeing (prevents weapon loss).
- `GameState` (autoload) — Single source of truth: stage/wave, soul_shards, arsenal[], party[], meta_upgrades{}, run_log[], last_battle_result{}. Saves only meta_upgrades to `user://save_v3.json`.
- `Juice` (autoload) — Screen shake (trauma-based), hit-stop, particle system (pixel squares, directional, integer-snapped), ghost trail (4 fading afterimages at 0.07s intervals, denser + bluer when phasing).
- `SFX` (autoload) — 15 procedural SFX (blip, chime, thud, hit, shatter, coin, select, deny, bell, death, repair, recruit, footstep, phase_in, phase_out). Pre-rendered as AudioStreamWAV from raw PCM. 8-voice round-robin pool with pitch jitter. SFX + Music buses created at runtime.
- `Palette` — 48 curated colors. ALL colors in the game come from here.
- `Sprites` — All sprites procedurally generated at 16×16 via Image API. 30+ sprite types. `get_weapon_sprite(type, state)` returns state-tinted weapon art.
- `GameFont` — Press Start 2P helper. NEVER use default Godot font. Only crisp at 8px or 16px.
- `Weapon` (RefCounted class) — The emotional anchor. Has: type, display_name, day_forged, wielder, wear_state (PRISTINE/WORN/DAMAGED/BROKEN), durability, unexorcised_deaths, sharpness/balance/power/mystic (0-1 fingerprints), kill_log[], history[], is_legendary, is_broken, break_announced. Methods: stat_multiplier(), take_durability_damage(), apply_repair(), recalculate_wear(), can_repair_at(), exorcise(), record_kill(), get_full_history(), authoring_blurb().

### Phase Flow
`menu → gate → salvage → workshop → upgrade → planning → battle → results → aftermath → gate → ...`

### Key Systems (working)
- **Phase verb (V2):** SPACE in any walkable phase = go incorporeal for 1.5s, 4s cooldown, costs 1 soul shard. In salvage: 2x speed + bypass fire/spikes (NOT pits). In workshop/planning: 2x movement only (QoL). In battle: 2x slowdown of all enemies (replaces old '1'-key Haunt, was 20s cd / 4s dur). Ghost drawn semi-transparent while phasing, trail tints bluer and samples denser.
- **Movement feel (V2):** Tighter accel (220, was 300) and matched friction so the ghost stops on key release. Velocity-driven camera bob (3Hz idle -> 9Hz top speed). Ghost trail (4 fading afterimages). Footstep whoosh tied to velocity.
- **Salvage loop:** Dead party members' weapons go to `last_battle_result.fallen_gear`. Salvage reads this and spawns corpses carrying the ACTUAL weapons (preserving name, history, kill log, fingerprints). Bonus random corpses also spawn. Hazards trigger QTE on E press — touching hazards does NOT damage (fixed). Only QTE failure damages.
- **Graduated repair:** `repair_curve(quality)` is a logistic function. Single pass never fully restores. `apply_repair()` adds partial durability. `recalculate_wear()` syncs wear_state to durability_pct.
- **Weapon state model (v8):** `wear_state` is the single mechanical truth (gates repair stations). `State` enum (Bloodied/Rusted/Haunted/Cursed) is flavor-only. `unexorcised_deaths` is an orthogonal penalty (-6% per death, capped -30%, cleared at Altar). `can_repair_at(station_key)` is the single source of truth for what each station accepts: Polish=WORN, Grind=DAMAGED, Forge=BROKEN, Altar=any haunted weapon.
- **Persistent party:** Party persists across waves. Dead members stay dead. `spawn_party()` only spawns if no living members. `recruit_adventurer()` costs 40+stage*10 shards, requires a living vouch. Full wipe = lose.
- **Procedural SFX:** Zero audio files. All sounds synthesized at startup.
- **Ghost HP in salvage:** 5 HP (upgradeable via ghost_resilience). I-frames after damage. At 0 HP, forced exit to workshop.

### Known Bugs (as of latest commit)
- Solo survivor can never retreat (requires starting_party_count > 1)
- Duplicate name risk for recruits (`_random_name` can collide)
- `planning.gd` has dead code: map-view close via E (lines 139-141, unreachable)

### What's NOT Built Yet
- QTE variety in salvage (all same timing bar)
- Visible weapon transformation in polish/oil_grind/exorcise minigames (oil_grind now rotates + sparks, but no rust-flake fade or blood-wipe reveal)
- Live authoring feedback during minigames
- Quick-repair / triage system
- System-changing repair upgrades (Cannibalize, Cold Oil, etc.)
- Boss waves
- Ghost personality/dialogue
- Diegetic upgrade shop (currently a scroll list)
- Efficiency score / incremental reward curve
- Walk cycle animations
- Ambient music bed
- Push-your-luck salvage branching

---

## 4. KEY DESIGN RESEARCH (from conversation history)

### Jacksmith (Flipline)
- Weapon crafting is the PRIMARY causal link between player skill and battle outcome
- Weapons visibly degrade during spectator battle — you watch your craft succeed or fail
- Stat-as-fingerprint: each output stat traceable to a specific player physical action
- Named wielder binding: weapons are "Percy's sword," not "a sword"

### Papa's Pizzeria (Flipline)
- Active/passive step pairing creates multitasking (oven timer = passive, topping = active)
- Fully visible ticket queue — pressure from seeing the backlog, not hidden timers
- Graded scoring: failed ticket still yields partial credit

### Hades
- Multi-currency meta-progression: death advances ≥3 independent tracks
- Two-layer identity: permanent loadout + temporary build (boons)
- Story gated behind failure — death is the intended way to progress narrative

### Slay the Spire
- Planning = irreversible path selection on a visible graph
- Asymmetric intel: show node type + goal, hide content
- Small node vocabulary (≤6 types) so planning is reason-able in seconds

### Dumb Ways to Die
- One verb, one screen, one instruction per QTE (2.5-4s window)
- Window: 2.5-4s first time, 1.2-2s on repeat; floor 1s; total 3-7s
- Fail state = entertainment (comedy death), not punishment
- For management game: failure downgrades reward, doesn't end run

### Mina the Hollower
- One new verb (hollowing) that touches everything: traversal, dodge, puzzle-solving
- The verb and the character concept are the same fact
- Retro difficulty is chosen, not default — ships with accessibility modifiers

### UFO 50 (Derek Yu)
- Treat each game as a small, complete toy first — get core fun before connecting
- Regularly step back so ambition doesn't bury feel of any one part
- Mechanically simple but tuned obsessively at the feel level
- Smallness is the feature, not the compromise

### Camwing's Satisfactory Analysis
- Productivity illusion: visible output = brain reads as productive accomplishment
- Friction with a destination: manual crafting is annoying → motivates automation → automation creates NEW decisions (routing, ratios, priorities), doesn't delete the task
- Cascading complexity: solving one problem opens a new gameplay vector
- Reward curve transitions from basic tools to rule-breaking toys

### Sellers' Advanced Game Design
- Loop taxonomy: engines, economies, ecologies
- Ecology = balancing loop where parts are consumed but whole stays in equilibrium
- Logistic curves for difficulty scaling (slow start, steep middle, diminishing returns)
- "Parts should have one coherent state unless duality is doing real design work"

### Procedural Generation in Game Design (Short & Adams)
- Desktop Dungeons case study: solvability guarantee via placement heuristics, not formal proof
- Make bad rolls rare, not impossible — weighted placement, not a solver
- Don't chase infinite variety you don't need

---

## 5. DIFFICULTY/BALANCE NUMBERS (current)

### Party stats
- Knight: 100 HP, 4 base ATK (fists), 2 base DEF (clothes). Weapon adds 25*mult, armor adds 12*mult.
- Mage: 70 HP, 4 base ATK, 2 base DEF. Same weapon/armor formula.
- Party size: 2 + stage/2, capped at 4. Recruit cost: 40 + stage*10.

### Enemy stats
- HP: 100 + stage*20 + wave*10
- ATK: 20 + stage*5 + wave*3
- Count: 5 + stage + wave/2
- DEF: 4 (flat)

### Starter weapons
- All start at 30% durability (nearly broken)
- States: Rusted, Haunted, Rusted, Bloodied (flavor only)
- Authoring fingerprints: 0.2-0.3 (bad)
- No weapon starts Pristine

### Repair curve
- `repair_curve(quality)` = logistic(quality, midpoint=0.5, steepness=10) * 0.6
- If durability_pct < 0.15, restore *= 0.7 (harder to fix nearly-broken)
- Max restore per pass: ~60% of max durability

### Ghost HP
- 5 HP (base) + ghost_resilience upgrade level
- I-frames: 1 second after damage
- At 0 HP: forced exit to workshop

### Shard economy
- Start: 100 shards
- Win: 30 + stage*5 + wave*3 + survivors*25
- Lose: 10 + stage + dead_count*8
- Recruit: 40 + stage*10

---

## 6. PLAYTESTING METHODOLOGY

### How to playtest
1. Checkout debug-tools branch, get `scripts/playtest_driver.gd`
2. Add `PlaytestDriver` to autoloads in `project.godot`
3. Write commands to `user://playtest_commands.txt` (Linux: `~/.local/share/godot/app_userdata/Dungeon Caretaker/`)
4. Run with Xvfb: `Xvfb :42 -screen 0 960x540x24 && DISPLAY=:42 godot --path .`
5. Screenshots saved to `user://pt_NNN_label.png`
6. State log saved to `user://playtest_log.txt`

### Vision verification
- ALWAYS upscale screenshots 4x before sending to vision model (480×270 → 1920×1080, nearest-neighbor)
- Ask specific questions: "List every text element with position" not "is this clean?"
- Vision model CAN read Press Start 2P at 8px when upscaled — verified
- Vision model CANNOT reliably detect subtle overlaps at native resolution — must upscale

### Key playtest commands
- `start_game` — new run, go to gate
- `equip_all` — auto-equip party with best available weapons
- `set_phase <name>` — jump to any phase
- `kill_party` — test wipe/lose condition
- `win_battle` — set fake win result
- `move <dir> <sec>` — simulate movement
- `interact` — force-call interaction handler
- `screenshot <label>` — capture screenshot
- `log_state <context>` — write full game state to log

---

## 7. FILE MAP

```
dungeon_caretaker/
├── project.godot          — Godot config (480x270, viewport stretch, snap-to-pixel)
├── DESIGN_PLAN.md          — V2 implementation plan (7 priorities)
├── MEMORY_CONTEXT.md       — This file
├── DESIGN_IDEAS.md         — Cut/half-built ideas backlog
├── README.md               — Player-facing readme
├── assets/
│   ├── default_theme.tres  — Global theme (Press Start 2P)
│   └── fonts/press_start_2p.ttf
├── theme/pixel_theme.tres  — Project-wide pixel font theme
├── scenes/main.tscn        — Root scene (runs main.gd)
└── scripts/
    ├── autoload/
    │   ├── game_state.gd   — Run state, party, arsenal, upgrades, save/load
    │   └── sfx.gd          — Procedural SFX (12 sounds, zero audio files)
    ├── game_font.gd        — Press Start 2P helper (draw_string with outline)
    ├── juice.gd            — Screen shake, hit-stop, particles (autoload)
    ├── main.gd             — Phase manager (fade transitions, ESC handler)
    ├── palette.gd          — 48 curated colors
    ├── sprites.gd          — Procedural 16x16 pixel sprites (30+ types)
    ├── weapon.gd           — Weapon class (wear, durability, fingerprints, history)
    ├── phases/
    │   ├── main_menu.gd    — Title screen
    │   ├── gate.gd         — Walkable threshold with grave markers
    │   ├── salvage.gd      — Top-down corridor, corpses, QTE hazards, ghost HP
    │   ├── workshop.gd     — Walkable room, 5 repair stations, bell timer, TAB inspect
    │   ├── upgrade_shop.gd — Scrollable upgrade list (TO BE REPLACED with diegetic wall)
    │   ├── planning.gd     — Walkable room, weapon rack, recruit shrine, map table, bell
    │   ├── battle.gd       — Spectator auto-battler, weapon degradation, ghost ability
    │   ├── results.gd      — Weapon dossiers (clickable for full history), continue
    │   ├── aftermath.gd    — Memorial beat showing fallen
    │   └── win_lose.gd     — Run end screen with chronicle
    └── repair/
        ├── polish_bench.gd     — Drag-wipe minigame (BLOODIED → needs visible transform)
        ├── oil_grindstone.gd   — Hold-to-pour minigame (needs weapon rotation)
        ├── exorcise_altar.gd   — Trace-sigil minigame (needs visible wisp fade)
        └── reforge_furnace.gd  — 3-stage melt/pour/hammer (ALREADY transforms weapon)
```

---

## 8. GOTCHAS AND LESSONS LEARNED

1. **Press Start 2P is only crisp at 8px or 16px.** Any other size gets blurry. Never use font_size 5/6/7.
2. **Xvfb screenshots render differently from the actual game window.** Always verify with the user's screenshots, not just Xvfb captures. Upscale 4x before vision-checking.
3. **Camera2D smoothing + non-integer positions = jitter.** Snap camera to integers. Run camera in `_physics_process`. Use `1 - exp(-dt * k)` for frame-rate-independent lerp.
4. **`Input.action_press()` doesn't trigger Button signals.** Use `InputEventKey` with `KEY_SPACE` (triggers `ui_accept`) for Buttons, or use mouse clicks.
5. **ESC frees the phase node immediately.** Any carried weapon is lost unless `_on_phase_exit()` returns it to arsenal first.
6. **Graduated repair means weapons land in intermediate wear tiers.** The player must be able to put a weapon down (return to arsenal) after repair — `ghost.carrying` must be cleared.
7. **The state/wear_state dual model was the #1 bug.** v8 collapsed it: wear_state is mechanical truth, State is flavor-only. Never gate anything on State.
8. **`recalculate_wear()` must be called after ANY durability change** (damage OR repair) or wear_state desyncs from durability_pct.
9. **Salvage hazards used to damage on touch** — leftover from physical-dodge design. Fixed: only QTE failure damages.
10. **Rack paging was broken** — `rack_page` was never incremented. Fixed: `[` and `]` keys cycle pages. Don't use Q/E (conflicts with interact).
11. **The `.godot/` folder caches stale imports.** Delete it if experiencing rendering issues after pulling updates.
12. **Font import needs two passes** in headless mode — first pass imports the font, second pass loads the theme that references it.
13. **All draw positions must be integer-snapped** (`int(x)`) or sprites jitter at 480×270.
14. **Overscan: draw 3 tiles beyond viewport on all sides** so scroll edges are never visible.
15. **The theme/pixel_theme.tres import is fragile** — the `.import` file must exist or the font won't load. Delete `.godot/` and reimport if the theme fails to load.
