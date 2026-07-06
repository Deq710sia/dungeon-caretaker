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
	title.position = Vector2(0, 18)
	title.size = Vector2(480, 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var sub := Label.new()
	sub.text = "Stage %d Wave %d" % [GameState.stage, GameState.wave]
	sub.add_theme_font_size_override("font_size", 8)
	sub.add_theme_color_override("font_color", Palette.TEXT)
	sub.position = Vector2(0, 48)
	sub.size = Vector2(480, 14)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	var stats := Label.new()
	stats.text = "Survivors: %d  Shards: %d  Weapons: %d" % [survivors, GameState.soul_shards, GameState.arsenal.size()]
	stats.add_theme_font_size_override("font_size", 8)
	stats.add_theme_color_override("font_color", Palette.TEXT)
	stats.position = Vector2(0, 68)
	stats.size = Vector2(480, 14)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(stats)
	# The chronicle — the run's full run_log, finally shown to someone.
	var chronicle_title := Label.new()
	chronicle_title.text = "THE CHRONICLE" if is_win else "HOW IT ENDED"
	chronicle_title.add_theme_font_size_override("font_size", 8)
	chronicle_title.add_theme_color_override("font_color", Palette.TEXT_GOLD)
	chronicle_title.position = Vector2(0, 86)
	chronicle_title.size = Vector2(480, 14)
	chronicle_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(chronicle_title)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30, 102)
	scroll.size = Vector2(420, 84)
	add_child(scroll)
	var log_label := Label.new()
	log_label.text = "\n".join(GameState.run_log)
	log_label.add_theme_font_size_override("font_size", 8)
	log_label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	log_label.custom_minimum_size = Vector2(270, 8 * max(1, GameState.run_log.size()))
	scroll.add_child(log_label)
	var restart_btn := Button.new()
	restart_btn.text = "New Run"
	restart_btn.add_theme_font_size_override("font_size", 8)
	restart_btn.position = Vector2(45, 200)
	restart_btn.size = Vector2(180, 20)
	restart_btn.pressed.connect(_on_restart)
	add_child(restart_btn)
	var menu_btn := Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.add_theme_font_size_override("font_size", 8)
	menu_btn.position = Vector2(255, 200)
	menu_btn.size = Vector2(180, 20)
	menu_btn.pressed.connect(_on_menu)
	add_child(menu_btn)
	var hint := Label.new()
	hint.text = "Meta-upgrades carry over."
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Palette.TEXT_DIM)
	hint.position = Vector2(0, 232)
	hint.size = Vector2(480, 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

func _on_restart() -> void:
	GameState.start_new_run()
	GameState.set_phase("gate")

func _on_menu() -> void:
	GameState.set_phase("menu")
