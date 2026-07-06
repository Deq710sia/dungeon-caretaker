extends Node2D
## Main phase manager V6.
## Phase flow: menu -> gate -> salvage -> workshop -> upgrade -> planning
## -> battle -> results -> aftermath -> gate -> salvage -> ... (loop)
## A new run starts at the GATE (walking past predecessor graves), not
## planning — so the first thing the player sees is the dungeon's history
## of failure before they ever collect or assign gear.

const PHASE_SCRIPTS := {
        "menu":         preload("res://scripts/phases/main_menu.gd"),
        "gate":         preload("res://scripts/phases/gate.gd"),
        "salvage":      preload("res://scripts/phases/salvage.gd"),
        "workshop":     preload("res://scripts/phases/workshop.gd"),
        "battle":       preload("res://scripts/phases/battle.gd"),
        "results":      preload("res://scripts/phases/results.gd"),
        "aftermath":    preload("res://scripts/phases/aftermath.gd"),
        "upgrade":      preload("res://scripts/phases/upgrade_shop.gd"),
        "planning":     preload("res://scripts/phases/planning.gd"),
        "win_lose":     preload("res://scripts/phases/win_lose.gd"),
}

var current_phase_node: Node2D = null
var background: ColorRect

func _ready() -> void:
        background = ColorRect.new()
        background.color = Color(0.05, 0.04, 0.07)
        background.set_anchors_preset(Control.PRESET_FULL_RECT)
        background.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(background)
        background.set("layout_mode", 1)
        GameState.phase_changed.connect(_on_phase_changed)
        _on_phase_changed("menu")
        DisplayServer.window_set_title("Dungeon Caretaker: A Ghost's Salvage")

func _on_phase_changed(new_phase: String) -> void:
        if current_phase_node:
                current_phase_node.queue_free()
                current_phase_node = null
        # A fresh phase shouldn't inherit leftover shake/particles from the last one.
        Juice.clear_particles()
        Juice.trauma = 0.0
        Juice.shake_amount = 0.0
        Juice.hit_stop_timer = 0.0
        var script: GDScript = PHASE_SCRIPTS.get(new_phase)
        if script == null:
                push_error("Unknown phase: " + new_phase)
                return
        current_phase_node = Node2D.new()
        current_phase_node.set_script(script)
        current_phase_node.name = "Phase_" + new_phase
        add_child(current_phase_node)

func _input(event: InputEvent) -> void:
        if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
                if GameState.current_phase != "menu":
                        GameState.set_phase("menu")
