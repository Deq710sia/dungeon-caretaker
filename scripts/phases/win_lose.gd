extends Node2D
## Phase: win_lose (V2) — final screen for the run.

var title_label: Label
var stats_label: Label
var restart_btn: Button
var menu_btn: Button

func _ready() -> void:
	var status := GameState.is_run_over()
	var is_win := status == "win"

	var survivors := 0
	for adv in GameState.party:
		if adv.get("alive", false):
			survivors += 1

	title_label = Label.new()
	title_label.text = "VICTORY!" if is_win else "THE DUNGEON WINS..."
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55) if is_win else Color(0.95, 0.40, 0.40))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title_label.add_theme_constant_override("outline_size", 3)
	title_label.position = Vector2(8, 30)
	title_label.size = Vector2(304, 22)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title_label)

	var sub := Label.new()
	sub.text = "Reached Stage %d, Wave %d" % [GameState.stage, GameState.wave]
	sub.add_theme_font_size_override("font_size", 9)
	sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
	sub.position = Vector2(8, 58)
	sub.size = Vector2(304, 12)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	var stats_panel := Panel.new()
	stats_panel.position = Vector2(40, 80)
	stats_panel.size = Vector2(240, 50)
	add_child(stats_panel)

	stats_label = Label.new()
	var flavor := "The party cleared the dungeon!\n" if is_win else "Another party lost to the dark.\n"
	stats_label.text = flavor + "Survivors: %d\nSoul Shards: %d" % [survivors, GameState.soul_shards]
	stats_label.add_theme_font_size_override("font_size", 8)
	stats_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
	stats_label.position = Vector2(8, 4)
	stats_label.size = Vector2(224, 42)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_panel.add_child(stats_label)

	restart_btn = Button.new()
	restart_btn.text = "New Run"
	restart_btn.add_theme_font_size_override("font_size", 9)
	restart_btn.custom_minimum_size = Vector2(140, 22)
	restart_btn.position = Vector2(8, 140)
	restart_btn.pressed.connect(_on_restart)
	add_child(restart_btn)

	menu_btn = Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.add_theme_font_size_override("font_size", 9)
	menu_btn.custom_minimum_size = Vector2(140, 22)
	menu_btn.position = Vector2(172, 140)
	menu_btn.pressed.connect(_on_menu)
	add_child(menu_btn)

	var hint := Label.new()
	hint.text = "Meta-upgrades carry over to future runs."
	hint.add_theme_font_size_override("font_size", 7)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	hint.position = Vector2(8, 178)
	hint.size = Vector2(304, 8)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

func _on_restart() -> void:
	GameState.start_new_run()
	GameState.set_phase("salvage_run")

func _on_menu() -> void:
	GameState.set_phase("menu")
