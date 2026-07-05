extends Node2D
## Repair Minigame: Oil & Grindstone
## Removes RUSTED state. Hold mouse to pour oil while rotating the grindstone.
## Goal: keep the oil-level meter inside the green "sweet spot" band for as long as possible.

signal completed(quality: float)

const TIME_LIMIT: float = 6.0
const SWEET_SPOT_MIN: float = 0.55
const SWEET_SPOT_MAX: float = 0.75
const DECAY_RATE: float = 0.30     # oil drains over time
const FILL_RATE: float = 0.85      # oil fills when mouse held

var time_left: float = TIME_LIMIT
var oil_level: float = 0.0  # 0..1
var pouring: bool = false
var time_in_zone: float = 0.0
var finished: bool = false

var wheel_angle: float = 0.0
var area_origin: Vector2
var area_size: Vector2

func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	area_origin = Vector2(vp.x * 0.15, vp.y * 0.30)
	area_size = Vector2(vp.x * 0.70, vp.y * 0.35)

	var lbl := Label.new()
	lbl.text = "Oil & Grindstone — Hold mouse to pour. Keep meter in the GREEN band!"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(area_origin.x - 60, area_origin.y - 24)
	lbl.size = Vector2(area_size.x + 120, 20)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)

func _process(delta: float) -> void:
	if finished:
		return
	time_left -= delta
	if time_left <= 0:
		time_left = 0
		_finish()
		return
	# Update oil level
	if pouring:
		oil_level += FILL_RATE * delta
	else:
		oil_level -= DECAY_RATE * delta
	oil_level = clampf(oil_level, 0.0, 1.0)
	# Track time in zone
	if oil_level >= SWEET_SPOT_MIN and oil_level <= SWEET_SPOT_MAX:
		time_in_zone += delta
	# Wheel spins faster when oiled
	wheel_angle += delta * (0.5 + oil_level * 4.0)
	queue_redraw()

func _draw() -> void:
	# Background
	draw_rect(Rect2(area_origin, area_size), Color(0.10, 0.08, 0.14), true)
	# Wheel
	var wheel_center := area_origin + Vector2(area_size.x * 0.30, area_size.y * 0.50)
	var wheel_r: float = min(area_size.x, area_size.y) * 0.30
	# Wheel shadow
	draw_circle(wheel_center + Vector2(2, 2), wheel_r, Color(0.05, 0.04, 0.07))
	# Wheel body
	draw_circle(wheel_center, wheel_r, Color(0.55, 0.55, 0.58))
	# Wheel spokes
	for i in 8:
		var a := wheel_angle + i * (PI / 4.0)
		draw_line(wheel_center, wheel_center + Vector2(cos(a), sin(a)) * wheel_r, Color(0.30, 0.30, 0.33), 2)
	# Hub
	draw_circle(wheel_center, wheel_r * 0.15, Color(0.20, 0.20, 0.23))

	# Oil meter (vertical bar on right)
	var meter_x := area_origin.x + area_size.x * 0.65
	var meter_y := area_origin.y + area_size.y * 0.10
	var meter_w := area_size.x * 0.08
	var meter_h := area_size.y * 0.80
	# Background
	draw_rect(Rect2(meter_x, meter_y, meter_w, meter_h), Color(0.15, 0.13, 0.18), true)
	# Sweet spot band
	var band_y := meter_y + meter_h * (1.0 - SWEET_SPOT_MAX)
	var band_h := meter_h * (SWEET_SPOT_MAX - SWEET_SPOT_MIN)
	draw_rect(Rect2(meter_x, band_y, meter_w, band_h), Color(0.30, 0.65, 0.30), true)
	# Oil fill
	var fill_h := meter_h * oil_level
	draw_rect(Rect2(meter_x, meter_y + meter_h - fill_h, meter_w, fill_h), Color(0.60, 0.45, 0.20), true)
	# Border
	draw_rect(Rect2(meter_x, meter_y, meter_w, meter_h), Color(0.55, 0.55, 0.65), false, 2)

	# Stats
	var _pct := time_in_zone / TIME_LIMIT
	draw_string(get_default_font(), area_origin + Vector2(8, area_size.y + 20), "In-zone: %.1fs / %.1fs" % [time_in_zone, TIME_LIMIT], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.95, 0.85))
	draw_string(get_default_font(), area_origin + Vector2(area_size.x - 8, area_size.y + 20), "Time: %.1fs" % time_left, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color(0.95, 0.85, 0.40))

	# "POUR" indicator
	if pouring:
		draw_string(get_default_font(), wheel_center + Vector2(-20, -wheel_r - 12), "POUR", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.95, 0.85, 0.40))

func _input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pouring = event.pressed

func _finish() -> void:
	finished = true
	# Quality = fraction of time spent in sweet spot
	var quality := clampf(time_in_zone / TIME_LIMIT, 0.0, 1.0)
	await get_tree().create_timer(0.5).timeout
	completed.emit(quality)

func get_default_font() -> Font:
	return ThemeDB.get_default_theme().default_font
