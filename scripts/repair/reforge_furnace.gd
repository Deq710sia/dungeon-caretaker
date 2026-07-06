extends Node2D
## Repair Minigame: Reforge Furnace (V2)
## Removes SHATTERED state. Multi-stage (melt → pour → hammer).
## The WEAPON is drawn large and visible in each stage, showing it being reformed.

signal completed(quality: float)

const TIME_LIMIT: float = 12.0

var time_left: float = TIME_LIMIT
var stage: int = 0
var finished: bool = false
var gear: Weapon = null

# Stage 1: melt
var melt_level: float = 0.0
var melt_target_min: float = 0.55
var melt_target_max: float = 0.75
var melt_pouring: bool = false
var melt_score: float = 0.0
var melt_locked: bool = false

# Stage 2: pour
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
var hammer_total: int = 32
# NOTE: this was 12 — with only 12 swings across 40 cells, a perfect player
# could never exceed 30% coverage, making a flawless hammer stage impossible.
# Bumped so full coverage rewards precision instead of being unreachable; a
# few swings of slack still punishes sloppy clicking (misses/duplicates).
var hammer_swings: int = 46
var hammer_score: float = 0.0
var hammer_locked: bool = false

func _ready() -> void:
	var p := get_parent()
	if p and p.get("carrying") != null:
		gear = p.carrying
	hammer_cells.resize(hammer_total)
	for i in hammer_total:
		hammer_cells[i] = 0
	pour_target_x = randf_range(0.25, 0.75)
	var lbl := Label.new()
	lbl.text = "REFORGE FURNACE — 3 stages: Melt > Pour > Hammer"
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.55, 0.30))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.position = Vector2(0, 22)
	lbl.size = Vector2(320, 14)
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
	pass

func _draw() -> void:
	var vp := Vector2(480, 270)
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.03, 0.08, 1.0), true)
	var stage_names := ["MELT", "POUR", "HAMMER"]
	if stage < 3:
		GameFont.draw_string_centered(self, Vector2(vp.x / 2, 18), stage_names[stage], 8, Palette.TEXT_GOLD)
	# Draw the weapon (state changes per stage to show progress)
	if gear != null:
		var display_state := gear.state
		match stage:
			0: display_state = Weapon.State.SHATTERED
			1: display_state = Weapon.State.SHATTERED
			2: display_state = Weapon.State.RUSTED
			3: display_state = Weapon.State.PRISTINE
		var weapon_tex := Sprites.get_weapon_sprite(gear.type, display_state)
		var wsize := 56
		var wpos := Vector2(int(vp.x / 2 - wsize / 2), 28)
		# Glow
		var glow_c := Color(0.95, 0.55, 0.20, 0.3 + 0.2 * sin(Time.get_ticks_msec() * 0.005))
		draw_rect(Rect2(wpos.x - 4, wpos.y - 4, wsize + 8, wsize + 8), glow_c, true)
		# Weapon
		draw_texture_rect(weapon_tex, Rect2(wpos.x, wpos.y, wsize, wsize), false)
		# Name (ABOVE weapon, not below — was being painted over by crucible)
		GameFont.draw_string_centered(self, Vector2(vp.x / 2, 90), gear.display_name, 8, gear.wear_color())
	match stage:
		0: _draw_melt()
		1: _draw_pour()
		2: _draw_hammer()
		3:
			GameFont.draw_string_centered(self, Vector2(vp.x / 2, vp.y / 2), "COMPLETE!", 16, Color(0.55, 0.95, 0.75))
	GameFont.draw_string(self, Vector2(vp.x - 10, 12), "%.1fs" % time_left, 8, Palette.TEXT_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)

func _draw_melt() -> void:
	var vp := Vector2(480, 270)
	# Crucible — moved UP so lock button + text fit on screen
	var cruc_x: float = vp.x * 0.25
	var cruc_y: float = 100.0  # was 0.65*180=117 — too low
	var cruc_w: float = vp.x * 0.50
	var cruc_h: float = 36.0   # was 50 — too tall
	# Background
	draw_rect(Rect2(cruc_x, cruc_y, cruc_w, cruc_h), Color(0.18, 0.10, 0.10), true)
	# Sweet spot band
	var band_y: float = cruc_y + cruc_h * (1.0 - melt_target_max)
	var band_h: float = cruc_h * (melt_target_max - melt_target_min)
	draw_rect(Rect2(cruc_x, band_y, cruc_w, band_h), Color(0.30, 0.65, 0.30), true)
	# Melt fill
	var fill_h: float = cruc_h * melt_level
	draw_rect(Rect2(cruc_x, cruc_y + cruc_h - fill_h, cruc_w, fill_h), Color(0.95, 0.55, 0.20), true)
	# Glowing top
	if melt_level > 0.1:
		draw_rect(Rect2(cruc_x, cruc_y + cruc_h - fill_h, cruc_w, 3), Color(1.0, 0.85, 0.40), true)
	# Border
	draw_rect(Rect2(cruc_x, cruc_y, cruc_w, cruc_h), Color(0.55, 0.55, 0.65), false, 2)
	# Lock button — now fits on screen
	var lock_rect := Rect2(int(vp.x / 2 - 30), int(cruc_y + cruc_h + 6), 60, 16)
	var lock_c := Color(0.55, 0.40, 0.20) if not melt_locked else Color(0.30, 0.65, 0.30)
	draw_rect(lock_rect, lock_c, true)
	GameFont.draw_string_centered(self, Vector2(vp.x / 2, lock_rect.position.y + 12), "LOCK", 8, Color(1, 1, 1))
	if melt_locked:
		GameFont.draw_string_centered(self, Vector2(vp.x / 2, lock_rect.position.y + 26), "Score: %.0f%%" % (melt_score * 100), 8, Color(0.55, 0.95, 0.75))
	else:
		GameFont.draw_string_centered(self, Vector2(vp.x / 2, lock_rect.position.y + 26), "Hold mouse. Lock in green.", 8, Color(0.85, 0.85, 0.85))

func _draw_pour() -> void:
	var vp := Vector2(480, 270)
	var bar_y: float = 110.0  # was 0.70*180=126
	var bar_h: float = 16.0
	var bar_x: float = vp.x * 0.15
	var bar_w: float = vp.x * 0.70
	# Background
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.18, 0.10, 0.10), true)
	# Target zone
	var tz_x: float = bar_x + bar_w * (pour_target_x - pour_target_w / 2)
	draw_rect(Rect2(tz_x, bar_y, bar_w * pour_target_w, bar_h), Color(0.30, 0.65, 0.30), true)
	# Marker
	var mx: float = bar_x + bar_w * pour_marker_x
	draw_rect(Rect2(mx - 3, bar_y - 4, 6, bar_h + 8), Color(0.95, 0.85, 0.30), true)
	# Border
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.55, 0.55, 0.65), false, 2)
	if not pour_locked:
		GameFont.draw_string_centered(self, Vector2(vp.x / 2, bar_y + bar_h + 14), "Click in green zone!", 8, Color(0.85, 0.85, 0.85))
	else:
		GameFont.draw_string_centered(self, Vector2(vp.x / 2, bar_y + bar_h + 14), "Score: %.0f%%" % (pour_score * 100), 8, Color(0.55, 0.95, 0.75))

func _draw_hammer() -> void:
	var vp := Vector2(480, 270)
	var cols: int = 8
	var rows: int = 4  # was 5 — too tall, went off-screen
	var cell_w: float = 32.0  # was 36 — too wide
	var cell_h: float = 12.0  # was 16 — too tall
	var gx: float = int(vp.x / 2 - cols * cell_w / 2)
	var gy: float = 104.0  # was 0.65*180=117 — too low
	for y in rows:
		for x in cols:
			var idx := y * cols + x
			var c := Color(0.45, 0.45, 0.48) if hammer_cells[idx] == 0 else Color(0.95, 0.85, 0.40)
			draw_rect(Rect2(gx + x * cell_w, gy + y * cell_h, cell_w - 2, cell_h - 2), c, true)
	draw_rect(Rect2(gx - 2, gy - 2, cols * cell_w + 4, rows * cell_h + 4), Color(0.55, 0.55, 0.65), false, 2)
	GameFont.draw_string_centered(self, Vector2(vp.x / 2, gy + rows * cell_h + 14), "Click! Swings: %d" % max(0, hammer_swings), 8, Color(0.85, 0.85, 0.85))

func _input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if stage == 0:
			melt_pouring = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and stage == 0 and not melt_locked:
		melt_pouring = event.pressed

func _handle_click(pos: Vector2) -> void:
	match stage:
		0: _click_melt(pos)
		1: _click_pour(pos)
		2: _click_hammer(pos)

func _click_melt(pos: Vector2) -> void:
	var vp := Vector2(480, 270)
	# Match the lock_rect from _draw_melt: (130, 142, 60, 16)
	var lock_rect := Rect2(int(vp.x / 2 - 30), int(100 + 36 + 6), 60, 16)
	if lock_rect.has_point(pos):
		if melt_level >= melt_target_min and melt_level <= melt_target_max:
			melt_score = 1.0
		else:
			var dist: float = 0.0
			if melt_level < melt_target_min:
				dist = melt_target_min - melt_level
			else:
				dist = melt_level - melt_target_max
			melt_score = clampf(1.0 - dist * 2.0, 0.0, 1.0)
		melt_locked = true
		stage = 1

func _click_pour(_pos: Vector2) -> void:
	if pour_locked:
		return
	var diff: float = absf(pour_marker_x - pour_target_x)
	if diff <= pour_target_w / 2.0:
		pour_score = 1.0 - (diff / (pour_target_w / 2.0)) * 0.3
	else:
		pour_score = clampf(1.0 - (diff - pour_target_w / 2.0) * 3.0, 0.0, 1.0)
	pour_score = clampf(pour_score, 0.0, 1.0)
	pour_locked = true
	stage = 2

func _click_hammer(pos: Vector2) -> void:
	if hammer_locked:
		return
	if hammer_swings <= 0:
		hammer_score = float(hammer_covered) / float(hammer_total)
		hammer_locked = true
		stage = 3
		_finish()
		return
	var vp := Vector2(480, 270)
	var cols: int = 8
	var rows: int = 4
	var cell_w: float = 32.0
	var cell_h: float = 12.0
	var gx: float = int(vp.x / 2 - cols * cell_w / 2)
	var gy: float = 104.0
	var rel := pos - Vector2(gx, gy)
	if rel.x < 0 or rel.y < 0 or rel.x >= cols * cell_w or rel.y >= rows * cell_h:
		return
	var cx: int = int(rel.x / cell_w)
	var cy: int = int(rel.y / cell_h)
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
	if stage < 3:
		if not melt_locked:
			melt_score = 0.0
		if not pour_locked:
			pour_score = 0.0
		if not hammer_locked:
			hammer_score = float(hammer_covered) / float(hammer_total)
	var quality: float = (melt_score + pour_score + hammer_score) / 3.0
	await get_tree().create_timer(0.5).timeout
	completed.emit(quality)
	queue_free()
