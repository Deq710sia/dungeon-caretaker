extends Node2D
## Repair Minigame: Exorcise Altar
## Removes HAUNTED and CURSED states.
## HAUNTED: trace the glowing sigil path before time runs out (forward).
## CURSED: same sigil, but you must trace it in REVERSE (Simon-says style).
## Quality = fraction of waypoints hit correctly in order.

signal completed(quality: float)

const TIME_LIMIT: float = 7.0

var time_left: float = TIME_LIMIT
var sigil_points: PackedVector2Array = PackedVector2Array()
var visited: PackedByteArray = PackedByteArray()  # 1 if visited in correct order
var next_idx: int = 0
var finished: bool = false
var is_cursed: bool = false  # if true, traverse in reverse
var area_origin: Vector2
var area_size: Vector2

func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	area_origin = Vector2(vp.x * 0.15, vp.y * 0.30)
	area_size = Vector2(vp.x * 0.70, vp.y * 0.40)
	# Determine if cursed variant
	if GameState.salvage_pit.size() > 0:
		# The active gear is determined by workshop.gd when launching; we just trust the workshop
		# to pass the gear via group "current_gear" — but for simplicity, we detect by checking
		# if any current gear is cursed. The workshop sets current_gear before launching us.
		pass
	# Pull the current gear from the workshop (parent)
	var parent := get_parent()
	if parent and parent.has_method("get") and parent.get("current_gear") != null:
		var g = parent.get("current_gear")
		if g is GearItem:
			is_cursed = g.is_cursed_variant()
	# Build sigil: pentagram-ish 5-point star
	_build_sigil()

	var lbl := Label.new()
	var instruction := "Trace the sigil!" if not is_cursed else "Trace the sigil IN REVERSE!"
	lbl.text = "Exorcise Altar — %s (%.0fs)" % [instruction, TIME_LIMIT]
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.75, 0.95) if not is_cursed else Color(0.85, 0.55, 0.95))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(area_origin.x - 80, area_origin.y - 24)
	lbl.size = Vector2(area_size.x + 160, 20)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)

func _build_sigil() -> void:
	# 7 waypoints forming a sigil (rough pentagram + ring)
	var cx := area_origin.x + area_size.x * 0.5
	var cy := area_origin.y + area_size.y * 0.5
	var r: float = min(area_size.x, area_size.y) * 0.35
	# Build a star pattern (pentagram visit order)
	var n := 5
	for i in n:
		var a := -PI / 2.0 + i * (2.0 * PI / n)
		sigil_points.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	# Add center as final waypoint
	sigil_points.append(Vector2(cx, cy))
	# If cursed, reverse the order
	if is_cursed:
		sigil_points.reverse()
	visited.resize(sigil_points.size())
	for i in visited.size():
		visited[i] = 0

func _process(delta: float) -> void:
	if finished:
		return
	time_left -= delta
	if time_left <= 0:
		time_left = 0
		_finish()
		return
	queue_redraw()

func _draw() -> void:
	# Background (altar)
	draw_rect(Rect2(area_origin, area_size), Color(0.08, 0.06, 0.12), true)
	# Connecting lines (faint)
	for i in sigil_points.size():
		var j := (i + 1) % sigil_points.size()
		var c := Color(0.30, 0.20, 0.40, 0.5)
		if visited[i] == 1 and visited[j] == 1:
			c = Color(0.55, 0.75, 0.95, 0.9)
		draw_line(sigil_points[i], sigil_points[j], c, 2)
	# Waypoints
	for i in sigil_points.size():
		var p := sigil_points[i]
		var c: Color
		if visited[i] == 1:
			c = Color(0.55, 0.95, 0.75)
		elif i == next_idx:
			c = Color(0.95, 0.85, 0.30)
		else:
			c = Color(0.40, 0.30, 0.55)
		draw_circle(p, 14, c)
		draw_circle(p, 14, Color(1, 1, 1, 0.3), false, 2)
		# Number label
		draw_string(get_default_font(), p + Vector2(-4, 4), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0, 0, 0))

	# Progress
	var hit := 0
	for v in visited:
		if v == 1:
			hit += 1
	var pct := float(hit) / float(sigil_points.size())
	draw_string(get_default_font(), area_origin + Vector2(8, area_size.y + 20), "Sigil: %.0f%%" % (pct * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.95, 0.85))
	draw_string(get_default_font(), area_origin + Vector2(area_size.x - 8, area_size.y + 20), "Time: %.1fs" % time_left, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color(0.95, 0.85, 0.40))

func _input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_check_click(event.position)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_check_click(event.position)

func _check_click(pos: Vector2) -> void:
	if next_idx >= sigil_points.size():
		return
	var target := sigil_points[next_idx]
	if pos.distance_to(target) <= 18:
		visited[next_idx] = 1
		next_idx += 1
		if next_idx >= sigil_points.size():
			# All hit! Early finish with full quality
			_finish()

func _finish() -> void:
	finished = true
	var hit := 0
	for v in visited:
		if v == 1:
			hit += 1
	# Quality: hits / total. Bonus for early completion.
	var quality := float(hit) / float(sigil_points.size())
	if next_idx >= sigil_points.size():
		quality = 1.0  # perfect trace
	await get_tree().create_timer(0.5).timeout
	completed.emit(quality)

func get_default_font() -> Font:
	return ThemeDB.get_default_theme().default_font
