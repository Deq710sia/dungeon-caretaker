extends Node2D
## Phase: salvage V6 — full agency, momentum movement, pixel-snapped camera,
## ambient torch lighting, no jitter.

const TILE: int = 16
const CORRIDOR_W: int = 18
const CORRIDOR_H: int = 60
const VIEW_W: int = 480
const VIEW_H: int = 270

var ghost_pos: Vector2 = Vector2(CORRIDOR_W * TILE / 2, 48)
var ghost_vel: Vector2 = Vector2.ZERO
var ghost_speed: float = 55.0
var ghost_accel: float = 300.0
var ghost_friction: float = 12.0
var ghost_bob: float = 0.0
var ghost_squash: float = 1.0
var ghost_facing: Vector2 = Vector2.DOWN  # for look-ahead
const BASE_GHOST_HP: int = 5
var ghost_hp: int = 5  # V6: ghost has health. Forced exit at 0. Set for real in _ready().
var ghost_hp_max: int = 5
const INTERACT_RADIUS: float = 16.0  # matches workshop.gd's STATION_RADIUS
var ghost_invuln: float = 0.0  # i-frames after taking damage
var camera_y: float = 0.0
var cam: Camera2D

var corpses: Array = []
var hazards: Array = []
var exit_pos: Vector2
var finished: bool = false
var collected_count: int = 0
var near_interactive: Variant = null
var interact_pressed: bool = false
var active_qte: Dictionary = {}

# Decorative props (placed once, drawn every frame)
var props: Array = []  # {pos, sprite}

var hud_stage: Label
var hud_collected: Label
var hud_hint: Label
var hud_hp: Label  # V6: ghost health display

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
        cam = Camera2D.new()
        cam.position = ghost_pos
        cam.enabled = true
        cam.position_smoothing_enabled = false  # we do our own smoothing in _physics_process
        add_child(cam)
        _build_level()
        _build_hud()

func _build_level() -> void:
        corpses.clear()
        hazards.clear()
        props.clear()
        # V2: Corpses are the ACTUAL DEAD PARTY MEMBERS' gear, not random NPCs.
        # Read fallen_gear from last_battle_result. If no fallen gear (first run
        # or everyone survived), use the old random system as a fallback.
        var fallen_gear: Array = GameState.last_battle_result.get("fallen_gear", [])
        if not fallen_gear.is_empty():
                # Use actual fallen gear — this is the core loop
                for i in fallen_gear.size():
                        var fg: Dictionary = fallen_gear[i]
                        var w: Weapon = fg["weapon"]
                        var x := (2 + (i * 5) % (CORRIDOR_W - 4)) * TILE + TILE / 2
                        var y := (10 + i * 8) * TILE + TILE / 2
                        corpses.append({
                                "pos": Vector2(x, y),
                                "gear_type": w.type,
                                "gear_state": w.state,
                                "gear_name": w.display_name,
                                "corpse_name": fg.get("name", "Unknown"),
                                "death_cause": "slain in battle",
                                "collected": false,
                                "weapon": w,  # V2: carry the ACTUAL weapon object, not a new random one
                        })
                # Also add a few bonus random corpses for variety (fewer than before)
                var bonus_count: int = 1 + int(GameState.stage / 3) + int(GameState.meta_upgrades["salvage_expert"])
                var name_pool := CORPSE_NAMES.duplicate()
                name_pool.shuffle()
                var death_pool := CORPSE_DEATHS.duplicate()
                death_pool.shuffle()
                var all_types := ["sword", "helm", "staff", "robe"]
                all_types.shuffle()
                var all_states := [Weapon.State.BLOODIED, Weapon.State.RUSTED, Weapon.State.HAUNTED, Weapon.State.CURSED]
                all_states.shuffle()
                # Placement guardrail (cheap heuristic, not a formal solvability proof —
                # same spirit as Desktop Dungeons' monster-placement heuristics: make
                # the worst-case draw rare, not impossible). Two rules:
                #  1. Types cycle through a shuffled pool instead of independent random
                #     draws, so a run of bonus_count <= 4 corpses can't duplicate a
                #     type until every other type has appeared once.
                #  2. If the player's current arsenal has ZERO working (non-broken)
                #     copies of some gear type, force the first bonus corpse to be
                #     that type, so a stage can never leave the player with no route
                #     back to a whole equipment slot.
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
                        var idx: int = fallen_gear.size() + i
                        var x: float = (2 + (idx * 5) % (CORRIDOR_W - 4)) * TILE + TILE / 2.0
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
                                "weapon": null,  # will be created fresh on pickup
                        })
        else:
                # Fallback: first run or no deaths — use random corpses (old behavior)
                var corpse_count := 2 + int(GameState.stage / 2)
                var name_pool := CORPSE_NAMES.duplicate()
                name_pool.shuffle()
                var death_pool := CORPSE_DEATHS.duplicate()
                death_pool.shuffle()
                var all_types := ["sword", "helm", "staff", "robe"]
                all_types.shuffle()
                var all_states := [Weapon.State.BLOODIED, Weapon.State.RUSTED, Weapon.State.HAUNTED, Weapon.State.CURSED]
                for i in corpse_count:
                        var x := (2 + (i * 5) % (CORRIDOR_W - 4)) * TILE + TILE / 2
                        var y := (10 + i * 8) * TILE + TILE / 2
                        var type: String = all_types[i % all_types.size()]
                        var state: int = all_states[randi() % all_states.size()]
                        var name: String = name_pool[i % name_pool.size()]
                        var death: String = death_pool[i % death_pool.size()]
                        corpses.append({
                                "pos": Vector2(x, y),
                                "gear_type": type,
                                "gear_state": state,
                                "gear_name": _gen_weapon_name(type),
                                "corpse_name": name,
                                "death_cause": death,
                                "collected": false,
                                "weapon": null,
                        })
        # Hazards — MORE and CLOSER together. Was 3+stage (too few, easy to avoid).
        # Now 4+stage*2, placed at tighter intervals.
        var hazard_count := 4 + GameState.stage * 2
        for i in hazard_count:
                var x := (2 + (i * 3) % (CORRIDOR_W - 4)) * TILE + TILE / 2
                var y := (6 + i * 6) * TILE + TILE / 2  # was 12 spacing, now 6 — tighter
                for c in corpses:
                        if c.pos.distance_to(Vector2(x, y)) < TILE * 2:
                                y += TILE * 3
                var htypes := ["pit", "fire", "spikes"]
                hazards.append({
                        "pos": Vector2(x, y),
                        "type": htypes[i % htypes.size()],
                        "active": true,
                        "cooldown": 0.0,
                })
        # Decorative props (cobwebs in corners, skull piles, crates)
        for i in CORRIDOR_H / 8:
                var y := (4 + i * 8) * TILE
                if randf() < 0.3:
                        props.append({"pos": Vector2(TILE, y), "sprite": "cobweb"})
                if randf() < 0.3:
                        props.append({"pos": Vector2((CORRIDOR_W - 1) * TILE, y), "sprite": "cobweb"})
                if randf() < 0.15:
                        props.append({"pos": Vector2(2 * TILE + randi() % (CORRIDOR_W - 4) * TILE, y + 4), "sprite": "crate"})
                if randf() < 0.1:
                        props.append({"pos": Vector2(2 * TILE + randi() % (CORRIDOR_W - 4) * TILE, y + 4), "sprite": "skull_pile"})
        exit_pos = Vector2(CORRIDOR_W * TILE / 2, (CORRIDOR_H - 3) * TILE)

func _gen_weapon_name(type: String) -> String:
        var prefixes := ["Rusted", "Bloodied", "Cursed", "Whispering", "Forgotten", "Pitted", "Haunted"]
        var bases := {"sword": "Blade", "staff": "Staff", "helm": "Helm", "robe": "Robe"}
        return "%s %s" % [prefixes[randi() % prefixes.size()], bases.get(type, "Item")]

func _build_hud() -> void:
        # Same fix as battle.gd: this room has a moving Camera2D, so anything not
        # in a CanvasLayer gets dragged along with it. Without this, the stage/
        # wave label (and the collected count) would drift and eventually scroll
        # out of view as the ghost explores — looking exactly like a label that
        # "never updates" even though its text is correct underneath.
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
        hud_stage.size = Vector2(160, 12)
        panel.add_child(hud_stage)
        hud_collected = Label.new()
        hud_collected.text = "Salvaged: 0"
        hud_collected.add_theme_font_size_override("font_size", 8)
        hud_collected.add_theme_color_override("font_color", Palette.TEXT_BLUE)
        hud_collected.position = Vector2(340, 2)
        hud_collected.size = Vector2(130, 12)
        hud_collected.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        panel.add_child(hud_collected)
        # Ghost HP display (hearts)
        hud_hp = Label.new()
        hud_hp.text = "HP: " + "♥".repeat(ghost_hp) + "·".repeat(ghost_hp_max - ghost_hp)
        hud_hp.add_theme_font_size_override("font_size", 8)
        hud_hp.add_theme_color_override("font_color", Palette.TEXT_RED)
        hud_hp.position = Vector2(190, 2)
        hud_hp.size = Vector2(120, 12)
        panel.add_child(hud_hp)
        hud_hint = Label.new()
        hud_hint.text = "WASD: move | E: interact"
        hud_hint.add_theme_font_size_override("font_size", 8)
        hud_hint.add_theme_color_override("font_color", Palette.TEXT_DIM)
        hud_hint.position = Vector2(0, VIEW_H - 12)
        hud_hint.size = Vector2(VIEW_W, 10)
        hud_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        hud_layer.add_child(hud_hint)

func _physics_process(delta: float) -> void:
        if finished:
                return
        if Juice.is_hit_stopped():
                return
        ghost_bob += delta * 6.0
        ghost_squash = lerp(ghost_squash, 1.0, 1.0 - exp(-delta * 8.0))
        # Movement with acceleration + friction (momentum-based, not instant)
        var input_dir := Vector2.ZERO
        if active_qte.is_empty():
                if Input.is_action_pressed("move_left"):  input_dir.x -= 1
                if Input.is_action_pressed("move_right"): input_dir.x += 1
                if Input.is_action_pressed("move_up"):    input_dir.y -= 1
                if Input.is_action_pressed("move_down"):  input_dir.y += 1
        if input_dir != Vector2.ZERO:
                input_dir = input_dir.normalized()
                ghost_facing = input_dir
                ghost_vel = ghost_vel.move_toward(input_dir * ghost_speed, ghost_accel * delta)
        else:
                ghost_vel = ghost_vel.move_toward(Vector2.ZERO, ghost_friction * delta * ghost_speed / 10.0)
        ghost_pos += ghost_vel * delta
        ghost_pos.x = clampf(ghost_pos.x, TILE, (CORRIDOR_W - 1) * TILE)
        ghost_pos.y = clampf(ghost_pos.y, 22, (CORRIDOR_H - 1) * TILE)
        # Camera: smooth follow with look-ahead in movement direction
        # Look-ahead offset based on velocity (not just fixed +40)
        var look_ahead := ghost_facing * 24.0
        var cam_target_y := ghost_pos.y + look_ahead.y
        var cam_target_x := ghost_pos.x + look_ahead.x * 0.3  # less horizontal drift
        camera_y = lerpf(camera_y, cam_target_y, 1.0 - exp(-delta * 6.0))
        # Snap camera to integer positions — THIS IS THE JITTER FIX
        cam.position = Vector2(int(cam_target_x), int(camera_y))
        cam.offset = Vector2(0, 0) + Juice.get_shake_offset()
        # Interactions
        _find_nearest_interactive()
        if Input.is_action_just_pressed("interact") and not interact_pressed:
                interact_pressed = true
                _handle_interact()
        if not Input.is_action_pressed("interact"):
                interact_pressed = false
        # V2: Hazards do NOT damage on touch — only on QTE failure.
        for h in hazards:
                h.cooldown = max(0, h.cooldown - delta)
        ghost_invuln = max(0, ghost_invuln - delta)
        # Exit
        if ghost_pos.distance_to(exit_pos) < 12:
                _finish()
        # QTE
        if not active_qte.is_empty():
                _update_qte(delta)
        # Particles
        Juice.update_particles(delta)
        queue_redraw()

func _find_nearest_interactive() -> void:
        near_interactive = null
        if not active_qte.is_empty():
                return
        var best_dist: float = INTERACT_RADIUS
        for c in corpses:
                if not c.collected and ghost_pos.distance_to(c.pos) < best_dist:
                        best_dist = ghost_pos.distance_to(c.pos)
                        near_interactive = c
        for h in hazards:
                if h.active and ghost_pos.distance_to(h.pos) < best_dist:
                        best_dist = ghost_pos.distance_to(h.pos)
                        near_interactive = h
        if near_interactive is Dictionary:
                if near_interactive.has("corpse_name"):
                        hud_hint.text = "[E] Salvage %s" % near_interactive.gear_name
                elif near_interactive.has("type"):
                        hud_hint.text = "Hazard: %s — step away or [E] to disarm" % near_interactive.type.to_upper()
        else:
                hud_hint.text = "WASD:move E:interact Find exit"

func _handle_interact() -> void:
        if near_interactive is Dictionary:
                if near_interactive.has("corpse_name") and not near_interactive.collected:
                        _collect_corpse(near_interactive)
                elif near_interactive.has("type") and near_interactive.active:
                        _start_qte(near_interactive)

func _collect_corpse(c: Dictionary) -> void:
        c.collected = true
        collected_count += 1
        hud_collected.text = "Salvaged: %d" % collected_count
        # V2: If the corpse carries an actual weapon object (from a dead party member),
        # use THAT weapon — preserving its name, history, kill log, authoring fingerprints.
        # Only create a new random weapon if this is a bonus corpse.
        var w: Weapon = c.get("weapon", null)
        if w == null:
                # Bonus corpse — create a new random weapon
                w = Weapon.new(c.gear_type, c.gear_name, "Salvaged from %s, %s." % [c.corpse_name, c.death_cause])
                w.state = c.gear_state
                w.durability_max = Weapon.BASE_DURABILITY + GameState.meta_upgrades["sturdy_grip"] * 25
                w.durability = int(w.durability_max * 0.5)
                w.sharpness = randf_range(0.3, 0.6)
                w.balance = randf_range(0.3, 0.6)
                w.power = randf_range(0.3, 0.6)
                w.mystic = randf_range(0.3, 0.6)
        else:
                # Actual fallen party member's weapon — preserve everything, just add history
                w.history.append("Salvaged from %s, %s." % [c.corpse_name, c.death_cause])
        w.history.append("Here lies %s, %s." % [c.corpse_name, c.death_cause])
        GameState.add_weapon(w)
        ghost_squash = 1.3
        Juice.add_trauma(0.2)
        Juice.hit_stop(0.06)
        Juice.spawn_particles(c.pos, 8, Palette.TEXT_GOLD, 30.0, 0.5)
        hud_hint.text = "Salvaged %s!" % c.gear_name
        SFX.play("coin")

func _take_hazard_damage(h: Dictionary) -> void:
        h.cooldown = 1.5
        ghost_invuln = 1.0  # 1 second of i-frames
        ghost_hp -= 1  # V6: ghost has health now
        Juice.add_trauma(0.6)
        Juice.hit_stop(0.1)
        Juice.spawn_particles(ghost_pos, 10, Palette.TEXT_RED, 50.0, 0.4, Vector2(0, -1))
        SFX.play("thud")
        ghost_squash = 0.7
        if not GameState.arsenal.is_empty():
                var w: Weapon = GameState.arsenal[-1]
                w.take_durability_damage(15, "hit by %s" % h.type)
                hud_hint.text = "Hit! -1 HP | %s damaged!" % w.display_name
        else:
                hud_hint.text = "Hit! -1 HP | Ghost HP: %d/%d" % [ghost_hp, ghost_hp_max]
        var away: Vector2 = (ghost_pos - h.pos).normalized()
        ghost_pos += away * 16
        ghost_vel = away * 30  # knockback
        # If ghost is out of HP, force exit to workshop
        if ghost_hp <= 0:
                hud_hint.text = "The ghost fades... forced to retreat!"
                _finish()
        else:
                hud_hp.text = "HP: " + "♥".repeat(ghost_hp) + "·".repeat(ghost_hp_max - ghost_hp)

func _start_qte(hazard: Dictionary) -> void:
        var verb := "TAP"
        match hazard.type:
                "pit": verb = "JUMP"
                "fire": verb = "BLOW"
                "spikes": verb = "DODGE"
        active_qte = {
                "verb": verb,
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
        if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or \
           (event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_E]):
                var diff: float = absf(active_qte.marker_x - active_qte.target_x)
                if diff <= 0.15:
                        _qte_success()
                else:
                        _qte_fail()

func _qte_success() -> void:
        var h: Dictionary = active_qte.hazard
        h.active = false
        Juice.add_trauma(0.3)
        Juice.hit_stop(0.08)
        Juice.spawn_particles(h.pos, 12, Palette.TEXT_GREEN, 40.0, 0.5)
        ghost_squash = 1.2
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

func _draw() -> void:
        # Overscan: draw 3 tiles beyond viewport so edges are never visible
        var cam_top := int((camera_y - VIEW_H / 2) / TILE) - 3
        var cam_bot := int((camera_y + VIEW_H / 2) / TILE) + 3
        cam_top = max(-2, cam_top)
        cam_bot = min(CORRIDOR_H + 1, cam_bot)
        # Floor — extend beyond corridor walls so there's no hard edge
        for y in range(cam_top, cam_bot + 1):
                for x in range(-2, CORRIDOR_W + 2):
                        var p := Vector2(x * TILE, y * TILE)
                        var hash := (x * 7 + y * 13) % 31
                        if x < 0 or x >= CORRIDOR_W:
                                # Beyond walls — draw dark stone (cavern background)
                                draw_texture(Sprites.get_sprite("wall"), p)
                        elif hash < 3 and y > 5:
                                draw_texture(Sprites.get_sprite("floor_moss"), p)
                        elif hash < 6 and y > 8:
                                draw_texture(Sprites.get_sprite("floor_crack"), p)
                        elif hash < 8 and y > 10:
                                draw_texture(Sprites.get_sprite("floor_blood"), p)
                        else:
                                draw_texture(Sprites.get_sprite("floor"), p)
        # Side walls with torches (extend beyond viewport)
        for y in range(cam_top, cam_bot + 1):
                draw_texture(Sprites.get_sprite("wall"), Vector2(-TILE, y * TILE))
                draw_texture(Sprites.get_sprite("wall_mossy"), Vector2(CORRIDOR_W * TILE, y * TILE))
                if y % 4 == 0:
                        draw_texture(Sprites.get_sprite("torch"), Vector2(-TILE, y * TILE))
                        draw_texture(Sprites.get_sprite("torch"), Vector2(CORRIDOR_W * TILE, y * TILE))
                        _draw_torch_glow(Vector2(-TILE + 8, y * TILE + 8))
                        _draw_torch_glow(Vector2(CORRIDOR_W * TILE + 8, y * TILE + 8))
        # Decorative props — snapped
        for prop in props:
                if prop.pos.y > cam_top * TILE - 16 and prop.pos.y < cam_bot * TILE + 16:
                        draw_texture(Sprites.get_sprite(prop.sprite), Vector2(int(prop.pos.x), int(prop.pos.y)))
        # Hazards — all positions snapped
        for h in hazards:
                if h.active:
                        var hx := int(h.pos.x)
                        var hy := int(h.pos.y)
                        match h.type:
                                "pit":
                                        draw_texture(Sprites.get_sprite("pit"), Vector2(hx - 8, hy - 8))
                                "fire":
                                        draw_texture(Sprites.get_sprite("torch"), Vector2(hx - 8, hy - 8))
                                        _draw_fire_glow(h.pos)
                                "spikes":
                                        draw_texture(Sprites.get_sprite("floor_crack"), Vector2(hx - 8, hy - 8))
                                        for i in 3:
                                                var sx := hx - 6 + i * 6
                                                draw_rect(Rect2(sx, hy - 4, 2, 8), Palette.STEEL_LT, true)
                                                draw_rect(Rect2(sx, hy - 4, 1, 8), Palette.STEEL, true)
                        if ghost_pos.distance_to(h.pos) < 30:
                                var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
                                for i in 8:
                                        var a := i * (TAU / 8) + Time.get_ticks_msec() * 0.002
                                        var px := int(h.pos.x + cos(a) * 12)
                                        var py := int(h.pos.y + sin(a) * 12)
                                        draw_rect(Rect2(px, py, 2, 2), Color(0.95, 0.40, 0.40, pulse), true)
        # Corpses — snapped
        for c in corpses:
                var cx := int(c.pos.x)
                var cy := int(c.pos.y)
                if c.collected:
                        draw_texture(Sprites.get_sprite("bones"), Vector2(cx - 8, cy - 8))
                else:
                        draw_texture(Sprites.get_sprite("corpse"), Vector2(cx - 8, cy - 8))
                        var bob := int(sin(Time.get_ticks_msec() * 0.004 + c.pos.x) * 2)
                        var gear_tex := Sprites.get_weapon_sprite(c.gear_type, c.gear_state)
                        draw_texture(gear_tex, Vector2(cx - 8, cy - 20 + bob))
                        _draw_gear_glow(Vector2(cx, cy - 12 + bob))
                        if near_interactive == c:
                                GameFont.draw_string_centered(self, Vector2(cx, cy - 32), c.corpse_name, 8, Palette.TEXT_GOLD)
                                GameFont.draw_string_centered(self, Vector2(cx, cy - 26), c.gear_name, 8, Palette.TEXT_BLUE)
        # Exit — snapped
        var ex := int(exit_pos.x)
        var ey := int(exit_pos.y)
        draw_texture(Sprites.get_sprite("stairs"), Vector2(ex - 8, ey - 8))
        _draw_exit_glow(exit_pos)
        var exit_pulse := 0.5 + 0.3 * sin(Time.get_ticks_msec() * 0.003)
        GameFont.draw_string_centered(self, Vector2(ex, ey - 16), "EXIT", 8, Color(0.55, 0.95, 0.75, exit_pulse))
        # Ghost — snapped
        var bob := int(sin(ghost_bob) * 1.5)
        var gx := int(ghost_pos.x)
        var gy := int(ghost_pos.y)
        draw_rect(Rect2(gx - 5, gy + 6, 10, 2), Color(0, 0, 0, 0.3), true)
        var ghost_tex := Sprites.get_sprite("ghost")
        var sw := int(16.0 / maxf(0.1, ghost_squash))
        var sh := int(16 * ghost_squash)
        draw_texture_rect(ghost_tex, Rect2(gx - sw / 2, gy - sh / 2 + bob, sw, sh), false)
        # QTE bar
        if not active_qte.is_empty():
                _draw_qte_bar()
        # Particles
        Juice.draw_particles(self)
        # Progress bar (fixed at right edge of screen)
        var progress := clampf(ghost_pos.y / (CORRIDOR_H * TILE), 0, 1)
        draw_rect(Rect2(VIEW_W - 6, 24, 2, VIEW_H - 30), Palette.DARK, true)
        draw_rect(Rect2(VIEW_W - 6, 24 + int((VIEW_H - 30) * (1 - progress)), 2, int((VIEW_H - 30) * progress)), Palette.SLIME, true)

func _draw_torch_glow(pos: Vector2) -> void:
        # Radial gradient glow (pixel-art friendly: drawn as concentric circles)
        var center := Vector2(int(pos.x), int(pos.y))
        for r in [20, 14, 8]:
                var c := Palette.LIGHT_TORCH
                c.a = c.a * (1.0 - float(r) / 20.0) * 0.8
                draw_circle(center, r, c)

func _draw_fire_glow(pos: Vector2) -> void:
        var center := Vector2(int(pos.x), int(pos.y))
        for r in [16, 10, 5]:
                var c := Palette.LIGHT_FURNACE
                c.a = c.a * (1.0 - float(r) / 16.0) * 1.2
                draw_circle(center, r, c)

func _draw_gear_glow(pos: Vector2) -> void:
        var center := Vector2(int(pos.x), int(pos.y))
        for r in [8, 5, 3]:
                var c := Color(0.95, 0.85, 0.40, 0.15 * (1.0 - float(r) / 8.0))
                draw_circle(center, r, c)

func _draw_exit_glow(pos: Vector2) -> void:
        var center := Vector2(int(pos.x), int(pos.y))
        for r in [16, 10, 5]:
                var c := Palette.LIGHT_EXIT
                c.a = c.a * (1.0 - float(r) / 16.0) * 1.5
                draw_circle(center, r, c)

func _draw_qte_bar() -> void:
        var h: Dictionary = active_qte.hazard
        var bar_center: Vector2 = h.pos + Vector2(0, -24)
        var bar_w := 24
        var bar_h := 4
        draw_rect(Rect2(int(bar_center.x) - bar_w / 2, int(bar_center.y), bar_w, bar_h), Palette.VOID, true)
        var tz_x := int(bar_center.x) - bar_w / 2 + int(bar_w * (active_qte.target_x - 0.15))
        draw_rect(Rect2(tz_x, int(bar_center.y), int(bar_w * 0.30), bar_h), Palette.SLIME, true)
        var mx := int(bar_center.x) - bar_w / 2 + int(bar_w * active_qte.marker_x)
        draw_rect(Rect2(mx, int(bar_center.y) - 1, 2, bar_h + 2), Palette.TEXT_GOLD, true)
        GameFont.draw_string_centered(self, bar_center + Vector2(0, -6), active_qte.verb, 8, Palette.TEXT_GOLD)
