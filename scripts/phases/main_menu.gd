extends Node2D
## Phase: main_menu V3 — title screen.

func _ready() -> void:
	# Title
	var title := Label.new()
	title.text = "DUNGEON CARETAKER"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 4)
	title.position = Vector2(40, 60)
	title.size = Vector2(560, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# Subtitle
	var sub := Label.new()
	sub.text = "A Ghost's Salvage"
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.65, 0.55, 0.85))
	sub.position = Vector2(40, 96)
	sub.size = Vector2(560, 16)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	# Decorative ghost
	var ghost := Sprite2D.new()
	ghost.texture = Sprites.get_sprite("ghost")
	ghost.scale = Vector2(4, 4)
	ghost.position = Vector2(320, 180)
	ghost.modulate = Color(1, 1, 1, 0.5)
	add_child(ghost)

	# Buttons
	var start_btn := Button.new()
	start_btn.text = "Start New Run"
	start_btn.add_theme_font_size_override("font_size", 12)
	start_btn.position = Vector2(220, 240)
	start_btn.size = Vector2(200, 32)
	start_btn.pressed.connect(_on_start)
	add_child(start_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.add_theme_font_size_override("font_size", 12)
	quit_btn.position = Vector2(220, 280)
	quit_btn.size = Vector2(200, 28)
	quit_btn.pressed.connect(_on_quit)
	add_child(quit_btn)

	# Hint
	var hint := Label.new()
	hint.text = "WASD: move | E: interact | 1: ghost ability | ESC: menu"
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	hint.position = Vector2(40, 330)
	hint.size = Vector2(560, 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

func _on_start() -> void:
	GameState.start_new_run()
	GameState.set_phase("planning")

func _on_quit() -> void:
	get_tree().quit()
