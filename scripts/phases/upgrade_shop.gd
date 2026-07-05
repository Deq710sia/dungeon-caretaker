extends Node2D
## Phase: upgrade_shop V3.

var upgrades_vbox: VBoxContainer
var shards_label: Label
var continue_btn: Button

func _ready() -> void:
	var header := Label.new()
	header.text = "UPGRADE SHOP — Stage %d Wave %d" % [GameState.stage, GameState.wave]
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	header.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	header.add_theme_constant_override("outline_size", 3)
	header.position = Vector2(0, 20)
	header.size = Vector2(640, 18)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(header)

	shards_label = Label.new()
	shards_label.text = "Soul Shards: %d" % GameState.soul_shards
	shards_label.add_theme_font_size_override("font_size", 12)
	shards_label.add_theme_color_override("font_color", Color(0.65, 0.85, 0.95))
	shards_label.position = Vector2(0, 44)
	shards_label.size = Vector2(640, 16)
	shards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(shards_label)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(80, 70)
	scroll.size = Vector2(480, 230)
	add_child(scroll)

	upgrades_vbox = VBoxContainer.new()
	upgrades_vbox.add_theme_constant_override("separation", 4)
	upgrades_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(upgrades_vbox)

	continue_btn = Button.new()
	continue_btn.text = "Continue >"
	continue_btn.add_theme_font_size_override("font_size", 12)
	continue_btn.position = Vector2(240, 312)
	continue_btn.size = Vector2(160, 28)
	continue_btn.pressed.connect(_on_continue)
	add_child(continue_btn)

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
		row.add_theme_constant_override("separation", 8)
		var name_lbl := Label.new()
		name_lbl.text = "%s  L%d/%d" % [def.name, lvl, def.max]
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90) if not maxed else Color(0.55, 0.85, 0.55))
		name_lbl.custom_minimum_size = Vector2(180, 28)
		row.add_child(name_lbl)
		var desc_lbl := Label.new()
		desc_lbl.text = def.desc
		desc_lbl.add_theme_font_size_override("font_size", 8)
		desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.custom_minimum_size = Vector2(180, 28)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(desc_lbl)
		var buy_btn := Button.new()
		if maxed:
			buy_btn.text = "MAX"
			buy_btn.disabled = true
		else:
			buy_btn.text = "%d" % cost
			buy_btn.disabled = GameState.soul_shards < cost
		buy_btn.add_theme_font_size_override("font_size", 10)
		buy_btn.custom_minimum_size = Vector2(80, 28)
		buy_btn.pressed.connect(_on_buy.bind(key))
		row.add_child(buy_btn)
		upgrades_vbox.add_child(row)

func _on_buy(key: String) -> void:
	if GameState.buy_upgrade(key):
		_refresh()

func _on_continue() -> void:
	var status := GameState.is_run_over()
	if status == "win":
		GameState.set_phase("win_lose")
	else:
		GameState.set_phase("planning")
