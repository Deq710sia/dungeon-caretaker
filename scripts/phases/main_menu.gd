extends Node2D
## Phase: main_menu — title screen, start run, quit.

var title_label: Label
var subtitle_label: Label
var start_btn: Button
var quit_btn: Button
var bg_sprite: Sprite2D

func _ready() -> void:
	# Title
	title_label = Label.new()
	title_label.text = "DUNGEON CARETAKER"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_label.position = Vector2(-160, 30)
	title_label.size = Vector2(320, 40)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title_label)

	# Subtitle
	subtitle_label = Label.new()
	subtitle_label.text = "A Ghost's Salvage"
	subtitle_label.add_theme_font_size_override("font_size", 14)
	subtitle_label.add_theme_color_override("font_color", Color(0.65, 0.55, 0.85))
	subtitle_label.position = Vector2(-100, 70)
	subtitle_label.size = Vector2(200, 20)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle_label)

	# Decorative ghost
	bg_sprite = Sprite2D.new()
	bg_sprite.texture = Sprites.get_sprite("ghost")
	bg_sprite.scale = Vector2(8, 8)
	bg_sprite.position = Vector2(0, 140)
	bg_sprite.modulate = Color(1, 1, 1, 0.4)
	add_child(bg_sprite)

	# Buttons container
	var container := VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	container.position = Vector2(-80, -120)
	container.size = Vector2(160, 80)
	container.add_theme_constant_override("separation", 6)
	add_child(container)

	start_btn = Button.new()
	start_btn.text = "Start New Run"
	start_btn.add_theme_font_size_override("font_size", 14)
	start_btn.custom_minimum_size = Vector2(160, 36)
	start_btn.pressed.connect(_on_start)
	container.add_child(start_btn)

	quit_btn = Button.new()
	quit_btn.text = "Quit"
	quit_btn.add_theme_font_size_override("font_size", 14)
	quit_btn.custom_minimum_size = Vector2(160, 36)
	quit_btn.pressed.connect(_on_quit)
	container.add_child(quit_btn)

	# Hint
	var hint := Label.new()
	hint.text = "WASD/Arrows: move | E/Space: interact | 1: ghost ability | ESC: menu"
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.position = Vector2(0, -16)
	hint.size = Vector2(640, 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

func _on_start() -> void:
	GameState.start_new_run()
	GameState.set_phase("salvage")

func _on_quit() -> void:
	get_tree().quit()
