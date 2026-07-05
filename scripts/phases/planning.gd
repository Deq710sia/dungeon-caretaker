extends Node2D
## Phase: planning V3 — the real planning phase.
## Shows: wave map (node types), boss/goal reveal, weapon-to-adventurer assignment,
## arsenal dossier cards, intel on next battle. Irreversible commit ("Begin Wave").

var hud_stage: Label
var hud_shards: Label
var wave_map_container: HBoxContainer
var arsenal_container: VBoxContainer
var party_container: VBoxContainer
var intel_label: Label
var begin_btn: Button
var selected_weapon: Weapon = null
var assignment_lines: Array = []  # {weapon, adventurer_name}

func _ready() -> void:
	# Spawn party for this wave
	if GameState.party.is_empty():
		GameState.spawn_party()
	# Header
	var header := Panel.new()
	header.position = Vector2(0, 0)
	header.size = Vector2(640, 28)
	add_child(header)

	hud_stage = Label.new()
	hud_stage.text = "Stage %d  Wave %d/%d" % [GameState.stage, GameState.wave, GameState.WAVES_PER_STAGE]
	hud_stage.add_theme_font_size_override("font_size", 12)
	hud_stage.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	hud_stage.position = Vector2(8, 6)
	hud_stage.size = Vector2(200, 18)
	header.add_child(hud_stage)

	hud_shards = Label.new()
	hud_shards.text = "Shards: %d" % GameState.soul_shards
	hud_shards.add_theme_font_size_override("font_size", 12)
	hud_shards.add_theme_color_override("font_color", Color(0.65, 0.85, 0.95))
	hud_shards.position = Vector2(500, 6)
	hud_shards.size = Vector2(130, 18)
	hud_shards.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(hud_shards)

	# Title
	var title := Label.new()
	title.text = "PLANNING PHASE"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	title.position = Vector2(0, 32)
	title.size = Vector2(640, 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# Wave map (visual path of upcoming waves)
	_build_wave_map()

	# Intel panel (next battle info)
	_build_intel()

	# Arsenal (weapon dossier cards)
	_build_arsenal()

	# Party (adventurers to equip)
	_build_party()

	# Begin button
	begin_btn = Button.new()
	begin_btn.text = "BEGIN WAVE >"
	begin_btn.add_theme_font_size_override("font_size", 14)
	begin_btn.position = Vector2(240, 320)
	begin_btn.size = Vector2(160, 30)
	begin_btn.pressed.connect(_on_begin)
	add_child(begin_btn)

	GameState.shards_changed.connect(_on_shards_changed)
	GameState.arsenal_changed.connect(_refresh_arsenal)

func _build_wave_map() -> void:
	var map_label := Label.new()
	map_label.text = "WAVE PATH:"
	map_label.add_theme_font_size_override("font_size", 10)
	map_label.add_theme_color_override("font_color", Color(0.75, 0.70, 0.85))
	map_label.position = Vector2(8, 58)
	map_label.size = Vector2(100, 14)
	add_child(map_label)

	wave_map_container = HBoxContainer.new()
	wave_map_container.position = Vector2(110, 56)
	wave_map_container.size = Vector2(520, 20)
	wave_map_container.add_theme_constant_override("separation", 8)
	add_child(wave_map_container)

	# Show 3 upcoming waves with node types
	for i in 3:
		var wave_num := GameState.wave + i
		if wave_num > GameState.WAVES_PER_STAGE:
			# Show next stage boss
			var boss_node := _make_wave_node("STAGE\nBOSS", Color(0.95, 0.40, 0.40), true)
			wave_map_container.add_child(boss_node)
			break
		var is_current := (i == 0)
		var is_boss := (wave_num == GameState.WAVES_PER_STAGE)
		var label := "WAVE %d" % wave_num
		var color := Color(0.95, 0.40, 0.40) if is_boss else Color(0.55, 0.95, 0.55)
		var node := _make_wave_node(label, color, is_current)
		wave_map_container.add_child(node)
		if i < 2:
			var arrow := Label.new()
			arrow.text = ">"
			arrow.add_theme_font_size_override("font_size", 12)
			arrow.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
			arrow.size = Vector2(12, 20)
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			wave_map_container.add_child(arrow)

func _make_wave_node(label_text: String, color: Color, is_current: bool) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(80, 20)
	if is_current:
		panel.modulate = Color(1.2, 1.2, 1.0)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = Vector2(2, 4)
	lbl.size = Vector2(76, 14)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(lbl)
	return panel

func _build_intel() -> void:
	var intel_panel := Panel.new()
	intel_panel.position = Vector2(8, 84)
	intel_panel.size = Vector2(300, 100)
	add_child(intel_panel)

	var intel_title := Label.new()
	intel_title.text = "BATTLE INTEL"
	intel_title.add_theme_font_size_override("font_size", 10)
	intel_title.add_theme_color_override("font_color", Color(0.85, 0.55, 0.55))
	intel_title.position = Vector2(8, 4)
	intel_title.size = Vector2(284, 14)
	intel_panel.add_child(intel_title)

	intel_label = Label.new()
	var enemy_count := GameState.get_enemy_count()
	var enemy_hp := GameState.get_enemy_hp()
	# Show enemy TYPES (asymmetric intel: type yes, specifics no)
	var types := []
	if GameState.stage >= 1:
		types.append("Slime")
	if GameState.stage >= 2:
		types.append("Skeleton")
	if GameState.stage >= 3:
		types.append("Bat")
	var types_text := ", ".join(types)
	intel_label.text = "Enemies: %d (%s)\nHP: ~%d each\nATK: ~%d each\n\nAssign weapons to adventurers.\nClick a weapon, then an adventurer." % [enemy_count, types_text, enemy_hp, GameState.get_enemy_atk()]
	intel_label.add_theme_font_size_override("font_size", 8)
	intel_label.add_theme_color_override("font_color", Color(0.80, 0.80, 0.85))
	intel_label.position = Vector2(8, 20)
	intel_label.size = Vector2(284, 76)
	intel_panel.add_child(intel_label)

func _build_arsenal() -> void:
	var ars_label := Label.new()
	ars_label.text = "ARSENAL (click to select):"
	ars_label.add_theme_font_size_override("font_size", 10)
	ars_label.add_theme_color_override("font_color", Color(0.75, 0.70, 0.85))
	ars_label.position = Vector2(8, 190)
	ars_label.size = Vector2(300, 14)
	add_child(ars_label)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(8, 206)
	scroll.size = Vector2(300, 110)
	add_child(scroll)

	arsenal_container = VBoxContainer.new()
	arsenal_container.add_theme_constant_override("separation", 2)
	arsenal_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(arsenal_container)
	_refresh_arsenal()

func _refresh_arsenal() -> void:
	for c in arsenal_container.get_children():
		c.queue_free()
	for w in GameState.arsenal:
		var card := _make_weapon_card(w)
		arsenal_container.add_child(card)

func _make_weapon_card(w: Weapon) -> Button:
	var btn := Button.new()
	var wear_tag := "[%s]" % w.wear_name()
	var state_tag := ""
	if w.state != Weapon.State.PRISTINE:
		state_tag = " [%s]" % Weapon.STATE_EMOJI[w.state]
	var kill_text := ""
	if w.kill_log.size() > 0:
		kill_text = " (%d kills)" % w.kill_log.size()
	var wielder_text := ""
	if w.wielder != "":
		wielder_text = " -> %s" % w.wielder
	btn.text = "%s %s%s%s%s" % [w.display_name, wear_tag, state_tag, kill_text, wielder_text]
	btn.add_theme_font_size_override("font_size", 8)
	btn.custom_minimum_size = Vector2(290, 22)
	btn.add_theme_color_override("font_color", w.wear_color())
	if w.is_broken:
		btn.add_theme_color_override("font_color", Color(0.55, 0.30, 0.30))
		btn.text = "[BROKEN] " + btn.text
	if selected_weapon == w:
		btn.modulate = Color(1.3, 1.3, 0.8)
	btn.pressed.connect(_on_weapon_selected.bind(w))
	return btn

func _on_weapon_selected(w: Weapon) -> void:
	selected_weapon = w
	_refresh_arsenal()

func _build_party() -> void:
	var party_label := Label.new()
	party_label.text = "ADVENTURERS (assign selected weapon):"
	party_label.add_theme_font_size_override("font_size", 10)
	party_label.add_theme_color_override("font_color", Color(0.75, 0.70, 0.85))
	party_label.position = Vector2(320, 190)
	party_label.size = Vector2(312, 14)
	add_child(party_label)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(320, 206)
	scroll.size = Vector2(312, 110)
	add_child(scroll)

	party_container = VBoxContainer.new()
	party_container.add_theme_constant_override("separation", 2)
	party_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(party_container)
	_refresh_party()

func _refresh_party() -> void:
	for c in party_container.get_children():
		c.queue_free()
	for adv in GameState.party:
		var card := _make_adventurer_card(adv)
		party_container.add_child(card)

func _make_adventurer_card(adv: Dictionary) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	var btn := Button.new()
	var status := "ALIVE" if adv.get("alive", false) else "DEAD"
	var weapon_text := "no weapon"
	if adv.get("equipped_weapon") != null:
		var w: Weapon = adv.equipped_weapon
		weapon_text = w.display_name
	if adv.get("equipped_armor") != null:
		var a: Weapon = adv.equipped_armor
		weapon_text += " + " + a.display_name
	btn.text = "%s (%s)  HP %d/%d  | %s" % [adv.name, adv.class, adv.hp, adv.hp_max, weapon_text]
	btn.add_theme_font_size_override("font_size", 8)
	btn.custom_minimum_size = Vector2(300, 18)
	btn.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55) if adv.alive else Color(0.55, 0.55, 0.65))
	btn.pressed.connect(_on_adventurer_selected.bind(adv))
	vbox.add_child(btn)
	# Sub-buttons for weapon/armor slots
	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 4)
	var w_btn := Button.new()
	w_btn.text = "Assign Weapon"
	w_btn.add_theme_font_size_override("font_size", 7)
	w_btn.custom_minimum_size = Vector2(146, 14)
	w_btn.pressed.connect(_on_assign_slot.bind(adv, "weapon"))
	slot_row.add_child(w_btn)
	var a_btn := Button.new()
	a_btn.text = "Assign Armor"
	a_btn.add_theme_font_size_override("font_size", 7)
	a_btn.custom_minimum_size = Vector2(146, 14)
	a_btn.pressed.connect(_on_assign_slot.bind(adv, "armor"))
	slot_row.add_child(a_btn)
	vbox.add_child(slot_row)
	return vbox

func _on_adventurer_selected(adv: Dictionary) -> void:
	# If a weapon is selected, assign it
	if selected_weapon != null:
		_assign_weapon(adv, "weapon")

func _on_assign_slot(adv: Dictionary, slot: String) -> void:
	if selected_weapon == null:
		return
	_assign_weapon(adv, slot)

func _assign_weapon(adv: Dictionary, slot: String) -> void:
	# Check type compatibility
	var expected_type := "sword"
	match slot:
		"weapon":
			expected_type = "sword" if adv.class == "knight" else "staff"
		"armor":
			expected_type = "helm" if adv.class == "knight" else "robe"
	if selected_weapon.type != expected_type:
		# Flash error
		intel_label.text = "Wrong type! %s needs %s for %s slot." % [adv.name, expected_type, slot]
		return
	# Remove from previous owner
	if selected_weapon.wielder != "":
		for other in GameState.party:
			if other.get("name", "") == selected_weapon.wielder:
				if other.get("equipped_weapon") == selected_weapon:
					other.equipped_weapon = null
				if other.get("equipped_armor") == selected_weapon:
					other.equipped_armor = null
	# Assign
	match slot:
		"weapon": adv.equipped_weapon = selected_weapon
		"armor": adv.equipped_armor = selected_weapon
	selected_weapon.wielder = adv.name
	intel_label.text = "Assigned %s to %s." % [selected_weapon.display_name, adv.name]
	selected_weapon = null
	_refresh_arsenal()
	_refresh_party()

func _on_shards_changed(new_count: int) -> void:
	hud_shards.text = "Shards: %d" % new_count

func _on_begin() -> void:
	# Commit — go to salvage phase
	GameState.set_phase("salvage")
