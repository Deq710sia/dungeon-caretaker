extends Node2D
## Repair Minigame: Oil & Grindstone (V2)
## Removes RUSTED state. The WEAPON is drawn large, rotating on the grindstone.
## Hold mouse to pour oil; keep the meter in the green band.

signal completed(quality: float)

const TIME_LIMIT: float = 7.0
const SWEET_SPOT_MIN: float = 0.55
const SWEET_SPOT_MAX: float = 0.75
const DECAY_RATE: float = 0.30
const FILL_RATE: float = 0.85

var time_left: float = TIME_LIMIT
var oil_level: float = 0.0
var pouring: bool = false
var time_in_zone: float = 0.0
var finished: bool = false
var wheel_angle: float = 0.0
var weapon_angle: float = 0.0

var gear: Weapon = null

func _ready() -> void:
	var p := get_parent()
	if p and p.get("ghost") != null and p.ghost.carrying != null:
		gear = p.ghost.carrying
	elif p and p.get("current_gear_for_minigame") != null:
		gear = p.current_weapon
	var lbl := Label.new()
	lbl.text = "OIL & GRINDSTONE — Hold mouse to pour. Keep meter GREEN!"
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.position = Vector2(0, 22)
	lbl.size = Vector2(320, 14)
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
	if pouring:
		oil_level += FILL_RATE * delta
	else:
		oil_level -= DECAY_RATE * delta
	oil_level = clampf(oil_level, 0.0, 1.0)
	if oil_level >= SWEET_SPOT_MIN and oil_level <= SWEET_SPOT_MAX:
		time_in_zone += delta
	wheel_angle += delta * (0.5 + oil_level * 4.0)
	weapon_angle += delta * (1.0 + oil_level * 3.0)  # weapon rotates faster when oiled
	queue_redraw()

func _draw() -> void:
	var vp := Vector2(320, 180)
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.04, 0.07, 0.95), true)
	# Grindstone (large, center-left)
	var wheel_center := Vector2(vp.x * 0.35, vp.y * 0.55)
	var wheel_r: float = 45.0
	# Wheel shadow
	draw_circle(wheel_center + Vector2(3, 3), wheel_r, Color(0, 0, 0, 0.4))
	# Wheel body
	draw_circle(wheel_center, wheel_r, Color(0.55, 0.55, 0.58))
	draw_circle(wheel_center, wheel_r - 4, Color(0.40, 0.40, 0.43))
	draw_circle(wheel_center, wheel_r - 8, Color(0.65, 0.65, 0.68))
	# Spokes
	for i in 8:
		var a := wheel_angle + i * (PI / 4.0)
		draw_line(wheel_center, wheel_center + Vector2(cos(a), sin(a)) * (wheel_r - 2), Color(0.25, 0.25, 0.28), 2)
	# Hub
	draw_circle(wheel_center, 8, Color(0.30, 0.20, 0.15))
	draw_circle(wheel_center, 4, Color(0.20, 0.15, 0.10))
	# Stand
	draw_rect(Rect2(wheel_center.x - 4, wheel_center.y + wheel_r, 8, 25), Color(0.45, 0.30, 0.20))
	draw_rect(Rect2(wheel_center.x - 18, wheel_center.y + wheel_r + 22, 36, 4), Color(0.30, 0.18, 0.12))
	# Sparks when oil is flowing
	if oil_level > 0.3:
		for i in 5:
			var sa := wheel_angle + i * (TAU / 5)
			var sp := wheel_center + Vector2(cos(sa), sin(sa)) * wheel_r
			draw_circle(sp, 2, Color(1.0, 0.85, 0.30, 0.8))
	# Weapon (rotating on the wheel — the centerpiece!)
	if gear != null:
		var weapon_tex := Sprites.get_weapon_sprite(gear.type, gear.state)
		# Draw weapon rotated, positioned on top of the wheel
		var wpos := wheel_center + Vector2(0, -wheel_r - 10)
		# We can't easily rotate a texture rect in _draw, so we'll draw it at an offset and use Transform2D
		var tex_size := 64
		var offset_pos := wpos - Vector2(tex_size / 2, tex_size / 2)
		# Draw weapon (just draw it scaled, with a glow when oil hits sweet spot)
		if oil_level >= SWEET_SPOT_MIN and oil_level <= SWEET_SPOT_MAX:
			# Glow effect
			draw_rect(Rect2(offset_pos.x - 4, offset_pos.y - 4, tex_size + 8, tex_size + 8), Color(0.55, 0.95, 0.55, 0.3), true)
		draw_texture_rect(weapon_tex, Rect2(offset_pos.x, offset_pos.y, tex_size, tex_size), false)
		# Weapon name
		draw_string(ThemeDB.get_default_theme().default_font, wpos + Vector2(-50, -50), gear.display_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 7, gear.wear_color())
	# Oil meter (vertical bar on right)
	var meter_x: float = vp.x * 0.75
	var meter_y: float = vp.y * 0.20
	var meter_w: float = 20
	var meter_h: float = vp.y * 0.55
	# Background
	draw_rect(Rect2(meter_x, meter_y, meter_w, meter_h), Color(0.15, 0.13, 0.18), true)
	# Sweet spot band
	var band_y: float = meter_y + meter_h * (1.0 - SWEET_SPOT_MAX)
	var band_h: float = meter_h * (SWEET_SPOT_MAX - SWEET_SPOT_MIN)
	draw_rect(Rect2(meter_x, band_y, meter_w, band_h), Color(0.30, 0.65, 0.30), true)
	# Oil fill
	var fill_h: float = meter_h * oil_level
	draw_rect(Rect2(meter_x, meter_y + meter_h - fill_h, meter_w, fill_h), Color(0.60, 0.45, 0.20), true)
	# Border
	draw_rect(Rect2(meter_x, meter_y, meter_w, meter_h), Color(0.55, 0.55, 0.65), false, 2)
	# Label
	draw_string(ThemeDB.get_default_theme().default_font, Vector2(meter_x - 4, meter_y - 4), "OIL", HORIZONTAL_ALIGNMENT_CENTER, -1, 7, Color(0.85, 0.85, 0.90))
	# Stats
	var pct: float = time_in_zone / TIME_LIMIT
	draw_string(ThemeDB.get_default_theme().default_font, Vector2(10, vp.y - 24), "In-zone: %.1fs" % time_in_zone, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.85, 0.95, 0.85))
	draw_string(ThemeDB.get_default_theme().default_font, Vector2(vp.x - 10, vp.y - 24), "Time: %.1fs" % time_left, HORIZONTAL_ALIGNMENT_RIGHT, -1, 8, Color(0.95, 0.85, 0.40))
	if pouring:
		draw_string(ThemeDB.get_default_theme().default_font, Vector2(vp.x / 2 - 20, vp.y - 24), "POURING", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.95, 0.85, 0.40))

func _input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pouring = event.pressed

func _finish() -> void:
	finished = true
	var quality: float = clampf(time_in_zone / TIME_LIMIT, 0.0, 1.0)
	await get_tree().create_timer(0.4).timeout
	completed.emit(quality)
	queue_free()
