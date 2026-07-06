# Dungeon Caretaker: A Ghost's Salvage (V5)

A top-down **pixel-art roguelike management sim** where weapons are the persistent, named, degrading objects you invest in across waves. You don't fight — you salvage, repair, and assign weapons to doomed adventurers, then watch them auto-battle and witness your craft succeed or shatter.

## V5 — Polish, Persistent Party, Chronicle

V4 fixed the pixel art, agency, and juice. V5 fixes the gameplay loop: **the party now persists across waves** (dead members stay dead), there's a **real lose condition** (full party wipe ends the run), a **recruiting shrine** in the planning room to replace the fallen, **clickable weapon dossiers** that show full narrative history, a **run chronicle** on the win/lose screen, and **legendary weapons** that earn an epithet after 8 kills. Plus dead-code cleanup and rebalanced reforge minigame.

### What V5 adds:

**1. Persistent party + lose condition** — The party no longer respawns fresh each wave. Dead adventurers stay dead. If the whole party wipes, the run ends ("THE DUNGEON WINS..."). This gives real stakes to combat — you can't just throw bodies at the dungeon.

**2. Recruiting shrine** — In the planning room, walk to the shrine (top-right) to recruit a new adventurer for shards (cost scales with stage). Requires at least one living member to "vouch" — a wiped party can't recruit, which is the lose condition.

**3. Clickable weapon dossiers** — The results screen now shows weapon dossier cards as clickable buttons. Click any weapon to see its full narrative history: dossier text, authoring blurb ("razor-sharp, perfectly balanced"), kill log, and chronicle (every event ever logged). This is where all the flavor text that was being written but never shown finally gets read.

**4. Run chronicle** — The win/lose screen now shows the full `run_log` as a scrollable chronicle. Every wave result, every recruit, every stage clear — the story of your run, finally visible.

**5. Legendary weapons** — Weapons that reach 8 kills earn "legendary" status (marked with ★), get a +5% stat bonus, and a history entry: "has drunk enough blood to earn a legend."

**6. Weapon.deliver_to()** — Assignment logic is now encapsulated in the Weapon class (was inline in planning.gd with a bug-prone key typo). Unequips from previous wielder automatically.

**7. Juice cleanup on phase transitions** — `main.gd` now clears Juice particles/trauma/shake when switching phases, so effects don't bleed between phases.

**8. Reforge furnace rebalanced** — Hammer stage had 40 cells but only 12 swings (capped at 30% max). Now has 24 swings so a skilled player can reach 100%.

**9. Dead code removed** — `qte_cutscene.gd` (unreferenced V3 leftover) deleted. Dead `current_gear_for_minigame` branches removed from 3 repair minigames. `break_announced` moved from a history-array hack to a proper boolean field. Palette/Weapon color duplication resolved (Weapon now references Palette directly).

**10. DESIGN_IDEAS.md** — Preserved 6 unimplemented-but-good ideas (boss waves, haunted/cursed combat behavior, individual fallen memorials, wielder-history bonuses, live authoring feedback, cinematic QTE cutscenes for boss waves) so they don't get lost.

### Carried over from V4:

- **Real pixel art** — 320×180, `viewport` stretch, 32-color palette, 16×16 sprites, snap-to-pixel
- **Diegetic planning** — walk to map table / weapon rack / adventurers / bell
- **Salvage with full agency** — WASD movement, named corpses, diegetic QTE bars
- **Juice system** — screen shake, hit-stop, directional particles, squash/stretch
- **Weapons as characters** — named, day-stamped, 4 wear states, kill log, authoring fingerprints
- **Spectator battle** — party auto-fights, weapons visibly degrade, break = hit-stop + particles

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
| Minigames | Mouse click (or Space/E for QTEs) |
| Ghost ability (battle) | 1 |
| Back to menu | ESC |

## Game Loop (Per Wave)

1. **Planning** (diegetic room) — Walk to map table → view wave path & intel. Walk to weapon rack → pick up weapon. Walk to adventurers → assign. Walk to bell → ring it, begin wave.
2. **Salvage** (top-down, full agency) — WASD movement through dungeon. Collect gear from named corpses. Hazards are visible pixel sprites — approach to disarm via diegetic QTE (bar drawn at hazard position). Failure damages a visible weapon.
3. **Workshop** (top-down room) — Walk between 4 repair stations. Each minigame shows the weapon large. Repair restores durability and state. Ring bell to battle.
4. **Battle** (spectator, top-down scroller) — Party auto-fights. Weapons visibly degrade. Watch your craft succeed or shatter. Press 1 to Haunt enemies (slow them).
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

320×180 internal (Celeste standard), `viewport` stretch mode, `keep` aspect. Scales to 4K+ with pixel-perfect integer scaling. Snap-to-pixel enabled.

## Art

- All sprites procedurally generated at runtime (`scripts/sprites.gd`) — 16×16, palette-disciplined
- 32-color curated palette (`scripts/palette.gd`)
- Pixel font: Press Start 2P (bundled in `assets/fonts/`), applied everywhere via `GameFont.gd`
- Juice: `scripts/juice.gd` (screen shake, hit-stop, directional particles)

## Save Data

Meta-upgrades persist between sessions, saved to `user://save_v3.json`.

## Tech

- **Engine:** Godot 4.3+ (GL Compatibility renderer)
- **Language:** GDScript
- **Resolution:** 320×180 base, scales to 4K+ (pixel-perfect)
- **Pixel art:** snap_2d_transforms_to_pixel + snap_2d_vertices_to_pixel enabled

## Project Structure

```
dungeon_caretaker/
├── project.godot              (320x180, viewport stretch, snap-to-pixel)
├── assets/
│   ├── default_theme.tres     (Press Start 2P global theme)
│   └── fonts/press_start_2p.ttf
├── scripts/
│   ├── autoload/
│   │   ├── game_state.gd      (run state, arsenal, party, upgrades)
│   │   └── juice.gd           (screen shake, hit-stop, particles)
│   ├── palette.gd             (32-color curated palette)
│   ├── game_font.gd           (Press Start 2P helper, no default font)
│   ├── sprites.gd             (16x16 procedural pixel sprites)
│   ├── weapon.gd              (Weapon class: name, wear, kill log, fingerprints)
│   ├── main.gd                (phase manager)
│   ├── phases/
│   │   ├── main_menu.gd
│   │   ├── planning.gd        (diegetic room: map table, rack, bell, adventurers)
│   │   ├── salvage.gd         (WASD movement, named corpses, diegetic QTE)
│   │   ├── workshop.gd        (4 repair stations, weapon visible in minigames)
│   │   ├── battle.gd          (spectator, weapons degrade, hit-stop on break)
│   │   ├── results.gd         (weapon dossier cards)
│   │   ├── upgrade_shop.gd
│   │   └── win_lose.gd
│   └── repair/
│       ├── polish_bench.gd
│       ├── oil_grindstone.gd
│       ├── exorcise_altar.gd
│       └── reforge_furnace.gd
└── scenes/
    └── main.tscn
```

## License

Code: MIT. Press Start 2P font: OFL. Generated sprites: CC0.
