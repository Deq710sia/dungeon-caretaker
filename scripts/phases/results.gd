extends Node2D
## Phase: results V5 — 320x180, weapon dossiers with a real detail view,
## plus a chronicle line so the run_log actually gets read by someone.

var continue_btn: Button
var detail_overlay: Panel = null

func _ready() -> void:
        var res: Dictionary = GameState.last_battle_result
        var won: bool = res.get("won", false)
        var survivors: int = res.get("survivors", 0)
        var party_size: int = res.get("party_size", 0)
        var shards: int = res.get("shards_earned", 0)
        var header := Label.new()
        header.text = "S%d W%d %s" % [GameState.stage, GameState.wave, "VICTORY!" if won else "DEFEAT..."]
        header.add_theme_font_size_override("font_size", 16)
        header.add_theme_color_override("font_color", Palette.TEXT_GREEN if won else Palette.TEXT_RED)
        header.add_theme_color_override("font_outline_color", Palette.VOID)
        header.add_theme_constant_override("outline_size", 2)
        header.position = Vector2(0, 20)
        header.size = Vector2(320, 14)
        header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        add_child(header)
        var stats := Label.new()
        stats.text = "Survivors %d/%d  +%d shards" % [survivors, party_size, shards]
        stats.add_theme_font_size_override("font_size", 8)
        stats.add_theme_color_override("font_color", Palette.TEXT)
        stats.position = Vector2(0, 44)
        stats.size = Vector2(320, 10)
        stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        add_child(stats)
        # Chronicle — last run_log line, so all that flavor text written during the
        # wave actually gets read by the player instead of sitting unused forever.
        var chronicle := Label.new()
        chronicle.text = _latest_log_line()
        chronicle.add_theme_font_size_override("font_size", 8)
        chronicle.add_theme_color_override("font_color", Palette.TEXT_DIM)
        chronicle.position = Vector2(15, 62)
        chronicle.size = Vector2(300, 9)
        chronicle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        chronicle.clip_text = true
        add_child(chronicle)
        # Weapon dossiers (scrollable, clickable for full history)
        var dossier_title := Label.new()
        dossier_title.text = "WEAPON DOSSIERS — click for full history"
        dossier_title.add_theme_font_size_override("font_size", 8)
        dossier_title.add_theme_color_override("font_color", Palette.TEXT_GOLD)
        dossier_title.position = Vector2(0, 80)
        dossier_title.size = Vector2(320, 9)
        dossier_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        add_child(dossier_title)
        var scroll := ScrollContainer.new()
        scroll.position = Vector2(15, 94)
        scroll.size = Vector2(450, 130)
        add_child(scroll)
        var vbox := VBoxContainer.new()
        vbox.add_theme_constant_override("separation", 1)
        vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        scroll.add_child(vbox)
        for w in GameState.arsenal:
                var card := _make_dossier(w)
                vbox.add_child(card)
        continue_btn = Button.new()
        # If the party wiped, make the button text reflect the end of the run
        var is_wipe := (survivors == 0)
        continue_btn.text = "End Run >" if is_wipe else "Continue >"
        continue_btn.add_theme_font_size_override("font_size", 8)
        continue_btn.position = Vector2(100, 158)
        continue_btn.size = Vector2(180, 20)
        continue_btn.pressed.connect(_on_continue)
        add_child(continue_btn)

func _latest_log_line() -> String:
        if GameState.run_log.is_empty():
                return ""
        return "\"%s\"" % GameState.run_log[-1]

func _make_dossier(w: Weapon) -> Button:
        var btn := Button.new()
        var broken := " [BROKEN]" if w.is_broken else ""
        var kills := " K:%d" % w.kill_log.size() if w.kill_log.size() > 0 else ""
        var star := "★ " if w.is_legendary else ""
        btn.text = "%s%s [%s]%s%s  D:%d/%d" % [star, w.display_name, w.wear_name(), broken, kills, w.durability, w.durability_max]
        btn.add_theme_font_size_override("font_size", 8)
        var col := w.wear_color() if not w.is_broken else Palette.TEXT_RED
        btn.add_theme_color_override("font_color", col)
        btn.add_theme_color_override("font_color_hover", Palette.TEXT_GOLD)
        btn.custom_minimum_size = Vector2(440, 16)
        btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
        btn.flat = true
        btn.pressed.connect(_show_detail.bind(w))
        return btn

func _show_detail(w: Weapon) -> void:
        if detail_overlay:
                detail_overlay.queue_free()
        detail_overlay = Panel.new()
        detail_overlay.position = Vector2(30, 30)
        detail_overlay.size = Vector2(420, 200)
        add_child(detail_overlay)
        var text := Label.new()
        text.text = w.get_full_history()
        text.add_theme_font_size_override("font_size", 8)
        text.add_theme_color_override("font_color", Palette.TEXT)
        text.position = Vector2(8, 8)
        text.size = Vector2(264, 108)
        text.autowrap_mode = TextServer.AUTOWRAP_WORD
        detail_overlay.add_child(text)
        var close_btn := Button.new()
        close_btn.text = "Close"
        close_btn.add_theme_font_size_override("font_size", 8)
        close_btn.position = Vector2(100, 120)
        close_btn.size = Vector2(80, 14)
        close_btn.pressed.connect(func(): detail_overlay.queue_free(); detail_overlay = null)
        detail_overlay.add_child(close_btn)

func _on_continue() -> void:
        # Check the loss condition BEFORE advancing — a full party wipe ends the
        # run right here rather than silently rolling into a fresh, undamaged party.
        if GameState.is_run_over() == "lose":
                GameState.set_phase("win_lose")
                return
        GameState.next_wave()
        var status := GameState.is_run_over()
        if status == "win":
                GameState.set_phase("win_lose")
        else:
                # aftermath -> salvage -> workshop -> upgrade -> planning -> battle.
                # Gear gets collected and repaired before the player ever assigns
                # it, instead of the old order where planning happened first and
                # this wave's salvage/repairs only became usable next wave.
                GameState.set_phase("aftermath")
