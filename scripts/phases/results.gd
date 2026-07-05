extends Node2D
## Phase: results (V2) — shows outcome of last battle, advances to next wave or next stage.

var continue_btn: Button
var upgrade_btn: Button
var log_label: Label

func _ready() -> void:
	var res: Dictionary = GameState.last_battle_result
	var won: bool = res.get("won", false)
	var survivors: int = res.get("survivors", 0)
	var party_size: int = res.get("party_size", 0)
	var shards: int = res.get("shards_earned", 0)
	var stage: int = res.get("stage", 1)
	var wave: int = res.get("wave", 1)

	# Header
	var header := Label.new()
	var header_text := "VICTORY!" if won else "DEFEAT..."
	header.text = "Stage %d Wave %d — %s" % [stage, wave, header_text]
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55) if won else Color(0.95, 0.40, 0.40))
	header.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	header.add_theme_constant_override("outline_size", 3)
	header.position = Vector2(8, 18)
	header.size = Vector2(304, 18)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(header)

	# Survivors panel
	var surv_panel := Panel.new()
	surv_panel.position = Vector2(20, 44)
	surv_panel.size = Vector2(280, 50)
	add_child(surv_panel)

	var surv_label := Label.new()
	surv_label.text = "Survivors: %d / %d" % [survivors, party_size]
	surv_label.add_theme_font_size_override("font_size", 10)
	surv_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
	surv_label.position = Vector2(8, 4)
	surv_label.size = Vector2(264, 16)
	surv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	surv_panel.add_child(surv_label)

	var shards_label := Label.new()
	shards_label.text = "+%d Soul Shards  (Total: %d)" % [shards, GameState.soul_shards]
	shards_label.add_theme_font_size_override("font_size", 9)
	shards_label.add_theme_color_override("font_color", Color(0.65, 0.85, 0.95))
	shards_label.position = Vector2(8, 22)
	shards_label.size = Vector2(264, 14)
	shards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	surv_panel.add_child(shards_label)

	# Wave/stage progress
	var progress_label := Label.new()
	var progress_text := ""
	if won:
		if GameState.wave >= GameState.WAVES_PER_STAGE:
			progress_text = "Stage %d CLEARED! Next: Stage %d" % [GameState.stage, GameState.stage + 1]
		else:
			progress_text = "Wave %d/%d cleared. Next: Wave %d" % [GameState.wave, GameState.WAVES_PER_STAGE, GameState.wave + 1]
	else:
		progress_text = "The party has fallen. The dungeon claims them."
	progress_label.text = progress_text
	progress_label.add_theme_font_size_override("font_size", 8)
	progress_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.40) if won else Color(0.85, 0.55, 0.55))
	progress_label.position = Vector2(8, 100)
	progress_label.size = Vector2(304, 14)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(progress_label)

	# Party status
	var party_panel := Panel.new()
	party_panel.position = Vector2(20, 118)
	party_panel.size = Vector2(280, 40)
	add_child(party_panel)

	var y := 4
	for adv in GameState.party:
		var status := "ALIVE" if adv.get("alive", false) else "DEAD"
		var c := Color(0.55, 0.95, 0.55) if adv.alive else Color(0.95, 0.40, 0.40)
		var l := Label.new()
		l.text = "%s (%s): %s" % [adv.name, adv.class, status]
		l.add_theme_font_size_override("font_size", 7)
		l.add_theme_color_override("font_color", c)
		l.position = Vector2(8, y)
		l.size = Vector2(264, 10)
		party_panel.add_child(l)
		y += 10

	# Buttons
	upgrade_btn = Button.new()
	upgrade_btn.text = "Upgrade Shop"
	upgrade_btn.add_theme_font_size_override("font_size", 8)
	upgrade_btn.custom_minimum_size = Vector2(140, 22)
	upgrade_btn.position = Vector2(8, 160)
	upgrade_btn.pressed.connect(_on_upgrade)
	add_child(upgrade_btn)

	continue_btn = Button.new()
	var next_label := "Continue >"
	continue_btn.text = next_label
	continue_btn.add_theme_font_size_override("font_size", 8)
	continue_btn.custom_minimum_size = Vector2(140, 22)
	continue_btn.position = Vector2(172, 160)
	continue_btn.pressed.connect(_on_continue)
	add_child(continue_btn)

	log_label = Label.new()
	log_label.text = "Survivors take gear with them. The dead drop theirs back to your pit."
	log_label.add_theme_font_size_override("font_size", 6)
	log_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	log_label.position = Vector2(8, 178)
	log_label.size = Vector2(304, 8)
	log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(log_label)

func _on_upgrade() -> void:
	GameState.set_phase("upgrade")

func _on_continue() -> void:
	# Remove gear from survivors (they leave with it)
	var to_remove: Array = []
	for gear in GameState.salvage_pit:
		for adv in GameState.party:
			if adv.get("alive", false):
				if gear.last_owner == adv.get("name", ""):
					to_remove.append(gear)
					break
	for gear in to_remove:
		GameState.salvage_pit.erase(gear)
	GameState.salvage_changed.emit()
	# Advance wave/stage
	GameState.next_wave()
	var status := GameState.is_run_over()
	if status == "win":
		GameState.set_phase("win_lose")
	else:
		# Next wave -> back to salvage run
		GameState.set_phase("salvage_run")
