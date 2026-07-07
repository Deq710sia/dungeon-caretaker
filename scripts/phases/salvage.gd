extends Node2D
## Phase: salvage — top-down corridor, ghosts, hazards, QTE variety.
## Uses the shared GhostMovement script for normalized movement + phase verb.
## Dungeon generation persists per stage (same layout for battle + salvage).
## Hazards trigger on TOUCH (not just E press). 3 QTE types: timing, spam,
## pattern. Corridor has width segments (wide/narrow zones). Noise-based
## floor detail. Timer for the salvage phase.

const TILE: int = 16
const VIEW_W: int = 480
const VIEW_H: int = 270
const BASE_GHOST_HP: int = 5
const INTERACT_RADIUS: float = 16.0
const SALVAGE_TIMER: float = 45.0  # seconds before forced exit
# Push-your-luck: the main exit is at the corridor midpoint. Past it is
# the "deeper" section with better gear but more hazards. The player can
# leave anytime (reach the exit) or push deeper for more reward.
const DEEPER_GEAR_CHANCE: float = 0.30  # chance deeper corpses have legendary/cursed gear

var move: GhostMovement
var ghost_hp: int = 5
var ghost_hp_max: int = 5
var ghost_invuln: float = 0.0
var camera_y: float = 0.0
var cam: Camera2D
var salvage_timer: float = SALVAGE_TIMER

var gen: DungeonGen  # dungeon generation (cached from GameState)
var corridor_w: int = 18
var corridor_h: int = 60
var narrow_zones: Array = []
var corpses: Array = []
var hazards: Array = []
var exit_pos: Vector2
var finished: bool = false
var collected_count: int = 0
var near_interactive: Variant = null
var interact_pressed: bool = false
var active_qte: Dictionary = {}
var props: Array = []
var _noise: FastNoiseLite

var hud_stage: Label
var hud_collected: Label
var hud_hint: Label
var hud_hp: Label
var hud_phase: Label
var hud_timer: Label

const CORPSE_NAMES := [
        "Bram the Bold", "Wren the Swift", "Cael the Steady", "Mira the Wise",
        "Edric the Brave", "Solis the Bright", "Thora the Strong", "Quill the Quiet",
        "Harlan the Unlucky", "Isolde the Reckless", "Corwin the Loud", "Vashti the Grim",
        "Petra the Careful (evidently not)", "Ambrose the Greedy", "Sasha the Late",
]
const CORPSE_DEATHS := [
        "felled by slimes", "lost to a pit", "overwhelmed by bats", "caught by spikes",
        "swarmed by skeletons", "fell to the dungeon", "outran nothing, apparently",
        "trusted a lever", "went in alone", "read the warning sign too late",
]

func _ready() -> void:
        ghost_hp_max = BASE_GHOST_HP + int(GameState.meta_upgrades.get("ghost_resilience", 0))
        ghost_hp = ghost_hp_max
        move = GhostMovement.new()
        gen = GameState.get_dungeon_gen()
        corridor_w = gen.corridor_w
        corridor_h = gen.corridor_h
        narrow_zones = gen.narrow_zones
        _noise = gen.get_noise()
        move.reset(Vector2(corridor_w * TILE / 2, 48))
        cam = Camera2D.new()
        cam.position = move.pos
        cam.enabled = true
        cam.position_smoothing_enabled = false
        add_child(cam)
        _build_level()
        _build_hud()

func _build_level() -> void:
        corpses.clear()
        hazards.clear()
        props.clear()
        # Load hazards from the persistent dungeon generation (tile coords → pixel)
        for h in gen.hazards:
                hazards.append({
                        "pos": Vector2(h.pos.x * TILE + TILE / 2.0, h.pos.y * TILE + TILE / 2.0),
                        "type": h.type,
                        "active": true,
                        "cooldown": 0.0,
                })
        # Corpses: actual fallen party gear + bonus corpses
        # Fallen party gear is placed at the death position (recorded in battle)
        # so the player finds their gear where they actually died.
        var fallen_gear: Array = GameState.last_battle_result.get("fallen_gear", [])
        if not fallen_gear.is_empty():
                for i in fallen_gear.size():
                        var fg: Dictionary = fallen_gear[i]
                        var w: Weapon = fg["weapon"]
                        # Use death_tile if available (actual death position from battle)
                        # Otherwise fall back to a spread layout.
                        var death_tile: Variant = fg.get("death_tile", null)
                        var cx: float
                        var cy: float
                        if death_tile != null:
                                cx = death_tile.x * TILE + TILE / 2.0
                                cy = death_tile.y * TILE + TILE / 2.0
                                # Clamp to corridor bounds
                                cx = clampf(cx, TILE, (corridor_w - 1) * TILE)
                                cy = clampf(cy, TILE * 3, (corridor_h - 3) * TILE)
                        else:
                                cx = (2 + (i * 5) % (corridor_w - 4)) * TILE + TILE / 2
                                cy = (10 + i * 8) * TILE + TILE / 2
                        corpses.append({
                                "pos": Vector2(cx, cy),
                                "gear_type": w.type,
                                "gear_state": w.state,
                                "gear_name": w.display_name,
                                "corpse_name": fg.get("name", "Unknown"),
                                "death_cause": fg.get("cause", "slain in battle"),
                                "collected": false,
                                "weapon": w,
                        })
                _add_bonus_corpses(fallen_gear.size())
        else:
                # First run: use the simulated predecessor deaths if available
                if GameState.has_meta("_first_party_sim"):
                        var sim: Array = GameState.get_meta("_first_party_sim")
                        for i in sim.size():
                                var death: Dictionary = sim[i]
                                var x := (2 + (i * 5) % (corridor_w - 4)) * TILE + TILE / 2
                                var y := (10 + i * 8) * TILE + TILE / 2
                                corpses.append({
                                        "pos": Vector2(x, y),
                                        "gear_type": death.gear_type,
                                        "gear_state": Weapon.State.RUSTED,
                                        "gear_name": _gen_weapon_name(death.gear_type),
                                        "corpse_name": death.name,
                                        "death_cause": "slain by %s" % death.enemy,
                                        "collected": false,
                                        "weapon": null,
                                })
                        _add_bonus_corpses(sim.size())
                else:
                        _add_bonus_corpses(0)
        # Main exit at the MIDPOINT of the corridor (push-your-luck: the player
        # can leave here, or push deeper for more gear + more hazards).
        # The deeper section (past the exit) has bonus corpses with better gear.
        exit_pos = Vector2(corridor_w * TILE / 2, (corridor_h / 2) * TILE)
        # Add deeper-section bonus corpses (past the exit, harder to reach)
        _add_deeper_corpses()
        # Decorative props
        for i in corridor_h / 8:
                var y := (4 + i * 8) * TILE
                if randf() < 0.3:
                        props.append({"pos": Vector2(TILE, y), "sprite": "cobweb"})
                if randf() < 0.3:
                        props.append({"pos": Vector2((corridor_w - 1) * TILE, y), "sprite": "cobweb"})
                if randf() < 0.15:
                        props.append({"pos": Vector2(2 * TILE + randi() % (corridor_w - 4) * TILE, y + 4), "sprite": "crate"})
                if randf() < 0.1:
                        props.append({"pos": Vector2(2 * TILE + randi() % (corridor_w - 4) * TILE, y + 4), "sprite": "skull_pile"})

func _add_bonus_corpses(fallen_count: int) -> void:
        var bonus_count: int = 1 + int(GameState.stage / 3) + int(GameState.meta_upgrades["salvage_expert"])
        var name_pool := CORPSE_NAMES.duplicate()
        name_pool.shuffle()
        var death_pool := CORPSE_DEATHS.duplicate()
        death_pool.shuffle()
        var all_types := ["sword", "helm", "staff", "robe"]
        all_types.shuffle()
        var all_states := [Weapon.State.BLOODIED, Weapon.State.RUSTED, Weapon.State.HAUNTED, Weapon.State.CURSED]
        all_states.shuffle()
        var missing_type := ""
        for t in all_types:
                var has_working := false
                for w in GameState.arsenal:
                        if w.type == t and not w.is_broken:
                                has_working = true
                                break
                if not has_working:
                        missing_type = t
                        break
        for i in bonus_count:
                var idx: int = fallen_count + i
                var x: float = (2 + (idx * 5) % (corridor_w - 4)) * TILE + TILE / 2.0
                var y: float = (10 + idx * 8) * TILE + TILE / 2.0
                var type: String = missing_type if (i == 0 and missing_type != "") else all_types[i % all_types.size()]
                var state: int = all_states[i % all_states.size()]
                corpses.append({
                        "pos": Vector2(x, y),
                        "gear_type": type,
                        "gear_state": state,
                        "gear_name": _gen_weapon_name(type),
                        "corpse_name": name_pool[i % name_pool.size()],
                        "death_cause": death_pool[i % death_pool.size()],
                        "collected": false,
                        "weapon": null,
                        "is_deeper": false,
                })

## Push-your-luck: adds bonus corpses in the DEEPER section of the corridor
## (past the main exit). These corpses have better gear — chance of legendary
## or cursed weapons. The player must pass the exit to reach them, risking
## more hazards and ghost HP for better rewards. This is the "exceed
## expectations" curve from the design philosophy: the floor (reach exit)
## is guaranteed, the ceiling (collect everything) costs real risk.
func _add_deeper_corpses() -> void:
        var deeper_count: int = 1 + int(GameState.stage / 2)
        var name_pool := CORPSE_NAMES.duplicate()
        name_pool.shuffle()
        var death_pool := CORPSE_DEATHS.duplicate()
        death_pool.shuffle()
        var all_types := ["sword", "helm", "staff", "robe"]
        all_types.shuffle()
        for i in deeper_count:
                # Place in the deeper section (past the exit at corridor_h / 2)
                var y_tile: int = (corridor_h / 2) + 4 + i * 5
                var x_tile: int = 2 + (i * 5) % (corridor_w - 4)
                var type: String = all_types[i % all_types.size()]
                var is_special: bool = randf() < DEEPER_GEAR_CHANCE
                var gear_name: String = _gen_weapon_name(type)
                if is_special:
                        var special_prefixes := ["Legendary", "Cursed", "Ancient", "Volatile"]
                        gear_name = "%s %s" % [special_prefixes[randi() % special_prefixes.size()], gear_name]
                corpses.append({
                        "pos": Vector2(x_tile * TILE + TILE / 2.0, y_tile * TILE + TILE / 2.0),
                        "gear_type": type,
                        "gear_state": Weapon.State.RUSTED,
                        "gear_name": gear_name,
                        "corpse_name": name_pool[i % name_pool.size()],
                        "death_cause": death_pool[i % death_pool.size()],
                        "collected": false,
                        "weapon": null,
                        "is_deeper": true,
                        "is_special": is_special,
                })

func _gen_weapon_name(type: String) -> String:
        var prefixes := ["Rusted", "Bloodied", "Cursed", "Whispering", "Forgotten", "Pitted", "Haunted"]
        var bases := {"sword": "Blade", "staff": "Staff", "helm": "Helm", "robe": "Robe"}
        return "%s %s" % [prefixes[randi() % prefixes.size()], bases.get(type, "Item")]

func _build_hud() -> void:
        var hud_layer := CanvasLayer.new()
        add_child(hud_layer)
        var panel := Panel.new()
        panel.position = Vector2(0, 0)
        panel.size = Vector2(VIEW_W, 20)
        hud_layer.add_child(panel)
        hud_stage = Label.new()
        hud_stage.text = "S%d W%d SALVAGE" % [GameState.stage, GameState.wave]
        hud_stage.add_theme_font_size_override("font_size", 8)
        hud_stage.add_theme_color_override("font_color", Palette.TEXT_GOLD)
        hud_stage.position = Vector2(2, 2)
        hud_stage.size = Vector2(140, 12)
        panel.add_child(hud_stage)
        hud_timer = Label.new()
        hud_timer.text = "Time: %.0f" % salvage_timer
        hud_timer.add_theme_font_size_override("font_size", 8)
        hud_timer.add_theme_color_override("font_color", Palette.TEXT_RED)
        hud_timer.position = Vector2(145, 2)
        hud_timer.size = Vector2(70, 12)
        panel.add_child(hud_timer)
        hud_hp = Label.new()
        hud_hp.text = "HP: " + "♥".repeat(ghost_hp) + "·".repeat(ghost_hp_max - ghost_hp)
        hud_hp.add_theme_font_size_override("font_size", 8)
        hud_hp.add_theme_color_override("font_color", Palette.TEXT_RED)
        hud_hp.position = Vector2(220, 2)
        hud_hp.size = Vector2(110, 12)
        panel.add_child(hud_hp)
        hud_collected = Label.new()
        hud_collected.text = "Salvaged: 0"
        hud_collected.add_theme_font_size_override("font_size", 8)
        hud_collected.add_theme_color_override("font_color", Palette.TEXT_BLUE)
        hud_collected.position = Vector2(340, 2)
        hud_collected.size = Vector2(130, 12)
        hud_collected.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        panel.add_child(hud_collected)
        hud_hint = Label.new()
        hud_hint.text = "WASD:move E:interact SPACE:phase Find exit"
        hud_hint.add_theme_font_size_override("font_size", 8)
        hud_hint.add_theme_color_override("font_color", Palette.TEXT_DIM)
        hud_hint.position = Vector2(0, VIEW_H - 12)
        hud_hint.size = Vector2(VIEW_W, 10)
        hud_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        hud_layer.add_child(hud_hint)
        hud_phase = Label.new()
        hud_phase.text = "[SPACE] PHASE ready"
        hud_phase.add_theme_font_size_override("font_size", 8)
        hud_phase.add_theme_color_override("font_color", Palette.TEXT_GREEN)
        hud_phase.position = Vector2(2, VIEW_H - 24)
        hud_phase.size = Vector2(160, 10)
        hud_layer.add_child(hud_phase)

func _physics_process(delta: float) -> void:
        # Reset interact_pressed BEFORE any early returns
        if not Input.is_action_pressed("interact"):
                interact_pressed = false
        if finished:
                return
        if Juice.is_hit_stopped():
                return
        # Salvage timer — counts down, forced exit at 0
        salvage_timer -= delta
        hud_timer.text = "Time: %.0f" % max(0, salvage_timer)
        if salvage_timer <= 0:
                hud_hint.text = "Time's up — forced retreat!"
                _finish()
                return
        # Input
        var input_dir := Vector2.ZERO
        if active_qte.is_empty():
                if Input.is_action_pressed("move_left"):  input_dir.x -= 1
                if Input.is_action_pressed("move_right"): input_dir.x += 1
                if Input.is_action_pressed("move_up"):    input_dir.y -= 1
                if Input.is_action_pressed("move_down"):  input_dir.y += 1
        move.update(input_dir, delta)
        # Clamp to corridor bounds (respecting narrow zones)
        _clamp_to_corridor()
        # Camera follow with look-ahead
        var look_ahead := move.facing * 24.0
        var cam_target_y := move.pos.y + look_ahead.y
        var cam_target_x := move.pos.x + look_ahead.x * 0.3
        camera_y = lerpf(camera_y, cam_target_y, 1.0 - exp(-delta * 6.0))
        cam.position = Vector2(int(cam_target_x), int(camera_y))
        cam.offset = Juice.get_shake_offset()
        # Hazards on TOUCH — if ghost overlaps an active hazard, auto-trigger QTE
        _check_hazard_touch()
        # Interactions (corpses still need E press)
        _find_nearest_interactive()
        if Input.is_action_just_pressed("interact") and not interact_pressed:
                interact_pressed = true
                _handle_interact()
        # Phase verb
        if active_qte.is_empty() and Input.is_action_just_pressed("phase"):
                move.try_activate_phase()
        # Hazard cooldowns
        for h in hazards:
                h.cooldown = max(0, h.cooldown - delta)
        ghost_invuln = max(0, ghost_invuln - delta)
        # Exit
        if move.pos.distance_to(exit_pos) < 12:
                _finish()
        # QTE update
        if not active_qte.is_empty():
                _update_qte(delta)
        # Update phase HUD
        _update_phase_hud()
        Juice.update_particles(delta)
        queue_redraw()

func _clamp_to_corridor() -> void:
        # Default full-width clamp
        var left := float(TILE)
        var right := float((corridor_w - 1) * TILE)
        # Check if we're in a narrow zone — if so, clamp to the narrow width
        var ghost_tile_y := int(move.pos.y / TILE)
        for nz in narrow_zones:
                if abs(ghost_tile_y - nz.y_center) < nz.y_half:
                        left = nz.width_left * TILE
                        right = nz.width_right * TILE
                        break
        move.pos.x = clampf(move.pos.x, left, right)
        move.pos.y = clampf(move.pos.y, 22, (corridor_h - 1) * TILE)

func _check_hazard_touch() -> void:
        # Hazards activate on TOUCH, not just E press. If the ghost overlaps an
        # active hazard and isn't phasing (phase bypasses fire/spikes), auto-start
        # the QTE. This makes hazards harder to avoid — you can't just walk past.
        if not active_qte.is_empty():
                return
        if ghost_invuln > 0:
                return
        for h in hazards:
                if not h.active:
                        continue
                # Phase bypasses fire and spikes (NOT pits or debris — you still
                # fall into pits and debris still hits you even when incorporeal)
                if move.is_phasing() and h.type in ["fire", "spikes"]:
                        continue
                if move.pos.distance_to(h.pos) < 14.0:
                        _start_qte(h)
                        return

func _find_nearest_interactive() -> void:
        near_interactive = null
        if not active_qte.is_empty():
                return
        var best_dist: float = INTERACT_RADIUS
        for c in corpses:
                if not c.collected and move.pos.distance_to(c.pos) < best_dist:
                        best_dist = move.pos.distance_to(c.pos)
                        near_interactive = c
        if near_interactive is Dictionary:
                if near_interactive.has("corpse_name"):
                        hud_hint.text = "[E] Salvage %s" % near_interactive.gear_name
        else:
                hud_hint.text = "WASD:move E:interact SPACE:phase Find exit"

func _handle_interact() -> void:
        if near_interactive is Dictionary:
                if near_interactive.has("corpse_name") and not near_interactive.collected:
                        _collect_corpse(near_interactive)

func _collect_corpse(c: Dictionary) -> void:
        c.collected = true
        collected_count += 1
        hud_collected.text = "Salvaged: %d" % collected_count
        var w: Weapon = c.get("weapon", null)
        if w == null:
                w = Weapon.new(c.gear_type, c.gear_name, "Salvaged from %s, %s." % [c.corpse_name, c.death_cause])
                var affliction := Weapon.roll_affliction(c.gear_type)
                w.state = affliction.state
                w.wear_state = affliction.wear_state
                w.unexorcised_deaths = affliction.unexorcised_deaths
                w.durability_max = Weapon.BASE_DURABILITY + GameState.meta_upgrades["sturdy_grip"] * 25
                w.durability = int(w.durability_max * affliction.durability_pct)
                if affliction.wear_state == Weapon.WearState.BROKEN:
                        w.is_broken = true
                w.sharpness = randf_range(0.3, 0.6)
                w.balance = randf_range(0.3, 0.6)
                w.power = randf_range(0.3, 0.6)
                w.mystic = randf_range(0.3, 0.6)
        else:
                w.history.append("Salvaged from %s, %s." % [c.corpse_name, c.death_cause])
        w.history.append("Here lies %s, %s." % [c.corpse_name, c.death_cause])
        GameState.add_weapon(w)
        move.squash = 1.3
        Juice.add_trauma(0.2)
        Juice.hit_stop(0.06)
        Juice.spawn_particles(c.pos, 8, Palette.TEXT_GOLD, 30.0, 0.5)
        hud_hint.text = "Salvaged %s!" % c.gear_name
        SFX.play("coin")

func _take_hazard_damage(h: Dictionary) -> void:
        h.cooldown = 1.5
        ghost_invuln = 1.0
        ghost_hp -= 1
        Juice.add_trauma(0.6)
        Juice.hit_stop(0.1)
        Juice.spawn_particles(move.pos, 10, Palette.TEXT_RED, 50.0, 0.4, Vector2(0, -1))
        SFX.play("thud")
        move.squash = 0.7
        if not GameState.arsenal.is_empty():
                var w: Weapon = GameState.arsenal[-1]
                w.take_durability_damage(15, "hit by %s" % h.type)
                hud_hint.text = "Hit! -1 HP | %s damaged!" % w.display_name
        else:
                hud_hint.text = "Hit! -1 HP | Ghost HP: %d/%d" % [ghost_hp, ghost_hp_max]
        var away: Vector2 = (move.pos - h.pos).normalized()
        move.pos += away * 16
        move.vel = away * 30
        if ghost_hp <= 0:
                hud_hint.text = "The ghost fades... forced to retreat!"
                _finish()
        else:
                hud_hp.text = "HP: " + "♥".repeat(ghost_hp) + "·".repeat(ghost_hp_max - ghost_hp)

func _start_qte(hazard: Dictionary) -> void:
        # 3 QTE types: timing bar (pit), spam (fire), pattern (spikes)
        var qte_type: String = hazard.get("type", "pit")
        match qte_type:
                "pit":
                        # Timing bar — hit the green zone on a sweeping bar
                        active_qte = {
                                "type": "timing",
                                "verb": "JUMP",
                                "timer": 2.5,
                                "max_timer": 2.5,
                                "target_x": 0.5,
                                "marker_x": 0.0,
                                "marker_dir": 1.0,
                                "marker_speed": 0.8,
                                "hazard": hazard,
                        }
                "fire":
                        # Spam — press SPACE rapidly to fill a meter before time runs out
                        active_qte = {
                                "type": "spam",
                                "verb": "MASH SPACE!",
                                "timer": 3.0,
                                "max_timer": 3.0,
                                "progress": 0.0,
                                "target": 1.0,
                                "last_press_time": 0.0,
                                "hazard": hazard,
                        }
                "spikes":
                        # Pattern — press a sequence of keys (W A S D) in order
                        var pattern := []
                        var keys := ["W", "A", "S", "D"]
                        keys.shuffle()
                        for i in 4:
                                pattern.append(keys[i % keys.size()])
                        active_qte = {
                                "type": "pattern",
                                "verb": "PATTERN",
                                "timer": 4.0,
                                "max_timer": 4.0,
                                "pattern": pattern,
                                "index": 0,
                                "hazard": hazard,
                        }
                "debris":
                        # Reverse QTE — DON'T press anything. The falling debris will
                        # miss if you stay still. Pressing any key = failure (you
                        # flinched into the debris). This is the "Dumb Ways to Die"
                        # reverse QTE — the comedy is in NOT acting.
                        active_qte = {
                                "type": "reverse",
                                "verb": "DON'T MOVE!",
                                "timer": 3.0,
                                "max_timer": 3.0,
                                "hazard": hazard,
                        }
                _:
                        active_qte = {
                                "type": "timing",
                                "verb": "TAP",
                                "timer": 2.5,
                                "max_timer": 2.5,
                                "target_x": 0.5,
                                "marker_x": 0.0,
                                "marker_dir": 1.0,
                                "marker_speed": 0.8,
                                "hazard": hazard,
                        }

func _update_qte(delta: float) -> void:
        active_qte.timer -= delta
        if active_qte.timer <= 0:
                _qte_fail()
                return
        match active_qte.type:
                "timing":
                        active_qte.marker_x += active_qte.marker_dir * active_qte.marker_speed * delta
                        if active_qte.marker_x >= 1.0:
                                active_qte.marker_x = 1.0
                                active_qte.marker_dir = -1.0
                        elif active_qte.marker_x <= 0.0:
                                active_qte.marker_x = 0.0
                                active_qte.marker_dir = 1.0

func _input(event: InputEvent) -> void:
        if active_qte.is_empty():
                return
        match active_qte.type:
                "timing":
                        if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or \
                           (event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_E]):
                                var diff: float = absf(active_qte.marker_x - active_qte.target_x)
                                if diff <= 0.15:
                                        _qte_success()
                                else:
                                        _qte_fail()
                "spam":
                        if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
                                active_qte.progress += 0.15
                                if active_qte.progress >= active_qte.target:
                                        _qte_success()
                "pattern":
                        if event is InputEventKey and event.pressed:
                                var expected: String = active_qte.pattern[active_qte.index]
                                var pressed: String = ""
                                match event.keycode:
                                        KEY_W: pressed = "W"
                                        KEY_A: pressed = "A"
                                        KEY_S: pressed = "S"
                                        KEY_D: pressed = "D"
                                if pressed != "" and pressed == expected:
                                        active_qte.index += 1
                                        if active_qte.index >= active_qte.pattern.size():
                                                _qte_success()
                                elif pressed != "":
                                        _qte_fail()
                "reverse":
                        # Reverse QTE: pressing ANY movement/interact/space key = failure
                        # (you flinched into the debris). The only way to succeed is to
                        # NOT press anything until the timer expires.
                        if event is InputEventKey and event.pressed:
                                if event.keycode in [KEY_SPACE, KEY_E, KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
                                        _qte_fail()

func _qte_success() -> void:
        var h: Dictionary = active_qte.hazard
        h.active = false
        Juice.add_trauma(0.3)
        Juice.hit_stop(0.08)
        Juice.spawn_particles(h.pos, 12, Palette.TEXT_GREEN, 40.0, 0.5)
        move.squash = 1.2
        hud_hint.text = "Disarmed the %s!" % h.type
        active_qte = {}

func _qte_fail() -> void:
        var h: Dictionary = active_qte.hazard
        _take_hazard_damage(h)
        hud_hint.text = "Failed! Hit by %s!" % h.type
        active_qte = {}

func _finish() -> void:
        if finished:
                return
        finished = true
        Juice.add_trauma(0.4)
        Juice.spawn_particles(exit_pos, 16, Palette.TEXT_GREEN, 50.0, 0.8)
        await get_tree().create_timer(0.5).timeout
        GameState.set_phase("workshop")

func _update_phase_hud() -> void:
        if move.is_phasing():
                hud_phase.text = "PHASING! %.1fs" % move.phase_active
                hud_phase.add_theme_color_override("font_color", Palette.GLOW_BLUE)
        elif move.phase_cd > 0:
                var bank_text := " +%4.1f bank" % move.phase_bank if move.phase_bank > 0.1 else ""
                hud_phase.text = "[SPACE] cd %.1fs%s" % [move.phase_cd, bank_text]
                hud_phase.add_theme_color_override("font_color", Palette.TEXT_DIM)
        elif GameState.soul_shards < GhostMovement.PHASE_COST:
                hud_phase.text = "[SPACE] phase — need %d shard" % GhostMovement.PHASE_COST
                hud_phase.add_theme_color_override("font_color", Palette.TEXT_RED)
        else:
                var bank_text := " +%4.1f bank" % move.phase_bank if move.phase_bank > 0.1 else ""
                hud_phase.text = "[SPACE] PHASE ready%s" % bank_text
                hud_phase.add_theme_color_override("font_color", Palette.TEXT_GREEN)

func _get_corridor_width_at_y(tile_y: int) -> int:
        # Returns the corridor width (in tiles) at the given y. Wide zones = full
        # 18 tiles, narrow zones = width_right - width_left.
        for nz in narrow_zones:
                if abs(tile_y - nz.y_center) < nz.y_half:
                        return nz.width_right - nz.width_left
        return corridor_w

func _draw() -> void:
        var cam_top := int((camera_y - VIEW_H / 2) / TILE) - 3
        var cam_bot := int((camera_y + VIEW_H / 2) / TILE) + 3
        cam_top = max(-2, cam_top)
        cam_bot = min(corridor_h + 1, cam_bot)
        # Floor with noise-based detail (replaces hash)
        for y in range(cam_top, cam_bot + 1):
                var width_at_y := _get_corridor_width_at_y(y)
                var left_bound: int
                var right_bound: int
                # Compute left/right bounds for this y (wide or narrow)
                var in_narrow := false
                for nz in narrow_zones:
                        if abs(y - nz.y_center) < nz.y_half:
                                left_bound = nz.width_left
                                right_bound = nz.width_right
                                in_narrow = true
                                break
                if not in_narrow:
                        left_bound = 0
                        right_bound = corridor_w
                for x in range(left_bound - 1, right_bound + 1):
                        var p := Vector2(x * TILE, y * TILE)
                        if x < left_bound or x >= right_bound:
                                # Beyond walls — void gradient
                                var void_t := float(y) / float(corridor_h)
                                draw_rect(Rect2(p, Vector2(TILE, TILE)), Color(0.03 + void_t * 0.02, 0.02 + void_t * 0.015, 0.06 + void_t * 0.03), true)
                        else:
                                # Noise-based floor detail
                                var n := _noise.get_noise_2d(x, y)
                                if n < -0.3 and y > 5:
                                        draw_texture(Sprites.get_sprite("floor_moss"), p)
                                elif n < -0.1 and y > 8:
                                        draw_texture(Sprites.get_sprite("floor_crack"), p)
                                elif n > 0.3 and y > 10:
                                        draw_texture(Sprites.get_sprite("floor_blood"), p)
                                else:
                                        draw_texture(Sprites.get_sprite("floor"), p)
        # Side walls (only in wide zones; narrow zones have diagonal transitions)
        for y in range(cam_top, cam_bot + 1):
                var in_narrow := false
                for nz in narrow_zones:
                        if abs(y - nz.y_center) < nz.y_half:
                                in_narrow = true
                                # Draw narrow zone walls
                                draw_texture(Sprites.get_sprite("wall"), Vector2((nz.width_left - 1) * TILE, y * TILE))
                                draw_texture(Sprites.get_sprite("wall_mossy"), Vector2(nz.width_right * TILE, y * TILE))
                                if y % 4 == 0:
                                        draw_texture(Sprites.get_sprite("torch"), Vector2((nz.width_left - 1) * TILE, y * TILE))
                                        draw_texture(Sprites.get_sprite("torch"), Vector2(nz.width_right * TILE, y * TILE))
                                break
                if not in_narrow:
                        draw_texture(Sprites.get_sprite("wall"), Vector2(-TILE, y * TILE))
                        draw_texture(Sprites.get_sprite("wall_mossy"), Vector2(corridor_w * TILE, y * TILE))
                        if y % 4 == 0:
                                draw_texture(Sprites.get_sprite("torch"), Vector2(-TILE, y * TILE))
                                draw_texture(Sprites.get_sprite("torch"), Vector2(corridor_w * TILE, y * TILE))
                                DrawUtils.draw_radial_glow(self, Vector2(-TILE + 8, y * TILE + 8), [20, 14, 8], Palette.LIGHT_TORCH, 0.8)
                                DrawUtils.draw_radial_glow(self, Vector2(corridor_w * TILE + 8, y * TILE + 8), [20, 14, 8], Palette.LIGHT_TORCH, 0.8)
        # Props
        for prop in props:
                if prop.pos.y > cam_top * TILE - 16 and prop.pos.y < cam_bot * TILE + 16:
                        draw_texture(Sprites.get_sprite(prop.sprite), Vector2(int(prop.pos.x), int(prop.pos.y)))
        # Hazards — harder to see (dimmer, smaller indicator)
        for h in hazards:
                if h.active:
                        var hx := int(h.pos.x)
                        var hy := int(h.pos.y)
                        match h.type:
                                "pit":
                                        draw_texture(Sprites.get_sprite("pit"), Vector2(hx - 8, hy - 8))
                                "fire":
                                        draw_texture(Sprites.get_sprite("torch"), Vector2(hx - 8, hy - 8))
                                        DrawUtils.draw_radial_glow(self, h.pos, [16, 10, 5], Palette.LIGHT_FURNACE, 1.2)
                                "spikes":
                                        draw_texture(Sprites.get_sprite("floor_crack"), Vector2(hx - 8, hy - 8))
                                        for i in 3:
                                                var sx := hx - 6 + i * 6
                                                draw_rect(Rect2(sx, hy - 4, 2, 8), Palette.STEEL_LT, true)
                                                draw_rect(Rect2(sx, hy - 4, 1, 8), Palette.STEEL, true)
                                "debris":
                                        # Falling debris — drawn as brown rocks suspended above
                                        # the ground with a shadow underneath
                                        for i in 3:
                                                var dx := hx - 6 + i * 6
                                                var dy := hy - 6 + int(sin(Time.get_ticks_msec() * 0.005 + i) * 2)
                                                draw_rect(Rect2(dx, dy, 4, 4), Palette.STONE, true)
                                                draw_rect(Rect2(dx, dy, 3, 1), Palette.STONE_LT, true)
                                        # Shadow on the ground
                                        draw_rect(Rect2(hx - 8, hy + 4, 16, 2), Color(0, 0, 0, 0.3), true)
                        # Only show proximity indicator when VERY close (harder to see)
                        if move.pos.distance_to(h.pos) < 20:
                                var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
                                for i in 8:
                                        var a := i * (TAU / 8) + Time.get_ticks_msec() * 0.002
                                        var px := int(h.pos.x + cos(a) * 12)
                                        var py := int(h.pos.y + sin(a) * 12)
                                        draw_rect(Rect2(px, py, 2, 2), Color(0.95, 0.40, 0.40, pulse), true)
        # Corpses — visual identity:
        #   YOUR fallen (weapon != null): blue soul-glow + name + death cause
        #   Bonus corpses (is_deeper == false): gold glow + name only
        #   Deeper corpses (is_deeper == true): purple glow + name + "DEEPER"
        for c in corpses:
                var cx := int(c.pos.x)
                var cy := int(c.pos.y)
                if c.collected:
                        draw_texture(Sprites.get_sprite("bones"), Vector2(cx - 8, cy - 8))
                else:
                        draw_texture(Sprites.get_sprite("corpse"), Vector2(cx - 8, cy - 8))
                        var bob := int(sin(Time.get_ticks_msec() * 0.004 + c.pos.x) * 2)
                        # Cache the weapon lookup once (was calling c.get 4× per frame)
                        var w = c.get("weapon", null)
                        var gear_tex: Texture2D
                        if w != null:
                                gear_tex = Sprites.get_weapon_sprite_wear(c.gear_type, w.wear_state, w.is_haunted())
                        else:
                                gear_tex = Sprites.get_weapon_sprite(c.gear_type, c.gear_state)
                        draw_texture(gear_tex, Vector2(cx - 8, cy - 20 + bob))
                        # Corpse identity glow — blue for YOUR fallen, gold for bonus,
                        # purple for deeper section (push-your-luck reward indicator)
                        var is_yours: bool = w != null
                        var is_deeper: bool = c.get("is_deeper", false)
                        if is_yours:
                                DrawUtils.draw_radial_glow(self, Vector2(cx, cy - 12 + bob), [10, 6, 3], Color(0.45, 0.78, 1.0, 0.25), 1.0)
                        elif is_deeper:
                                DrawUtils.draw_radial_glow(self, Vector2(cx, cy - 12 + bob), [10, 6, 3], Color(0.65, 0.40, 0.85, 0.25), 1.0)
                        else:
                                DrawUtils.draw_radial_glow(self, Vector2(cx, cy - 12 + bob), [8, 5, 3], Color(0.95, 0.85, 0.40, 0.15), 1.0)
                        if near_interactive == c:
                                # YOUR fallen show death cause; deeper show "DEEPER" tag
                                GameFont.draw_string_centered(self, Vector2(cx, cy - 32), c.corpse_name, 8, Palette.TEXT_GOLD)
                                GameFont.draw_string_centered(self, Vector2(cx, cy - 26), c.gear_name, 8, Palette.TEXT_BLUE)
                                if is_yours:
                                        GameFont.draw_string_centered(self, Vector2(cx, cy - 38), c.death_cause, 8, Palette.TEXT_DIM)
                                elif is_deeper and c.get("is_special", false):
                                        GameFont.draw_string_centered(self, Vector2(cx, cy - 38), "DEEPER - special", 8, Palette.GLOW_PURP)
        # Exit
        var ex := int(exit_pos.x)
        var ey := int(exit_pos.y)
        draw_texture(Sprites.get_sprite("stairs"), Vector2(ex - 8, ey - 8))
        DrawUtils.draw_radial_glow(self, exit_pos, [16, 10, 5], Palette.LIGHT_EXIT, 1.5)
        var exit_pulse := 0.5 + 0.3 * sin(Time.get_ticks_msec() * 0.003)
        GameFont.draw_string_centered(self, Vector2(ex, ey - 16), "EXIT", 8, Color(0.55, 0.95, 0.75, exit_pulse))
        # Push-your-luck: show "DEEPER ↓" below the exit to indicate the
        # optional deeper section with better gear
        var deeper_count := 0
        for c in corpses:
                if c.get("is_deeper", false) and not c.collected:
                        deeper_count += 1
        if deeper_count > 0:
                GameFont.draw_string_centered(self, Vector2(ex, ey + 10), "DEEPER ↓ (%d)" % deeper_count, 8, Palette.GLOW_PURP)
        # Ghost trail + ghost (shared draw method — underground variant)
        GhostMovement.draw_ghost(self, move, true)
        # QTE
        if not active_qte.is_empty():
                _draw_qte()
        # Particles
        Juice.draw_particles(self)
        # Progress bar
        var progress := clampf(move.pos.y / (corridor_h * TILE), 0, 1)
        draw_rect(Rect2(VIEW_W - 6, 24, 2, VIEW_H - 30), Palette.DARK, true)
        draw_rect(Rect2(VIEW_W - 6, 24 + int((VIEW_H - 30) * (1 - progress)), 2, int((VIEW_H - 30) * progress)), Palette.SLIME, true)

func _draw_qte() -> void:
        var h: Dictionary = active_qte.hazard
        var bar_center: Vector2 = h.pos + Vector2(0, -24)
        match active_qte.type:
                "timing":
                        # Sweeping bar with green target zone
                        var bar_w := 24
                        var bar_h := 4
                        draw_rect(Rect2(int(bar_center.x) - bar_w / 2, int(bar_center.y), bar_w, bar_h), Palette.VOID, true)
                        var tz_x := int(bar_center.x) - bar_w / 2 + int(bar_w * (active_qte.target_x - 0.15))
                        draw_rect(Rect2(tz_x, int(bar_center.y), int(bar_w * 0.30), bar_h), Palette.SLIME, true)
                        var mx := int(bar_center.x) - bar_w / 2 + int(bar_w * active_qte.marker_x)
                        draw_rect(Rect2(mx, int(bar_center.y) - 1, 2, bar_h + 2), Palette.TEXT_GOLD, true)
                        GameFont.draw_string_centered(self, bar_center + Vector2(0, -6), active_qte.verb, 8, Palette.TEXT_GOLD)
                "spam":
                        # Progress bar that fills as you mash SPACE
                        var bar_w := 30
                        var bar_h := 5
                        draw_rect(Rect2(int(bar_center.x) - bar_w / 2, int(bar_center.y), bar_w, bar_h), Palette.VOID, true)
                        var fill_w := int(bar_w * active_qte.progress)
                        draw_rect(Rect2(int(bar_center.x) - bar_w / 2, int(bar_center.y), fill_w, bar_h), Palette.TEXT_GOLD, true)
                        draw_rect(Rect2(int(bar_center.x) - bar_w / 2, int(bar_center.y), bar_w, bar_h), Palette.TEXT_DIM, false, 1)
                        GameFont.draw_string_centered(self, bar_center + Vector2(0, -6), active_qte.verb, 8, Palette.TEXT_GOLD)
                        # Time remaining indicator
                        var time_pct: float = float(active_qte.timer) / float(active_qte.max_timer)
                        draw_rect(Rect2(int(bar_center.x) - bar_w / 2, int(bar_center.y) + bar_h + 1, int(bar_w * time_pct), 1), Palette.TEXT_RED, true)
                "pattern":
                        # Show the key sequence — highlight current key, dim completed keys
                        var pattern: Array = active_qte.pattern
                        var spacing := 14
                        var start_x := int(bar_center.x) - (pattern.size() - 1) * spacing / 2
                        for i in pattern.size():
                                var key_x := start_x + i * spacing
                                var key_y := int(bar_center.y)
                                var c: Color
                                if i < active_qte.index:
                                        c = Palette.TEXT_GREEN  # completed
                                elif i == active_qte.index:
                                        c = Palette.TEXT_GOLD  # current
                                else:
                                        c = Palette.TEXT_DIM  # pending
                                draw_rect(Rect2(key_x - 5, key_y - 4, 10, 10), Palette.DARK, true)
                                draw_rect(Rect2(key_x - 5, key_y - 4, 10, 10), c, false, 1)
                                GameFont.draw_string_centered(self, Vector2(key_x, key_y + 3), pattern[i], 8, c)
                        GameFont.draw_string_centered(self, bar_center + Vector2(0, -10), active_qte.verb, 8, Palette.TEXT_GOLD)
                "reverse":
                        # Reverse QTE: big "DON'T MOVE!" text with a shrinking timer bar.
                        # The bar shrinks from full to empty — when it empties, you succeed
                        # (you stayed still). Any key press = instant fail.
                        var time_pct: float = float(active_qte.timer) / float(active_qte.max_timer)
                        var bar_w := 30
                        var bar_h := 5
                        # Red bar that shrinks (opposite of the spam bar which fills)
                        draw_rect(Rect2(int(bar_center.x) - bar_w / 2, int(bar_center.y), bar_w, bar_h), Palette.DARK, true)
                        draw_rect(Rect2(int(bar_center.x) - bar_w / 2, int(bar_center.y), int(bar_w * time_pct), bar_h), Palette.TEXT_RED, true)
                        draw_rect(Rect2(int(bar_center.x) - bar_w / 2, int(bar_center.y), bar_w, bar_h), Palette.TEXT_DIM, false, 1)
                        # Pulsing "DON'T MOVE!" text
                        var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)
                        GameFont.draw_string_centered(self, bar_center + Vector2(0, -10), active_qte.verb, 8, Color(0.98, 0.42 + 0.2 * pulse, 0.42))

func _on_phase_exit() -> void:
        # No carried weapon to return in salvage
        pass
