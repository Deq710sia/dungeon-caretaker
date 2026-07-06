extends Node2D
## Repair Minigame: Polish Bench (V2)
## Removes BLOODIED state. The WEAPON is drawn large in the center of the screen.
## Drag mouse across the weapon to wipe off the blood. Coverage % = quality.

signal completed(quality: float)

const TIME_LIMIT: float = 7.0
const TARGET_COVERAGE: float = 0.80

var time_left: float = TIME_LIMIT
var cells: PackedByteArray = PackedByteArray()
var cells_wide: int = 20
var cells_high: int = 12
var total_cells: int
var covered: int = 0
var finished: bool = false

var brush_pos: Vector2 = Vector2.ZERO
var last_brush_pos: Vector2 = Vector2.ZERO
var brush_down: bool = false
var area_origin: Vector2
var area_size: Vector2

# The gear being repaired (passed from workshop via parent)
var gear: Weapon = null

func _ready() -> void:
	# Get the gear from parent
	var p := get_parent()
	if p and p.get("ghost") != null and p.ghost.carrying != null:
		gear = p.ghost.carrying
	# Setup area
	var vp := Vector2(320, 180)
	area_origin = Vector2(vp.x * 0.20, vp.y * 0.30)
	area_size = Vector2(vp.x * 0.60, vp.y * 0.45)
	total_cells = cells_wide * cells_high
	cells.resize(total_cells)
	for i in total_cells:
		cells[i] = 0
	# Title
	var lbl := Label.new()
	lbl.text = "POLISH BENCH — Drag to wipe the blood!"
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.position = Vector2(0, 22)
	lbl.size = Vector2(vp.x, 14)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)

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
	var vp := Vector2(320, 180)
	# Dim background
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.04, 0.07, 0.95), true)
	# Draw the weapon LARGE in the center (the centerpiece!)
	if gear != null:
		var weapon_tex := Sprites.get_weapon_sprite(gear.type, gear.state)
		var wsize := 96  # 3x scale (32 * 3)
		var wpos := Vector2(vp.x / 2 - wsize / 2, vp.y / 2 - wsize / 2)
		# Weapon shadow
		draw_rect(Rect2(wpos.x + 4, wpos.y + 4, wsize, wsize), Color(0, 0, 0, 0.4), true)
		# Weapon
		draw_texture_rect(weapon_tex, Rect2(wpos.x, wpos.y, wsize, wsize), false)
		# Blood overlay grid (cells not yet wiped)
		var cell_w: float = wsize / cells_wide
		var cell_h: float = wsize / cells_high
		for y in cells_high:
			for x in cells_wide:
				var idx := y * cells_wide + x
				if cells[idx] == 0:
					# Blood splatter (only some cells have visible blood)
					if (x + y * 3) % 4 < 2:
						var cell_origin := wpos + Vector2(x * cell_w, y * cell_h)
						var blood_c := Color(0.45, 0.10, 0.10, 0.85) if (x + y) % 3 == 0 else Color(0.30, 0.05, 0.05, 0.7)
						draw_rect(Rect2(cell_origin, Vector2(cell_w, cell_h)), blood_c, true)
		# Border around weapon
		draw_rect(Rect2(wpos.x - 2, wpos.y - 2, wsize + 4, wsize + 4), Color(0.55, 0.55, 0.65), false, 2)
		# Wipe cursor (brush)
		if brush_down:
			draw_circle(brush_pos, 8, Color(1, 1, 1, 0.7))
			draw_circle(brush_pos, 6, Color(0.95, 0.95, 0.40, 0.9))
		# Stats
		var pct: float = float(covered) / float(total_cells)
		var clean_pct := clampf(pct / TARGET_COVERAGE, 0.0, 1.0)
		draw_string(GameFont.get_font(), Vector2(10, vp.y - 24), "Clean: %.0f%%" % (clean_pct * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.85, 0.95, 0.85))
		draw_string(GameFont.get_font(), Vector2(vp.x - 10, vp.y - 24), "Time: %.1fs" % time_left, HORIZONTAL_ALIGNMENT_RIGHT, -1, 8, Color(0.95, 0.85, 0.40))
		# Item name
		draw_string(GameFont.get_font(), Vector2(vp.x / 2 - 50, vp.y - 24), gear.display_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, gear.wear_color())
	# Progress bar
	var bar_x: float = vp.x * 0.20
	var bar_y: float = vp.y * 0.82
	var bar_w: float = vp.x * 0.60
	draw_rect(Rect2(bar_x, bar_y, bar_w, 4), Color(0.20, 0.20, 0.20), true)
	var fill_pct: float = clampf(float(covered) / float(total_cells * TARGET_COVERAGE), 0, 1)
	draw_rect(Rect2(bar_x, bar_y, bar_w * fill_pct, 4), Color(0.55, 0.95, 0.55), true)

func _input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventMouseMotion:
		brush_pos = event.position
		if brush_down:
			_paint_line(last_brush_pos, brush_pos)
		last_brush_pos = brush_pos
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			brush_down = event.pressed
			brush_pos = event.position
			last_brush_pos = brush_pos
			if brush_down:
				_paint_at(brush_pos)

func _paint_at(pos: Vector2) -> void:
	if gear == null:
		return
	var vp := Vector2(320, 180)
	var wsize := 96
	var wpos := Vector2(vp.x / 2 - wsize / 2, vp.y / 2 - wsize / 2)
	var cell_w: float = float(wsize) / float(cells_wide)
	var cell_h: float = float(wsize) / float(cells_high)
	var rel := pos - wpos
	if rel.x < 0 or rel.y < 0 or rel.x >= wsize or rel.y >= wsize:
		return
	var cx: int = int(rel.x / cell_w)
	var cy: int = int(rel.y / cell_h)
	if cx < 0 or cx >= cells_wide or cy < 0 or cy >= cells_high:
		return
	var idx := cy * cells_wide + cx
	if cells[idx] == 0:
		cells[idx] = 1
		covered += 1

func _paint_line(from: Vector2, to: Vector2) -> void:
	var dist: float = from.distance_to(to)
	var steps: int = max(1, int(dist / 4))
	for i in steps + 1:
		var t: float = float(i) / float(steps)
		_paint_at(from.lerp(to, t))

func _finish() -> void:
	finished = true
	var pct: float = float(covered) / float(total_cells)
	var quality: float = clampf(pct / TARGET_COVERAGE, 0.0, 1.0)
	await get_tree().create_timer(0.4).timeout
	completed.emit(quality)
	queue_free()
