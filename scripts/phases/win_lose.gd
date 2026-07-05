extends Node2D
## Phase: win_lose V5 — 320x180. Shows the run's chronicle as a send-off,
## win or lose, so the run_log (previously write-only) finally pays off.

func _ready() -> void:
	var status := GameState.is_run_over()
	var is_win := status == "win"
	var survivors := GameState.living_party_count()
	var title := Label.new()
	title.text = "VICTORY!" if is_win else "THE DUNGEON WINS..."
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Palette.TEXT_GREEN if is_win else Palette.TEXT_RED)
	title.add_theme_color_override("font_outline_color", Palette.VOID)
	title.add_theme_constant_override("outline_size", 3)
	title.position = Vector2(0, 12)
	title.size = Vector2(320, 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var sub := Label.new()
	sub.text = "Stage %d Wave %d" % [GameState.stage, GameState.wave]
	sub.add_theme_font_size_override("font_size", 8)
	sub.add_theme_color_override("font_color", Palette.TEXT)
	sub.position = Vector2(0, 32)
	sub.size = Vector2(320, 10)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	var stats := Label.new()
	stats.text = "Survivors: %d    Shards: %d    Arsenal: %d weapons" % [survivors, GameState.soul_shards, GameState.arsenal.size()]
	stats.add_theme_font_size_override("font_size", 7)
	stats.add_theme_color_override("font_color", Palette.TEXT)
	stats.position = Vector2(0, 46)
	stats.size = Vector2(320, 10)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(stats)
	# The chronicle — the run's full run_log, finally shown to someone.
	var chronicle_title := Label.new()
	chronicle_title.text = "THE CHRONICLE" if is_win else "HOW IT ENDED"
	chronicle_title.add_theme_font_size_override("font_size", 7)
	chronicle_title.add_theme_color_override("font_color", Palette.TEXT_GOLD)
	chronicle_title.position = Vector2(0, 58)
	chronicle_title.size = Vector2(320, 9)
	chronicle_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(chronicle_title)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 68)
	scroll.size = Vector2(280, 56)
	add_child(scroll)
	var log_label := Label.new()
	log_label.text = "\n".join(GameState.run_log)
	log_label.add_theme_font_size_override("font_size", 7)
	log_label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	log_label.custom_minimum_size = Vector2(270, 8 * max(1, GameState.run_log.size()))
	scroll.add_child(log_label)
	var restart_btn := Button.new()
	restart_btn.text = "New Run"
	restart_btn.add_theme_font_size_override("font_size", 8)
	restart_btn.position = Vector2(30, 130)
	restart_btn.size = Vector2(120, 16)
	restart_btn.pressed.connect(_on_restart)
	add_child(restart_btn)
	var menu_btn := Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.add_theme_font_size_override("font_size", 8)
	menu_btn.position = Vector2(170, 130)
	menu_btn.size = Vector2(120, 16)
	menu_btn.pressed.connect(_on_menu)
	add_child(menu_btn)
	var hint := Label.new()
	hint.text = "Meta-upgrades carry over."
	hint.add_theme_font_size_override("font_size", 6)
	hint.add_theme_color_override("font_color", Palette.TEXT_DIM)
	hint.position = Vector2(0, 152)
	hint.size = Vector2(320, 7)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

func _on_restart() -> void:
	GameState.start_new_run()
	GameState.set_phase("planning")

func _on_menu() -> void:
	GameState.set_phase("menu")
