extends Node2D
## Phase: main_menu V4 — pixel-art styled, 480x270.
## Centered on the 480-wide viewport (was offset to the left from when
## the internal resolution was 320x180).

func _ready() -> void:
	# Title — full viewport width so horizontal_alignment truly centers
	var title := Label.new()
	title.text = "DUNGEON CARETAKER"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Palette.TEXT)
	title.add_theme_color_override("font_outline_color", Palette.VOID)
	title.add_theme_constant_override("outline_size", 2)
	title.position = Vector2(0, 50)
	title.size = Vector2(480, 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	# Subtitle
	var sub := Label.new()
	sub.text = "A Ghost's Salvage"
	sub.add_theme_font_size_override("font_size", 8)
	sub.add_theme_color_override("font_color", Palette.GLOW_PURP)
	sub.position = Vector2(0, 72)
	sub.size = Vector2(480, 10)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	# Decorative ghost
	var ghost := Sprite2D.new()
	ghost.texture = Sprites.get_sprite("ghost")
	ghost.scale = Vector2(4, 4)
	ghost.position = Vector2(240, 140)
	ghost.modulate = Color(1, 1, 1, 0.6)
	add_child(ghost)
	# Buttons — centered on 480 (140 + 200 = 340, center is 240, so x=140)
	var start_btn := Button.new()
	start_btn.text = "Start New Run"
	start_btn.add_theme_font_size_override("font_size", 8)
	start_btn.position = Vector2(140, 195)
	start_btn.size = Vector2(200, 20)
	start_btn.pressed.connect(_on_start)
	add_child(start_btn)
	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.add_theme_font_size_override("font_size", 8)
	quit_btn.position = Vector2(140, 225)
	quit_btn.size = Vector2(200, 18)
	quit_btn.pressed.connect(_on_quit)
	add_child(quit_btn)
	# Hint — full viewport width so horizontal_alignment truly centers
	var hint := Label.new()
	hint.text = "WASD: move | E: interact | SPACE: phase | ESC: pause"
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Palette.TEXT_DIM)
	hint.position = Vector2(0, 255)
	hint.size = Vector2(480, 7)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

func _on_start() -> void:
	GameState.start_new_run()
	GameState.set_phase("gate")

func _on_quit() -> void:
	get_tree().quit()
