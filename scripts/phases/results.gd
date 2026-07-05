extends Node2D
## Phase: results V4 — 320x180, weapon dossiers.

var continue_btn: Button
var upgrade_btn: Button

func _ready() -> void:
	var res: Dictionary = GameState.last_battle_result
	var won: bool = res.get("won", false)
	var survivors: int = res.get("survivors", 0)
	var party_size: int = res.get("party_size", 0)
	var shards: int = res.get("shards_earned", 0)
	var header := Label.new()
	header.text = "S%d W%d %s" % [GameState.stage, GameState.wave, "VICTORY!" if won else "DEFEAT..."]
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Palette.TEXT_GREEN if won else Palette.TEXT_RED)
	header.add_theme_color_override("font_outline_color", Palette.VOID)
	header.add_theme_constant_override("outline_size", 2)
	header.position = Vector2(0, 14)
	header.size = Vector2(320, 14)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(header)
	var stats := Label.new()
	stats.text = "Survivors %d/%d  +%d shards" % [survivors, party_size, shards]
	stats.add_theme_font_size_override("font_size", 8)
	stats.add_theme_color_override("font_color", Palette.TEXT)
	stats.position = Vector2(0, 32)
	stats.size = Vector2(320, 10)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(stats)
	# Weapon dossiers (scrollable)
	var dossier_title := Label.new()
	dossier_title.text = "WEAPON DOSSIERS"
	dossier_title.add_theme_font_size_override("font_size", 8)
	dossier_title.add_theme_color_override("font_color", Palette.TEXT_GOLD)
	dossier_title.position = Vector2(0, 48)
	dossier_title.size = Vector2(320, 10)
	dossier_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(dossier_title)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 60)
	scroll.size = Vector2(300, 90)
	add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	for w in GameState.arsenal:
		var card := _make_dossier(w)
		vbox.add_child(card)
	upgrade_btn = Button.new()
	upgrade_btn.text = "Upgrades"
	upgrade_btn.add_theme_font_size_override("font_size", 8)
	upgrade_btn.position = Vector2(30, 158)
	upgrade_btn.size = Vector2(120, 16)
	upgrade_btn.pressed.connect(_on_upgrade)
	add_child(upgrade_btn)
	continue_btn = Button.new()
	continue_btn.text = "Continue >"
	continue_btn.add_theme_font_size_override("font_size", 8)
	continue_btn.position = Vector2(170, 158)
	continue_btn.size = Vector2(120, 16)
	continue_btn.pressed.connect(_on_continue)
	add_child(continue_btn)

func _make_dossier(w: Weapon) -> Label:
	var lbl := Label.new()
	var broken := " [BROKEN]" if w.is_broken else ""
	var kills := " K:%d" % w.kill_log.size() if w.kill_log.size() > 0 else ""
	lbl.text = "%s [%s]%s%s  D:%d/%d" % [w.display_name, w.wear_name(), broken, kills, w.durability, w.durability_max]
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.add_theme_color_override("font_color", w.wear_color() if not w.is_broken else Palette.TEXT_RED)
	lbl.custom_minimum_size = Vector2(290, 10)
	return lbl

func _on_upgrade() -> void:
	GameState.set_phase("upgrade")

func _on_continue() -> void:
	GameState.next_wave()
	var status := GameState.is_run_over()
	if status == "win":
		GameState.set_phase("win_lose")
	else:
		GameState.set_phase("planning")
