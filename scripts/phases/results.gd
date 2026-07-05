extends Node2D
## Phase: results — show outcome of last battle, then offer Upgrade or Sleep.

var continue_btn: Button
var upgrade_btn: Button
var log_label: Label

func _ready() -> void:
	var res: Dictionary = GameState.last_battle_result
	var won: bool = res.get("won", false)
	var survivors: int = res.get("survivors", 0)
	var party_size: int = res.get("party_size", 0)
	var shards: int = res.get("shards_earned", 0)

	# Header
	var header := Label.new()
	header.text = "Day %d — %s" % [GameState.day, "Victory!" if won else "Defeat..."]
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55) if won else Color(0.95, 0.40, 0.40))
	header.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	header.add_theme_constant_override("outline_size", 3)
	header.position = Vector2(8, 12)
	header.size = Vector2(304, 28)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(header)

	# Survivors panel
	var surv_panel := Panel.new()
	surv_panel.position = Vector2(8, 50)
	surv_panel.size = Vector2(304, 50)
	add_child(surv_panel)

	var surv_label := Label.new()
	surv_label.text = "Survivors: %d / %d" % [survivors, party_size]
	surv_label.add_theme_font_size_override("font_size", 14)
	surv_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
	surv_label.position = Vector2(8, 4)
	surv_label.size = Vector2(288, 18)
	surv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	surv_panel.add_child(surv_label)

	var shards_label := Label.new()
	shards_label.text = "+%d Soul Shards  (Total: %d)" % [shards, GameState.soul_shards]
	shards_label.add_theme_font_size_override("font_size", 12)
	shards_label.add_theme_color_override("font_color", Color(0.65, 0.85, 0.95))
	shards_label.position = Vector2(8, 24)
	shards_label.size = Vector2(288, 18)
	shards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	surv_panel.add_child(shards_label)

	# Party status list
	var party_panel := Panel.new()
	party_panel.position = Vector2(8, 104)
	party_panel.size = Vector2(304, 50)
	add_child(party_panel)

	var party_label := Label.new()
	party_label.text = "Party Status:"
	party_label.add_theme_font_size_override("font_size", 9)
	party_label.add_theme_color_override("font_color", Color(0.75, 0.70, 0.85))
	party_label.position = Vector2(8, 2)
	party_label.size = Vector2(288, 12)
	party_panel.add_child(party_label)

	var y := 16
	for adv in GameState.party:
		var status := "ALIVE" if adv.get("alive", false) else "DEAD"
		var c := Color(0.55, 0.95, 0.55) if adv.alive else Color(0.95, 0.40, 0.40)
		var l := Label.new()
		l.text = "%s (%s): %s" % [adv.name, adv.class, status]
		l.add_theme_font_size_override("font_size", 8)
		l.add_theme_color_override("font_color", c)
		l.position = Vector2(16, y)
		l.size = Vector2(280, 10)
		party_panel.add_child(l)
		y += 11

	# Buttons
	upgrade_btn = Button.new()
	upgrade_btn.text = "Upgrade Shop"
	upgrade_btn.add_theme_font_size_override("font_size", 11)
	upgrade_btn.custom_minimum_size = Vector2(140, 24)
	upgrade_btn.position = Vector2(8, 160)
	upgrade_btn.pressed.connect(_on_upgrade)
	add_child(upgrade_btn)

	continue_btn = Button.new()
	var next_label := "Sleep >" if GameState.day < GameState.MAX_DAY else "Final Day >"
	continue_btn.text = next_label
	continue_btn.add_theme_font_size_override("font_size", 11)
	continue_btn.custom_minimum_size = Vector2(140, 24)
	continue_btn.position = Vector2(172, 160)
	continue_btn.pressed.connect(_on_continue)
	add_child(continue_btn)

	# Hint
	log_label = Label.new()
	log_label.text = "Survivors take gear with them. The dead drop it back to your pit."
	log_label.add_theme_font_size_override("font_size", 7)
	log_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	log_label.position = Vector2(8, 178)
	log_label.size = Vector2(304, 8)
	log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(log_label)

func _on_upgrade() -> void:
	GameState.set_phase("upgrade")

func _on_continue() -> void:
	# Remove gear from survivors (they leave with it)
	# Dead already had their gear returned to pit in battle.gd
	var to_remove: Array = []
	for gear in GameState.salvage_pit:
		# Find if this gear was equipped by a survivor
		for adv in GameState.party:
			if adv.get("alive", false):
				# Survivor — gear is gone (taken)
				# We already pushed all gear back to pit in battle.gd; remove survivor's gear
				if gear.last_owner == adv.get("name", ""):
					to_remove.append(gear)
					break
	for gear in to_remove:
		GameState.salvage_pit.erase(gear)
	GameState.salvage_changed.emit()

	# Advance day or end run
	GameState.next_day()
	var status := GameState.is_run_over()
	if status == "win":
		GameState.set_phase("win_lose")
	elif status == "lose":
		GameState.set_phase("win_lose")
	else:
		GameState.set_phase("hub")
