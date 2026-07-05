extends Node2D
## Phase: salvage_run (V2)
## Top-down scroller. Camera follows the ghost through a dungeon corridor.
## The ghost collects gear from corpses and dodges hazards (pits, fire, spikes).
## Reaches the end -> workshop phase.

const TILE: int = 32
const CORRIDOR_W: int = 7       # tiles wide (224 px)
const CORRIDOR_H: int = 60      # tiles long (the level)
const VIEW_W: int = 320
const VIEW_H: int = 180

var ghost_pos: Vector2 = Vector2(CORRIDOR_W * TILE / 2, 32)
var ghost_speed: float = 70.0
var ghost_bob: float = 0.0
var camera_y: float = 0.0

var corpses: Array = []        # {pos, gear_type, gear_state, gear_name, collected}
var hazards: Array = []        # {pos, type, size}
var particles: Array = []      # visual effects
var exit_pos: Vector2
var finished: bool = false
var time_left: float = 60.0    # 60 seconds to reach the end

var cam: Camera2D

# HUD
var hud_panel: Panel
var hud_stage: Label
var hud_wave: Label
var hud_timer: Label
var hud_collected: Label
var hud_hint: Label

func _ready() -> void:
	# Spawn camera
	cam = Camera2D.new()
	cam.position = ghost_pos
	cam.enabled = true
	add_child(cam)
	# Build the level
	_build_level()
	# Build HUD
	_build_hud()

func _build_level() -> void:
	corpses.clear()
	hazards.clear()
	# Place 5-7 corpses along the corridor
	var corpse_count := 5 + GameState.stage
	for i in corpse_count:
		var x := (1 + (i * 3) % (CORRIDOR_W - 2)) * TILE + TILE / 2
		var y := (8 + i * 7) * TILE + TILE / 2
		var types := ["sword", "helm", "staff", "robe"]
		var states := [GearItem.State.BLOODIED, GearItem.State.RUSTED, GearItem.State.HAUNTED, GearItem.State.CURSED]
		corpses.append({
			"pos": Vector2(x, y),
			"gear_type": types[i % types.size()],
			"gear_state": states[i % states.size()],
			"gear_name": "Salvaged %s" % types[i % types.size()].capitalize(),
			"collected": false,
		})
	# Place hazards: pits, fire, spikes
	var hazard_count := 4 + GameState.stage * 2
	for i in hazard_count:
		var x := (1 + (i * 5) % (CORRIDOR_W - 2)) * TILE + TILE / 2
		var y := (5 + i * 4) * TILE + TILE / 2
		# Don't place on top of corpses
		var on_corpse := false
		for c in corpses:
			if c.pos.distance_to(Vector2(x, y)) < TILE * 1.5:
				on_corpse = true
				break
		if on_corpse:
			y += TILE * 2
		var htypes := ["pit", "fire", "spikes"]
		hazards.append({
			"pos": Vector2(x, y),
			"type": htypes[i % htypes.size()],
			"size": TILE * 0.7,
			"phase": randf() * TAU,
		})
	# Exit at the end
	exit_pos = Vector2(CORRIDOR_W * TILE / 2, (CORRIDOR_H - 2) * TILE)

func _build_hud() -> void:
	hud_panel = Panel.new()
	hud_panel.position = Vector2(0, 0)
	hud_panel.size = Vector2(VIEW_W, 22)
	add_child(hud_panel)

	hud_stage = Label.new()
	hud_stage.text = "Stage %d Wave %d" % [GameState.stage, GameState.wave]
	hud_stage.add_theme_font_size_override("font_size", 8)
	hud_stage.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	hud_stage.position = Vector2(4, 4)
	hud_stage.size = Vector2(120, 14)
	hud_panel.add_child(hud_stage)

	hud_timer = Label.new()
	hud_timer.text = "Time: 60s"
	hud_timer.add_theme_font_size_override("font_size", 8)
	hud_timer.add_theme_color_override("font_color", Color(0.95, 0.55, 0.40))
	hud_timer.position = Vector2(110, 4)
	hud_timer.size = Vector2(70, 14)
	hud_panel.add_child(hud_timer)

	hud_collected = Label.new()
	hud_collected.text = "Salvaged: 0"
	hud_collected.add_theme_font_size_override("font_size", 8)
	hud_collected.add_theme_color_override("font_color", Color(0.65, 0.85, 0.95))
	hud_collected.position = Vector2(180, 4)
	hud_collected.size = Vector2(80, 14)
	hud_panel.add_child(hud_collected)

	hud_hint = Label.new()
	hud_hint.text = "WASD: move | Walk over corpses to salvage | Avoid hazards"
	hud_hint.add_theme_font_size_override("font_size", 6)
	hud_hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	hud_hint.position = Vector2(0, VIEW_H - 12)
	hud_hint.size = Vector2(VIEW_W, 10)
	hud_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hud_hint)

func _process(delta: float) -> void:
	if finished:
		return
	time_left -= delta
	if time_left <= 0:
		time_left = 0
		# Force-end the salvage run (you escape with what you have)
		_finish()
		return
	hud_timer.text = "Time: %.0fs" % time_left
	# Movement
	var move := Vector2.ZERO
	if Input.is_action_pressed("move_left"):  move.x -= 1
	if Input.is_action_pressed("move_right"): move.x += 1
	if Input.is_action_pressed("move_up"):    move.y -= 1
	if Input.is_action_pressed("move_down"):  move.y += 1
	if move != Vector2.ZERO:
		move = move.normalized() * ghost_speed * delta
		ghost_pos += move
	# Bounds: stay within corridor
	ghost_pos.x = clampf(ghost_pos.x, TILE, (CORRIDOR_W - 1) * TILE)
	ghost_pos.y = clampf(ghost_pos.y, 24, (CORRIDOR_H - 1) * TILE)
	# Bob
	ghost_bob += delta * 6.0
	# Camera follows
	camera_y = lerp(camera_y, ghost_pos.y, 0.15)
	cam.position = Vector2(ghost_pos.x, camera_y)
	cam.offset = Vector2(0, -40)  # shift ghost toward bottom of view
	# Check corpse pickups
	for c in corpses:
		if not c.collected and ghost_pos.distance_to(c.pos) < 20:
			c.collected = true
			var g := GearItem.new(c.gear_type, c.gear_state, c.gear_name, "Salvaged from a fallen adventurer.")
			g.durability_max = GearItem.BASE_DURABILITY + GameState.meta_upgrades["sturdy_grip"] * 25
			g.durability = int(g.durability_max * 0.6)  # worn from combat
			GameState.add_gear_to_pit(g)
			# Particle burst
			for i in 6:
				particles.append({
					"pos": c.pos,
					"vel": Vector2(randf_range(-30, 30), randf_range(-30, 30)),
					"color": g.state_color(),
					"life": 0.5,
					"max_life": 0.5,
				})
	# Check hazard collisions
	for h in hazards:
		var pulse := 1.0 + 0.1 * sin(Time.get_ticks_msec() * 0.005 + h.phase)
		if ghost_pos.distance_to(h.pos) < h.size * pulse:
			# Knockback + lose time
			var away: Vector2 = (ghost_pos - h.pos).normalized()
			ghost_pos += away * 30
			time_left = max(0, time_left - 1.5)
			# Damage flash particles
			for i in 4:
				particles.append({
					"pos": ghost_pos,
					"vel": Vector2(randf_range(-40, 40), randf_range(-40, 40)),
					"color": Color(0.95, 0.40, 0.40),
					"life": 0.3,
					"max_life": 0.3,
				})
	# Check exit
	if ghost_pos.distance_to(exit_pos) < 30:
		_finish()
	# Update particles
	for p in particles:
		p.pos += p.vel * delta
		p.life -= delta
	particles = particles.filter(func(p): return p.life > 0)
	queue_redraw()

func _finish() -> void:
	if finished:
		return
	finished = true
	# Brief pause then move to workshop
	await get_tree().create_timer(0.5).timeout
	# Spawn party for next phase
	GameState.spawn_party()
	GameState.set_phase("workshop")

func _draw() -> void:
	# Draw floor tiles (only visible ones, based on camera)
	var cam_top := int((camera_y - VIEW_H / 2) / TILE) - 1
	var cam_bot := int((camera_y + VIEW_H / 2) / TILE) + 1
	cam_top = max(0, cam_top)
	cam_bot = min(CORRIDOR_H - 1, cam_bot)
	for y in range(cam_top, cam_bot + 1):
		for x in CORRIDOR_W:
			var p := Vector2(x * TILE, y * TILE)
			# Mix floor types
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
		# Wall torches every 4 tiles
		if y % 4 == 0:
			draw_texture_rect(Sprites.get_sprite("torch"), Rect2(-TILE - 12, y * TILE + 8, 24, 24), false)
			draw_texture_rect(Sprites.get_sprite("torch"), Rect2(CORRIDOR_W * TILE + 4, y * TILE + 8, 24, 24), false)
	# Hazards
	for h in hazards:
		var pulse := 1.0 + 0.1 * sin(Time.get_ticks_msec() * 0.005 + h.phase)
		match h.type:
			"pit":
				# Dark pit with jagged edge
				draw_circle(h.pos, h.size, Color(0, 0, 0))
				draw_circle(h.pos, h.size * 0.9, Color(0.05, 0.03, 0.08))
				# Inner gradient
				draw_circle(h.pos, h.size * 0.5, Color(0.10, 0.06, 0.12))
			"fire":
				# Animated flame
				var flicker := 1.0 + 0.2 * sin(Time.get_ticks_msec() * 0.01 + h.phase)
				draw_circle(h.pos, h.size * pulse, Color(0.55, 0.20, 0.10, 0.5))
				draw_circle(h.pos, h.size * 0.7 * pulse, Color(0.95, 0.55, 0.20))
				draw_circle(h.pos, h.size * 0.4 * pulse * flicker, Color(1.0, 0.85, 0.40))
			"spikes":
				# Spike trap
				draw_rect(Rect2(h.pos.x - h.size, h.pos.y - h.size, h.size * 2, h.size * 2), Color(0.20, 0.18, 0.20), true)
				for i in 4:
					var sx: float = h.pos.x - h.size * 0.6 + i * h.size * 0.4
					draw_colored_polygon(PackedVector2Array([
						Vector2(sx, h.pos.y + h.size * 0.4),
						Vector2(sx + h.size * 0.15, h.pos.y - h.size * 0.6),
						Vector2(sx + h.size * 0.3, h.pos.y + h.size * 0.4),
					]), Color(0.75, 0.75, 0.78))
	# Corpses (with floating gear above them)
	for c in corpses:
		if c.collected:
			# Show empty spot (bone pile)
			draw_texture_rect(Sprites.get_sprite("bone_pile"), Rect2(c.pos.x - 16, c.pos.y - 16, 32, 32), false)
		else:
			# Corpse
			draw_texture_rect(Sprites.get_sprite("corpse"), Rect2(c.pos.x - 16, c.pos.y - 16, 32, 32), false)
			# Floating gear above (state-tinted)
			var bob := sin(Time.get_ticks_msec() * 0.004 + c.pos.x) * 3
			var gear_tex := Sprites.get_weapon_sprite(c.gear_type, c.gear_state)
			draw_texture_rect(gear_tex, Rect2(c.pos.x - 16, c.pos.y - 44 + bob, 32, 32), false)
			# Glow ring under gear
			draw_arc(Vector2(c.pos.x, c.pos.y - 28 + bob), 18, 0, TAU, 16, Color(0.95, 0.85, 0.40, 0.5), 1.5)
	# Exit (stairs down)
	draw_texture_rect(Sprites.get_sprite("stairs_down"), Rect2(exit_pos.x - 16, exit_pos.y - 16, 32, 32), false)
	# Exit glow
	var exit_pulse := 0.5 + 0.3 * sin(Time.get_ticks_msec() * 0.003)
	draw_arc(exit_pos, 24, 0, TAU, 16, Color(0.55, 0.95, 0.75, exit_pulse), 2)
	draw_string(ThemeDB.get_default_theme().default_font, exit_pos + Vector2(-30, -32), "EXIT", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.55, 0.95, 0.75))
	# Ghost
	var ghost_bob_off := sin(ghost_bob) * 2
	var gp := ghost_pos + Vector2(0, ghost_bob_off)
	# Shadow
	draw_rect(Rect2(gp.x - 8, ghost_pos.y + 10, 16, 3), Color(0, 0, 0, 0.3), true)
	# Ghost sprite (32x32, scaled)
	var ghost_tex := Sprites.get_sprite("ghost")
	draw_texture_rect(ghost_tex, Rect2(gp.x - 16, gp.y - 16, 32, 32), false)
	# Particles
	for p in particles:
		var alpha: float = p.life / p.max_life
		var c: Color = p.color
		c.a = alpha
		draw_circle(p.pos, 3 * alpha, c)
	# Bottom progress bar (how far through the corridor)
	var progress := clampf(ghost_pos.y / (CORRIDOR_H * TILE), 0, 1)
	draw_rect(Rect2(VIEW_W - 8, 26, 4, VIEW_H - 50), Color(0.20, 0.20, 0.25), true)
	draw_rect(Rect2(VIEW_W - 8, 26 + (VIEW_H - 50) * (1 - progress), 4, (VIEW_H - 50) * progress), Color(0.55, 0.95, 0.55), true)
