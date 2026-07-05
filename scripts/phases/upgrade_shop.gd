extends Node2D
## Phase: upgrade_shop — spend soul shards on permanent meta-upgrades.

var upgrades_vbox: VBoxContainer
var shards_label: Label
var continue_btn: Button

func _ready() -> void:
	# Header
	var header := Label.new()
	header.text = "Upgrade Shop — Day %d" % GameState.day
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	header.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	header.add_theme_constant_override("outline_size", 3)
	header.position = Vector2(8, 6)
	header.size = Vector2(304, 20)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(header)

	# Shards
	shards_label = Label.new()
	shards_label.text = "Soul Shards: %d" % GameState.soul_shards
	shards_label.add_theme_font_size_override("font_size", 12)
	shards_label.add_theme_color_override("font_color", Color(0.65, 0.85, 0.95))
	shards_label.position = Vector2(8, 28)
	shards_label.size = Vector2(304, 14)
	shards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(shards_label)

	# Scrollable upgrade list
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(8, 46)
	scroll.size = Vector2(304, 110)
	add_child(scroll)

	upgrades_vbox = VBoxContainer.new()
	upgrades_vbox.add_theme_constant_override("separation", 3)
	upgrades_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(upgrades_vbox)

	# Continue button
	continue_btn = Button.new()
	continue_btn.text = "Sleep >"
	continue_btn.add_theme_font_size_override("font_size", 11)
	continue_btn.custom_minimum_size = Vector2(304, 24)
	continue_btn.position = Vector2(8, 160)
	continue_btn.pressed.connect(_on_continue)
	add_child(continue_btn)

	# Hint
	var hint := Label.new()
	hint.text = "Upgrades are permanent across runs."
	hint.add_theme_font_size_override("font_size", 7)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	hint.position = Vector2(8, 178)
	hint.size = Vector2(304, 8)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	GameState.shards_changed.connect(_on_shards_changed)
	_refresh()

func _on_shards_changed(new_count: int) -> void:
	shards_label.text = "Soul Shards: %d" % new_count
	_refresh()

func _refresh() -> void:
	for c in upgrades_vbox.get_children():
		c.queue_free()
	for key in GameState.UPGRADE_DEFS.keys():
		var def: Dictionary = GameState.UPGRADE_DEFS[key]
		var lvl: int = GameState.meta_upgrades[key]
		var maxed: bool = lvl >= def.max
		var cost: int = GameState.upgrade_cost(key)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		# Name
		var name_lbl := Label.new()
		name_lbl.text = "%s  L%d/%d" % [def.name, lvl, def.max]
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90) if not maxed else Color(0.55, 0.85, 0.55))
		name_lbl.custom_minimum_size = Vector2(120, 22)
		row.add_child(name_lbl)
		# Description
		var desc_lbl := Label.new()
		desc_lbl.text = def.desc
		desc_lbl.add_theme_font_size_override("font_size", 7)
		desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.custom_minimum_size = Vector2(100, 22)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(desc_lbl)
		# Buy button
		var buy_btn := Button.new()
		if maxed:
			buy_btn.text = "MAX"
			buy_btn.disabled = true
		elif cost < 0:
			buy_btn.text = "—"
			buy_btn.disabled = true
		else:
			buy_btn.text = "%d" % cost
			buy_btn.disabled = GameState.soul_shards < cost
		buy_btn.add_theme_font_size_override("font_size", 9)
		buy_btn.custom_minimum_size = Vector2(50, 22)
		buy_btn.pressed.connect(_on_buy.bind(key))
		row.add_child(buy_btn)
		upgrades_vbox.add_child(row)

func _on_buy(key: String) -> void:
	if GameState.buy_upgrade(key):
		_refresh()

func _on_continue() -> void:
	# Apply same logic as results.gd's _on_continue (without advancing day again — results already advanced)
	# Actually, results.gd advances day BEFORE coming here. So we just go to salvage.
	var status := GameState.is_run_over()
	if status == "win" or status == "lose":
		GameState.set_phase("win_lose")
	else:
		GameState.set_phase("salvage")
