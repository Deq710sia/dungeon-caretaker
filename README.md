# Dungeon Caretaker: A Ghost's Salvage (V2)

A top-down pixel-art **roguelike management sim** where you play the spectral caretaker of a cursed dungeon. You don't fight — you salvage, repair, and deliver gear to waves of doomed adventurers. The dungeon is a top-down scroller; the camera follows the action.

## V2 Changes (Major Redesign)

V1 was all menus. V2 is a real game:

- **Top-down scroller** — camera follows the ghost through dungeon corridors
- **3 distinct phases per wave**, each visually unique:
  1. **Salvage Run** — walk through a dungeon corridor, collect gear from corpses, dodge pits/fire/spikes
  2. **Workshop** — top-down room with physical stations; repair minigames show the WEAPON as the centerpiece
  3. **Battle** — camera follows the party as they auto-fight through enemies toward the exit
- **Weapons are the stars** — every repair minigame draws the weapon large in the center, state-tinted (bloodied/rusted/haunted/cursed/shattered)
- **Durability system** — weapons degrade during battle; breakage drops the state
- **Stages + Waves** — 5 stages, 3 waves each. Party persists across waves; gear pool carries over.
- **Legible pixel font** — Press Start 2P embedded, used globally via Theme
- **Better sprites** — 32×32 base with detail (highlight, shadow, shading); 18+ sprite types
- **Animated** — bobbing characters, pulsing highlights, particle effects, floating damage numbers

## How to Run

1. Install **Godot 4.3 stable** (or newer) from https://godotengine.org/
2. Open the project folder in Godot
3. Press **F5** to play

No external assets required — all sprites are generated procedurally. The pixel font (Press Start 2P) is bundled.

## Controls

| Action | Keys |
|---|---|
| Move ghost | WASD or Arrow keys |
| Interact | E or Space |
| Minigames | Mouse |
| Ghost ability (battle) | 1 |
| Back to menu | ESC |

## Game Loop (Per Wave)

1. **Salvage Run** (top-down scroller):
   - Ghost spawns at the top of a dungeon corridor
   - Walk down, collecting gear from corpses (walk over them)
   - Dodge hazards: pits, fire, spikes (knockback + time penalty)
   - Reach the exit stairs before the 60s timer ends
2. **Workshop** (top-down room):
   - 5 stations in a row: Salvage Pit, Polish Bench, Oil & Grindstone, Exorcise Altar, Reforge Furnace
   - Adventurers wait at the bottom with patience bars and order tickets
   - Walk to salvage pit + E → pick up gear
   - Walk to matching station + E → repair minigame (weapon shown large)
   - Walk to adventurer + E → delivery gauntlet (Dumb Ways to Die QTE)
   - Ring the bell (or wait for timer) → battle
3. **Battle** (top-down scroller):
   - Camera follows the party as they walk through the dungeon
   - Party auto-fights enemies they encounter
   - Press 1 to Haunt enemies (slow them, 25s cooldown)
   - Reach the exit = win the wave
4. **Results** → **Upgrade Shop** → next wave (or next stage)

## Gear States & Repair Stations

| State | Effect | Repair Station | Minigame |
|---|---|---|---|
| Pristine | Full stats | — | None |
| Bloodied | -20% stats | Polish Bench | Drag-wipe blood off the weapon (coverage %) |
| Rusted | -30% stats | Oil & Grindstone | Hold to pour oil; keep meter in green band |
| Haunted | -10% + jitter | Exorcise Altar | Trace the sigil forward |
| Cursed | -40% + debuff | Exorcise Altar (same!) | Trace the sigil in REVERSE |
| Shattered | Useless | Reforge Furnace | 3-stage: Melt → Pour → Hammer |

Each minigame shows the **weapon large in the center of the screen**, state-tinted, so you see exactly what you're repairing.

## Durability System (V2)

Every weapon has durability (100 base, +25 per Sturdy Grip upgrade). Each battle hit costs 8 durability (weapons) or 5 (armor). When durability hits 0:
- Pristine → Bloodied
- Bloodied → Rusted
- Rusted → Shattered
- Haunted → Cursed
- Cursed → Shattered

This creates the core tension: a well-repaired weapon might survive multiple waves, but a neglected one will break mid-battle and need full reforge.

## Win Condition

Clear all **5 stages** (3 waves each = 15 waves total).

## Resolution

Built for any display, including 4K. Base viewport is 320×180, scaled with `viewport` stretch mode (pixel-perfect). Window can be resized freely.

## Art

- All sprites procedurally generated at runtime (`scripts/sprites.gd`)
- Pixel font: Press Start 2P (bundled in `assets/fonts/`)
- For V3: drop Kenney.nl CC0 pixel art packs into `assets/sprites/` and swap the `Sprites.get_sprite()` calls

## Save Data

Meta-upgrades persist between sessions, saved to `user://save_v2.json`.

## Tech

- **Engine:** Godot 4.3+ (GL Compatibility renderer)
- **Language:** GDScript
- **Resolution:** 320×180 base, scales to 4K+
- **Input:** Keyboard + Mouse

## License

Code: MIT. Press Start 2P font: OFL. Generated sprites: CC0.
