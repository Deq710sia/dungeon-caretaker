# Dungeon Caretaker: A Ghost's Salvage

A top-down pixel-art **roguelike management sim** where you play the spectral caretaker of a cursed dungeon. Adventurers come, adventurers die — and they leave their gear behind. Each morning you salvage and revitalize the rusted, bloodied, cursed remains of yesterday's party, then physically run each piece to the next batch of doomed heroes before the dungeon bell tolls.

Inspired by **Papa's Pizzeria** (ticket queue + multitasking stations), **Jacksmith** (hands-on physical crafting minigames), **Dumb Ways to Die** (rapid QTE microgames), and **Hades** (meta-progression between runs).

## How to Run

1. Install **Godot 4.3 stable** (or newer) from https://godotengine.org/
2. Open the project: `godot --path /path/to/dungeon-caretaker`
3. Press **F5** (or click the ▶ button) to play.

No external assets required — all sprites are generated procedurally at runtime. The project is fully self-contained.

## Controls

| Action | Keys |
|---|---|
| Move ghost | WASD or Arrow keys |
| Interact / Pick up / Drop | E or Space |
| Click | Mouse (for minigames) |
| Ghost ability (battle) | 1 |
| Pause / back to menu | ESC |

## Game Loop (One Day)

1. **Dawn — Hub Scene:** You spawn as a ghost in a top-down room. The room contains:
   - **Salvage Pit** (top-left): a pile of yesterday's gear. Walk to it and press E to pick up the next piece.
   - **4 Repair Stations** (top row): Polish Bench, Oil & Grindstone, Exorcise Altar, Reforge Furnace. Walk to one while carrying gear and press E to start that station's minigame.
   - **Merc Post** (top-right): walk here + E to hire martyr adventurers (costs 60 shards).
   - **Adventurers** (bottom row): the new party, waiting with order tickets and patience timers.
2. **Repair Minigames:** Each station has a tactile minigame (drag-wipe, hold-to-pour, trace-sigil, multi-stage forge). Quality score 0-100%.
3. **Delivery Gauntlet:** Walk to an adventurer with gear + press E to trigger a *Dumb Ways to Die*-style QTE gauntlet (3-5 microgames, 3 integrity pips).
4. **Bell Timer:** Counts down in the HUD. When it hits zero (or you click "Ring Bell"), the party auto-descends to battle.
5. **Auto-Battle:** Top-down view. Party auto-fights. Press 1 to use your ghost Haunt ability (slows enemies).
6. **Results:** Survivors leave with their gear. The dead drop theirs back to the pit, worse for wear.
7. **Upgrade Shop:** Spend soul shards on permanent meta-upgrades.
8. **Sleep → Next Day:** Repeat for 30 days.

## Gear States & Repair Stations

| State | Effect | Repair Station | Minigame |
|---|---|---|---|
| Pristine | Full stats | — | None |
| Bloodied | -20% stats | Polish Bench | Drag-wipe to clean (coverage %) |
| Rusted | -30% stats | Oil & Grindstone | Hold to pour oil; keep meter in green band |
| Haunted | -10% + jitter | Exorcise Altar | Trace the sigil forward |
| Cursed | -40% + debuff | Exorcise Altar (same minigame!) | Trace the sigil in REVERSE |
| Shattered | Useless | Reforge Furnace | 3-stage: Melt → Pour → Hammer |

Haunted and Cursed share the **Exorcise Altar** — Cursed is the harder variant where you trace the sigil backwards (Simon-says twist). This is intentional design consolidation.

## Where Fresh Gear Comes From

When the salvage pit runs dry:

1. **Bare-Knuckle Run** (default): send the party in with nothing. They'll die fast but their corpses might drop gear.
2. **Hire Mercenary Martyrs** (60 shards, from Salvage Pit screen): summon a disposable merc party to die and leave gear.
3. **Grateful Survivor Gifts** (passive, from Day 2): survivors sometimes return bearing a pristine gift.
4. **Wandering Haunt-Merchant** (planned for V1.1).

## Win / Lose

- **WIN:** Reach Day 30 with at least one survivor at the end of the descent.
- **LOSE:** Party wipes on Day 30 with no survivors.
- Earlier wipes are recoverable — that's the roguelike loop.

## V1 Scope

- 2 adventurer classes (Knight, Mage)
- 4 gear types (Sword, Staff, Helm, Robe)
- 6 gear states (Pristine, Bloodied, Rusted, Haunted, Cursed, Shattered)
- 4 repair stations with distinct minigames (Exorcise covers 2 states)
- 6 delivery microgames (Tap-Rapid, Swipe-Direction, Timing-Tap, Trace-Sigil, Multi-Hold, Do-Nothing)
- 1 ghost support ability in battle (Haunt Enemy)
- 6 meta-upgrades (persist between runs)
- 3 enemy types (Slime, Skeleton, Bat)
- Day 30 win condition

## Resolution

Built for any display, including 4K. The base viewport is 320×180 (16:9 pixel-art friendly), rendered with `canvas_items` stretch mode + `expand` aspect + nearest-neighbor filtering. The window can be resized freely or maximized — Godot handles the scaling.

## Art

All sprites in V1 are **procedurally generated** at runtime via GDScript's `Image` API (see `scripts/sprites.gd`). This means:
- Zero external dependencies
- No asset licensing concerns
- Fully self-contained repo

### Drop-in Pixel Art for V1.1

For a more polished look, download these **CC0** packs from Kenney.nl and drop them into `assets/sprites/`:

- **Kenney "1-Bit Pack"** — https://kenney.nl/assets/1-bit-pack (monochrome tileset + characters)
- **Kenney "Tiny Dungeon"** — https://kenney.nl/assets/tiny-dungeon (16×16 dungeon tiles, perfect fit)
- **Kenney "Tiny Town"** — https://kenney.nl/assets/tiny-town (matching overworld tiles)
- **Kenney "Pixel Platformer"** — https://kenney.nl/assets/pixel-platformer (characters & items)

To integrate: replace the `Sprites.get_sprite(name)` calls in `scripts/sprites.gd` with `load("res://assets/sprites/<name>.png")`.

## Save Data

Meta-upgrades persist between sessions, saved to `user://save.json` (Godot's per-user data dir). Run state resets on each new run.

## Tech

- **Engine:** Godot 4.3+ (GL Compatibility renderer for max compatibility)
- **Language:** GDScript
- **Resolution:** 320×180 base, scales to 4K+
- **Input:** Keyboard + Mouse

## License

Code: MIT (see LICENSE). Generated sprites: CC0.
