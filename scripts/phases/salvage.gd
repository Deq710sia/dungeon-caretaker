extends Node2D
## Phase: salvage V3 — QTE cutscenes at hazard points (not physical dodging).
## The ghost auto-walks through the dungeon. At each hazard, a Dumb Ways to Die style
## QTE cutscene triggers (3-5 beats, one verb, ~15-25s). Success = collect gear + continue.
## Failure = lose the gear + take durability damage to carried items.

const TILE: int = 32
const CORRIDOR_W: int = 14  # doubled for 640 wide
const CORRIDOR_H: int = 80
const VIEW_W: int = 640
const VIEW_H: int = 360

var ghost_pos: Vector2 = Vector2(CORRIDOR_W * TILE / 2, 32)
var ghost_bob: float = 0.0
var camera_y: float = 0.0
var cam: Camera2D
var auto_walk_speed: float = 45.0
var walk_paused: bool = false

var corpses: Array = []
var hazards: Array = []
var particles: Array = []
var exit_pos: Vector2
var finished: bool = false
var current_qte: Node2D = null
var collected_this_run: int = 0

# HUD
var hud_stage: Label
var hud_collected: Label
var hud_hint: Label
var dialogue_label: Label

func _ready() -> void:
	cam = Camera2D.new()
	cam.position = ghost_pos
	cam.enabled = true
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	add_child(cam)
	_build_level()
	_build_hud()

func _build_level() -> void:
	corpses.clear()
	hazards.clear()
	# Place corpses with gear
	var corpse_count := 4 + GameState.stage
	for i in corpse_count:
		var x := (2 + (i * 5) % (CORRIDOR_W - 4)) * TILE + TILE / 2
		var y := (12 + i * 12) * TILE + TILE / 2
		var types := ["sword", "helm", "staff", "robe"]
		var states := [Weapon.State.BLOODIED, Weapon.State.RUSTED, Weapon.State.HAUNTED, Weapon.State.CURSED]
		corpses.append({
			"pos": Vector2(x, y),
			"gear_type": types[i % types.size()],
			"gear_state": states[i % states.size()],
			"gear_name": _gen_weapon_name(types[i % types.size()]),
			"collected": false,
		})
	# Place hazards (QTE triggers)
	var hazard_count := 3 + GameState.stage
	for i in hazard_count:
		var x := (2 + (i * 7) % (CORRIDOR_W - 4)) * TILE + TILE / 2
		var y := (8 + i * 14) * TILE + TILE / 2
		# Don't overlap corpses
		for c in corpses:
			if c.pos.distance_to(Vector2(x, y)) < TILE * 2:
				y += TILE * 3
		var htypes := ["pit", "fire", "spikes", "falling"]
		hazards.append({
			"pos": Vector2(x, y),
			"type": htypes[i % htypes.size()],
			"triggered": false,
			"qte_verb": _verb_for_hazard(htypes[i % htypes.size()]),
		})
	exit_pos = Vector2(CORRIDOR_W * TILE / 2, (CORRIDOR_H - 3) * TILE)

func _gen_weapon_name(type: String) -> String:
	var prefixes := ["Rusted", "Bloodied", "Cursed", "Whispering", "Forgotten", "Pitted", "Haunted"]
	var bases := {"sword": "Blade", "staff": "Staff", "helm": "Helm", "robe": "Robe"}
	return "%s %s" % [prefixes[randi() % prefixes.size()], bases.get(type, "Item")]

func _verb_for_hazard(htype: String) -> String:
	match htype:
		"pit": return "JUMP"
		"fire": return "BLOW"
		"spikes": return "DODGE"
		"falling": return "CATCH"
		_: return "TAP"

func _build_hud() -> void:
	var panel := Panel.new()
	panel.position = Vector2(0, 0)
	panel.size = Vector2(VIEW_W, 24)
	add_child(panel)

	hud_stage = Label.new()
	hud_stage.text = "Stage %d Wave %d — SALVAGE RUN" % [GameState.stage, GameState.wave]
	hud_stage.add_theme_font_size_override("font_size", 10)
	hud_stage.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	hud_stage.position = Vector2(8, 4)
	hud_stage.size = Vector2(300, 16)
	panel.add_child(hud_stage)

	hud_collected = Label.new()
	hud_collected.text = "Salvaged: 0"
	hud_collected.add_theme_font_size_override("font_size", 10)
	hud_collected.add_theme_color_override("font_color", Color(0.65, 0.85, 0.95))
	hud_collected.position = Vector2(450, 4)
	hud_collected.size = Vector2(180, 16)
	hud_collected.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(hud_collected)

	hud_hint = Label.new()
	hud_hint.text = "Auto-walking... QTE cutscenes at hazards!"
	hud_hint.add_theme_font_size_override("font_size", 8)
	hud_hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	hud_hint.position = Vector2(0, VIEW_H - 16)
	hud_hint.size = Vector2(VIEW_W, 12)
	hud_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hud_hint)

	# Dialogue label (for QTE prompts)
	dialogue_label = Label.new()
	dialogue_label.text = ""
	dialogue_label.add_theme_font_size_override("font_size", 14)
	dialogue_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.40))
	dialogue_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	dialogue_label.add_theme_constant_override("outline_size", 3)
	dialogue_label.position = Vector2(0, VIEW_H / 2 - 40)
	dialogue_label.size = Vector2(VIEW_W, 20)
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(dialogue_label)

func _process(delta: float) -> void:
	if finished:
		return
	ghost_bob += delta * 6.0
	if not walk_paused and current_qte == null:
		# Auto-walk forward
		ghost_pos.y += auto_walk_speed * delta
		ghost_pos.y = clampf(ghost_pos.y, 24, (CORRIDOR_H - 1) * TILE)
	# Check corpse pickups
	for c in corpses:
		if not c.collected and ghost_pos.distance_to(c.pos) < 24:
			c.collected = true
			collected_this_run += 1
			hud_collected.text = "Salvaged: %d" % collected_this_run
			var w := Weapon.new(c.gear_type, c.gear_name, "Salvaged from a fallen adventurer.")
			w.state = c.gear_state
			w.durability_max = Weapon.BASE_DURABILITY + GameState.meta_upgrades["sturdy_grip"] * 25
			w.durability = int(w.durability_max * 0.5)
			w.sharpness = randf_range(0.3, 0.6)
			w.balance = randf_range(0.3, 0.6)
			w.power = randf_range(0.3, 0.6)
			w.mystic = randf_range(0.3, 0.6)
			GameState.add_weapon(w)
			# Particle burst
			for i in 8:
				particles.append({
					"pos": c.pos,
					"vel": Vector2(randf_range(-40, 40), randf_range(-40, 40)),
					"color": Color(0.95, 0.85, 0.40),
					"life": 0.6,
					"max_life": 0.6,
				})
			dialogue_label.text = "Salvaged: %s" % c.gear_name
			get_tree().create_timer(1.5).timeout.connect(func(): dialogue_label.text = "")
	# Check hazard triggers
	for h in hazards:
		if not h.triggered and ghost_pos.distance_to(h.pos) < 30:
			h.triggered = true
			_start_qte(h)
	# Check exit
	if ghost_pos.distance_to(exit_pos) < 30:
		_finish()
	# Camera follows
	camera_y = lerp(camera_y, ghost_pos.y, 1.0 - exp(-delta * 6.0))
	cam.position = Vector2(ghost_pos.x, camera_y)
	cam.offset = Vector2(0, -60)
	# Update particles
	for p in particles:
		p.pos += p.vel * delta
		p.life -= delta
	particles = particles.filter(func(p): return p.life > 0)
	queue_redraw()

func _start_qte(hazard: Dictionary) -> void:
	walk_paused = true
	dialogue_label.text = "HAZARD: %s — %s!" % [hazard.type.to_upper(), hazard.qte_verb]
	# Spawn QTE cutscene node — 3 beats, one verb, ~15s total
	var qte_script := preload("res://scripts/delivery/qte_cutscene.gd")
	current_qte = Node2D.new()
	current_qte.set_script(qte_script)
	current_qte.name = "QTECutscene"
	add_child(current_qte)
	current_qte.start(hazard.qte_verb, 3, _on_qte_done.bind(hazard))

func _on_qte_done(success: bool, hazard: Dictionary) -> void:
	if current_qte:
		current_qte.queue_free()
		current_qte = null
	walk_paused = false
	if success:
		dialogue_label.text = "Dodged the %s!" % hazard.type
		# Spark particles
		for i in 6:
			particles.append({
				"pos": hazard.pos,
				"vel": Vector2(randf_range(-50, 50), randf_range(-50, 50)),
				"color": Color(0.55, 0.95, 0.55),
				"life": 0.5,
				"max_life": 0.5,
			})
	else:
		dialogue_label.text = "Hit the %s! Lost a salvage." % hazard.type
		# Penalty: remove the most recently collected weapon
		if not GameState.arsenal.is_empty():
			GameState.arsenal.pop_back()
			GameState.arsenal_changed.emit()
		# Damage particles
		for i in 6:
			particles.append({
				"pos": ghost_pos,
				"vel": Vector2(randf_range(-40, 40), randf_range(-40, 40)),
				"color": Color(0.95, 0.40, 0.40),
				"life": 0.5,
				"max_life": 0.5,
			})
	get_tree().create_timer(1.5).timeout.connect(func(): dialogue_label.text = "")

func _finish() -> void:
	if finished:
		return
	finished = true
	await get_tree().create_timer(0.5).timeout
	GameState.set_phase("workshop")

func _draw() -> void:
	# Floor
	var cam_top := int((camera_y - VIEW_H / 2) / TILE) - 1
	var cam_bot := int((camera_y + VIEW_H / 2) / TILE) + 1
	cam_top = max(0, cam_top)
	cam_bot = min(CORRIDOR_H - 1, cam_bot)
	for y in range(cam_top, cam_bot + 1):
		for x in CORRIDOR_W:
			var p := Vector2(x * TILE, y * TILE)
			if (x + y) % 7 == 0 and y > 5:
				draw_texture(Sprites.get_sprite("floor_cracked"), p)
			elif (x + y) % 11 == 0 and y > 8:
				draw_texture(Sprites.get_sprite("floor_blood"), p)
			else:
				draw_texture(Sprites.get_sprite("floor"), p)
	# Side walls
	for y in range(cam_top, cam_bot + 1):
		draw_texture(Sprites.get_sprite("wall"), Vector2(-TILE, y * TILE))
		draw_texture(Sprites.get_sprite("wall_mossy"), Vector2(CORRIDOR_W * TILE, y * TILE))
		if y % 4 == 0:
			draw_texture_rect(Sprites.get_sprite("torch"), Rect2(-TILE - 16, y * TILE + 8, 32, 32), false)
			draw_texture_rect(Sprites.get_sprite("torch"), Rect2(CORRIDOR_W * TILE, y * TILE + 8, 32, 32), false)
	# Hazards
	for h in hazards:
		if h.triggered:
			# Show as cleared (bone pile or scorch mark)
			draw_texture_rect(Sprites.get_sprite("bone_pile"), Rect2(h.pos.x - 16, h.pos.y - 16, 32, 32), false)
		else:
			match h.type:
				"pit":
					draw_circle(h.pos, 20, Color(0, 0, 0))
					draw_circle(h.pos, 18, Color(0.05, 0.03, 0.08))
					# Warning ring
					var pulse := 0.5 + 0.3 * sin(Time.get_ticks_msec() * 0.005)
					draw_arc(h.pos, 26, 0, TAU, 16, Color(0.95, 0.40, 0.40, pulse), 2)
				"fire":
					var flicker := 1.0 + 0.2 * sin(Time.get_ticks_msec() * 0.01)
					draw_circle(h.pos, 24, Color(0.55, 0.20, 0.10, 0.5))
					draw_circle(h.pos, 16 * flicker, Color(0.95, 0.55, 0.20))
					draw_circle(h.pos, 8 * flicker, Color(1.0, 0.85, 0.40))
				"spikes":
					draw_rect(Rect2(h.pos.x - 20, h.pos.y - 20, 40, 40), Color(0.20, 0.18, 0.20), true)
					for i in 4:
						var sx: float = h.pos.x - 16 + i * 10
						draw_colored_polygon(PackedVector2Array([
							Vector2(sx, h.pos.y + 16),
							Vector2(sx + 5, h.pos.y - 16),
							Vector2(sx + 10, h.pos.y + 16),
						]), Color(0.75, 0.75, 0.78))
				"falling":
					# Falling debris warning
					var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
					draw_rect(Rect2(h.pos.x - 16, h.pos.y - 24, 32, 8), Color(0.55, 0.30, 0.20, pulse), true)
					draw_string(ThemeDB.get_default_theme().default_font, h.pos + Vector2(-20, -32), "FALLING!", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.95, 0.55, 0.30))
	# Corpses
	for c in corpses:
		if c.collected:
			draw_texture_rect(Sprites.get_sprite("bone_pile"), Rect2(c.pos.x - 16, c.pos.y - 16, 32, 32), false)
		else:
			draw_texture_rect(Sprites.get_sprite("corpse"), Rect2(c.pos.x - 16, c.pos.y - 16, 32, 32), false)
			# Floating gear above
			var bob := sin(Time.get_ticks_msec() * 0.004 + c.pos.x) * 3
			var gear_tex := Sprites.get_weapon_sprite(c.gear_type, c.gear_state)
			draw_texture_rect(gear_tex, Rect2(c.pos.x - 16, c.pos.y - 44 + bob, 32, 32), false)
			draw_arc(Vector2(c.pos.x, c.pos.y - 28 + bob), 20, 0, TAU, 16, Color(0.95, 0.85, 0.40, 0.5), 1.5)
	# Exit
	draw_texture_rect(Sprites.get_sprite("stairs_down"), Rect2(exit_pos.x - 16, exit_pos.y - 16, 32, 32), false)
	var exit_pulse := 0.5 + 0.3 * sin(Time.get_ticks_msec() * 0.003)
	draw_arc(exit_pos, 28, 0, TAU, 16, Color(0.55, 0.95, 0.75, exit_pulse), 2)
	draw_string(ThemeDB.get_default_theme().default_font, exit_pos + Vector2(-40, -36), "EXIT", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.55, 0.95, 0.75))
	# Ghost
	var bob := sin(ghost_bob) * 2
	var gp := ghost_pos + Vector2(0, bob)
	draw_rect(Rect2(gp.x - 10, ghost_pos.y + 12, 20, 4), Color(0, 0, 0, 0.3), true)
	var ghost_tex := Sprites.get_sprite("ghost")
	draw_texture_rect(ghost_tex, Rect2(gp.x - 20, gp.y - 20, 40, 40), false)
	# Particles
	for p in particles:
		var alpha: float = p.life / p.max_life
		var c: Color = p.color
		c.a = alpha
		draw_circle(p.pos, 4 * alpha, c)
	# Progress bar
	var progress := clampf(ghost_pos.y / (CORRIDOR_H * TILE), 0, 1)
	draw_rect(Rect2(VIEW_W - 12, 28, 6, VIEW_H - 56), Color(0.20, 0.20, 0.25), true)
	draw_rect(Rect2(VIEW_W - 12, 28 + (VIEW_H - 56) * (1 - progress), 6, (VIEW_H - 56) * progress), Color(0.55, 0.95, 0.55), true)
