extends Node2D
## Phase: main_menu — title screen, start run, quit.
## Uses absolute positioning in 320x180 logical space (stretch mode = viewport).

var title_label: Label
var subtitle_label: Label
var start_btn: Button
var quit_btn: Button
var bg_sprite: Sprite2D

func _ready() -> void:
	# Title
	title_label = Label.new()
	title_label.text = "DUNGEON CARETAKER"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.position = Vector2(20, 24)
	title_label.size = Vector2(280, 24)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title_label)

	# Subtitle
	subtitle_label = Label.new()
	subtitle_label.text = "A Ghost's Salvage"
	subtitle_label.add_theme_font_size_override("font_size", 10)
	subtitle_label.add_theme_color_override("font_color", Color(0.65, 0.55, 0.85))
	subtitle_label.position = Vector2(20, 50)
	subtitle_label.size = Vector2(280, 14)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle_label)

	# Decorative ghost
	bg_sprite = Sprite2D.new()
	bg_sprite.texture = Sprites.get_sprite("ghost")
	bg_sprite.scale = Vector2(4, 4)
	bg_sprite.position = Vector2(160, 95)
	bg_sprite.modulate = Color(1, 1, 1, 0.4)
	add_child(bg_sprite)

	# Buttons (absolute positions in 320x180 space)
	start_btn = Button.new()
	start_btn.text = "Start New Run"
	start_btn.add_theme_font_size_override("font_size", 10)
	start_btn.position = Vector2(80, 130)
	start_btn.size = Vector2(160, 20)
	start_btn.pressed.connect(_on_start)
	add_child(start_btn)

	quit_btn = Button.new()
	quit_btn.text = "Quit"
	quit_btn.add_theme_font_size_override("font_size", 10)
	quit_btn.position = Vector2(80, 154)
	quit_btn.size = Vector2(160, 18)
	quit_btn.pressed.connect(_on_quit)
	add_child(quit_btn)

	# Hint at bottom
	var hint := Label.new()
	hint.text = "WASD: move | E/Space: interact | 1: ability | ESC: menu"
	hint.add_theme_font_size_override("font_size", 6)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	hint.position = Vector2(10, 173)
	hint.size = Vector2(300, 8)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

func _on_start() -> void:
	GameState.start_new_run()
	GameState.set_phase("salvage")

func _on_quit() -> void:
	get_tree().quit()
