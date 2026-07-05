extends Node2D
## Phase: workshop — repair gear via 4 stations (polish, oil_grind, exorcise, reforge).
## Multitasking: drop a piece onto a station, the minigame pops up; quality saved on success.

var header: Label
var shards_label: Label
var gear_list: VBoxContainer
var stations_grid: GridContainer
var active_minigame: Node2D = null
var current_gear: GearItem = null
var open_doors_btn: Button
var log_label: Label

const STATION_DEFS := [
	{"key": "polish",     "name": "Polish Bench",    "sprite": "bench",      "states": [GearItem.State.BLOODIED]},
	{"key": "oil_grind",  "name": "Oil & Grindstone","sprite": "grindstone", "states": [GearItem.State.RUSTED]},
	{"key": "exorcise",   "name": "Exorcise Altar",  "sprite": "altar",      "states": [GearItem.State.HAUNTED, GearItem.State.CURSED]},
	{"key": "reforge",    "name": "Reforge Furnace", "sprite": "furnace",    "states": [GearItem.State.SHATTERED]},
]

func _ready() -> void:
	# Header
	var header_panel := Panel.new()
	header_panel.position = Vector2(8, 4)
	header_panel.size = Vector2(304, 28)
	add_child(header_panel)

	var day_label := Label.new()
	day_label.text = "Day %d — Workshop" % GameState.day
	day_label.add_theme_font_size_override("font_size", 14)
	day_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	day_label.position = Vector2(8, 6)
	day_label.size = Vector2(180, 20)
	header_panel.add_child(day_label)

	shards_label = Label.new()
	shards_label.text = "Shards: %d" % GameState.soul_shards
	shards_label.add_theme_font_size_override("font_size", 12)
	shards_label.add_theme_color_override("font_color", Color(0.65, 0.85, 0.95))
	shards_label.position = Vector2(160, 6)
	shards_label.size = Vector2(140, 20)
	shards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_panel.add_child(shards_label)

	# Salvage list
	var salvage_header := Label.new()
	salvage_header.text = "Salvage Pit (drag to station):"
	salvage_header.add_theme_font_size_override("font_size", 9)
	salvage_header.add_theme_color_override("font_color", Color(0.75, 0.70, 0.85))
	salvage_header.position = Vector2(8, 36)
	salvage_header.size = Vector2(304, 12)
	add_child(salvage_header)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(8, 50)
	scroll.size = Vector2(304, 56)
	add_child(scroll)

	gear_list = VBoxContainer.new()
	gear_list.add_theme_constant_override("separation", 2)
	gear_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(gear_list)

	# Stations grid (2x2)
	stations_grid = GridContainer.new()
	stations_grid.columns = 2
	stations_grid.position = Vector2(8, 110)
	stations_grid.size = Vector2(304, 50)
	stations_grid.add_theme_constant_override("h_separation", 6)
	stations_grid.add_theme_constant_override("v_separation", 6)
	add_child(stations_grid)

	for def in STATION_DEFS:
		var btn := Button.new()
		btn.text = def.name
		btn.add_theme_font_size_override("font_size", 8)
		btn.custom_minimum_size = Vector2(146, 30)
		btn.pressed.connect(_on_station_pressed.bind(def))
		# Add sprite above
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 1)
		var spr := TextureRect.new()
		spr.texture = Sprites.get_sprite(def.sprite)
		spr.custom_minimum_size = Vector2(20, 20)
		spr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		spr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stations_grid.add_child(btn)

	# Open doors button
	open_doors_btn = Button.new()
	open_doors_btn.text = "Open Doors (Skip to Delivery) >"
	open_doors_btn.add_theme_font_size_override("font_size", 10)
	open_doors_btn.custom_minimum_size = Vector2(304, 22)
	open_doors_btn.position = Vector2(8, 150)
	open_doors_btn.pressed.connect(_on_open_doors)
	add_child(open_doors_btn)

	log_label = Label.new()
	log_label.text = "Click a station, then choose gear to repair."
	log_label.add_theme_font_size_override("font_size", 7)
	log_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	log_label.position = Vector2(8, 174)
	log_label.size = Vector2(304, 8)
	log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(log_label)

	GameState.shards_changed.connect(_on_shards_changed)
	GameState.salvage_changed.connect(_refresh_list)
	_refresh_list()

func _on_shards_changed(new_count: int) -> void:
	shards_label.text = "Shards: %d" % new_count

func _refresh_list() -> void:
	for c in gear_list.get_children():
		c.queue_free()
	for gear in GameState.salvage_pit:
		var btn := Button.new()
		var target: String = gear.repair_target_station()
		var ready_text: String = " (READY)" if target == "" else ""
		btn.text = "[%s] %s%s" % [GearItem.STATE_EMOJI[gear.state], gear.display_name, ready_text]
		btn.add_theme_font_size_override("font_size", 8)
		btn.custom_minimum_size = Vector2(290, 16)
		btn.add_theme_color_override("font_color", gear.state_color())
		# Disable if no repair needed
		btn.disabled = (target == "")
		if btn.disabled:
			btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.85, 0.55))
		btn.pressed.connect(_on_gear_selected.bind(gear))
		gear_list.add_child(btn)

func _on_gear_selected(gear: GearItem) -> void:
	current_gear = gear
	var target: String = gear.repair_target_station()
	if target == "":
		log_label.text = "%s is already pristine." % gear.display_name
		return
	# Find matching station and launch its minigame
	_launch_minigame(target)

func _on_station_pressed(def: Dictionary) -> void:
	# Find first matching gear for this station
	var wanted_states: Array = def.states
	var found: GearItem = null
	for gear in GameState.salvage_pit:
		if gear.state in wanted_states:
			found = gear
			break
	if found == null:
		log_label.text = "No gear needs the %s." % def.name
		return
	current_gear = found
	_launch_minigame(def.key)

func _launch_minigame(station_key: String) -> void:
	if active_minigame != null:
		return  # already playing
	log_label.text = "Repairing %s at %s..." % [current_gear.display_name, station_key]
	var script: GDScript = null
	match station_key:
		"polish":    script = preload("res://scripts/repair/polish_bench.gd")
		"oil_grind": script = preload("res://scripts/repair/oil_grindstone.gd")
		"exorcise":  script = preload("res://scripts/repair/exorcise_altar.gd")
		"reforge":   script = preload("res://scripts/repair/reforge_furnace.gd")
		_:
			push_error("Unknown station: " + station_key)
			return
	active_minigame = Node2D.new()
	active_minigame.set_script(script)
	active_minigame.name = "Minigame_" + station_key
	add_child(active_minigame)
	# Wait for minigame to signal completion
	active_minigame.completed.connect(_on_minigame_completed)

func _on_minigame_completed(quality: float) -> void:
	# quality is 0.0..1.0
	if active_minigame:
		active_minigame.queue_free()
		active_minigame = null
	if current_gear == null:
		return
	# Apply quality threshold: >=0.6 = pristine, 0.3..0.6 = pristine but lower quality, <0.3 = unchanged
	if quality >= 0.6:
		current_gear.quality = quality
		current_gear.state = GearItem.State.PRISTINE
		current_gear.history.append("Revitalized to Pristine on Day %d (quality %.0f%%)." % [GameState.day, quality * 100])
		log_label.text = "%s revitalized! Quality: %.0f%%" % [current_gear.display_name, quality * 100]
	elif quality >= 0.3:
		current_gear.quality = quality
		current_gear.state = GearItem.State.PRISTINE
		current_gear.history.append("Hastily revitalized on Day %d (quality %.0f%%)." % [GameState.day, quality * 100])
		log_label.text = "%s barely saved. Quality: %.0f%%" % [current_gear.display_name, quality * 100]
	else:
		log_label.text = "%s repair failed — state unchanged." % current_gear.display_name
		current_gear.history.append("Repair attempt failed on Day %d." % GameState.day)
	GameState.salvage_changed.emit()
	current_gear = null

func _on_open_doors() -> void:
	# Move to entrance hall — the party will arrive there.
	GameState.set_phase("hall")
