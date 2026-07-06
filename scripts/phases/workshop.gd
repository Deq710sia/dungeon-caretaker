extends Node2D
## Phase: workshop V4 — 320x180, palette-disciplined, juice.
## Walk between stations. Repair minigames show weapon large. Ring bell to
## move on to the upgrade shop, then planning to assign the gear you just fixed.

const ROOM_W: int = 320
const ROOM_H: int = 180
const HUD_H: int = 14
const STATION_RADIUS: float = 16.0

const STATIONS := [
        {"key": "arsenal",   "name": "ARSENAL",   "sprite": "chest",      "pos": Vector2(30, 50)},
        {"key": "polish",    "name": "POLISH",    "sprite": "bench",      "pos": Vector2(90, 50),  "states": [Weapon.State.BLOODIED]},
        {"key": "oil_grind", "name": "GRIND",     "sprite": "grindstone", "pos": Vector2(150, 50), "states": [Weapon.State.RUSTED]},
        {"key": "exorcise",  "name": "EXORCISE",  "sprite": "altar",      "pos": Vector2(210, 50), "states": [Weapon.State.HAUNTED, Weapon.State.CURSED]},
        {"key": "reforge",   "name": "REFORGE",   "sprite": "furnace",    "pos": Vector2(270, 50), "states": [Weapon.State.SHATTERED]},
]

var ghost: Dictionary = {
        "pos": Vector2(160, 110),
        "vel": Vector2.ZERO,
        "speed": 55.0,
        "accel": 300.0,
        "carrying": null,
        "bob": 0.0,
        "squash": 1.0,
}
var bell_timer: float = 75.0
var bell_rang: bool = false
var minigame_active: bool = false
var active_minigame: Node2D = null
var current_weapon: Weapon = null
var near_station_key: String = ""
var interact_pressed: bool = false
var adventurers: Array = []

var hud_stage: Label
var hud_bell: Label
var hud_shards: Label
var hud_carrying: Label
var prompt_label: Label
var ring_bell_btn: Button

func _ready() -> void:
        if GameState.party.is_empty():
                # Defensive fallback only — normal flow always starts a run with a party.
                GameState.start_new_run()
        _adventurers_arrive()
        _build_hud()
        bell_timer = max(50.0, 90.0 - GameState.stage * 5)

func _adventurers_arrive() -> void:
        adventurers.clear()
        var living := GameState.party.filter(func(a): return a.get("alive", true))
        var n := living.size()
        var spacing: float = 200.0 / float(max(1, n))
        var start_x: float = 60.0 + spacing / 2.0
        for i in n:
                var adv: Dictionary = living[i]
                adventurers.append({
                        "pos": Vector2(start_x + i * spacing, 130),
                        "sprite": "knight" if adv["class"] == "knight" else "mage",
                        "adv": adv,
                })

func _build_hud() -> void:
        var panel := Panel.new()
        panel.position = Vector2(0, 0)
        panel.size = Vector2(ROOM_W, HUD_H)
        add_child(panel)
        hud_stage = Label.new()
        hud_stage.text = "S%d W%d WORKSHOP" % [GameState.stage, GameState.wave]
        hud_stage.add_theme_font_size_override("font_size", 8)
        hud_stage.add_theme_color_override("font_color", Palette.TEXT_GOLD)
        hud_stage.position = Vector2(2, 2)
        hud_stage.size = Vector2(120, 10)
        panel.add_child(hud_stage)
        hud_bell = Label.new()
        hud_bell.text = "Bell: 75s"
        hud_bell.add_theme_font_size_override("font_size", 8)
        hud_bell.add_theme_color_override("font_color", Palette.TEXT_RED)
        hud_bell.position = Vector2(125, 2)
        hud_bell.size = Vector2(50, 10)
        panel.add_child(hud_bell)
        hud_shards = Label.new()
        hud_shards.text = "Shards: 0"
        hud_shards.add_theme_font_size_override("font_size", 8)
        hud_shards.add_theme_color_override("font_color", Palette.TEXT_BLUE)
        hud_shards.position = Vector2(180, 2)
        hud_shards.size = Vector2(60, 10)
        panel.add_child(hud_shards)
        hud_carrying = Label.new()
        hud_carrying.text = "Carry: -"
        hud_carrying.add_theme_font_size_override("font_size", 8)
        hud_carrying.add_theme_color_override("font_color", Palette.TEXT_DIM)
        hud_carrying.position = Vector2(240, 2)
        hud_carrying.size = Vector2(76, 10)
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
        ring_bell_btn.position = Vector2(250, 160)
        ring_bell_btn.size = Vector2(60, 14)
        ring_bell_btn.pressed.connect(_on_ring_bell)
        add_child(ring_bell_btn)
        GameState.shards_changed.connect(_on_shards_changed)
        _update_hud()

func _update_hud() -> void:
        hud_bell.text = "Bell: %.0fs" % bell_timer
        hud_shards.text = "Shards: %d" % GameState.soul_shards
        if ghost.carrying != null:
                var w: Weapon = ghost.carrying
                hud_carrying.text = "Carry: %s" % w.display_name
                hud_carrying.add_theme_color_override("font_color", w.wear_color())
        else:
                hud_carrying.text = "Carry: -"
                hud_carrying.add_theme_color_override("font_color", Palette.TEXT_DIM)

func _on_shards_changed(new_count: int) -> void:
        hud_shards.text = "Shards: %d" % new_count

func _process(delta: float) -> void:
        if minigame_active:
                ghost.bob += delta * 6
                return
        if Juice.is_hit_stopped():
                return
        bell_timer -= delta
        if bell_timer <= 0:
                bell_timer = 0
                _bell_tolls()
                return
        ghost.bob += delta * 6
        ghost.squash = lerp(ghost.squash, 1.0, 1.0 - exp(-delta * 8.0))
        # Momentum-based movement
        var input_dir := Vector2.ZERO
        if Input.is_action_pressed("move_left"):  input_dir.x -= 1
        if Input.is_action_pressed("move_right"): input_dir.x += 1
        if Input.is_action_pressed("move_up"):    input_dir.y -= 1
        if Input.is_action_pressed("move_down"):  input_dir.y += 1
        if input_dir != Vector2.ZERO:
                input_dir = input_dir.normalized()
                ghost.vel = ghost.vel.move_toward(input_dir * ghost.speed, ghost.accel * delta)
        else:
                ghost.vel = ghost.vel.move_toward(Vector2.ZERO, ghost.accel * delta)
        ghost.pos += ghost.vel * delta
        ghost.pos.x = clampf(ghost.pos.x, 12, ROOM_W - 12)
        ghost.pos.y = clampf(ghost.pos.y, HUD_H + 30, ROOM_H - 30)
        _find_nearest_interactive()
        if Input.is_action_just_pressed("interact") and not interact_pressed:
                interact_pressed = true
                _handle_interact()
        if not Input.is_action_pressed("interact"):
                interact_pressed = false
        Juice.update_particles(delta)
        _update_hud()
        queue_redraw()

func _find_nearest_interactive() -> void:
        near_station_key = ""
        var best_dist: float = STATION_RADIUS
        for st in STATIONS:
                var d: float = ghost.pos.distance_to(st.pos)
                if d < best_dist:
                        best_dist = d
                        near_station_key = st.key
        prompt_label.text = ""
        prompt_label.position = Vector2(0, 0)
        if near_station_key == "arsenal":
                if ghost.carrying == null:
                        if GameState.arsenal.size() > 0:
                                prompt_label.text = "[E] Pick up (%d in arsenal)" % GameState.arsenal.size()
                        else:
                                prompt_label.text = "Arsenal empty"
                else:
                        prompt_label.text = "[E] Drop weapon back"
        elif near_station_key != "":
                var st_def: Dictionary = _get_station_def(near_station_key)
                if ghost.carrying != null:
                        if ghost.carrying.state in st_def.get("states", []):
                                prompt_label.text = "[E] Repair at %s" % st_def.name
                        else:
                                prompt_label.text = "%s — wrong state" % st_def.name
                else:
                        prompt_label.text = st_def.name
        if prompt_label.text != "":
                prompt_label.position = Vector2(0, ghost.pos.y - 24)

func _get_station_def(key: String) -> Dictionary:
        for st in STATIONS:
                if st.key == key:
                        return st
        return {}

func _handle_interact() -> void:
        if near_station_key == "":
                return
        if near_station_key == "arsenal":
                if ghost.carrying == null:
                        _pick_up_from_arsenal()
                else:
                        GameState.add_weapon(ghost.carrying)
                        ghost.carrying = null
                return
        if ghost.carrying != null:
                var st_def: Dictionary = _get_station_def(near_station_key)
                if ghost.carrying.state in st_def.get("states", []):
                        _start_repair(near_station_key)

func _pick_up_from_arsenal() -> void:
        if GameState.arsenal.is_empty():
                return
        var picked: Weapon = null
        for w in GameState.arsenal:
                if w.state != Weapon.State.PRISTINE and not w.is_broken:
                        picked = w
                        break
        if picked == null:
                picked = GameState.arsenal[0]
        ghost.carrying = picked
        GameState.arsenal.erase(picked)
        GameState.arsenal_changed.emit()
        Juice.spawn_particles(ghost.pos, 4, Palette.TEXT_GOLD, 20.0, 0.3)

func _start_repair(station_key: String) -> void:
        if minigame_active:
                return
        current_weapon = ghost.carrying
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
                return
        var bonus: float = float(GameState.meta_upgrades["master_forge"]) * 0.10
        quality = clampf(quality + bonus, 0.0, 1.0)
        match current_weapon.repair_target_station():
                "polish":    current_weapon.sharpness = quality
                "oil_grind": current_weapon.balance = quality
                "exorcise":  current_weapon.mystic = quality
                "reforge":   current_weapon.power = quality
        if quality >= 0.5:
                current_weapon.state = Weapon.State.PRISTINE
                current_weapon.wear_state = Weapon.WearState.PRISTINE
                current_weapon.durability = current_weapon.durability_max
                current_weapon.history.append("Repaired (q=%.0f%%)." % (quality * 100))
                Juice.add_trauma(0.3)
                Juice.hit_stop(0.06)
                Juice.spawn_particles(ghost.pos, 10, Palette.TEXT_GOLD, 40.0, 0.5)
                ghost.squash = 1.2
        else:
                current_weapon.history.append("Repair attempt failed.")
        GameState.arsenal_changed.emit()
        current_weapon = null

func _on_ring_bell() -> void:
        bell_timer = 0
        _bell_tolls()

func _bell_tolls() -> void:
        if bell_rang:
                return
        bell_rang = true
        Juice.add_trauma(0.5)
        Juice.hit_stop(0.1)
        if ghost.carrying != null:
                GameState.add_weapon(ghost.carrying)
                ghost.carrying = null
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
                _draw_glow(Vector2(x + 8, HUD_H + 8), 20, Palette.LIGHT_TORCH)
        # Stations
        for st in STATIONS:
                var tex := Sprites.get_sprite(st.sprite)
                # Shadow
                draw_rect(Rect2(int(st.pos.x) - 9, int(st.pos.y) - 6, 18, 4), Color(0, 0, 0, 0.3), true)
                draw_texture(tex, st.pos - Vector2(8, 8))
                # Ambient glow for specific stations
                match st.key:
                        "furnace": _draw_glow(st.pos, 24, Palette.LIGHT_FURNACE)
                        "exorcise": _draw_glow(st.pos, 20, Palette.LIGHT_ALTAR)
                if near_station_key == st.key:
                        var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
                        draw_rect(Rect2(st.pos.x - 12, st.pos.y - 12, 24, 24), Color(0.95, 0.85, 0.40, pulse), false, 1)
                GameFont.draw_string_centered(self, st.pos + Vector2(0, 18), st.name, 6, Palette.TEXT)
                # Arsenal weapon pile
                if st.key == "arsenal" and GameState.arsenal.size() > 0:
                        var pile_count: int = min(GameState.arsenal.size(), 3)
                        for i in pile_count:
                                var w: Weapon = GameState.arsenal[i]
                                var gear_tex := Sprites.get_weapon_sprite(w.type, w.state)
                                draw_texture(gear_tex, st.pos + Vector2(-12 + i * 8, -18))
        # Adventurers
        for a in adventurers:
                var tex := Sprites.get_sprite(a.sprite)
                draw_rect(Rect2(int(a.pos.x) - 5, int(a.pos.y) + 6, 10, 2), Color(0, 0, 0, 0.3), true)
                draw_texture(tex, a.pos - Vector2(8, 8))
                GameFont.draw_string_centered(self, a.pos + Vector2(0, -12), a.adv.name, 5, Palette.TEXT)
                # Equipped weapon
                if a.adv.get("equipped_weapon") != null:
                        var w: Weapon = a.adv.equipped_weapon
                        draw_texture(Sprites.get_weapon_sprite(w.type, w.state), a.pos + Vector2(8, -4))
        # Ghost
        var bob := sin(ghost.bob) * 1.5
        var gp: Vector2 = ghost.pos + Vector2(0, bob)
        draw_rect(Rect2(int(gp.x) - 5, int(ghost.pos.y) + 6, 10, 2), Color(0, 0, 0, 0.3), true)
        var ghost_tex := Sprites.get_sprite("ghost")
        var sw := int(16 / ghost.squash)
        var sh := int(16 * ghost.squash)
        draw_texture_rect(ghost_tex, Rect2(int(gp.x) - sw / 2, int(gp.y) - sh / 2, sw, sh), false)
        # Carried weapon
        if ghost.carrying != null:
                var item_tex := Sprites.get_weapon_sprite(ghost.carrying.type, ghost.carrying.state)
                draw_texture(item_tex, gp + Vector2(-8, -16))
        # Particles
        Juice.draw_particles(self)
        # Hint
        GameFont.draw_string_centered(self, Vector2(ROOM_W / 2, ROOM_H - 2), "WASD: move | E: interact", 5, Palette.TEXT_DIM)

func _draw_glow(pos: Vector2, radius: int, color: Color) -> void:
        var center := Vector2(int(pos.x), int(pos.y))
        for r in [radius, int(radius * 0.6), int(radius * 0.3)]:
                var c := color
                c.a = c.a * (1.0 - float(r) / float(radius)) * 0.8
                draw_circle(center, r, c)
