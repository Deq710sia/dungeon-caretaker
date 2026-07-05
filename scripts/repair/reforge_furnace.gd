extends Node2D
## Repair Minigame: Reforge Furnace
## Removes SHATTERED state. Multi-stage (Jacksmith-style compressed):
## Stage 1: Melt — hold mouse to fill meter, release in green zone (timing)
## Stage 2: Pour — click at the right moment (marker-on-bar)
## Stage 3: Hammer — click repeatedly to cover area
## Combined quality = average of 3 stage scores.

signal completed(quality: float)

const TIME_LIMIT: float = 10.0

var time_left: float = TIME_LIMIT
var stage: int = 0  # 0=melt, 1=pour, 2=hammer, 3=done
var finished: bool = false

# Stage 1: melt
var melt_level: float = 0.0
var melt_target_min: float = 0.55
var melt_target_max: float = 0.75
var melt_pouring: bool = false
var melt_score: float = 0.0
var melt_locked: bool = false

# Stage 2: pour (marker on bar)
var pour_marker_x: float = 0.0
var pour_target_x: float = 0.5
var pour_target_w: float = 0.10
var pour_dir: float = 1.0
var pour_speed: float = 0.8
var pour_score: float = 0.0
var pour_locked: bool = false

# Stage 3: hammer
var hammer_cells: PackedByteArray = PackedByteArray()
var hammer_covered: int = 0
var hammer_total: int = 40  # 8x5
var hammer_swings: int = 12
var hammer_score: float = 0.0
var hammer_locked: bool = false

var area_origin: Vector2
var area_size: Vector2

func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	area_origin = Vector2(vp.x * 0.12, vp.y * 0.30)
	area_size = Vector2(vp.x * 0.76, vp.y * 0.40)
	hammer_cells.resize(hammer_total)
	for i in hammer_total:
		hammer_cells[i] = 0
	# Pick a random pour target
	pour_target_x = randf_range(0.25, 0.75)

	var lbl := Label.new()
	lbl.text = "Reforge Furnace — 3 stages: Melt > Pour > Hammer"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.55, 0.30))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(area_origin.x - 60, area_origin.y - 24)
	lbl.size = Vector2(area_size.x + 120, 20)
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
	match stage:
		0: _process_melt(delta)
		1: _process_pour(delta)
		2: _process_hammer(delta)
	queue_redraw()

func _process_melt(delta: float) -> void:
	if melt_locked:
		return
	if melt_pouring:
		melt_level += 0.50 * delta
	else:
		melt_level -= 0.20 * delta
	melt_level = clampf(melt_level, 0.0, 1.0)

func _process_pour(delta: float) -> void:
	if pour_locked:
		return
	pour_marker_x += pour_dir * pour_speed * delta
	if pour_marker_x >= 1.0:
		pour_marker_x = 1.0
		pour_dir = -1.0
	elif pour_marker_x <= 0.0:
		pour_marker_x = 0.0
		pour_dir = 1.0

func _process_hammer(_delta: float) -> void:
	# No automatic updates; clicks drive progress
	pass

func _draw() -> void:
	# Background
	draw_rect(Rect2(area_origin, area_size), Color(0.10, 0.06, 0.10), true)
	# Stage indicator
	var stage_names := ["Stage 1: MELT", "Stage 2: POUR", "Stage 3: HAMMER"]
	if stage < 3:
		draw_string(get_default_font(), area_origin + Vector2(area_size.x / 2 - 80, 16), stage_names[stage], HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.95, 0.85, 0.40))

	match stage:
		0: _draw_melt()
		1: _draw_pour()
		2: _draw_hammer()
		3:
			draw_string(get_default_font(), area_origin + Vector2(area_size.x / 2 - 80, area_size.y / 2), "Complete!", HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color(0.55, 0.95, 0.75))

	# Time
	draw_string(get_default_font(), area_origin + Vector2(area_size.x - 8, area_size.y + 20), "Time: %.1fs" % time_left, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color(0.95, 0.85, 0.40))

func _draw_melt() -> void:
	# Crucible
	var cruc_x := area_origin.x + area_size.x * 0.30
	var cruc_y := area_origin.y + area_size.y * 0.30
	var cruc_w := area_size.x * 0.40
	var cruc_h := area_size.y * 0.50
	# Background
	draw_rect(Rect2(cruc_x, cruc_y, cruc_w, cruc_h), Color(0.18, 0.10, 0.10), true)
	# Sweet spot band
	var band_y := cruc_y + cruc_h * (1.0 - melt_target_max)
	var band_h := cruc_h * (melt_target_max - melt_target_min)
	draw_rect(Rect2(cruc_x, band_y, cruc_w, band_h), Color(0.30, 0.65, 0.30), true)
	# Melt fill
	var fill_h := cruc_h * melt_level
	draw_rect(Rect2(cruc_x, cruc_y + cruc_h - fill_h, cruc_w, fill_h), Color(0.95, 0.55, 0.20), true)
	# Border
	draw_rect(Rect2(cruc_x, cruc_y, cruc_w, cruc_h), Color(0.55, 0.55, 0.65), false, 2)

	# Instructions
	if not melt_locked:
		draw_string(get_default_font(), area_origin + Vector2(area_size.x / 2 - 120, area_size.y - 8), "Hold mouse to melt. Release in green zone, then click LOCK.", HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.85, 0.85, 0.85))
	else:
		draw_string(get_default_font(), area_origin + Vector2(area_size.x / 2 - 60, area_size.y - 8), "Melt score: %.0f%%" % (melt_score * 100), HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.55, 0.95, 0.75))

	# Lock button (drawn as a rect)
	var lock_rect := Rect2(area_origin.x + area_size.x * 0.40, area_origin.y + area_size.y * 0.85, area_size.x * 0.20, 18)
	draw_rect(lock_rect, Color(0.55, 0.40, 0.20), true)
	draw_string(get_default_font(), lock_rect.position + Vector2(20, 13), "LOCK", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1, 1, 1))

func _draw_pour() -> void:
	# Bar across middle
	var bar_y := area_origin.y + area_size.y * 0.45
	var bar_h := 24.0
	var bar_x := area_origin.x + area_size.x * 0.10
	var bar_w := area_size.x * 0.80
	# Background
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.18, 0.10, 0.10), true)
	# Target zone
	var tz_x := bar_x + bar_w * (pour_target_x - pour_target_w / 2)
	draw_rect(Rect2(tz_x, bar_y, bar_w * pour_target_w, bar_h), Color(0.30, 0.65, 0.30), true)
	# Marker
	var mx := bar_x + bar_w * pour_marker_x
	draw_rect(Rect2(mx - 3, bar_y - 4, 6, bar_h + 8), Color(0.95, 0.85, 0.30), true)
	# Border
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.55, 0.55, 0.65), false, 2)

	if not pour_locked:
		draw_string(get_default_font(), area_origin + Vector2(area_size.x / 2 - 120, area_size.y - 8), "Click when marker is in the green zone!", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.85, 0.85, 0.85))
	else:
		draw_string(get_default_font(), area_origin + Vector2(area_size.x / 2 - 60, area_size.y - 8), "Pour score: %.0f%%" % (pour_score * 100), HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.55, 0.95, 0.75))

func _draw_hammer() -> void:
	# Grid of cells
	var cols := 8
	var rows := 5
	var cell_w := area_size.x * 0.60 / cols
	var cell_h := area_size.y * 0.50 / rows
	var gx := area_origin.x + area_size.x * 0.20
	var gy := area_origin.y + area_size.y * 0.20
	for y in rows:
		for x in cols:
			var idx := y * cols + x
			var c := Color(0.45, 0.45, 0.48) if hammer_cells[idx] == 0 else Color(0.95, 0.85, 0.40)
			draw_rect(Rect2(gx + x * cell_w, gy + y * cell_h, cell_w - 1, cell_h - 1), c, true)
	# Border
	draw_rect(Rect2(gx - 2, gy - 2, cols * cell_w + 4, rows * cell_h + 4), Color(0.55, 0.55, 0.65), false, 2)
	# Swings counter
	draw_string(get_default_font(), area_origin + Vector2(area_size.x / 2 - 80, area_size.y - 8), "Click cells! Swings left: %d" % max(0, hammer_swings), HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.85, 0.85, 0.85))

func _input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if stage == 0:
			melt_pouring = false

	# Hold for melt
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and stage == 0 and not melt_locked:
		melt_pouring = event.pressed

func _handle_click(pos: Vector2) -> void:
	match stage:
		0: _click_melt(pos)
		1: _click_pour(pos)
		2: _click_hammer(pos)

func _click_melt(pos: Vector2) -> void:
	# Check if click is in the LOCK button
	var lock_rect := Rect2(area_origin.x + area_size.x * 0.40, area_origin.y + area_size.y * 0.85, area_size.x * 0.20, 18)
	if lock_rect.has_point(pos):
		# Lock in current melt_level
		if melt_level >= melt_target_min and melt_level <= melt_target_max:
			melt_score = 1.0
		else:
			# Score decays with distance from zone
			var dist := 0.0
			if melt_level < melt_target_min:
				dist = melt_target_min - melt_level
			else:
				dist = melt_level - melt_target_max
			melt_score = clampf(1.0 - dist * 2.0, 0.0, 1.0)
		melt_locked = true
		stage = 1
	# Otherwise, holding mouse handled in _input

func _click_pour(_pos: Vector2) -> void:
	# Any click locks the pour
	if pour_locked:
		return
	# Score = distance from target zone center
	var diff := absf(pour_marker_x - pour_target_x)
	if diff <= pour_target_w / 2.0:
		pour_score = 1.0 - (diff / (pour_target_w / 2.0)) * 0.3  # slight penalty for off-center
	else:
		pour_score = clampf(1.0 - (diff - pour_target_w / 2.0) * 3.0, 0.0, 1.0)
	pour_score = clampf(pour_score, 0.0, 1.0)
	pour_locked = true
	stage = 2

func _click_hammer(pos: Vector2) -> void:
	if hammer_locked:
		return
	if hammer_swings <= 0:
		# Lock in score
		hammer_score = float(hammer_covered) / float(hammer_total)
		hammer_locked = true
		stage = 3
		_finish()
		return
	# Find cell clicked
	var cols := 8
	var rows := 5
	var cell_w := area_size.x * 0.60 / cols
	var cell_h := area_size.y * 0.50 / rows
	var gx := area_origin.x + area_size.x * 0.20
	var gy := area_origin.y + area_size.y * 0.20
	var rel := pos - Vector2(gx, gy)
	if rel.x < 0 or rel.y < 0 or rel.x >= cols * cell_w or rel.y >= rows * cell_h:
		return
	var cx := int(rel.x / cell_w)
	var cy := int(rel.y / cell_h)
	var idx := cy * cols + cx
	if hammer_cells[idx] == 0:
		hammer_cells[idx] = 1
		hammer_covered += 1
	hammer_swings -= 1
	if hammer_swings <= 0 or hammer_covered >= hammer_total:
		hammer_score = float(hammer_covered) / float(hammer_total)
		hammer_locked = true
		stage = 3
		_finish()

func _finish() -> void:
	if finished:
		return
	finished = true
	# If we ran out of time without finishing all stages, score what we have
	if stage < 3:
		# Compute partial scores
		if not melt_locked:
			melt_score = 0.0
		if not pour_locked:
			pour_score = 0.0
		if not hammer_locked:
			hammer_score = float(hammer_covered) / float(hammer_total)
	var quality := (melt_score + pour_score + hammer_score) / 3.0
	await get_tree().create_timer(0.5).timeout
	completed.emit(quality)

func get_default_font() -> Font:
	return ThemeDB.get_default_theme().default_font
