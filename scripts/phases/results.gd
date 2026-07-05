extends Node2D
## Phase: results V3 — shows battle outcome + weapon dossier cards (what happened to your weapons).

var continue_btn: Button
var upgrade_btn: Button

func _ready() -> void:
	var res: Dictionary = GameState.last_battle_result
	var won: bool = res.get("won", false)
	var survivors: int = res.get("survivors", 0)
	var party_size: int = res.get("party_size", 0)
	var shards: int = res.get("shards_earned", 0)

	# Header
	var header := Label.new()
	header.text = "Stage %d Wave %d — %s" % [GameState.stage, GameState.wave, "VICTORY!" if won else "DEFEAT..."]
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55) if won else Color(0.95, 0.40, 0.40))
	header.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	header.add_theme_constant_override("outline_size", 3)
	header.position = Vector2(0, 36)
	header.size = Vector2(640, 22)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(header)

	# Stats panel
	var stats_panel := Panel.new()
	stats_panel.position = Vector2(120, 70)
	stats_panel.size = Vector2(400, 60)
	add_child(stats_panel)

	var stats_label := Label.new()
	stats_label.text = "Survivors: %d / %d\n+%d Soul Shards (Total: %d)" % [survivors, party_size, shards, GameState.soul_shards]
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
	stats_label.position = Vector2(8, 6)
	stats_label.size = Vector2(384, 48)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_panel.add_child(stats_label)

	# Weapon dossier section
	var dossier_title := Label.new()
	dossier_title.text = "WEAPON DOSSIERS"
	dossier_title.add_theme_font_size_override("font_size", 12)
	dossier_title.add_theme_color_override("font_color", Color(0.75, 0.70, 0.85))
	dossier_title.position = Vector2(0, 138)
	dossier_title.size = Vector2(640, 16)
	dossier_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(dossier_title)

	# Scrollable dossier list
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 158)
	scroll.size = Vector2(560, 150)
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	for w in GameState.arsenal:
		var card := _make_dossier_card(w)
		vbox.add_child(card)

	# Buttons
	upgrade_btn = Button.new()
	upgrade_btn.text = "Upgrade Shop"
	upgrade_btn.add_theme_font_size_override("font_size", 12)
	upgrade_btn.position = Vector2(120, 318)
	upgrade_btn.size = Vector2(180, 28)
	upgrade_btn.pressed.connect(_on_upgrade)
	add_child(upgrade_btn)

	continue_btn = Button.new()
	continue_btn.text = "Continue >"
	continue_btn.add_theme_font_size_override("font_size", 12)
	continue_btn.position = Vector2(340, 318)
	continue_btn.size = Vector2(180, 28)
	continue_btn.pressed.connect(_on_continue)
	add_child(continue_btn)

func _make_dossier_card(w: Weapon) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(540, 32)
	# Weapon sprite
	var spr := TextureRect.new()
	spr.texture = Sprites.get_weapon_sprite(w.type, w.state)
	spr.position = Vector2(4, 4)
	spr.size = Vector2(24, 24)
	spr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(spr)
	# Name + wear
	var name_lbl := Label.new()
	var broken_tag := " [BROKEN]" if w.is_broken else ""
	name_lbl.text = "%s [%s]%s" % [w.display_name, w.wear_name(), broken_tag]
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", w.wear_color() if not w.is_broken else Color(0.55, 0.30, 0.30))
	name_lbl.position = Vector2(32, 4)
	name_lbl.size = Vector2(280, 12)
	panel.add_child(name_lbl)
	# Stats line
	var stats_lbl := Label.new()
	stats_lbl.text = "Forged S%d | Kills: %d | Waves: %d | Dur: %d/%d" % [w.day_forged, w.kill_log.size(), w.waves_survived, w.durability, w.durability_max]
	stats_lbl.add_theme_font_size_override("font_size", 8)
	stats_lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.75))
	stats_lbl.position = Vector2(32, 16)
	stats_lbl.size = Vector2(280, 12)
	panel.add_child(stats_lbl)
	# Wielder
	var wielder_lbl := Label.new()
	wielder_lbl.text = "Wielder: %s" % (w.wielder if w.wielder != "" else "unassigned")
	wielder_lbl.add_theme_font_size_override("font_size", 8)
	wielder_lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.75))
	wielder_lbl.position = Vector2(320, 4)
	wielder_lbl.size = Vector2(216, 12)
	panel.add_child(wielder_lbl)
	# Authoring fingerprint
	var auth_lbl := Label.new()
	auth_lbl.text = "SHP:%d BAL:%d PWR:%d MYS:%d" % [int(w.sharpness * 100), int(w.balance * 100), int(w.power * 100), int(w.mystic * 100)]
	auth_lbl.add_theme_font_size_override("font_size", 7)
	auth_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.70))
	auth_lbl.position = Vector2(320, 16)
	auth_lbl.size = Vector2(216, 12)
	panel.add_child(auth_lbl)
	return panel

func _on_upgrade() -> void:
	GameState.set_phase("upgrade")

func _on_continue() -> void:
	GameState.next_wave()
	var status := GameState.is_run_over()
	if status == "win":
		GameState.set_phase("win_lose")
	else:
		GameState.set_phase("planning")
