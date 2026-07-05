extends Node2D
## Phase: win_lose V3.

func _ready() -> void:
	var status := GameState.is_run_over()
	var is_win := status == "win"
	var survivors := 0
	for adv in GameState.party:
		if adv.get("alive", false):
			survivors += 1

	var title := Label.new()
	title.text = "VICTORY!" if is_win else "THE DUNGEON WINS..."
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55) if is_win else Color(0.95, 0.40, 0.40))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 4)
	title.position = Vector2(0, 80)
	title.size = Vector2(640, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var sub := Label.new()
	sub.text = "Reached Stage %d, Wave %d" % [GameState.stage, GameState.wave]
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
	sub.position = Vector2(0, 120)
	sub.size = Vector2(640, 16)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	var stats_panel := Panel.new()
	stats_panel.position = Vector2(160, 150)
	stats_panel.size = Vector2(320, 80)
	add_child(stats_panel)

	var stats := Label.new()
	var flavor := "The party cleared the dungeon!\n" if is_win else "Another party lost to the dark.\n"
	stats.text = flavor + "Survivors: %d\nSoul Shards: %d\nWeapons in arsenal: %d" % [survivors, GameState.soul_shards, GameState.arsenal.size()]
	stats.add_theme_font_size_override("font_size", 10)
	stats.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
	stats.position = Vector2(8, 6)
	stats.size = Vector2(304, 68)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_panel.add_child(stats)

	var restart_btn := Button.new()
	restart_btn.text = "New Run"
	restart_btn.add_theme_font_size_override("font_size", 12)
	restart_btn.position = Vector2(160, 250)
	restart_btn.size = Vector2(140, 28)
	restart_btn.pressed.connect(_on_restart)
	add_child(restart_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.add_theme_font_size_override("font_size", 12)
	menu_btn.position = Vector2(340, 250)
	menu_btn.size = Vector2(140, 28)
	menu_btn.pressed.connect(_on_menu)
	add_child(menu_btn)

	var hint := Label.new()
	hint.text = "Meta-upgrades carry over to future runs."
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	hint.position = Vector2(0, 300)
	hint.size = Vector2(640, 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

func _on_restart() -> void:
	GameState.start_new_run()
	GameState.set_phase("planning")

func _on_menu() -> void:
	GameState.set_phase("menu")
