extends Node2D
## Microgame: Don't Touch the Cursed Bell — DO NOTHING (reverse QTE)
## A glowing bell pulses with "RING ME?" prompt. Player must NOT click it for the duration.
## Clicking = instant fail. Surviving = success.

signal result(success: bool)

const TIME_LIMIT: float = 3.5

var time_left: float = TIME_LIMIT
var finished: bool = false
var bell_pos: Vector2
var bell_r: float = 40.0

func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	bell_pos = Vector2(vp.x * 0.5, vp.y * 0.55)
	bell_r = min(vp.x, vp.y) * 0.10
	var lbl := Label.new()
	lbl.text = "DON'T TOUCH the cursed bell! Just wait..."
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.55, 0.95))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(vp.x * 0.5 - 200, vp.y * 0.20)
	lbl.size = Vector2(400, 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)

func _process(delta: float) -> void:
	if finished:
		return
	time_left -= delta
	if time_left <= 0:
		time_left = 0
		_finish(true)  # Survived!
		return
	queue_redraw()

func _draw() -> void:
	var vp := get_viewport().get_visible_rect().size
	# Bell (pulsing)
	var pulse := 1.0 + 0.10 * sin(Time.get_ticks_msec() * 0.005)
	var r := bell_r * pulse
	# Outer glow
	draw_circle(bell_pos, r + 8, Color(0.65, 0.40, 0.85, 0.30))
	# Bell body
	draw_circle(bell_pos, r, Color(0.55, 0.35, 0.75))
	# Inner highlight
	draw_circle(bell_pos - Vector2(r * 0.3, r * 0.3), r * 0.3, Color(0.85, 0.65, 0.95, 0.6))
	# "RING ME?" text
	draw_string(ThemeDB.get_default_theme().default_font, bell_pos + Vector2(-40, r + 24), "RING ME?", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.95, 0.85, 0.40))
	# Stats
	draw_string(ThemeDB.get_default_theme().default_font, Vector2(vp.x * 0.75, vp.y * 0.88), "Hold steady: %.1fs" % time_left, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.95, 0.85, 0.40))

func _input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.distance_to(bell_pos) < bell_r + 8:
			_finish(false)  # Clicked the bell!
		# Clicks elsewhere are fine

func _finish(success: bool) -> void:
	finished = true
	await get_tree().create_timer(0.3).timeout
	result.emit(success)
	queue_free()
