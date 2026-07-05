extends Node2D
## Microgame: Trace the Warding Sigil — TRACE
## Player must drag mouse through 5 glowing waypoints in order before time runs out.

signal result(success: bool)

const TIME_LIMIT: float = 4.5
const NUM_WAYPOINTS: int = 5

var time_left: float = TIME_LIMIT
var waypoints: PackedVector2Array = PackedVector2Array()
var next_idx: int = 0
var finished: bool = false
var dragging: bool = false

func _ready() -> void:
        var vp := get_viewport().get_visible_rect().size
        var center := Vector2(vp.x * 0.5, vp.y * 0.55)
        var r: float = min(vp.x, vp.y) * 0.20
        # Generate waypoints in a pentagon
        for i in NUM_WAYPOINTS:
                var a := -PI / 2.0 + i * (2.0 * PI / NUM_WAYPOINTS)
                waypoints.append(center + Vector2(cos(a), sin(a)) * r)
        # Shuffle order for trace (PackedVector2Array has no shuffle, so convert)
        var shuffled: Array = []
        for p in waypoints:
                shuffled.append(p)
        shuffled.shuffle()
        waypoints.clear()
        for p in shuffled:
                waypoints.append(p)

        var lbl := Label.new()
        lbl.text = "TRACE the sigil — drag through the dots in order!"
        lbl.add_theme_font_size_override("font_size", 13)
        lbl.add_theme_color_override("font_color", Color(0.55, 0.75, 0.95))
        lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
        lbl.add_theme_constant_override("outline_size", 3)
        lbl.position = Vector2(vp.x * 0.5 - 200, vp.y * 0.20)
        lbl.size = Vector2(400, 24)
        lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        add_child(lbl)

func _process(delta: float) -> void:
        if finished:
                return
        time_left -= delta
        if time_left <= 0:
                time_left = 0
                _finish(false)
                return
        queue_redraw()

func _draw() -> void:
        var vp := get_viewport().get_visible_rect().size
        # Connecting lines (faded)
        for i in waypoints.size() - 1:
                var c := Color(0.40, 0.30, 0.55, 0.4) if i >= next_idx else Color(0.55, 0.95, 0.75, 0.8)
                draw_line(waypoints[i], waypoints[i + 1], c, 2)
        # Waypoints
        for i in waypoints.size():
                var p := waypoints[i]
                var c: Color
                if i < next_idx:
                        c = Color(0.55, 0.95, 0.75)  # done
                elif i == next_idx:
                        c = Color(0.95, 0.85, 0.30)  # active
                else:
                        c = Color(0.40, 0.55, 0.85)  # pending
                draw_circle(p, 16, c)
                draw_string(ThemeDB.get_default_theme().default_font, p + Vector2(-4, 4), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0, 0, 0))
        # Stats
        draw_string(ThemeDB.get_default_theme().default_font, Vector2(vp.x * 0.25, vp.y * 0.85), "Dot: %d / %d" % [next_idx, waypoints.size()], HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.85, 0.95, 0.85))
        draw_string(ThemeDB.get_default_theme().default_font, Vector2(vp.x * 0.75, vp.y * 0.85), "Time: %.1fs" % time_left, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.95, 0.85, 0.40))

func _input(event: InputEvent) -> void:
        if finished:
                return
        if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
                if event.pressed:
                        dragging = true
                        _check_hit(event.position)
                else:
                        dragging = false
        elif event is InputEventMouseMotion and dragging:
                _check_hit(event.position)

func _check_hit(pos: Vector2) -> void:
        if next_idx >= waypoints.size():
                return
        if pos.distance_to(waypoints[next_idx]) <= 20:
                next_idx += 1
                if next_idx >= waypoints.size():
                        _finish(true)

func _finish(success: bool) -> void:
        finished = true
        await get_tree().create_timer(0.3).timeout
        result.emit(success)
        queue_free()
