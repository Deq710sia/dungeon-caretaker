extends Node2D
## Microgame: Slippery Sword Catch — TAP RAPIDLY
## Mash the click button to fill the grip meter before time runs out.

signal result(success: bool)

const TIME_LIMIT: float = 3.5
const TAPS_NEEDED: int = 14

var time_left: float = TIME_LIMIT
var taps: int = 0
var finished: bool = false

func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	# Banner
	var lbl := Label.new()
	lbl.text = "TAP RAPIDLY! Catch the slippery sword!"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(vp.x * 0.5 - 200, vp.y * 0.30)
	lbl.size = Vector2(400, 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)

func _process(delta: float) -> void:
	if finished:
		return
	time_left -= delta
	if time_left <= 0:
		time_left = 0
		_finish(taps >= TAPS_NEEDED)
		return
	queue_redraw()

func _draw() -> void:
	var vp := get_viewport().get_visible_rect().size
	# Meter
	var meter_x := vp.x * 0.25
	var meter_y := vp.y * 0.55
	var meter_w := vp.x * 0.50
	var meter_h := 24.0
	# Background
	draw_rect(Rect2(meter_x, meter_y, meter_w, meter_h), Color(0.20, 0.18, 0.20), true)
	# Target zone
	var target_w := meter_w * (float(TAPS_NEEDED) / 30.0)
	draw_rect(Rect2(meter_x + meter_w - target_w, meter_y, target_w, meter_h), Color(0.30, 0.55, 0.30), true)
	# Fill
	var fill_w := meter_w * (float(taps) / 30.0)
	draw_rect(Rect2(meter_x, meter_y, fill_w, meter_h), Color(0.95, 0.85, 0.40), true)
	# Border
	draw_rect(Rect2(meter_x, meter_y, meter_w, meter_h), Color(0.55, 0.55, 0.65), false, 2)
	# Stats
	draw_string(ThemeDB.get_default_theme().default_font, Vector2(meter_x, meter_y + meter_h + 18), "Taps: %d / %d" % [taps, TAPS_NEEDED], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.95, 0.85))
	draw_string(ThemeDB.get_default_theme().default_font, Vector2(meter_x + meter_w, meter_y + meter_h + 18), "Time: %.1fs" % time_left, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color(0.95, 0.85, 0.40))

func _input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		taps += 1
		if taps >= TAPS_NEEDED:
			_finish(true)

func _finish(success: bool) -> void:
	finished = true
	await get_tree().create_timer(0.3).timeout
	result.emit(success)
	queue_free()
