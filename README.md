# Dungeon Caretaker: A Ghost's Salvage

A top-down **pixel-art roguelike management sim** where you play a ghost bound to a cursed dungeon. Adventurers come to raid it. They die. You salvage their gear, repair it, upgrade it, and assign it to the next batch of doomed heroes. The weapons persist — their history IS your progress.

**Win:** Clear all 5 stages (3 waves each = 15 waves).
**Lose:** Total party collapse — no survivors left to recruit around.

## How to Run

1. Install **Godot 4.3 stable** (or newer) from https://godotengine.org/
2. Open the project folder in Godot
3. Press **F5** to play

No external assets required — all sprites are procedurally generated. The pixel font (Press Start 2P) is bundled. All SFX + music are procedurally synthesized at runtime (zero audio files).

**Note:** First launch takes ~9 seconds to render the procedural main theme. Subsequent launches load from disk cache instantly. Press **M** anytime to mute music.

## Reset Save Data

Delete the save file to reset meta-upgrades:
- **Linux:** `~/.local/share/godot/app_userdata/Dungeon Caretaker/save_v3.json`
- **Windows:** `%APPDATA%\Godot\app_userdata\Dungeon Caretaker\save_v3.json`
- **Mac:** `~/Library/Application Support/Godot/app_userdata/Dungeon Caretaker/save_v3.json`

Also delete the `.godot/` folder in the project directory if experiencing stale imports. Delete `music_cache.bin` (same folder as save) to force music re-render.

## Controls

| Action | Keys |
|---|---|
| Move ghost | WASD or Arrow keys |
| Interact | E |
| Phase (ghost incorporeal dash) | SPACE |
| Pulse (momentum burst, tap) | SHIFT |
| Mute music | M |
| Rack paging | [ and ] |
| Inspect carried weapon | TAB (in workshop) |
| Back to menu | ESC |

## The Movement System (WORK IN PROGRESS)

The ghost uses a **4-state movement machine** with compoundable momentum. **Note: this system is implemented but still being tuned — it has design tension between rewarding speed and requiring precision.**

- **FLOAT** — normal walking. Build momentum by moving fast.
- **PHASE** (SPACE) — incorporeal dash, 2x speed, costs 1 soul shard, bypasses fire/spikes. 4s cooldown (halved to 2s when chained from COAST).
- **DIVE** — momentum burst on phase cancel. Boost scales with remaining phase energy + current momentum. Chain degrades 10% per consecutive phase (min 50%).
- **COAST** — carrying converted momentum. Low deceleration.
- **PULSE** (SHIFT, tap) — instant 1.5x burst. Costs 0.3 momentum, adds 0.4 (net +0.1). Resets chain degradation.

**Momentum** (0-2.0) builds when moving fast, decays when slow, and modifies speed up to +50%. It's preserved across states — the skill is compounding it through the chain: phase → cancel → dive → coast → pulse (reset) → phase → ...

**Known issue:** The momentum system rewards staying fast, but the game's tasks (narrow corridors, small hazard hitboxes, timer) reward stopping precisely. Phase auto-fires DIVE on natural expiry, costing ~2.5s of reduced control after using your hazard tool. Needs playtest-driven tuning.

## Game Loop (Per Wave)

1. **Gate** — Walk past grave markers of the fallen. New run shows predecessors; later cycles show actual casualties.
2. **Salvage** — Top-down corridor. Collect gear from named corpses (your dead party's ACTUAL weapons). 4 QTE types (timing, spam, pattern, reverse). Ghost has 3 Spirit (HP). Phase through fire/spikes. Push-your-luck branching exists (main path + optional deeper section) but is not yet a real choice — the "crossroads" is just text, not a visual fork, and the deeper path is currently a no-brainer. Reach exit → workshop.
3. **Workshop** — Walk between 5 repair stations (Arsenal, Polish, Grind, Altar, Forge). Each minigame shows the weapon large. Graduated repair (no full-reset). TAB inspects weapon stats. Phase for 2x movement. Pulse for momentum burst. Ring bell → upgrade shop.
4. **Upgrade** — Buy meta-upgrades (currently a scroll list — planned V2: diegetic wall).
5. **Planning** — Walk to weapon rack, pick up gear, carry to adventurers to assign. Recruit at shrine. View map for wave intel. Phase for faster movement. Ring bell → battle.
6. **Battle** — Spectator auto-battler. Party auto-fights. Weapons visibly degrade. Phase to slow all enemies.
7. **Results** — Weapon dossiers (click for full history). Continue → aftermath.
8. **Aftermath** — Memorial beat showing the fallen. Continue → gate (next cycle).

## Weapon System

Weapons are the persistent investment — the "save file" of the game.

- **Wear state** (Pristine → Worn → Damaged → Broken): the single mechanical truth, driven by durability percentage. Determines which repair station accepts the weapon.
- **Unexorcised deaths**: weapons present for a death accumulate haunting (-6% per death, capped at -30%). Only the Altar clears this. Orthogonal to physical wear.
- **Authoring fingerprints** (sharpness/balance/power/mystic): set by repair minigame quality. Persist as a permanent multiplier. A well-repaired weapon is permanently better.
- **Kill log + history**: full narrative log of everything that happened to the weapon. Click any dossier in results to read the full story.
- **Legendary status**: at 8 kills, a weapon earns legendary status (+5% stat bonus, star marker).

## Difficulty

Stage 1 is genuinely hard. Starter weapons begin at 30% durability in bad states. An unarmed party does 4 damage per hit. Enemy HP starts at 100. You MUST repair before you can win. The loop is: die → salvage → repair → try again.

## Branches

- **main** — The game. Always runnable. Clean game code only — no testing tools.
- **debug** — Testing branch. Has everything main has PLUS: music CI pipeline (`tools/music/`), generated analysis artifacts (`generated/`), and PlaytestDriver autoload (`scripts/playtest_driver.gd`). For automated testing and music evaluation only.

## Tech

- **Engine:** Godot 4.3+ (GL Compatibility renderer)
- **Language:** GDScript
- **Resolution:** 480×270 internal, scales to 4K+
- **Art:** All sprites procedurally generated at 16×16 via `scripts/sprites.gd`
- **Font:** Press Start 2P (bundled), rendered at 8px or 16px only
- **Audio:** 17 procedural SFX via `scripts/autoload/sfx.gd` + procedural main theme via `scripts/autoload/music.gd` (zero audio files)
- **Palette:** 48 curated colors via `scripts/palette.gd`
- **Music:** D major, AABA form, 4 motifs, FM bell chords + triangle lead + sine bass + woodblock perc. Disk-cached. Music CI pipeline in `tools/music/` (analyzes quality scores, ALL TESTS must pass before export)

## Documentation

- **VERSION_LOG.md** — Running changelog (most current — always check this first)
- **MEMORY_CONTEXT.md** — Handoff doc for AI sessions (architecture, systems, gotchas)
- **DESIGN_PLAN.md** — V2 implementation plan (7 priorities, build status)
- **DESIGN_IDEAS.md** — Cut/half-built ideas backlog
