extends Node2D
## Phase: workshop V3 — repair weapons at stations, weapon shown as centerpiece.
## Top-down room. Ghost walks between stations. Each repair shows the weapon large.

const ROOM_W: int = 640
const ROOM_H: int = 360
const HUD_H: int = 28
const STATION_RADIUS: float = 28.0

const STATIONS := [
	{"key": "arsenal",   "name": "Arsenal",          "sprite": "chest",      "pos": Vector2(60, 100)},
	{"key": "polish",    "name": "Polish Bench",     "sprite": "bench",      "pos": Vector2(180, 100), "states": [Weapon.State.BLOODIED]},
	{"key": "oil_grind", "name": "Oil & Grindstone", "sprite": "grindstone", "pos": Vector2(300, 100), "states": [Weapon.State.RUSTED]},
	{"key": "exorcise",  "name": "Exorcise Altar",   "sprite": "altar",      "pos": Vector2(420, 100), "states": [Weapon.State.HAUNTED, Weapon.State.CURSED]},
	{"key": "reforge",   "name": "Reforge Furnace",  "sprite": "furnace",    "pos": Vector2(540, 100), "states": [Weapon.State.SHATTERED]},
]

var ghost: Dictionary = {
	"pos": Vector2(320, 240),
	"speed": 90.0,
	"carrying": null,
	"bob": 0.0,
}
var bell_timer: float = 90.0
var bell_rang: bool = false
var minigame_active: bool = false
var active_minigame: Node2D = null
var current_weapon: Weapon = null
var near_station_key: String = ""
var interact_pressed: bool = false
var particles: Array = []

var hud_stage: Label
var hud_bell: Label
var hud_shards: Label
var hud_carrying: Label
var prompt_label: Label
var ring_bell_btn: Button

func _ready() -> void:
	if GameState.party.is_empty():
		GameState.spawn_party()
	_build_hud()
	bell_timer = max(60.0, 120.0 - GameState.stage * 8)

func _build_hud() -> void:
	var panel := Panel.new()
	panel.position = Vector2(0, 0)
	panel.size = Vector2(ROOM_W, HUD_H)
	add_child(panel)

	hud_stage = Label.new()
	hud_stage.text = "Stage %d Wave %d — WORKSHOP" % [GameState.stage, GameState.wave]
	hud_stage.add_theme_font_size_override("font_size", 10)
	hud_stage.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	hud_stage.position = Vector2(8, 6)
	hud_stage.size = Vector2(250, 16)
	panel.add_child(hud_stage)

	hud_bell = Label.new()
	hud_bell.text = "Bell: 90s"
	hud_bell.add_theme_font_size_override("font_size", 10)
	hud_bell.add_theme_color_override("font_color", Color(0.95, 0.55, 0.40))
	hud_bell.position = Vector2(260, 6)
	hud_bell.size = Vector2(80, 16)
	panel.add_child(hud_bell)

	hud_shards = Label.new()
	hud_shards.text = "Shards: 0"
	hud_shards.add_theme_font_size_override("font_size", 10)
	hud_shards.add_theme_color_override("font_color", Color(0.65, 0.85, 0.95))
	hud_shards.position = Vector2(350, 6)
	hud_shards.size = Vector2(100, 16)
	panel.add_child(hud_shards)

	hud_carrying = Label.new()
	hud_carrying.text = "Carrying: -"
	hud_carrying.add_theme_font_size_override("font_size", 9)
	hud_carrying.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
	hud_carrying.position = Vector2(460, 6)
	hud_carrying.size = Vector2(170, 16)
	panel.add_child(hud_carrying)

	prompt_label = Label.new()
	prompt_label.text = ""
	prompt_label.add_theme_font_size_override("font_size", 10)
	prompt_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.40))
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	prompt_label.add_theme_constant_override("outline_size", 2)
	prompt_label.position = Vector2(0, 0)
	prompt_label.size = Vector2(ROOM_W, 14)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(prompt_label)

	ring_bell_btn = Button.new()
	ring_bell_btn.text = "Ring Bell"
	ring_bell_btn.add_theme_font_size_override("font_size", 10)
	ring_bell_btn.position = Vector2(540, 320)
	ring_bell_btn.size = Vector2(90, 24)
	ring_bell_btn.pressed.connect(_on_ring_bell)
	add_child(ring_bell_btn)

	GameState.shards_changed.connect(_on_shards_changed)
	_update_hud()

func _update_hud() -> void:
	hud_bell.text = "Bell: %.0fs" % bell_timer
	hud_shards.text = "Shards: %d" % GameState.soul_shards
	if ghost.carrying != null:
		var w: Weapon = ghost.carrying
		hud_carrying.text = "Carry: %s [%s]" % [w.display_name, w.wear_name()]
		hud_carrying.add_theme_color_override("font_color", w.wear_color())
	else:
		hud_carrying.text = "Carrying: -"
		hud_carrying.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))

func _on_shards_changed(new_count: int) -> void:
	hud_shards.text = "Shards: %d" % new_count

func _process(delta: float) -> void:
	if minigame_active:
		ghost.bob += delta * 6
		return
	bell_timer -= delta
	if bell_timer <= 0:
		bell_timer = 0
		_bell_tolls()
		return
	ghost.bob += delta * 6
	# Movement
	var move := Vector2.ZERO
	if Input.is_action_pressed("move_left"):  move.x -= 1
	if Input.is_action_pressed("move_right"): move.x += 1
	if Input.is_action_pressed("move_up"):    move.y -= 1
	if Input.is_action_pressed("move_down"):  move.y += 1
	if move != Vector2.ZERO:
		move = move.normalized() * ghost.speed * delta
		ghost.pos += move
		ghost.pos.x = clampf(ghost.pos.x, 24, ROOM_W - 24)
		ghost.pos.y = clampf(ghost.pos.y, HUD_H + 40, ROOM_H - 40)
	_find_nearest_interactive()
	if Input.is_action_just_pressed("interact") and not interact_pressed:
		interact_pressed = true
		_handle_interact()
	if not Input.is_action_pressed("interact"):
		interact_pressed = false
	for p in particles:
		p.pos += p.vel * delta
		p.life -= delta
	particles = particles.filter(func(p): return p.life > 0)
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
				prompt_label.text = "[E] Pick up weapon (%d in arsenal)" % GameState.arsenal.size()
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
		prompt_label.position = Vector2(0, ghost.pos.y - 36)

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
	# Repair station
	if ghost.carrying != null:
		var st_def: Dictionary = _get_station_def(near_station_key)
		if ghost.carrying.state in st_def.get("states", []):
			_start_repair(near_station_key)

func _pick_up_from_arsenal() -> void:
	if GameState.arsenal.is_empty():
		return
	# Pick the first weapon that needs repair
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
	# Update authoring fingerprint based on which station
	match current_weapon.repair_target_station():
		"polish":    current_weapon.sharpness = quality
		"oil_grind": current_weapon.balance = quality
		"exorcise":  current_weapon.mystic = quality
		"reforge":   current_weapon.power = quality
	if quality >= 0.5:
		current_weapon.state = Weapon.State.PRISTINE
		current_weapon.wear_state = Weapon.WearState.PRISTINE
		current_weapon.durability = current_weapon.durability_max
		current_weapon.history.append("Repaired (q=%.0f%%) on Stage %d Wave %d." % [quality * 100, GameState.stage, GameState.wave])
		# Spark particles
		for i in 10:
			particles.append({
				"pos": ghost.pos,
				"vel": Vector2(randf_range(-60, 60), randf_range(-60, 60)),
				"color": Color(0.95, 0.95, 0.40),
				"life": 0.7,
				"max_life": 0.7,
			})
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
	if ghost.carrying != null:
		GameState.add_weapon(ghost.carrying)
		ghost.carrying = null
	GameState.set_phase("battle")

func _draw() -> void:
	# Floor
	for y in range(HUD_H + 20, ROOM_H - 20, 32):
		for x in range(0, ROOM_W, 32):
			draw_texture(Sprites.get_sprite("floor"), Vector2(x, y))
	# Walls
	for x in range(0, ROOM_W, 32):
		draw_texture(Sprites.get_sprite("wall"), Vector2(x, HUD_H))
		draw_texture(Sprites.get_sprite("wall"), Vector2(x, ROOM_H - 20))
	# Stations
	for st in STATIONS:
		var tex := Sprites.get_sprite(st.sprite)
		var p: Vector2 = st.pos
		draw_rect(Rect2(p.x - 22, p.y - 18, 44, 44), Color(0, 0, 0, 0.3), true)
		draw_texture_rect(tex, Rect2(p.x - 20, p.y - 20, 40, 40), false)
		if near_station_key == st.key:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
			draw_rect(Rect2(p.x - 26, p.y - 26, 52, 52), Color(0.95, 0.95, 0.40, pulse), false, 2)
		draw_string(ThemeDB.get_default_theme().default_font, Vector2(p.x - 40, p.y + 36), st.name, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.75, 0.75, 0.85))
		# Arsenal shows weapon pile
		if st.key == "arsenal" and GameState.arsenal.size() > 0:
			var pile_count: int = min(GameState.arsenal.size(), 4)
			for i in pile_count:
				var w: Weapon = GameState.arsenal[i]
				var gear_tex := Sprites.get_weapon_sprite(w.type, w.state)
				var offset := Vector2(-24 + i * 16, -36 - i * 4)
				draw_texture_rect(gear_tex, Rect2(p.x + offset.x, p.y + offset.y, 20, 20), false)
			if GameState.arsenal.size() > 4:
				draw_string(ThemeDB.get_default_theme().default_font, Vector2(p.x - 10, p.y - 48), "+%d" % (GameState.arsenal.size() - 4), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.85, 0.85, 0.90))
	# Ghost
	var bob := sin(ghost.bob) * 2
	var gp: Vector2 = ghost.pos + Vector2(0, bob)
	draw_rect(Rect2(gp.x - 10, ghost.pos.y + 14, 20, 4), Color(0, 0, 0, 0.25), true)
	var ghost_tex := Sprites.get_sprite("ghost")
	draw_texture_rect(ghost_tex, Rect2(gp.x - 20, gp.y - 20, 40, 40), false)
	# Carried weapon
	if ghost.carrying != null:
		var item_tex := Sprites.get_weapon_sprite(ghost.carrying.type, ghost.carrying.state)
		var item_pos := gp + Vector2(-16, -40)
		draw_texture_rect(item_tex, Rect2(item_pos.x, item_pos.y, 32, 32), false)
		draw_rect(Rect2(item_pos.x, item_pos.y, 32, 32), ghost.carrying.wear_color(), false, 2)
	# Particles
	for p in particles:
		var alpha: float = p.life / p.max_life
		var c: Color = p.color
		c.a = alpha
		draw_circle(p.pos, 4 * alpha, c)
	# Hint
	draw_string(ThemeDB.get_default_theme().default_font, Vector2(ROOM_W / 2 - 160, ROOM_H - 6), "WASD: move | E: interact | Repair weapons, then ring bell", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.55, 0.55, 0.65))
