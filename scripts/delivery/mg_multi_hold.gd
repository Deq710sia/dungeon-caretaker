extends Node2D
## Microgame: Poltergeist Repel — MULTI-HOLD
## Multiple glowing handprints appear; player must hold a finger (mouse button) on each.
## Since this is desktop, we use 1 handprint at a time, but spawn them rapidly.
## Player must HOLD the mouse button down on the active handprint for 0.6s to dispel it.
## Dispel 4 handprints before time runs out.

signal result(success: bool)

const TIME_LIMIT: float = 5.0
const DISPEL_NEEDED: int = 4
const HOLD_TIME: float = 0.6  # seconds to hold each

var time_left: float = TIME_LIMIT
var dispels: int = 0
var active_handprint: Vector2 = Vector2.ZERO
var handprint_active: bool = false
var handprint_hold_time: float = 0.0
var mouse_down: bool = false
var mouse_pos: Vector2 = Vector2.ZERO
var finished: bool = false

func _ready() -> void:
	_spawn_handprint()
	var vp := get_viewport().get_visible_rect().size
	var lbl := Label.new()
	lbl.text = "HOLD mouse on the glowing handprint to dispel it!"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.85, 0.95))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(vp.x * 0.5 - 200, vp.y * 0.20)
	lbl.size = Vector2(400, 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)

func _spawn_handprint() -> void:
	var vp := get_viewport().get_visible_rect().size
	active_handprint = Vector2(randf_range(vp.x * 0.25, vp.x * 0.75), randf_range(vp.y * 0.35, vp.y * 0.70))
	handprint_active = true
	handprint_hold_time = 0.0

func _process(delta: float) -> void:
	if finished:
		return
	time_left -= delta
	if time_left <= 0:
		time_left = 0
		_finish(false)
		return
	# Check if mouse is held over the handprint
	if handprint_active and mouse_down and mouse_pos.distance_to(active_handprint) < 30:
		handprint_hold_time += delta
		if handprint_hold_time >= HOLD_TIME:
			dispels += 1
			handprint_active = false
			if dispels >= DISPEL_NEEDED:
				_finish(true)
			else:
				_spawn_handprint()
	queue_redraw()

func _draw() -> void:
	var vp := get_viewport().get_visible_rect().size
	if handprint_active:
		# Draw a stylized handprint (circle with fingers)
		var c := Color(0.85, 0.55, 0.95, 0.9)
		var progress_c := Color(0.55, 0.95, 0.75, 0.95)
		# Palm
		draw_circle(active_handprint, 20, c)
		# Fingers (small circles)
		for i in 4:
			var a := -PI / 2.0 + (i - 1.5) * 0.4
			draw_circle(active_handprint + Vector2(cos(a), sin(a)) * 22, 6, c)
		# Hold progress ring
		if mouse_down and mouse_pos.distance_to(active_handprint) < 30:
			var pct := handprint_hold_time / HOLD_TIME
			# Draw arc as a thick line
			var arc_pts := PackedVector2Array()
			var segs := 24
			for s in segs + 1:
				var a := -PI / 2.0 + (float(s) / segs) * 2.0 * PI * pct
				arc_pts.append(active_handprint + Vector2(cos(a), sin(a)) * 28)
			if arc_pts.size() >= 2:
				for s in arc_pts.size() - 1:
					draw_line(arc_pts[s], arc_pts[s + 1], progress_c, 3)
	# Stats
	draw_string(ThemeDB.get_default_theme().default_font, Vector2(vp.x * 0.25, vp.y * 0.88), "Dispelled: %d / %d" % [dispels, DISPEL_NEEDED], HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.85, 0.95, 0.85))
	draw_string(ThemeDB.get_default_theme().default_font, Vector2(vp.x * 0.75, vp.y * 0.88), "Time: %.1fs" % time_left, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.95, 0.85, 0.40))

func _input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_down = event.pressed
		if mouse_down:
			mouse_pos = event.position
	elif event is InputEventMouseMotion:
		mouse_pos = event.position

func _finish(success: bool) -> void:
	finished = true
	await get_tree().create_timer(0.3).timeout
	result.emit(success)
	queue_free()
