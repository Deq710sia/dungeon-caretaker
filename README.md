# Dungeon Caretaker: A Ghost's Salvage

A top-down **pixel-art roguelike management sim** where you play a ghost bound to a cursed dungeon. Adventurers come to raid it. They die. You salvage their gear, repair it, upgrade it, and assign it to the next batch of doomed heroes. The weapons persist — their history IS your progress.

**Win:** Clear all 5 stages (3 waves each = 15 waves).
**Lose:** Total party collapse — no survivors left to recruit around.

## How to Run

1. Install **Godot 4.3 stable** (or newer) from https://godotengine.org/
2. Open the project folder in Godot
3. Press **F5** to play

No external assets required — all sprites are procedurally generated. The pixel font (Press Start 2P) is bundled. All SFX are procedurally synthesized at runtime (zero audio files).

## Reset Save Data

Delete the save file to reset meta-upgrades:
- **Linux:** `~/.local/share/godot/app_userdata/Dungeon Caretaker/save_v3.json`
- **Windows:** `%APPDATA%\Godot\app_userdata\Dungeon Caretaker\save_v3.json`
- **Mac:** `~/Library/Application Support/Godot/app_userdata/Dungeon Caretaker/save_v3.json`

Also delete the `.godot/` folder in the project directory if experiencing stale imports.

## Controls

| Action | Keys |
|---|---|
| Move ghost | WASD or Arrow keys |
| Interact | E |
| Phase (ghost incorporeal) | SPACE |
| Rack paging | [ and ] |
| Inspect carried weapon | TAB (in workshop) |
| Back to menu | ESC |

## Game Loop (Per Wave)

1. **Gate** — Walk past grave markers of the fallen. New run shows predecessors; later cycles show actual casualties.
2. **Salvage** — Top-down corridor. Collect gear from named corpses (your dead party's ACTUAL weapons). Hazards trigger QTE minigames. Ghost has 5 HP. Phase through fire/spikes to grab corpses faster. Reach exit → workshop.
3. **Workshop** — Walk between 5 repair stations (Arsenal, Polish, Grind, Altar, Forge). Each minigame shows the weapon large. Graduated repair (no full-reset). TAB inspects weapon stats. Phase for 2x movement between stations. Ring bell → upgrade shop.
4. **Upgrade** — Buy meta-upgrades and system-changing repair upgrades (planned V2: diegetic wall).
5. **Planning** — Walk to weapon rack, pick up gear, carry to adventurers to assign. Recruit at shrine. View map for wave intel. Phase for faster movement. Ring bell → battle.
6. **Battle** — Spectator auto-battler. Party auto-fights. Weapons visibly degrade. Phase to slow all enemies.
7. **Results** — Weapon dossiers (click for full history). Efficiency score (planned V2). Continue → aftermath.
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

- **main** — The game. Always runnable.
- **debug-tools** — Playtest harness (PlaytestDriver autoload). For automated testing only.

## Tech

- **Engine:** Godot 4.3+ (GL Compatibility renderer)
- **Language:** GDScript
- **Resolution:** 480×270 internal, scales to 4K+
- **Art:** All sprites procedurally generated at 16×16 via `scripts/sprites.gd`
- **Font:** Press Start 2P (bundled), rendered at 8px or 16px only
- **Audio:** 15 procedural SFX via `scripts/autoload/sfx.gd` (zero audio files)
- **Palette:** 48 curated colors via `scripts/palette.gd`
