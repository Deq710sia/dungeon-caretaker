extends Node2D
## Phase: workshop — walk between stations, repair weapons, ring bell.
## Uses the shared GhostMovement script for normalized movement + phase verb.
## Adventurers centered across room width. Station positions use ROOM_W fractions.

const ROOM_W: int = 480
const ROOM_H: int = 270
const HUD_H: int = 20
const STATION_RADIUS: float = 16.0

# Stations positioned as fractions of ROOM_W so they scale to any resolution.
# Was hardcoded x values (50, 140, 230, 320, 410) that only worked at 480.
const STATIONS := [
        {"key": "arsenal",   "name": "ARSENAL", "sprite": "chest",      "x_frac": 0.10},
        {"key": "polish",    "name": "POLISH",  "sprite": "bench",      "x_frac": 0.29},
        {"key": "oil_grind", "name": "GRIND",   "sprite": "grindstone", "x_frac": 0.48},
        {"key": "exorcise",  "name": "ALTAR",   "sprite": "altar",      "x_frac": 0.67},
        {"key": "reforge",   "name": "FORGE",   "sprite": "furnace",    "x_frac": 0.86},
]
const STATION_Y: float = 70.0

var move: GhostMovement
var bell_timer: float = 90.0
var bell_rang: bool = false
var minigame_active: bool = false
var active_minigame: Node2D = null
var current_weapon: Weapon = null
var current_station_key: String = ""
var near_station_key: String = ""
var interact_pressed: bool = false
var adventurers: Array = []
var carrying: Weapon = null  # replaced carrying

var hud_stage: Label
var hud_bell: Label
var hud_shards: Label
var hud_carrying: Label
var prompt_label: Label
var ring_bell_btn: Button
var inspect_panel: Panel = null
var inspect_visible: bool = false

func _ready() -> void:
        if GameState.party.is_empty():
                GameState.start_new_run()
        move = GhostMovement.new()
        move.reset(Vector2(ROOM_W / 2.0, ROOM_H * 0.6))
        _adventurers_arrive()
        _build_hud()
        bell_timer = max(50.0, 90.0 - GameState.stage * 5)

func _get_station_pos(key: String) -> Vector2:
        for st in STATIONS:
                if st.key == key:
                        return Vector2(st.x_frac * ROOM_W, STATION_Y)
        return Vector2(ROOM_W / 2, STATION_Y)

func _adventurers_arrive() -> void:
        adventurers.clear()
        var living := GameState.party.filter(func(a): return a.get("alive", true))
        var n := living.size()
        # Center adventurers across the room width (was offset to the left).
        # Spread them across 80% of the room width, centered.
        var spread := ROOM_W * 0.80
        var start_x := (ROOM_W - spread) / 2.0 + spread / float(max(1, n)) / 2.0
        var spacing := spread / float(max(1, n))
        for i in n:
                var adv: Dictionary = living[i]
                adventurers.append({
                        "pos": Vector2(start_x + i * spacing, ROOM_H - 60),
                        "sprite": "knight" if adv["class"] == "knight" else "mage",
                        "adv": adv,
                })

func _build_hud() -> void:
        var panel := Panel.new()
        panel.position = Vector2(0, 0)
        panel.size = Vector2(ROOM_W, 20)
        add_child(panel)
        hud_stage = Label.new()
        hud_stage.text = "S%d W%d WORKSHOP" % [GameState.stage, GameState.wave]
        hud_stage.add_theme_font_size_override("font_size", 8)
        hud_stage.add_theme_color_override("font_color", Palette.TEXT_GOLD)
        hud_stage.position = Vector2(2, 3)
        hud_stage.size = Vector2(130, 14)
        panel.add_child(hud_stage)
        hud_bell = Label.new()
        hud_bell.text = "Bell: 75s"
        hud_bell.add_theme_font_size_override("font_size", 8)
        hud_bell.add_theme_color_override("font_color", Palette.TEXT_RED)
        hud_bell.position = Vector2(135, 3)
        hud_bell.size = Vector2(90, 14)
        panel.add_child(hud_bell)
        hud_shards = Label.new()
        hud_shards.text = "Shards: 0"
        hud_shards.add_theme_font_size_override("font_size", 8)
        hud_shards.add_theme_color_override("font_color", Palette.TEXT_BLUE)
        hud_shards.position = Vector2(228, 3)
        hud_shards.size = Vector2(90, 14)
        panel.add_child(hud_shards)
        hud_carrying = Label.new()
        hud_carrying.text = "Carry: -"
        hud_carrying.add_theme_font_size_override("font_size", 8)
        hud_carrying.add_theme_color_override("font_color", Palette.TEXT_DIM)
        hud_carrying.position = Vector2(322, 3)
        hud_carrying.size = Vector2(150, 14)
        panel.add_child(hud_carrying)
        prompt_label = Label.new()
        prompt_label.text = ""
        prompt_label.add_theme_font_size_override("font_size", 8)
        prompt_label.add_theme_color_override("font_color", Palette.TEXT_GOLD)
        prompt_label.add_theme_color_override("font_outline_color", Palette.VOID)
        prompt_label.add_theme_constant_override("outline_size", 1)
        prompt_label.position = Vector2(0, 0)
        prompt_label.size = Vector2(ROOM_W, 10)
        prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        add_child(prompt_label)
        ring_bell_btn = Button.new()
        ring_bell_btn.text = "Ring Bell"
        ring_bell_btn.add_theme_font_size_override("font_size", 8)
        ring_bell_btn.position = Vector2(380, 240)
        ring_bell_btn.size = Vector2(80, 18)
        ring_bell_btn.pressed.connect(_on_ring_bell)
        add_child(ring_bell_btn)
        GameState.shards_changed.connect(_on_shards_changed)
        _update_hud()

func _update_hud() -> void:
        hud_bell.text = "%.0fs" % bell_timer
        hud_shards.text = "Shards: %d" % GameState.soul_shards
        if carrying != null:
                var w: Weapon = carrying
                hud_carrying.text = "Carry: " + w.display_name.substr(0, 12)
                hud_carrying.add_theme_color_override("font_color", w.wear_color())
        else:
                hud_carrying.text = "Carry: -"
                hud_carrying.add_theme_color_override("font_color", Palette.TEXT_DIM)

func _on_shards_changed(new_count: int) -> void:
        hud_shards.text = "Shards: %d" % new_count

func _process(delta: float) -> void:
        # Reset interact_pressed BEFORE any early returns
        if not Input.is_action_pressed("interact"):
                interact_pressed = false
        if minigame_active:
                move.bob += delta * 6
                return
        if Juice.is_hit_stopped():
                return
        bell_timer -= delta
        if bell_timer <= 0:
                bell_timer = 0
                _bell_tolls()
                return
        # Input + movement via shared GhostMovement
        var input_dir := Vector2.ZERO
        if Input.is_action_pressed("move_left"):  input_dir.x -= 1
        if Input.is_action_pressed("move_right"): input_dir.x += 1
        if Input.is_action_pressed("move_up"):    input_dir.y -= 1
        if Input.is_action_pressed("move_down"):  input_dir.y += 1
        # Sidestep
        move.update_pulse(delta)
        move.update(input_dir, delta)
        # FIX: zero velocity on clamped axis (prevents momentum buildup against walls)
        # v0.38: use bleed_wall_velocity — when coasting, bleed 50% not full zero
        var new_x: float = clampf(move.pos.x, 12, ROOM_W - 12)
        if new_x != move.pos.x:
                move.bleed_wall_velocity("x")
        move.pos.x = new_x
        var new_y: float = clampf(move.pos.y, HUD_H + 30, ROOM_H - 40)
        if new_y != move.pos.y:
                move.bleed_wall_velocity("y")
        move.pos.y = new_y
        _find_nearest_interactive()
        if Input.is_action_just_pressed("interact") and not interact_pressed:
                interact_pressed = true
                _handle_interact()
        # Phase verb
        if Input.is_action_just_pressed("phase"):
                move.try_activate_phase()
        # TAB to inspect carried weapon
        if Input.is_key_pressed(KEY_TAB) and carrying != null and not inspect_visible:
                _show_weapon_inspect(carrying)
        if not Input.is_key_pressed(KEY_TAB) and inspect_visible:
                _hide_weapon_inspect()
        Juice.update_particles(delta)
        _update_hud()
        queue_redraw()

func _find_nearest_interactive() -> void:
        near_station_key = ""
        var best_dist: float = STATION_RADIUS
        for st in STATIONS:
                var d: float = move.pos.distance_to(_get_station_pos(st.key))
                if d < best_dist:
                        best_dist = d
                        near_station_key = st.key
        prompt_label.text = ""
        prompt_label.position = Vector2(0, 0)
        if near_station_key == "arsenal":
                if carrying == null:
                        if GameState.arsenal.size() > 0:
                                prompt_label.text = "[E] Pick up (%d in arsenal)" % GameState.arsenal.size()
                        else:
                                prompt_label.text = "Arsenal empty"
                else:
                        prompt_label.text = "[E] Drop weapon back"
        elif near_station_key != "":
                var st_def: Dictionary = _get_station_def(near_station_key)
                if carrying != null:
                        if carrying.can_repair_at(near_station_key):
                                prompt_label.text = "[E] Repair at %s" % st_def.name
                        else:
                                prompt_label.text = "%s — doesn't need this" % st_def.name
                else:
                        prompt_label.text = st_def.name
        if prompt_label.text != "":
                prompt_label.position = Vector2(0, move.pos.y - 24)

func _get_station_def(key: String) -> Dictionary:
        for st in STATIONS:
                if st.key == key:
                        return st
        return {}

func _handle_interact() -> void:
        if near_station_key == "":
                return
        if near_station_key == "arsenal":
                if carrying == null:
                        _pick_up_from_arsenal()
                else:
                        GameState.add_weapon(carrying)
                        carrying = null; move.carry_count = 0
                return
        if carrying != null:
                if carrying.can_repair_at(near_station_key):
                        _start_repair(near_station_key)

func _pick_up_from_arsenal() -> void:
        if GameState.arsenal.is_empty():
                return
        var picked: Weapon = null
        # Prefer whatever actually needs a station right now — checked against
        # wear_state/is_haunted(), not the old flavor-only state field, so gear
        # that's taken real durability damage is never invisible to the ghost.
        for w in GameState.arsenal:
                if w.wear_state != Weapon.WearState.PRISTINE or w.is_haunted():
                        picked = w
                        break
        if picked == null:
                picked = GameState.arsenal[0]
        carrying = picked; move.carry_count = 1
        GameState.arsenal.erase(picked)
        GameState.arsenal_changed.emit()
        Juice.spawn_particles(move.pos, 4, Palette.TEXT_GOLD, 20.0, 0.3)

func _start_repair(station_key: String) -> void:
        if minigame_active:
                return
        current_weapon = carrying
        current_station_key = station_key
        minigame_active = true
        var script: GDScript = null
        match station_key:
                "polish":    script = preload("res://scripts/repair/polish_bench.gd")
                "oil_grind": script = preload("res://scripts/repair/oil_grindstone.gd")
                "exorcise":  script = preload("res://scripts/repair/exorcise_altar.gd")
                "reforge":   script = preload("res://scripts/repair/reforge_furnace.gd")
                _:
                        minigame_active = false
                        return
        active_minigame = Node2D.new()
        active_minigame.set_script(script)
        active_minigame.name = "Minigame_" + station_key
        add_child(active_minigame)
        active_minigame.completed.connect(_on_minigame_completed)

func _on_minigame_completed(quality: float) -> void:
        if active_minigame:
                active_minigame.queue_free()
                active_minigame = null
        minigame_active = false
        if current_weapon == null:
                current_station_key = ""
                return
        var bonus: float = float(GameState.meta_upgrades["master_forge"]) * 0.10
        quality = clampf(quality + bonus, 0.0, 1.0)
        var stat_key := current_weapon.fingerprint_stat_for_station(current_station_key)
        if stat_key != "":
                current_weapon.set(stat_key, quality)
        if current_station_key == "exorcise":
                # The Altar's real job: clear unexorcised dread. It doesn't touch
                # durability/wear at all — a weapon can be fully cleansed and still
                # need the Forge, or fully repaired and still need the Altar.
                current_weapon.exorcise()
                Juice.add_trauma(0.25)
                Juice.hit_stop(0.06)
                Juice.spawn_particles(move.pos, 10, Palette.GLOW_BLUE, 40.0, 0.5)
                SFX.play("repair")
                move.squash = 1.2
        else:
                # Graduated restore — never a full reset. A single great pass on a
                # badly damaged weapon still leaves real, visible cost behind.
                var restored: int = current_weapon.apply_repair(quality)
                current_weapon.history.append(
                        "Repaired at %s (q=%.0f%%, +%d durability, now %d/%d)." % [
                                current_station_key, quality * 100, restored,
                                current_weapon.durability, current_weapon.durability_max])
                if restored > 0:
                        var trauma: float = 0.15 + 0.15 * quality
                        Juice.add_trauma(trauma)
                        Juice.hit_stop(0.06)
                        Juice.spawn_particles(move.pos, int(6 + quality * 8), Palette.TEXT_GOLD, 40.0, 0.5)
                        SFX.play("repair")
                        move.squash = 1.1 + quality * 0.2
        GameState.arsenal_changed.emit()
        # Keep the weapon in the ghost's hands after repair. The player can
        # see the repaired weapon, take it to another station (e.g. grind then
        # altar), or drop it at the arsenal (press E at arsenal while carrying).
        #
        # The previous code auto-returned the weapon to arsenal, which caused
        # the "item disappears" bug: the weapon went back to the arsenal pile
        # but the player couldn't tell which weapon it was or easily pick it
        # up again (the arsenal picker prefers weapons that still need work,
        # so a freshly-repaired PRISTINE weapon would never be re-selected).
        # Keeping it visible in the ghost's hands is clearer and gives the
        # player agency over where the weapon goes next.
        current_weapon = null
        current_station_key = ""

func _on_ring_bell() -> void:
        bell_timer = 0
        _bell_tolls()

func _bell_tolls() -> void:
        if bell_rang:
                return
        bell_rang = true
        Juice.add_trauma(0.5)
        SFX.play("bell")
        Juice.hit_stop(0.1)
        if carrying != null:
                GameState.add_weapon(carrying)
                carrying = null; move.carry_count = 0
        await get_tree().create_timer(0.3).timeout
        GameState.set_phase("upgrade")

func _draw() -> void:
        # Floor with subtle variation
        for y in range(HUD_H + 8, ROOM_H - 8, 16):
                for x in range(0, ROOM_W, 16):
                        var hash := (x / 16 * 7 + y / 16 * 13) % 31
                        if hash < 3:
                                draw_texture(Sprites.get_sprite("floor_crack"), Vector2(x, y))
                        elif hash < 5:
                                draw_texture(Sprites.get_sprite("floor_moss"), Vector2(x, y))
                        else:
                                draw_texture(Sprites.get_sprite("floor"), Vector2(x, y))
        # Walls
        for x in range(0, ROOM_W, 16):
                draw_texture(Sprites.get_sprite("wall"), Vector2(x, HUD_H))
                draw_texture(Sprites.get_sprite("wall"), Vector2(x, ROOM_H - 8))
        # Wall torches for ambient light
        for x in [32, 160, 288]:
                draw_texture(Sprites.get_sprite("torch"), Vector2(x, HUD_H))
                DrawUtils.draw_glow(self, Vector2(x + 8, HUD_H + 8), 20, Palette.LIGHT_TORCH)
        # Stations
        for st in STATIONS:
                var tex := Sprites.get_sprite(st.sprite)
                # Shadow
                draw_rect(Rect2(int(_get_station_pos(st.key).x) - 9, int(_get_station_pos(st.key).y) - 6, 18, 4), Color(0, 0, 0, 0.3), true)
                draw_texture(tex, _get_station_pos(st.key) - Vector2(8, 8))
                # Ambient glow for specific stations
                match st.key:
                        "furnace": DrawUtils.draw_glow(self, _get_station_pos(st.key), 24, Palette.LIGHT_FURNACE)
                        "exorcise": DrawUtils.draw_glow(self, _get_station_pos(st.key), 20, Palette.LIGHT_ALTAR)
                if near_station_key == st.key:
                        var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
                        draw_rect(Rect2(_get_station_pos(st.key).x - 12, _get_station_pos(st.key).y - 12, 24, 24), Color(0.95, 0.85, 0.40, pulse), false, 1)
                GameFont.draw_string_centered(self, _get_station_pos(st.key) + Vector2(0, 18), st.name, 8, Palette.TEXT)
                # Arsenal weapon pile
                if st.key == "arsenal" and GameState.arsenal.size() > 0:
                        var pile_count: int = min(GameState.arsenal.size(), 3)
                        for i in pile_count:
                                var w: Weapon = GameState.arsenal[i]
                                var gear_tex := Sprites.get_weapon_sprite_wear(w.type, w.wear_state, w.is_haunted())
                                draw_texture(gear_tex, _get_station_pos(st.key) + Vector2(-12 + i * 8, -18))
        # Adventurers
        for a in adventurers:
                var tex := Sprites.get_sprite(a.sprite)
                draw_rect(Rect2(int(a.pos.x) - 5, int(a.pos.y) + 6, 10, 2), Color(0, 0, 0, 0.3), true)
                draw_texture(tex, a.pos - Vector2(8, 8))
                GameFont.draw_string_centered(self, a.pos + Vector2(0, -12), a.adv.name, 8, Palette.TEXT)
                # Equipped weapon
                if a.adv.get("equipped_weapon") != null:
                        var w: Weapon = a.adv.equipped_weapon
                        draw_texture(Sprites.get_weapon_sprite_wear(w.type, w.wear_state, w.is_haunted()), a.pos + Vector2(8, -4))
        # Ghost (shared draw method)
        GhostMovement.draw_ghost(self, move)
        # Carried weapon
        if carrying != null:
                var item_tex := Sprites.get_weapon_sprite_wear(carrying.type, carrying.wear_state, carrying.is_haunted())
                var gp: Vector2 = move.pos + Vector2(0, sin(move.bob) * 1.5)
                draw_texture(item_tex, gp + Vector2(-8, -16))
        # Particles
        Juice.draw_particles(self)
        # Hint
        GameFont.draw_string_centered(self, Vector2(ROOM_W / 2, ROOM_H - 6), "WASD:move E:interact SPACE:phase SHIFT:pulse TAB:inspect  M:mute", 8, Palette.TEXT_DIM)

func _show_weapon_inspect(w: Weapon) -> void:
        if inspect_panel:
                inspect_panel.queue_free()
        inspect_visible = true
        inspect_panel = Panel.new()
        inspect_panel.position = Vector2(40, 30)
        inspect_panel.size = Vector2(240, 120)
        add_child(inspect_panel)
        var title := Label.new()
        title.text = w.display_name
        title.add_theme_font_size_override("font_size", 8)
        title.add_theme_color_override("font_color", w.wear_color())
        title.position = Vector2(8, 4)
        title.size = Vector2(224, 12)
        inspect_panel.add_child(title)
        var state_line := Label.new()
        state_line.text = "State: %s | Wear: %s" % [w.state_name(), w.wear_name()]
        state_line.add_theme_font_size_override("font_size", 8)
        state_line.add_theme_color_override("font_color", Palette.TEXT)
        state_line.position = Vector2(8, 18)
        state_line.size = Vector2(224, 10)
        inspect_panel.add_child(state_line)
        var dur_line := Label.new()
        dur_line.text = "Durability: %d/%d" % [w.durability, w.durability_max]
        dur_line.add_theme_font_size_override("font_size", 8)
        dur_line.add_theme_color_override("font_color", Palette.TEXT)
        dur_line.position = Vector2(8, 30)
        dur_line.size = Vector2(224, 10)
        inspect_panel.add_child(dur_line)
        var stats := Label.new()
        stats.text = "SHP:%d%% BAL:%d%% PWR:%d%% MYS:%d%%" % [int(w.sharpness*100), int(w.balance*100), int(w.power*100), int(w.mystic*100)]
        stats.add_theme_font_size_override("font_size", 8)
        stats.add_theme_color_override("font_color", Palette.TEXT_BLUE)
        stats.position = Vector2(8, 42)
        stats.size = Vector2(224, 10)
        inspect_panel.add_child(stats)
        var blurb := Label.new()
        blurb.text = w.authoring_blurb()
        blurb.add_theme_font_size_override("font_size", 8)
        blurb.add_theme_color_override("font_color", Palette.TEXT_DIM)
        blurb.position = Vector2(8, 54)
        blurb.size = Vector2(224, 20)
        blurb.autowrap_mode = TextServer.AUTOWRAP_WORD
        inspect_panel.add_child(blurb)
        var wielder := Label.new()
        wielder.text = "Wielder: %s | Kills: %d" % [w.wielder if w.wielder != "" else "unassigned", w.kill_log.size()]
        wielder.add_theme_font_size_override("font_size", 8)
        wielder.add_theme_color_override("font_color", Palette.TEXT_DIM)
        wielder.position = Vector2(8, 76)
        wielder.size = Vector2(224, 10)
        inspect_panel.add_child(wielder)
        if w.is_haunted():
                var haunt := Label.new()
                haunt.text = "Haunted: %d unexorcised death(s) — Altar" % w.unexorcised_deaths
                haunt.add_theme_font_size_override("font_size", 8)
                haunt.add_theme_color_override("font_color", Palette.STATE_HAUNTED)
                haunt.position = Vector2(8, 88)
                haunt.size = Vector2(224, 10)
                inspect_panel.add_child(haunt)
        var hint := Label.new()
        hint.text = "[TAB] close"
        hint.add_theme_font_size_override("font_size", 8)
        hint.add_theme_color_override("font_color", Palette.TEXT_GOLD)
        hint.position = Vector2(8, 104)
        hint.size = Vector2(224, 10)
        inspect_panel.add_child(hint)

func _hide_weapon_inspect() -> void:
        if inspect_panel:
                inspect_panel.queue_free()
                inspect_panel = null
        inspect_visible = false

func _on_phase_exit() -> void:
        if carrying != null:
                GameState.add_weapon(carrying)
                carrying = null; move.carry_count = 0
