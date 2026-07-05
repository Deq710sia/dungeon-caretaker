# Dungeon Caretaker: A Ghost's Salvage (V4)

A top-down **pixel-art roguelike management sim** where weapons are the persistent, named, degrading objects you invest in across waves. You don't fight — you salvage, repair, and assign weapons to doomed adventurers, then watch them auto-battle and witness your craft succeed or shatter.

## V4 — The Pixel Art + Agency + Juice Redesign

V3 still failed: 640×360 wasn't chunky enough to read as pixel art, `canvas_items` stretch blurred pixels, vector primitives for hazards broke the aesthetic, planning was a menu, salvage had zero agency (auto-walk removed the player), no juice. V4 fixes all of this based on deep research (Camwing's Satisfactory brain-hooks analysis, Dead Space diegetic UI, Saint11's pixel art rules, Vlambeer's juice principles, Slay the Spire's planning).

### What V4 does differently:

**1. Real pixel art now** — Internal resolution 320×180 (Celeste standard, chunky pixels). Stretch mode `viewport` (pixel-perfect, no blur). Aspect `keep` (no non-integer scaling). 32-color curated palette (`scripts/palette.gd`) — every color in the game comes from it. All sprites 16×16, palette-disciplined, no vector primitives. Snap-to-pixel enabled. Press Start 2P font everywhere via `GameFont.gd` (no default Godot font anywhere). Verified 8/10 "authentic pixel art, chunky, palette-disciplined" via visual inspection.

**2. Diegetic planning phase** — No menus. Walk to the **map table** → view wave path & intel overlay. Walk to the **weapon rack** → pick up a weapon (3 visible per page). Walk to **adventurers** → assign the carried weapon. Walk to the **bell** → ring it, begin the wave. Everything is physical. Carries weapons visually, same as workshop.

**3. Salvage with full agency** — Killed the auto-walk. Ghost moves with WASD (reuses workshop code). Camera looks AHEAD (+40 offset, not backwards). Hazards are visible pixel sprites you CHOOSE to approach. Corpses have names ("Here lies Bram the Bold, felled by slimes"). QTE bar is drawn at the hazard position (diegetic, not full-screen overlay). Failure is FAIR: damages the most recently collected weapon (visible, not random deletion). Push-your-luck: hazards have cooldown, you can retreat.

**4. Juice system** — New `Juice.gd` autoload: trauma-based screen shake, hit-stop (0.06–0.15s freezes on impacts/breaks/bell), directional pixel-square particles (not vector circles), squash & stretch on the ghost (preserves volume, eases back). Every significant event has visual + kinesthetic response.

**5. Brain hooks (from research)** — Visible state change (corpses → bone piles, persistent). Anticipation (hazards pulse before you reach them). Investment (weapons have authoring fingerprints: sharpness/balance/power/mystic). Narrative (named corpses with death causes in weapon history). Near-miss (QTE shows the target zone so you see how close you were). Failure-is-progress (weapons retained as broken mementos, never deleted).

**6. Weapons are characters** — Every weapon has: unique name, day-stamp, wielder binding, 4 discrete wear states with distinct art, kill log, authoring fingerprints, retained as broken memento when shattered.

**7. Spectator battle with visible degradation** — Party auto-fights, you watch. Weapons visibly degrade during the fight (wear state changes, durability bar drops). When a weapon breaks: 0.15s hit-stop + 12-particle burst + log message. This is the Jacksmith "judgement phase" that reads your crafting.

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
