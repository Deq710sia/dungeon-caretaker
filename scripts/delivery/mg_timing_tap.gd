extends Node2D
## Microgame: Catch the Runaway Shield — TIMING TAP
## Marker sweeps a bar; tap when it's in the green zone. 2 hits to win.
## Missing the green zone = fail (lose a pip).

signal result(success: bool)

const TIME_LIMIT: float = 5.0
const HITS_NEEDED: int = 2
const TARGET_W: float = 0.18  # 18% of bar width
const SWEEP_SPEED: float = 0.85  # cycles per second

var time_left: float = TIME_LIMIT
var hits: int = 0
var marker_x: float = 0.0
var dir: float = 1.0
var target_center: float = 0.5
var finished: bool = false

func _ready() -> void:
	_randomize_target()
	var vp := get_viewport().get_visible_rect().size
	var lbl := Label.new()
	lbl.text = "TAP when marker hits the GREEN zone!"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(vp.x * 0.5 - 200, vp.y * 0.25)
	lbl.size = Vector2(400, 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)

func _randomize_target() -> void:
	target_center = randf_range(0.20, 0.80)

func _process(delta: float) -> void:
	if finished:
		return
	time_left -= delta
	if time_left <= 0:
		time_left = 0
		_finish(false)
		return
	marker_x += dir * SWEEP_SPEED * delta
	if marker_x >= 1.0:
		marker_x = 1.0
		dir = -1.0
	elif marker_x <= 0.0:
		marker_x = 0.0
		dir = 1.0
	queue_redraw()

func _draw() -> void:
	var vp := get_viewport().get_visible_rect().size
	var bar_x := vp.x * 0.15
	var bar_y := vp.y * 0.50
	var bar_w := vp.x * 0.70
	var bar_h := 28.0
	# Background
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.18, 0.10, 0.10), true)
	# Target zone
	var tz_x := bar_x + bar_w * (target_center - TARGET_W / 2)
	draw_rect(Rect2(tz_x, bar_y, bar_w * TARGET_W, bar_h), Color(0.30, 0.65, 0.30), true)
	# Marker
	var mx := bar_x + bar_w * marker_x
	draw_rect(Rect2(mx - 4, bar_y - 6, 8, bar_h + 12), Color(0.95, 0.85, 0.30), true)
	# Border
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.55, 0.55, 0.65), false, 2)
	# Stats
	draw_string(ThemeDB.get_default_theme().default_font, Vector2(bar_x, bar_y + bar_h + 18), "Hits: %d / %d" % [hits, HITS_NEEDED], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.95, 0.85))
	draw_string(ThemeDB.get_default_theme().default_font, Vector2(bar_x + bar_w, bar_y + bar_h + 18), "Time: %.1fs" % time_left, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color(0.95, 0.85, 0.40))

func _input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Evaluate hit
		var diff := absf(marker_x - target_center)
		if diff <= TARGET_W / 2.0:
			hits += 1
			if hits >= HITS_NEEDED:
				_finish(true)
			else:
				_randomize_target()
		else:
			_finish(false)  # missed

func _finish(success: bool) -> void:
	finished = true
	await get_tree().create_timer(0.3).timeout
	result.emit(success)
	queue_free()
