extends Node2D
## Microgame: Helm Down the Stairs — SWIPE in the arrow direction.
## Arrow flashes one of 4 directions; player must swipe (drag) in that direction.
## 3 successful swipes = win. Each wrong/missed swipe = lose a pip (handled by gauntlet).

signal result(success: bool)

const TIME_LIMIT: float = 5.0
const SUCCESS_NEEDED: int = 3

var time_left: float = TIME_LIMIT
var successes: int = 0
var current_dir: int = 0  # 0=up, 1=right, 2=down, 3=left
var finished: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO
var dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO

func _ready() -> void:
	_pick_new_dir()
	var vp := get_viewport().get_visible_rect().size
	var lbl := Label.new()
	lbl.text = "SWIPE in the arrow direction!"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(vp.x * 0.5 - 200, vp.y * 0.20)
	lbl.size = Vector2(400, 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)

func _pick_new_dir() -> void:
	var new_dir := randi() % 4
	while new_dir == current_dir:
		new_dir = randi() % 4
	current_dir = new_dir

func _process(delta: float) -> void:
	if finished:
		return
	time_left -= delta
	if time_left <= 0:
		time_left = 0
		_finish(false)
		return
	queue_redraw()

func _draw() -> void:
	var vp := get_viewport().get_visible_rect().size
	var center := Vector2(vp.x * 0.5, vp.y * 0.55)
	# Arrow
	var arrow_dir := Vector2.ZERO
	match current_dir:
		0: arrow_dir = Vector2(0, -1)
		1: arrow_dir = Vector2(1, 0)
		2: arrow_dir = Vector2(0, 1)
		3: arrow_dir = Vector2(-1, 0)
	# Arrow background
	draw_circle(center, 50, Color(0.20, 0.20, 0.30))
	# Arrow shape (triangle)
	var tip := center + arrow_dir * 35
	var perp := Vector2(-arrow_dir.y, arrow_dir.x) * 20
	var p1 := tip
	var p2 := center - arrow_dir * 15 + perp
	var p3 := center - arrow_dir * 15 - perp
	var col := Color(0.95, 0.85, 0.40)
	draw_colored_polygon(PackedVector2Array([p1, p2, p3]), col)
	# Success counter
	draw_string(ThemeDB.get_default_theme().default_font, Vector2(vp.x * 0.25, vp.y * 0.85), "Hits: %d / %d" % [successes, SUCCESS_NEEDED], HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.85, 0.95, 0.85))
	draw_string(ThemeDB.get_default_theme().default_font, Vector2(vp.x * 0.75, vp.y * 0.85), "Time: %.1fs" % time_left, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.95, 0.85, 0.40))

func _input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_start = event.position
		else:
			if dragging:
				_evaluate_swipe(drag_start, event.position)
				dragging = false
	elif event is InputEventMouseMotion and dragging:
		# If dragged far enough, evaluate
		if drag_start.distance_to(event.position) > 30:
			_evaluate_swipe(drag_start, event.position)
			dragging = false

func _evaluate_swipe(from: Vector2, to: Vector2) -> void:
	var delta_v := to - from
	if delta_v.length() < 15:
		return  # too small
	# Determine direction
	var angle := atan2(delta_v.y, delta_v.x)
	# Convert angle to direction index: 0=up, 1=right, 2=down, 3=left
	var dir_idx := -1
	# Up: angle around -PI/2
	if angle < -PI * 0.25 and angle > -PI * 0.75:
		dir_idx = 0  # up
	elif angle >= -PI * 0.25 and angle < PI * 0.25:
		dir_idx = 1  # right
	elif angle >= PI * 0.25 and angle < PI * 0.75:
		dir_idx = 2  # down
	else:
		dir_idx = 3  # left
	if dir_idx == current_dir:
		successes += 1
		if successes >= SUCCESS_NEEDED:
			_finish(true)
		else:
			_pick_new_dir()
	# Wrong swipe = lose (gauntlet takes a pip)
	else:
		_finish(false)

func _finish(success: bool) -> void:
	finished = true
	await get_tree().create_timer(0.3).timeout
	result.emit(success)
	queue_free()
