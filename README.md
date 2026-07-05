# Dungeon Caretaker: A Ghost's Salvage (V3)

A top-down pixel-art **roguelike management sim** where weapons are the persistent, named, degrading objects you invest in across waves. You don't fight — you salvage, repair, and assign weapons to doomed adventurers, then watch them auto-battle and witness your craft succeed or shatter.

## V3 — The Real Redesign

V1 was all menus. V2 was top-down but broken: text unreadable, no planning phase, QTE cutscenes replaced with physical dodging, weapons weren't central. V3 fixes all of this based on actual game design research (Jacksmith, Papa's Pizzeria, Hades, Slay the Spire, Dumb Ways to Die).

### What V3 does differently:

**1. Text is legible now** — Internal resolution raised to 640×360 (from 320×180). Press Start 2P font at 8-12px body, 16-24px headers. Verified 9/10 legibility via visual inspection.

**2. Real Planning phase** — Wave path map (showing node types + boss), battle intel (enemy types, count, HP/ATK estimates), weapon-to-adventurer assignment UI, irreversible commit. Based on Slay the Spire's asymmetric intel pattern.

**3. QTE cutscenes, not physical dodging** — The salvage phase auto-walks the ghost through the dungeon. At each hazard, a Dumb Ways to Die style QTE cutscene triggers: one verb, 3 beats, ~15s. Failure = lose a salvage (not run-ending).

**4. Weapons are characters** — Every weapon has:
- A unique name (procedurally generated)
- A day-stamp (when it was forged/found)
- A wielder binding (who it's assigned to)
- 4 discrete wear states with distinct art (Pristine → Worn → Damaged → Shattered)
- A kill log (enemies slain)
- Authoring fingerprints (sharpness/balance/power/mystic from crafting minigames)
- Retained as a broken memento when shattered (never deleted)

**5. Spectator battle with visible degradation** — The party auto-fights. You watch. Weapons visibly degrade during the fight (wear state changes, durability bar drops). When a weapon breaks, there's hit-stop + particle burst + log message. This is the "judgement phase" that reads your crafting.

**6. Weapon dossier cards** — After each battle, the results screen shows every weapon's dossier: name, wear state, day forged, kills, waves survived, wielder, authoring fingerprints. This is how you remember "the bad sword from wave 3."

## How to Run

1. Install **Godot 4.3 stable** (or newer) from https://godotengine.org/
2. Open the project folder in Godot
3. Press **F5** to play

## Controls

| Action | Keys |
|---|---|
| Move ghost | WASD or Arrow keys |
| Interact | E or Space |
| Minigames | Mouse click (or Space/E for QTEs) |
| Ghost ability (battle) | 1 |
| Back to menu | ESC |

## Game Loop (Per Wave)

1. **Planning** — See the wave path, battle intel, your arsenal. Assign weapons to adventurers. Commit.
2. **Salvage** — Auto-walk through dungeon. QTE cutscenes at hazards. Collect gear from corpses.
3. **Workshop** — Walk between 4 repair stations. Each minigame shows the weapon large. Repair restores durability and state.
4. **Battle** — Spectator phase. Party auto-fights. Weapons visibly degrade. Watch your craft succeed or shatter.
5. **Results** — Weapon dossier cards show what happened. Earn soul shards.
6. **Upgrade Shop** — Spend shards on permanent meta-upgrades.
7. Next wave (or next stage).

## Gear States & Repair Stations

| State | Effect | Repair Station | Minigame |
|---|---|---|---|
| Pristine | Full stats | — | None |
| Bloodied | -20% stats | Polish Bench | Drag-wipe blood off the weapon |
| Rusted | -30% stats | Oil & Grindstone | Hold to pour oil; keep meter in green |
| Haunted | -10% + jitter | Exorcise Altar | Trace the sigil forward |
| Cursed | -40% + debuff | Exorcise Altar (same!) | Trace the sigil in REVERSE |
| Shattered | Useless | Reforge Furnace | 3-stage: Melt → Pour → Hammer |

## Wear States (visible on weapon art)

| Wear | Durability % | Effect |
|---|---|---|
| Pristine | 75-100% | Full effectiveness |
| Worn | 40-75% | 85% effectiveness |
| Damaged | 0-40% | 60% effectiveness |
| Shattered | 0% | 0% — weapon breaks (hit-stop + particles) |

## Win Condition

Clear all **5 stages** (3 waves each = 15 waves total).

## Resolution

640×360 internal, scales to 4K+ via `canvas_items` stretch mode. Pixel-perfect.

## Art

- All sprites procedurally generated at runtime (`scripts/sprites.gd`)
- Pixel font: Press Start 2P (bundled in `assets/fonts/`)

## Save Data

Meta-upgrades persist between sessions, saved to `user://save_v3.json`.

## Tech

- **Engine:** Godot 4.3+ (GL Compatibility renderer)
- **Language:** GDScript
- **Resolution:** 640×360 base, scales to 4K+

## License

Code: MIT. Press Start 2P font: OFL. Generated sprites: CC0.
