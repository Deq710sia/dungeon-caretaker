extends Node2D
## Main phase manager (V2).
## Phase flow: menu -> salvage_run -> workshop -> battle -> results -> upgrade -> (loop or next stage)

const PHASE_SCRIPTS := {
        "menu":         preload("res://scripts/phases/main_menu.gd"),
        "salvage_run":  preload("res://scripts/phases/salvage_run.gd"),
        "workshop":     preload("res://scripts/phases/workshop.gd"),
        "battle":       preload("res://scripts/phases/battle.gd"),
        "results":      preload("res://scripts/phases/results.gd"),
        "upgrade":      preload("res://scripts/phases/upgrade_shop.gd"),
        "win_lose":     preload("res://scripts/phases/win_lose.gd"),
}

var current_phase_node: Node2D = null
var background: ColorRect

func _ready() -> void:
        # Black background behind everything
        background = ColorRect.new()
        background.color = Color(0.05, 0.04, 0.07)
        background.set_anchors_preset(Control.PRESET_FULL_RECT)
        background.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(background)
        background.set("layout_mode", 1)

        GameState.phase_changed.connect(_on_phase_changed)
        # Start at main menu
        _on_phase_changed("menu")

        # Window can be resized freely; engine handles scaling.
        DisplayServer.window_set_title("Dungeon Caretaker: A Ghost's Salvage")

func _on_phase_changed(new_phase: String) -> void:
        if current_phase_node:
                current_phase_node.queue_free()
                current_phase_node = null
        var script: GDScript = PHASE_SCRIPTS.get(new_phase)
        if script == null:
                push_error("Unknown phase: " + new_phase)
                return
        current_phase_node = Node2D.new()
        current_phase_node.set_script(script)
        current_phase_node.name = "Phase_" + new_phase
        add_child(current_phase_node)

func _process(_delta: float) -> void:
        pass

func _input(event: InputEvent) -> void:
        # Allow Esc to go back to menu from anywhere (debug)
        if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
                if GameState.current_phase != "menu":
                        GameState.set_phase("menu")
