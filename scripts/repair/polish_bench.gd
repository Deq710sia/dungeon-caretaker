extends Node2D
## Repair Minigame: Polish Bench
## Removes BLOODIED state. Drag mouse back and forth across the item to "wipe" it.
## Coverage % over a time limit = quality score.

signal completed(quality: float)

const TIME_LIMIT: float = 6.0
const TARGET_COVERAGE: float = 0.85  # need to cover 85% of cells

var time_left: float = TIME_LIMIT
var cells: PackedByteArray = PackedByteArray()  # 16x10 grid, 1 = wiped
var cells_wide: int = 24
var cells_high: int = 10
var total_cells: int
var covered: int = 0
var finished: bool = false

var brush_pos: Vector2 = Vector2.ZERO
var last_brush_pos: Vector2 = Vector2.ZERO
var brush_down: bool = false
var area_origin: Vector2
var area_size: Vector2

func _ready() -> void:
	total_cells = cells_wide * cells_high
	cells.resize(total_cells)
	for i in total_cells:
		cells[i] = 0
	# Compute area in screen space
	var vp := get_viewport().get_visible_rect().size
	area_origin = Vector2(vp.x * 0.10, vp.y * 0.30)
	area_size = Vector2(vp.x * 0.80, vp.y * 0.35)
	# Instructions
	var lbl := Label.new()
	lbl.text = "Polish Bench — Click + drag to wipe the blade clean! (%.0fs)" % TIME_LIMIT
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(area_origin.x, area_origin.y - 24)
	lbl.size = Vector2(area_size.x, 20)
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
	# Draw frame
	draw_rect(Rect2(area_origin, area_size), Color(0.10, 0.08, 0.14), true)
	# Draw cells
	var cell_w := area_size.x / cells_wide
	var cell_h := area_size.y / cells_high
	for y in cells_high:
		for x in cells_wide:
			var idx := y * cells_wide + x
			var cell_origin := area_origin + Vector2(x * cell_w, y * cell_h)
			if cells[idx] == 1:
				draw_rect(Rect2(cell_origin, Vector2(cell_w, cell_h)), Color(0.85, 0.85, 0.90), true)
			else:
				# Show grime pattern (red specks)
				var c := Color(0.45, 0.18, 0.18) if (x + y) % 3 == 0 else Color(0.20, 0.12, 0.12)
				draw_rect(Rect2(cell_origin, Vector2(cell_w, cell_h)), c, true)
	# Grid lines
	for x in cells_wide + 1:
		draw_line(area_origin + Vector2(x * cell_w, 0), area_origin + Vector2(x * cell_w, area_size.y), Color(0.05, 0.04, 0.07), 1)
	for y in cells_high + 1:
		draw_line(area_origin + Vector2(0, y * cell_h), area_origin + Vector2(area_size.x, y * cell_h), Color(0.05, 0.04, 0.07), 1)
	# Border
	draw_rect(Rect2(area_origin, area_size), Color(0.55, 0.55, 0.65), false, 2)
	# Coverage %
	var pct := float(covered) / float(total_cells)
	draw_string(get_default_font(), area_origin + Vector2(8, area_size.y + 20), "Coverage: %.0f%%" % (pct * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.95, 0.85))
	draw_string(get_default_font(), area_origin + Vector2(area_size.x - 8, area_size.y + 20), "Time: %.1fs" % time_left, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color(0.95, 0.85, 0.40))
	# Brush indicator
	if brush_down:
		draw_circle(brush_pos, 6, Color(1, 1, 1, 0.6))

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
	var cell_w := area_size.x / cells_wide
	var cell_h := area_size.y / cells_high
	var rel := pos - area_origin
	if rel.x < 0 or rel.y < 0 or rel.x > area_size.x or rel.y > area_size.y:
		return
	var cx := int(rel.x / cell_w)
	var cy := int(rel.y / cell_h)
	if cx < 0 or cx >= cells_wide or cy < 0 or cy >= cells_high:
		return
	var idx := cy * cells_wide + cx
	if cells[idx] == 0:
		cells[idx] = 1
		covered += 1

func _paint_line(from: Vector2, to: Vector2) -> void:
	# Sample along the line and paint each
	var dist: float = from.distance_to(to)
	var steps: int = max(1, int(dist / 4))
	for i in steps + 1:
		var t: float = float(i) / float(steps)
		_paint_at(from.lerp(to, t))

func _finish() -> void:
	finished = true
	var pct := float(covered) / float(total_cells)
	# Quality: coverage / target, capped at 1.0
	var quality := clampf(pct / TARGET_COVERAGE, 0.0, 1.0)
	# Wait a moment then signal completion
	await get_tree().create_timer(0.5).timeout
	completed.emit(quality)

func get_default_font() -> Font:
	return ThemeDB.get_default_theme().default_font
