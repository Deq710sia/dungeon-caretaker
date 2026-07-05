extends Node2D
## Delivery Gauntlet — Dumb Ways to Die style QTE overlay.
## Spawns 3-5 microgames in sequence. Player has 3 "integrity pips".
## Each failed microgame loses a pip. At 0 pips, gauntlet fails catastrophically.

signal done(success: bool, integrity: int)

var pips: int = 3
var current_mg: Node2D = null
var current_round: int = 0
var total_rounds: int = 4
var gear: GearItem = null
var callback: Callable
var finished: bool = false

const MG_SCRIPTS := [
	preload("res://scripts/delivery/mg_tap_rapid.gd"),
	preload("res://scripts/delivery/mg_swipe_direction.gd"),
	preload("res://scripts/delivery/mg_timing_tap.gd"),
	preload("res://scripts/delivery/mg_trace_sigil.gd"),
	preload("res://scripts/delivery/mg_multi_hold.gd"),
	preload("res://scripts/delivery/mg_do_nothing.gd"),
]

const MG_NAMES := [
	"Slippery Sword Catch!",
	"Helm Down the Stairs!",
	"Catch the Runaway Shield!",
	"Trace the Warding Sigil!",
	"Poltergeist Repel!",
	"Don't Touch the Cursed Bell!",
]

var used_indices: Array = []

func start(p_gear: GearItem, p_callback: Callable) -> void:
	gear = p_gear
	callback = p_callback
	_spawn_next()

func _spawn_next() -> void:
	if finished:
		return
	if current_round >= total_rounds or pips <= 0:
		_finish()
		return
	# Pick a random microgame (no repeats until pool exhausted)
	if used_indices.size() >= MG_SCRIPTS.size():
		used_indices.clear()
	var idx := randi() % MG_SCRIPTS.size()
	while idx in used_indices:
		idx = randi() % MG_SCRIPTS.size()
	used_indices.append(idx)
	current_mg = Node2D.new()
	current_mg.set_script(MG_SCRIPTS[idx])
	current_mg.name = "Microgame_%d" % idx
	add_child(current_mg)
	# Microgames signal success(bool)
	if current_mg.has_signal("result"):
		current_mg.result.connect(_on_mg_result)
	current_round += 1

func _on_mg_result(success: bool) -> void:
	if current_mg:
		current_mg.queue_free()
		current_mg = null
	if not success:
		pips -= 1
		# Brief delay so player sees the fail
		await get_tree().create_timer(0.4).timeout
	if pips <= 0:
		_finish()
		return
	# Brief delay before next
	await get_tree().create_timer(0.4).timeout
	_spawn_next()

func _finish() -> void:
	if finished:
		return
	finished = true
	var success := pips > 0
	await get_tree().create_timer(0.4).timeout
	callback.call(success, pips)
	# Self-cleanup happens via the entrance_hall when callback fires
	queue_free()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# Dim the background
	var vp := get_viewport().get_visible_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.6), true)
	# Pip display (top-right)
	var label := "Round %d/%d  |  Pips: " % [current_round, total_rounds]
	for i in 3:
		label += "O " if i < pips else "X "
	draw_string(ThemeDB.get_default_theme().default_font, Vector2(vp.x - 200, 24), label, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color(0.95, 0.85, 0.40))
	# Gear label
	if gear:
		draw_string(ThemeDB.get_default_theme().default_font, Vector2(vp.x / 2 - 100, 24), "Delivering: %s [%s]" % [gear.display_name, gear.state_name()], HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.85, 0.95, 0.85))
