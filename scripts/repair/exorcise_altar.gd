extends Node2D
## Repair Minigame: Exorcise Altar (V2)
## Removes HAUNTED and CURSED states.
## The WEAPON is drawn large in the center, surrounded by the sigil you must trace.
## HAUNTED: trace forward. CURSED: trace in reverse.

signal completed(quality: float)

const TIME_LIMIT: float = 8.0

var time_left: float = TIME_LIMIT
var sigil_points: PackedVector2Array = PackedVector2Array()
var visited: PackedByteArray = PackedByteArray()
var next_idx: int = 0
var finished: bool = false
var is_cursed: bool = false
var gear: Weapon = null

func _ready() -> void:
	var p := get_parent()
	if p and p.get("ghost") != null and p.ghost.carrying != null:
		gear = p.ghost.carrying
	if gear != null:
		is_cursed = gear.state == Weapon.State.CURSED
	_build_sigil()
	var instruction := "TRACE FORWARD!" if not is_cursed else "TRACE IN REVERSE!"
	var lbl := Label.new()
	lbl.text = "EXORCISE ALTAR — %s" % instruction
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.55, 0.95) if is_cursed else Color(0.55, 0.75, 0.95))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.position = Vector2(0, 22)
	lbl.size = Vector2(320, 14)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)

func _build_sigil() -> void:
	var vp := Vector2(480, 270)
	var center := Vector2(vp.x / 2, vp.y / 2 + 5)
	var r: float = 55.0
	# 7-pointed star pattern
	var n := 7
	for i in n:
		var a := -PI / 2.0 + i * (2.0 * PI / n)
		sigil_points.append(center + Vector2(cos(a), sin(a)) * r)
	# Center point
	sigil_points.append(center)
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
	var vp := Vector2(480, 270)
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.03, 0.08, 1.0), true)
	# Draw the WEAPON in the center (the centerpiece!)
	if gear != null:
		var weapon_tex := Sprites.get_weapon_sprite_wear(gear.type, gear.wear_state, gear.is_haunted())
		var wsize := 56
		var wpos := Vector2(vp.x / 2 - wsize / 2, vp.y / 2 - wsize / 2 + 5)
		# Mystical glow around weapon
		var glow_pulse := 0.5 + 0.3 * sin(Time.get_ticks_msec() * 0.005)
		var glow_c := Color(0.65, 0.40, 0.85, glow_pulse * 0.4) if is_cursed else Color(0.55, 0.75, 0.95, glow_pulse * 0.4)
		draw_circle(Vector2(vp.x / 2, vp.y / 2 + 5), 45, glow_c)
		# Weapon
		draw_texture_rect(weapon_tex, Rect2(wpos.x, wpos.y, wsize, wsize), false)
		# Weapon name
		draw_string(GameFont.get_font(), Vector2(vp.x / 2 - 50, vp.y / 2 + 40), gear.display_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, gear.wear_color())
	# Sigil lines (faded)
	for i in sigil_points.size():
		var j := (i + 1) % sigil_points.size()
		var c := Color(0.30, 0.20, 0.40, 0.4)
		if visited[i] == 1 and visited[j] == 1:
			c = Color(0.55, 0.95, 0.75, 0.9)
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
		# Pulse on active
		if i == next_idx:
			var pulse := 1.0 + 0.2 * sin(Time.get_ticks_msec() * 0.008)
			draw_circle(p, 18 * pulse, Color(0.95, 0.85, 0.30, 0.3))
		draw_circle(p, 14, c)
		draw_circle(p, 14, Color(1, 1, 1, 0.4), false, 2)
		# Number label
		draw_string(GameFont.get_font(), p + Vector2(-3, 4), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0, 0, 0))
	# Stats
	var hit := 0
	for v in visited:
		if v == 1:
			hit += 1
	var pct: float = float(hit) / float(sigil_points.size())
	draw_string(GameFont.get_font(), Vector2(10, vp.y - 24), "Sigil: %.0f%%" % (pct * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.85, 0.95, 0.85))
	draw_string(GameFont.get_font(), Vector2(vp.x - 10, vp.y - 24), "Time: %.1fs" % time_left, HORIZONTAL_ALIGNMENT_RIGHT, -1, 8, Color(0.95, 0.85, 0.40))

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
	if pos.distance_to(target) <= 20:
		visited[next_idx] = 1
		next_idx += 1
		if next_idx >= sigil_points.size():
			_finish()

func _finish() -> void:
	finished = true
	var hit := 0
	for v in visited:
		if v == 1:
			hit += 1
	var quality: float = float(hit) / float(sigil_points.size())
	if next_idx >= sigil_points.size():
		quality = 1.0
	await get_tree().create_timer(0.4).timeout
	completed.emit(quality)
	queue_free()
