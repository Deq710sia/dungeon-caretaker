extends Node2D
## QTE Cutscene V3 — Dumb Ways to Die style.
## One verb, 3-5 beats, ~15-25s total. Each beat is a single-input challenge.
## Failure = entertainment (comedic animation), not punishment (no run-end).

signal done(success: bool)

const BEAT_TIME: float = 3.0  # seconds per beat (first time, generous)
const BEAT_TIME_FAST: float = 1.8  # later beats tighten

var verb: String = "TAP"
var total_beats: int = 3
var current_beat: int = 0
var beats_succeeded: int = 0
var beat_time_left: float = BEAT_TIME
var finished: bool = false
var callback: Callable
var beat_active: bool = false

# Visual state
var marker_x: float = 0.5
var marker_dir: float = 1.0
var marker_speed: float = 0.6
var target_x: float = 0.5
var target_w: float = 0.20
var prompt_label: Label
var beat_label: Label

func _ready() -> void:
	# Dim overlay
	_build_ui()
	_start_beat()

func _build_ui() -> void:
	var vp := Vector2(640, 360)
	# Title
	var title := Label.new()
	title.text = "QTE! %s!" % verb
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 4)
	title.position = Vector2(0, 100)
	title.size = Vector2(vp.x, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# Prompt (changes per beat)
	prompt_label = Label.new()
	prompt_label.text = "%s when marker hits GREEN!" % verb
	prompt_label.add_theme_font_size_override("font_size", 12)
	prompt_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	prompt_label.add_theme_constant_override("outline_size", 2)
	prompt_label.position = Vector2(0, 140)
	prompt_label.size = Vector2(vp.x, 16)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(prompt_label)

	# Beat counter
	beat_label = Label.new()
	beat_label.text = "Beat 1 / %d" % total_beats
	beat_label.add_theme_font_size_override("font_size", 10)
	beat_label.add_theme_color_override("font_color", Color(0.65, 0.85, 0.95))
	beat_label.position = Vector2(0, 165)
	beat_label.size = Vector2(vp.x, 14)
	beat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(beat_label)

func start(p_verb: String, p_beats: int, p_callback: Callable) -> void:
	verb = p_verb
	total_beats = p_beats
	callback = p_callback

func _start_beat() -> void:
	if current_beat >= total_beats:
		_finish()
		return
	beat_active = true
	beat_time_left = BEAT_TIME if current_beat == 0 else BEAT_TIME_FAST
	target_x = randf_range(0.25, 0.75)
	marker_x = 0.0 if randf() > 0.5 else 1.0
	marker_dir = 1.0 if marker_x == 0.0 else -1.0
	marker_speed = 0.6 + current_beat * 0.15
	beat_label.text = "Beat %d / %d" % [current_beat + 1, total_beats]
	prompt_label.text = "%s when marker hits GREEN!" % verb

func _process(delta: float) -> void:
	if finished or not beat_active:
		return
	beat_time_left -= delta
	if beat_time_left <= 0:
		# Beat failed (timeout)
		_beat_result(false)
		return
	marker_x += marker_dir * marker_speed * delta
	if marker_x >= 1.0:
		marker_x = 1.0
		marker_dir = -1.0
	elif marker_x <= 0.0:
		marker_x = 0.0
		marker_dir = 1.0
	queue_redraw()

func _draw() -> void:
	var vp := Vector2(640, 360)
	# Dim background
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.7), true)
	if not beat_active and not finished:
		return
	# QTE bar
	var bar_x: float = vp.x * 0.20
	var bar_y: float = vp.y * 0.55
	var bar_w: float = vp.x * 0.60
	var bar_h: float = 40.0
	# Background
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.18, 0.10, 0.10), true)
	# Target zone (green)
	var tz_x: float = bar_x + bar_w * (target_x - target_w / 2)
	draw_rect(Rect2(tz_x, bar_y, bar_w * target_w, bar_h), Color(0.30, 0.65, 0.30), true)
	# Marker
	var mx: float = bar_x + bar_w * marker_x
	draw_rect(Rect2(mx - 6, bar_y - 8, 12, bar_h + 16), Color(0.95, 0.85, 0.30), true)
	# Border
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.55, 0.55, 0.65), false, 3)
	# Time bar
	var time_pct: float = beat_time_left / (BEAT_TIME if current_beat == 0 else BEAT_TIME_FAST)
	draw_rect(Rect2(bar_x, bar_y + bar_h + 8, bar_w, 4), Color(0.20, 0.20, 0.20), true)
	draw_rect(Rect2(bar_x, bar_y + bar_h + 8, bar_w * time_pct, 4), Color(0.95, 0.55, 0.40), true)
	# Verb hint (big, centered)
	draw_string(ThemeDB.get_default_theme().default_font, Vector2(vp.x / 2 - 30, vp.y * 0.50), verb, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(0.95, 0.95, 0.40))

func _input(event: InputEvent) -> void:
	if finished or not beat_active:
		return
	# Accept: left click OR spacebar OR E
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or \
	   (event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_E]):
		# Evaluate: is marker in target zone?
		var diff: float = absf(marker_x - target_x)
		if diff <= target_w / 2.0:
			_beat_result(true)
		else:
			_beat_result(false)

func _beat_result(success: bool) -> void:
	beat_active = false
	if success:
		beats_succeeded += 1
		prompt_label.text = "GOOD! %s" % verb
		# Success particles
		for i in 8:
			get_parent().particles.append({
				"pos": Vector2(640, 360) / 2 + Vector2(randf_range(-40, 40), randf_range(-20, 20)),
				"vel": Vector2(randf_range(-60, 60), randf_range(-60, 60)),
				"color": Color(0.55, 0.95, 0.55),
				"life": 0.4,
				"max_life": 0.4,
			})
	else:
		prompt_label.text = "MISS!"
	current_beat += 1
	await get_tree().create_timer(0.6).timeout
	_start_beat()

func _finish() -> void:
	if finished:
		return
	finished = true
	# Success if majority of beats succeeded
	var success: bool = beats_succeeded >= total_beats / 2 + 1
	await get_tree().create_timer(0.4).timeout
	callback.call(success)
	queue_free()
