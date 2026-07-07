extends Node2D
## Main phase manager V6.
## Phase flow: menu -> gate -> salvage -> workshop -> upgrade -> planning
## -> battle -> results -> aftermath -> gate -> salvage -> ... (loop)
## A new run starts at the GATE (walking past predecessor graves), not
## planning — so the first thing the player sees is the dungeon's history
## of failure before they ever collect or assign gear.

const PHASE_SCRIPTS := {
	"menu":         preload("res://scripts/phases/main_menu.gd"),
	"gate":         preload("res://scripts/phases/gate.gd"),
	"salvage":      preload("res://scripts/phases/salvage.gd"),
	"workshop":     preload("res://scripts/phases/workshop.gd"),
	"battle":       preload("res://scripts/phases/battle.gd"),
	"results":      preload("res://scripts/phases/results.gd"),
	"aftermath":    preload("res://scripts/phases/aftermath.gd"),
	"upgrade":      preload("res://scripts/phases/upgrade_shop.gd"),
	"planning":     preload("res://scripts/phases/planning.gd"),
	"win_lose":     preload("res://scripts/phases/win_lose.gd"),
}

var current_phase_node: Node2D = null
var background: ColorRect
var pause_overlay: CanvasLayer = null
var is_paused: bool = false

func _ready() -> void:
	background = ColorRect.new()
	background.color = Color(0.05, 0.04, 0.07)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set("layout_mode", 1)
	# process_mode = ALWAYS so _input still fires when the tree is paused
	# (needed for ESC to resume from pause). Without this, the pause
	# overlay's buttons can't be clicked and ESC can't unpause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.phase_changed.connect(_on_phase_changed)
	_on_phase_changed("menu")
	DisplayServer.window_set_title("Dungeon Caretaker: A Ghost's Salvage")

func _on_phase_changed(new_phase: String) -> void:
	# Every phase transition now actually cross-fades (this used to be
	# dead code: fade_rect was only ever created inside _start_fade(),
	# which nothing called, so this branch never ran and every change
	# was an instant, jarring cut).
	_start_fade(_instantiate_phase.bind(new_phase))

func _instantiate_phase(new_phase: String) -> void:
	if current_phase_node:
		if current_phase_node.has_method("_on_phase_exit"):
			current_phase_node._on_phase_exit()
		current_phase_node.queue_free()
		current_phase_node = null
	# A fresh phase shouldn't inherit leftover shake/particles/trail from the last one.
	Juice.clear_particles()
	Juice.trail_clear()
	Juice.trauma = 0.0
	Juice.shake_amount = 0.0
	Juice.hit_stop_timer = 0.0
	Juice.trail_phasing = false
	var script: GDScript = PHASE_SCRIPTS.get(new_phase)
	if script == null:
		push_error("Unknown phase: " + new_phase)
		return
	current_phase_node = Node2D.new()
	current_phase_node.set_script(script)
	current_phase_node.name = "Phase_" + new_phase
	# Explicitly PAUSABLE so the phase stops processing when the tree is
	# paused (ESC). main.gd is ALWAYS (for ESC/_input), but phase nodes
	# must stop — otherwise movement, timers, and combat keep running
	# behind the pause overlay.
	current_phase_node.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(current_phase_node)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# ESC pauses the game instead of quitting to menu. The pause overlay
		# shows Resume + Quit to Menu buttons. The run state is fully
		# preserved — resuming picks up exactly where you left off.
		# Previously ESC called GameState.set_phase("menu") which abandoned
		# the current phase (and any carried weapon) mid-action.
		if GameState.current_phase == "menu":
			return  # already at menu, ESC does nothing
		if is_paused:
			_unpause()
		else:
			_pause()

func _pause() -> void:
	if is_paused:
		return
	is_paused = true
	get_tree().paused = true
	pause_overlay = CanvasLayer.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.layer = 200
	# process_mode = ALWAYS so the overlay's buttons still receive clicks
	# while the tree is paused. Without this, the buttons are frozen and
	# Resume is unreachable (the bug the user reported).
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_overlay)
	# Dim background
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_overlay.add_child(dim)
	# Title
	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Palette.TEXT)
	title.add_theme_color_override("font_outline_color", Palette.VOID)
	title.add_theme_constant_override("outline_size", 2)
	title.position = Vector2(160, 90)
	title.size = Vector2(160, 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_overlay.add_child(title)
	# Resume button
	var resume_btn := Button.new()
	resume_btn.text = "Resume"
	resume_btn.add_theme_font_size_override("font_size", 8)
	resume_btn.position = Vector2(160, 130)
	resume_btn.size = Vector2(160, 20)
	resume_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	resume_btn.pressed.connect(_unpause)
	pause_overlay.add_child(resume_btn)
	# Quit to menu button
	var quit_btn := Button.new()
	quit_btn.text = "Quit to Menu"
	quit_btn.add_theme_font_size_override("font_size", 8)
	quit_btn.position = Vector2(160, 155)
	quit_btn.size = Vector2(160, 18)
	quit_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	quit_btn.pressed.connect(_quit_to_menu)
	pause_overlay.add_child(quit_btn)
	# Hint
	var hint := Label.new()
	hint.text = "ESC: resume"
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Palette.TEXT_DIM)
	hint.position = Vector2(160, 180)
	hint.size = Vector2(160, 10)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_overlay.add_child(hint)
	resume_btn.grab_focus()

func _unpause() -> void:
	if not is_paused:
		return
	is_paused = false
	get_tree().paused = false
	if pause_overlay:
		pause_overlay.queue_free()
		pause_overlay = null

func _quit_to_menu() -> void:
	# Quit to menu — this DOES abandon the current run's phase, but
	# GameState (party, arsenal, stage/wave) persists so the player can
	# start a new run from the menu. The current phase's _on_phase_exit
	# is called via _instantiate_phase to preserve any carried weapon.
	is_paused = false
	get_tree().paused = false
	if pause_overlay:
		pause_overlay.queue_free()
		pause_overlay = null
	GameState.set_phase("menu")

# V2: Screen fade transition between phases
var fade_rect: ColorRect
var fade_tween: Tween

func _start_fade(callback: Callable) -> void:
	if fade_rect == null:
		fade_rect = ColorRect.new()
		fade_rect.color = Color(0, 0, 0, 0)
		fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade_rect.z_index = 100
		add_child(fade_rect)
	if fade_tween:
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 1.0, 0.15)
	fade_tween.tween_callback(callback)
	fade_tween.tween_property(fade_rect, "color:a", 0.0, 0.15)
