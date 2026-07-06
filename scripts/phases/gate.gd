extends Node2D
## Phase: gate — a short walkable threshold between the aftermath recap (or,
## for a brand new run, nothing at all yet) and salvage. You walk past a
## couple of grave markers and push open the gate into the dungeon.
##
## This is deliberately where a NEW run enters, not "planning": the graves
## here are what tells a first-time player "someone was here before you and
## didn't make it" — which is the game's whole premise for why there's an
## arsenal of already-battered gear waiting to be found — without needing a
## stats screen that has nothing real to show yet. On every later cycle, the
## grave markers reflect whoever actually fell in the wave you just fought.

const ROOM_W: int = 320
const ROOM_H: int = 180
const GATE_POS := Vector2(160, 34)
const GATE_RADIUS: float = 20.0

var ghost_pos: Vector2 = Vector2(160, 150)
var ghost_vel: Vector2 = Vector2.ZERO
var graves: Array = []
var near_gate: bool = false
var opening: bool = false
var hint_label: Label

func _ready() -> void:
	_build_graves()
	_build_hud()

func _build_graves() -> void:
	graves.clear()
	var fallen: Array = GameState.last_battle_result.get("fallen_names", [])
	var first_ever_run: bool = GameState.stage == 1 and GameState.wave == 1 and GameState.run_log.size() <= 1
	var names: Array = []
	if not fallen.is_empty():
		names = fallen
	elif first_ever_run:
		# Nobody's died yet in THIS run — these are the caretaker's
		# predecessors, establishing why the dungeon entrance is already
		# littered with weapons for the taking.
		names = ["Toren", "Yselde"]
	else:
		names = []  # a clean wave — no fresh graves to add
	var spacing: float = min(70.0, 280.0 / max(1, names.size()))
	var start_x: float = ROOM_W / 2.0 - (names.size() - 1) * spacing / 2.0
	for i in names.size():
		graves.append({"pos": Vector2(start_x + i * spacing, 100), "name": names[i]})

func _build_hud() -> void:
	hint_label = Label.new()
	hint_label.text = "WASD:move E:open gate"
	hint_label.add_theme_font_size_override("font_size", 8)
	hint_label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	hint_label.position = Vector2(0, ROOM_H - 12)
	hint_label.size = Vector2(ROOM_W, 10)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint_label)

func _process(delta: float) -> void:
	if opening:
		queue_redraw()
		return
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_left"):  input_dir.x -= 1
	if Input.is_action_pressed("move_right"): input_dir.x += 1
	if Input.is_action_pressed("move_up"):    input_dir.y -= 1
	if Input.is_action_pressed("move_down"):  input_dir.y += 1
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		ghost_vel = ghost_vel.move_toward(input_dir * 55.0, 300.0 * delta)
	else:
		ghost_vel = ghost_vel.move_toward(Vector2.ZERO, 300.0 * delta)
	ghost_pos += ghost_vel * delta
	ghost_pos.x = clampf(ghost_pos.x, 12, ROOM_W - 12)
	ghost_pos.y = clampf(ghost_pos.y, 24, ROOM_H - 20)
	near_gate = ghost_pos.distance_to(GATE_POS) < GATE_RADIUS
	if near_gate and Input.is_action_just_pressed("interact"):
		_open_gate()
	queue_redraw()

func _open_gate() -> void:
	opening = true
	hint_label.text = "The gate groans open..."
	Juice.add_trauma(0.3)
	Juice.spawn_particles(GATE_POS, 10, Palette.TEXT_DIM, 30.0, 0.6)
	await get_tree().create_timer(0.6).timeout
	GameState.set_phase("salvage")

func _draw() -> void:
	# Floor
	for y in range(20, ROOM_H - 8, 16):
		for x in range(0, ROOM_W, 16):
			draw_texture(Sprites.get_sprite("floor"), Vector2(x, y))
	# Side walls of the approach
	for y in range(20, ROOM_H, 16):
		draw_texture(Sprites.get_sprite("wall"), Vector2(0, y))
		draw_texture(Sprites.get_sprite("wall_mossy"), Vector2(ROOM_W - 16, y))
	# Gate arch
	for x in range(GATE_POS.x - 40, GATE_POS.x + 41, 16):
		draw_texture(Sprites.get_sprite("wall"), Vector2(x, GATE_POS.y - 16))
	draw_texture_rect(Sprites.get_sprite("door"), Rect2(GATE_POS.x - 16, GATE_POS.y - 16, 32, 32), false)
	if near_gate and not opening:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		draw_rect(Rect2(GATE_POS.x - 20, GATE_POS.y - 20, 40, 40), Color(0.85, 0.75, 0.55, pulse), false, 1)
	# Grave markers
	for g in graves:
		var p: Vector2 = g.pos
		draw_rect(Rect2(p.x - 6, p.y + 2, 12, 3), Color(0.25, 0.22, 0.2), true)  # mound
		draw_line(p + Vector2(0, -8), p + Vector2(0, 2), Color(0.5, 0.42, 0.3), 2.0)
		draw_line(p + Vector2(-4, -4), p + Vector2(4, -4), Color(0.5, 0.42, 0.3), 2.0)
		GameFont.draw_string_centered(self, p + Vector2(0, 14), g.name, 8, Palette.TEXT_DIM)
	# Ghost
	var gp := ghost_pos
	draw_rect(Rect2(int(gp.x) - 5, int(gp.y) + 6, 10, 2), Color(0, 0, 0, 0.3), true)
	draw_texture(Sprites.get_sprite("ghost"), gp - Vector2(8, 8))
	Juice.draw_particles(self)
