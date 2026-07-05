extends Node2D
## Phase: salvage_pit — review yesterday's gear and plan repairs.
## Shows the salvage pit inventory with state, history, and repair target.

var vbox: VBoxContainer
var gear_list: VBoxContainer
var continue_btn: Button
var hire_merc_btn: Button
var header: Label
var day_label: Label
var shards_label: Label

func _ready() -> void:
	# Header panel
	var header_panel := Panel.new()
	header_panel.position = Vector2(8, 4)
	header_panel.size = Vector2(304, 28)
	add_child(header_panel)

	day_label = Label.new()
	day_label.text = "Day %d / %d" % [GameState.day, GameState.MAX_DAY]
	day_label.add_theme_font_size_override("font_size", 14)
	day_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	day_label.position = Vector2(8, 6)
	day_label.size = Vector2(150, 20)
	header_panel.add_child(day_label)

	shards_label = Label.new()
	shards_label.text = "Soul Shards: %d" % GameState.soul_shards
	shards_label.add_theme_font_size_override("font_size", 12)
	shards_label.add_theme_color_override("font_color", Color(0.65, 0.85, 0.95))
	shards_label.position = Vector2(160, 6)
	shards_label.size = Vector2(140, 20)
	shards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_panel.add_child(shards_label)

	# Title
	header = Label.new()
	header.text = "— Salvage Pit —"
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.75, 0.70, 0.85))
	header.position = Vector2(8, 36)
	header.size = Vector2(304, 16)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(header)

	# Scrollable gear list
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(8, 56)
	scroll.size = Vector2(304, 88)
	add_child(scroll)

	gear_list = VBoxContainer.new()
	gear_list.add_theme_constant_override("separation", 2)
	gear_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(gear_list)

	# Refresh list
	_refresh_list()

	# Buttons at bottom
	var btn_row := HBoxContainer.new()
	btn_row.position = Vector2(8, 152)
	btn_row.size = Vector2(304, 24)
	btn_row.add_theme_constant_override("separation", 6)
	add_child(btn_row)

	hire_merc_btn = Button.new()
	hire_merc_btn.text = "Hire Martyrs (60)"
	hire_merc_btn.add_theme_font_size_override("font_size", 10)
	hire_merc_btn.custom_minimum_size = Vector2(140, 24)
	hire_merc_btn.pressed.connect(_on_hire_mercs)
	btn_row.add_child(hire_merc_btn)

	continue_btn = Button.new()
	continue_btn.text = "To Workshop >"
	continue_btn.add_theme_font_size_override("font_size", 10)
	continue_btn.custom_minimum_size = Vector2(140, 24)
	continue_btn.pressed.connect(_on_continue)
	btn_row.add_child(continue_btn)

	# Hint
	var hint := Label.new()
	hint.text = "Review yesterday's gear. Each state needs a specific repair station."
	hint.add_theme_font_size_override("font_size", 7)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	hint.position = Vector2(8, 178)
	hint.size = Vector2(304, 8)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	GameState.shards_changed.connect(_on_shards_changed)
	GameState.salvage_changed.connect(_refresh_list)

func _refresh_list() -> void:
	for c in gear_list.get_children():
		c.queue_free()
	if GameState.salvage_pit.is_empty():
		var empty := Label.new()
		empty.text = "Salvage pit is empty. Send the party in bare-handed, or hire martyrs."
		empty.add_theme_font_size_override("font_size", 9)
		empty.add_theme_color_override("font_color", Color(0.70, 0.55, 0.55))
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(290, 40)
		gear_list.add_child(empty)
		return
	for gear in GameState.salvage_pit:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		# Sprite
		var spr := TextureRect.new()
		spr.texture = Sprites.get_sprite(gear.type)
		spr.custom_minimum_size = Vector2(20, 20)
		spr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(spr)
		# State badge
		var state_lbl := Label.new()
		state_lbl.text = "[%s]" % GearItem.STATE_EMOJI[gear.state]
		state_lbl.add_theme_font_size_override("font_size", 9)
		state_lbl.add_theme_color_override("font_color", gear.state_color())
		state_lbl.custom_minimum_size = Vector2(36, 16)
		row.add_child(state_lbl)
		# Name + station
		var info := Label.new()
		var target: String = gear.repair_target_station()
		var target_text: String = "— needs " + target if target != "" else "— ready"
		info.text = "%s	  %s" % [gear.display_name, target_text]
		info.add_theme_font_size_override("font_size", 8)
		info.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		gear_list.add_child(row)

func _on_shards_changed(new_count: int) -> void:
	shards_label.text = "Soul Shards: %d" % new_count

func _on_hire_mercs() -> void:
	if GameState.spend_shards(60):
		# Add 2-3 bloodied/cursed pieces of martyr gear
		var types := ["sword", "helm", "staff", "robe"]
		for i in 3:
			var t: String = types[i % types.size()]
			var s: int = GearItem.State.BLOODIED if i % 2 == 0 else GearItem.State.HAUNTED
			GameState.add_gear_to_pit(GearItem.new(t, s, "Martyr's %s" % t.capitalize(), "Left behind by hired mercs."))
		GameState.run_log.append("Day %d — Hired mercenary martyrs. They left us their gear." % GameState.day)
	else:
		# Flash the button red briefly
		hire_merc_btn.modulate = Color(1, 0.4, 0.4)
		await get_tree().create_timer(0.3).timeout
		hire_merc_btn.modulate = Color.WHITE

func _on_continue() -> void:
	# Spawn the day's party (they show up at the workshop-hall transition)
	GameState.spawn_party()
	GameState.set_phase("workshop")
