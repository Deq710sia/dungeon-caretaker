extends Node2D
## Phase: entrance_hall (HUB) — the main gameplay scene.
## Top-down room where the ghost physically walks between stations.
##   - Walk to Salvage Pit + E = pick up next gear
##   - Walk to a Repair Station + E = repair carried gear (triggers minigame)
##   - Walk to an Adventurer + E = deliver carried gear (triggers delivery gauntlet)
##   - Walk to Merc Post + E = hire martyr party (costs shards)
## Bell timer counts down; when it rings, go to battle.

const ROOM_W: int = 320
const ROOM_H: int = 180
const HUD_H: int = 18
const STATION_RADIUS: float = 18.0
const ADVENTURER_RADIUS: float = 16.0

# Station definitions (positions are center points)
const STATIONS := [
	{"key": "salvage",  "name": "Salvage Pit",        "sprite": "crate",      "pos": Vector2(28, 58)},
	{"key": "polish",   "name": "Polish Bench",       "sprite": "bench",      "pos": Vector2(76, 58),  "states": [GearItem.State.BLOODIED]},
	{"key": "oil_grind","name": "Oil & Grindstone",   "sprite": "grindstone", "pos": Vector2(124, 58), "states": [GearItem.State.RUSTED]},
	{"key": "exorcise", "name": "Exorcise Altar",     "sprite": "altar",      "pos": Vector2(172, 58), "states": [GearItem.State.HAUNTED, GearItem.State.CURSED]},
	{"key": "reforge",  "name": "Reforge Furnace",    "sprite": "furnace",    "pos": Vector2(220, 58), "states": [GearItem.State.SHATTERED]},
	{"key": "merc",     "name": "Merc Post",          "sprite": "chest",      "pos": Vector2(268, 58)},
]

var ghost: Dictionary = {
	"pos": Vector2(160, 120),
	"speed": 55.0,
	"carrying": null,  # GearItem or null
}
var adventurers: Array = []
var bell_timer: float = 90.0
var bell_rang: bool = false
var gauntlet_active: bool = false
var minigame_active: bool = false
var active_minigame: Node2D = null
var current_gear_for_minigame: GearItem = null
var near_station_key: String = ""
var interact_pressed: bool = false

# HUD elements
var hud_day: Label
var hud_shards: Label
var hud_bell: Label
var hud_carrying: Label
var prompt_label: Label
var hire_merc_btn: Button
var open_doors_btn: Button

func _ready() -> void:
	# Spawn party if not already spawned
	if GameState.party.is_empty():
		GameState.spawn_party()
	_adventurers_arrive()
	_build_hud()
	# Bell timer scales down with day
	bell_timer = max(45.0, 120.0 - GameState.day * 2.5)

func _adventurers_arrive() -> void:
	adventurers.clear()
	# Place adventurers along the bottom of the room
	var n: int = GameState.party.size()
	var spacing: float = 220.0 / float(max(1, n))
	var start_x: float = 50.0 + spacing / 2.0
	for i in n:
		var adv: Dictionary = GameState.party[i]
		var a := {
			"pos": Vector2(start_x + i * spacing, 145),
			"sprite": "knight" if adv["class"] == "knight" else "mage",
			"adv": adv,
			"patience": 60.0 + GameState.meta_upgrades["patient_adventurers"] * 12.0,
			"patience_max": 60.0 + GameState.meta_upgrades["patient_adventurers"] * 12.0,
		}
		adventurers.append(a)

func _build_hud() -> void:
	# Top HUD bar
	var panel := Panel.new()
	panel.position = Vector2(0, 0)
	panel.size = Vector2(ROOM_W, HUD_H)
	add_child(panel)

	hud_day = Label.new()
	hud_day.text = "Day %d/%d" % [GameState.day, GameState.MAX_DAY]
	hud_day.add_theme_font_size_override("font_size", 9)
	hud_day.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	hud_day.position = Vector2(3, 3)
	hud_day.size = Vector2(55, 12)
	panel.add_child(hud_day)

	hud_bell = Label.new()
	hud_bell.text = "Bell: 90s"
	hud_bell.add_theme_font_size_override("font_size", 9)
	hud_bell.add_theme_color_override("font_color", Color(0.95, 0.55, 0.40))
	hud_bell.position = Vector2(60, 3)
	hud_bell.size = Vector2(50, 12)
	panel.add_child(hud_bell)

	hud_shards = Label.new()
	hud_shards.text = "Shards: 0"
	hud_shards.add_theme_font_size_override("font_size", 9)
	hud_shards.add_theme_color_override("font_color", Color(0.65, 0.85, 0.95))
	hud_shards.position = Vector2(115, 3)
	hud_shards.size = Vector2(60, 12)
	panel.add_child(hud_shards)

	hud_carrying = Label.new()
	hud_carrying.text = "Carrying: -"
	hud_carrying.add_theme_font_size_override("font_size", 8)
	hud_carrying.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
	hud_carrying.position = Vector2(180, 3)
	hud_carrying.size = Vector2(140, 12)
	panel.add_child(hud_carrying)

	# Prompt label (appears above ghost when near interactive)
	prompt_label = Label.new()
	prompt_label.text = ""
	prompt_label.add_theme_font_size_override("font_size", 8)
	prompt_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.40))
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	prompt_label.add_theme_constant_override("outline_size", 2)
	prompt_label.position = Vector2(0, 0)
	prompt_label.size = Vector2(ROOM_W, 12)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(prompt_label)

	# Hire mercs button (top-right corner, always visible)
	hire_merc_btn = Button.new()
	hire_merc_btn.text = "Hire Martyrs (60)"
	hire_merc_btn.add_theme_font_size_override("font_size", 7)
	hire_merc_btn.position = Vector2(245, 164)
	hire_merc_btn.size = Vector2(70, 14)
	hire_merc_btn.pressed.connect(_on_hire_mercs)
	add_child(hire_merc_btn)

	# Open doors (skip to battle) button
	open_doors_btn = Button.new()
	open_doors_btn.text = "Ring Bell >"
	open_doors_btn.add_theme_font_size_override("font_size", 7)
	open_doors_btn.position = Vector2(170, 164)
	open_doors_btn.size = Vector2(70, 14)
	open_doors_btn.pressed.connect(_on_ring_bell)
	add_child(open_doors_btn)

	GameState.shards_changed.connect(_on_shards_changed)
	_update_hud()

func _update_hud() -> void:
	hud_day.text = "Day %d/%d" % [GameState.day, GameState.MAX_DAY]
	hud_bell.text = "Bell: %.0fs" % bell_timer
	hud_shards.text = "Shards: %d" % GameState.soul_shards
	if ghost.carrying != null:
		var g: GearItem = ghost.carrying
		hud_carrying.text = "Carrying: %s [%s]" % [g.display_name, g.state_name()]
		hud_carrying.add_theme_color_override("font_color", g.state_color())
	else:
		hud_carrying.text = "Carrying: -"
		hud_carrying.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))

func _on_shards_changed(new_count: int) -> void:
	hud_shards.text = "Shards: %d" % new_count

func _process(delta: float) -> void:
	if gauntlet_active or minigame_active:
		_update_hud()
		return
	# Bell timer
	bell_timer -= delta
	if bell_timer <= 0:
		bell_timer = 0
		_bell_tolls()
		return
	# Movement
	var move := Vector2.ZERO
	if Input.is_action_pressed("move_left"):  move.x -= 1
	if Input.is_action_pressed("move_right"): move.x += 1
	if Input.is_action_pressed("move_up"):    move.y -= 1
	if Input.is_action_pressed("move_down"):  move.y += 1
	if move != Vector2.ZERO:
		move = move.normalized() * ghost.speed * delta
		ghost.pos += move
		ghost.pos.x = clampf(ghost.pos.x, 8, ROOM_W - 8)
		ghost.pos.y = clampf(ghost.pos.y, HUD_H + 24, ROOM_H - 8)
	# Patience decay
	for a in adventurers:
		a.patience = max(0, a.patience - delta)
	# Find nearest interactive
	_find_nearest_interactive()
	# Interact input (edge-triggered)
	if Input.is_action_just_pressed("interact") and not interact_pressed:
		interact_pressed = true
		_handle_interact()
	if not Input.is_action_pressed("interact"):
		interact_pressed = false
	_update_hud()
	queue_redraw()

func _find_nearest_interactive() -> void:
	near_station_key = ""
	# Check stations
	var best_dist: float = STATION_RADIUS
	for st in STATIONS:
		var d: float = ghost.pos.distance_to(st.pos)
		if d < best_dist:
			best_dist = d
			near_station_key = st.key
	# Check adventurers (closer priority)
	for a in adventurers:
		if ghost.pos.distance_to(a.pos) < ADVENTURER_RADIUS:
			near_station_key = "adventurer_" + str(a.adv.name)
			break
	# Build prompt text
	prompt_label.text = ""
	prompt_label.position = Vector2(0, 0)
	if near_station_key.begins_with("adventurer_"):
		var adv_name := near_station_key.substr(12)
		if ghost.carrying != null:
			prompt_label.text = "[E] Deliver to %s" % adv_name
		else:
			prompt_label.text = "%s is waiting" % adv_name
	elif near_station_key == "salvage":
		if ghost.carrying == null:
			if GameState.salvage_pit.size() > 0:
				prompt_label.text = "[E] Pick up gear (%d in pit)" % GameState.salvage_pit.size()
			else:
				prompt_label.text = "Salvage pit is empty"
		else:
			prompt_label.text = "[E] Drop gear back in pit"
	elif near_station_key == "merc":
		prompt_label.text = "[E] Hire Merc Martyrs (60 shards)"
	elif near_station_key != "":
		# Find station def
		var st_def: Dictionary = _get_station_def(near_station_key)
		if ghost.carrying != null:
			if ghost.carrying.state in st_def.get("states", []):
				prompt_label.text = "[E] Repair at %s" % st_def.name
			else:
				prompt_label.text = "%s — wrong gear state" % st_def.name
		else:
			prompt_label.text = st_def.name
	# Position prompt above ghost
	if prompt_label.text != "":
		prompt_label.position = Vector2(0, ghost.pos.y - 28)

func _get_station_def(key: String) -> Dictionary:
	for st in STATIONS:
		if st.key == key:
			return st
	return {}

func _handle_interact() -> void:
	if near_station_key == "":
		return
	if near_station_key.begins_with("adventurer_"):
		_try_deliver(near_station_key.substr(12))
		return
	match near_station_key:
		"salvage":
			if ghost.carrying == null:
				_pick_up_from_pit()
			else:
				# Drop back into pit
				GameState.add_gear_to_pit(ghost.carrying)
				ghost.carrying = null
		"merc":
			_on_hire_mercs()
		_:
			# Repair station
			if ghost.carrying != null:
				var st_def: Dictionary = _get_station_def(near_station_key)
				if ghost.carrying.state in st_def.get("states", []):
					_start_repair(near_station_key)

func _pick_up_from_pit() -> void:
	if GameState.salvage_pit.is_empty():
		return
	# Pick the first gear that matches an outstanding ticket
	var picked: GearItem = null
	for gear in GameState.salvage_pit:
		for ticket in GameState.pending_deliveries:
			if ticket.fulfilled.values().has(gear.type):
				continue
			if ticket.needs.values().has(gear.type):
				picked = gear
				break
		if picked:
			break
	if picked == null:
		picked = GameState.salvage_pit[0]
	ghost.carrying = picked
	GameState.salvage_pit.erase(picked)
	GameState.salvage_changed.emit()

func _start_repair(station_key: String) -> void:
	if minigame_active:
		return
	current_gear_for_minigame = ghost.carrying
	minigame_active = true
	var script: GDScript = null
	match station_key:
		"polish":    script = preload("res://scripts/repair/polish_bench.gd")
		"oil_grind": script = preload("res://scripts/repair/oil_grindstone.gd")
		"exorcise":  script = preload("res://scripts/repair/exorcise_altar.gd")
		"reforge":   script = preload("res://scripts/repair/reforge_furnace.gd")
		_:
			minigame_active = false
			return
	active_minigame = Node2D.new()
	active_minigame.set_script(script)
	active_minigame.name = "Minigame_" + station_key
	add_child(active_minigame)
	active_minigame.completed.connect(_on_minigame_completed)

func _on_minigame_completed(quality: float) -> void:
	if active_minigame:
		active_minigame.queue_free()
		active_minigame = null
	minigame_active = false
	if current_gear_for_minigame == null:
		return
	# Apply quality threshold
	if quality >= 0.6:
		current_gear_for_minigame.quality = quality
		current_gear_for_minigame.state = GearItem.State.PRISTINE
		current_gear_for_minigame.history.append("Revitalized to Pristine on Day %d (q=%.0f%%)." % [GameState.day, quality * 100])
	elif quality >= 0.3:
		current_gear_for_minigame.quality = quality
		current_gear_for_minigame.state = GearItem.State.PRISTINE
		current_gear_for_minigame.history.append("Hastily revitalized on Day %d (q=%.0f%%)." % [GameState.day, quality * 100])
	else:
		current_gear_for_minigame.history.append("Repair attempt failed on Day %d." % GameState.day)
	GameState.salvage_changed.emit()
	current_gear_for_minigame = null

func _try_deliver(adv_name: String) -> void:
	if ghost.carrying == null:
		return
	# Find adventurer by name
	var a: Dictionary = {}
	for adv in adventurers:
		if str(adv.adv.name) == adv_name:
			a = adv
			break
	if a.is_empty():
		return
	var adv: Dictionary = a.adv
	var gear: GearItem = ghost.carrying
	# Find matching ticket
	var ticket_idx := -1
	for i in GameState.pending_deliveries.size():
		if GameState.pending_deliveries[i].adventurer == adv:
			ticket_idx = i
			break
	if ticket_idx < 0:
		return
	var ticket: Dictionary = GameState.pending_deliveries[ticket_idx]
	# Determine if gear type matches a needed slot
	var matched_slot: String = ""
	for slot in ticket.needs.keys():
		if ticket.fulfilled.has(slot):
			continue
		if ticket.needs[slot] == gear.type:
			matched_slot = slot
			break
	if matched_slot == "":
		# Wrong item — flash, send back
		a.patience = max(0, a.patience - 10)
		# Drop gear back to pit
		GameState.add_gear_to_pit(gear)
		ghost.carrying = null
		return
	# Start delivery gauntlet!
	gauntlet_active = true
	var gauntlet_script := preload("res://scripts/delivery/delivery_gauntlet.gd")
	var gauntlet := Node2D.new()
	gauntlet.set_script(gauntlet_script)
	gauntlet.name = "DeliveryGauntlet"
	add_child(gauntlet)
	gauntlet.start(gear, _on_gauntlet_done.bind(a, ticket_idx, matched_slot, gear))

func _on_gauntlet_done(success: bool, integrity: int, a: Dictionary, ticket_idx: int, matched_slot: String, gear: GearItem) -> void:
	var g := get_node_or_null("DeliveryGauntlet")
	if g:
		g.queue_free()
	gauntlet_active = false
	if success:
		match integrity:
			3:
				pass
			2:
				if gear.state == GearItem.State.PRISTINE:
					gear.state = GearItem.State.BLOODIED
			1:
				if gear.state == GearItem.State.PRISTINE:
					gear.state = GearItem.State.RUSTED
				elif gear.state == GearItem.State.BLOODIED:
					gear.state = GearItem.State.RUSTED
			0:
				gear.state = GearItem.State.SHATTERED
				GameState.add_gear_to_pit(gear)
				ghost.carrying = null
				a.patience = max(0, a.patience - 20)
				return
		var ticket: Dictionary = GameState.pending_deliveries[ticket_idx]
		ticket.fulfilled[matched_slot] = gear
		gear.deliver_to(a.adv)
		ghost.carrying = null
		GameState.run_log.append("Day %d — Delivered %s to %s." % [GameState.day, gear.display_name, a.adv.name])
	else:
		gear.state = GearItem.State.SHATTERED
		GameState.add_gear_to_pit(gear)
		ghost.carrying = null
		a.patience = max(0, a.patience - 30)

func _on_hire_mercs() -> void:
	if GameState.spend_shards(60):
		var types := ["sword", "helm", "staff", "robe"]
		for i in 3:
			var t: String = types[i % types.size()]
			var s: int = GearItem.State.BLOODIED if i % 2 == 0 else GearItem.State.HAUNTED
			GameState.add_gear_to_pit(GearItem.new(t, s, "Martyr's %s" % t.capitalize(), "Left by hired mercs."))
		GameState.run_log.append("Day %d — Hired merc martyrs." % GameState.day)
	else:
		hire_merc_btn.modulate = Color(1, 0.4, 0.4)
		await get_tree().create_timer(0.3).timeout
		hire_merc_btn.modulate = Color.WHITE

func _on_ring_bell() -> void:
	bell_timer = 0
	_bell_tolls()

func _bell_tolls() -> void:
	if bell_rang:
		return
	bell_rang = true
	if ghost.carrying != null:
		if ghost.carrying.state == GearItem.State.PRISTINE:
			ghost.carrying.state = GearItem.State.BLOODIED
		GameState.add_gear_to_pit(ghost.carrying)
		ghost.carrying = null
	GameState.set_phase("battle")

func _draw() -> void:
	# Floor tiles (16x16)
	for y in range(HUD_H + 16, ROOM_H - 16, 16):
		for x in range(0, ROOM_W, 16):
			draw_texture(Sprites.get_sprite("floor"), Vector2(x, y))
	# Top wall (just below HUD)
	for x in range(0, ROOM_W, 16):
		draw_texture(Sprites.get_sprite("wall"), Vector2(x, HUD_H))
	# Bottom wall
	for x in range(0, ROOM_W, 16):
		draw_texture(Sprites.get_sprite("wall"), Vector2(x, ROOM_H - 16))

	# Draw stations (2x scale = 32x32)
	for st in STATIONS:
		var tex := Sprites.get_sprite(st.sprite)
		var p: Vector2 = st.pos
		# Station shadow
		draw_rect(Rect2(p.x - 16, p.y - 14, 32, 32), Color(0, 0, 0, 0.3), true)
		# Station sprite (scaled 2x, centered)
		draw_texture_rect(tex, Rect2(p.x - 16, p.y - 16, 32, 32), false)
		# Highlight if nearby
		if near_station_key == st.key:
			draw_rect(Rect2(p.x - 18, p.y - 18, 36, 36), Color(0.95, 0.95, 0.40, 0.8), false, 1)
		# Station label
		draw_string(ThemeDB.get_default_theme().default_font, Vector2(p.x - 24, p.y + 26), st.name, HORIZONTAL_ALIGNMENT_CENTER, -1, 6, Color(0.75, 0.75, 0.85))
		# Salvage pit: draw gear pile on top
		if st.key == "salvage" and GameState.salvage_pit.size() > 0:
			var pile_count: int = min(GameState.salvage_pit.size(), 4)
			for i in pile_count:
				var gear: GearItem = GameState.salvage_pit[i]
				var gear_tex := Sprites.get_sprite(gear.type)
				var offset := Vector2(-6 + i * 4, -8 - i * 2)
				draw_texture_rect(gear_tex, Rect2(p.x + offset.x, p.y + offset.y, 12, 12), false)
			if GameState.salvage_pit.size() > 4:
				draw_string(ThemeDB.get_default_theme().default_font, Vector2(p.x - 6, p.y - 22), "+%d" % (GameState.salvage_pit.size() - 4), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.85, 0.85, 0.90))

	# Draw adventurers
	for a in adventurers:
		var tex := Sprites.get_sprite(a.sprite)
		var p: Vector2 = a.pos
		# Shadow
		draw_rect(Rect2(p.x - 8, p.y + 6, 16, 4), Color(0, 0, 0, 0.3), true)
		# Sprite (2x scale)
		draw_texture_rect(tex, Rect2(p.x - 16, p.y - 16, 32, 32), false)
		# Highlight if nearby
		if near_station_key == "adventurer_" + str(a.adv.name):
			draw_rect(Rect2(p.x - 18, p.y - 18, 36, 36), Color(0.55, 0.95, 0.55, 0.8), false, 1)
		# Patience bar above
		var pct: float = float(a.patience) / float(a.patience_max)
		var bar_w: float = 24.0
		var bar_x: float = p.x - bar_w / 2.0
		var bar_y: float = p.y - 22
		draw_rect(Rect2(bar_x, bar_y, bar_w, 2), Color(0.20, 0.20, 0.20), true)
		var bar_c: Color = Color(0.55, 0.95, 0.55) if pct > 0.5 else (Color(0.95, 0.85, 0.30) if pct > 0.25 else Color(0.95, 0.40, 0.40))
		draw_rect(Rect2(bar_x, bar_y, bar_w * pct, 2), bar_c, true)
		# Name + ticket
		var ticket_text := ""
		for t in GameState.pending_deliveries:
			if t.adventurer == a.adv:
				var unmet: Array = []
				for k in t.needs.keys():
					if not t.fulfilled.has(k):
						unmet.append(t.needs[k])
				if unmet.is_empty():
					ticket_text = "READY"
				else:
					ticket_text = "wants: " + ", ".join(unmet)
				break
		var name_c: Color = Color(0.55, 0.95, 0.55) if ticket_text == "READY" else Color(0.85, 0.85, 0.90)
		draw_string(ThemeDB.get_default_theme().default_font, Vector2(p.x - 30, p.y + 26), "%s (%s)" % [a.adv.name, a.adv.class], HORIZONTAL_ALIGNMENT_CENTER, -1, 6, name_c)
		draw_string(ThemeDB.get_default_theme().default_font, Vector2(p.x - 30, p.y + 34), ticket_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 5, name_c)

	# Draw ghost (2x scale = 32x32, with bobbing)
	var bob := sin(Time.get_ticks_msec() * 0.004) * 1.5
	var gp: Vector2 = ghost.pos + Vector2(0, bob)
	# Shadow
	draw_rect(Rect2(gp.x - 8, ghost.pos.y + 10, 16, 3), Color(0, 0, 0, 0.25), true)
	# Ghost sprite
	var ghost_tex := Sprites.get_sprite("ghost")
	draw_texture_rect(ghost_tex, Rect2(gp.x - 16, gp.y - 16, 32, 32), false)
	# Carried item above ghost
	if ghost.carrying != null:
		var item_tex := Sprites.get_sprite(ghost.carrying.type)
		var item_pos := gp + Vector2(-8, -26)
		draw_texture_rect(item_tex, Rect2(item_pos.x, item_pos.y, 16, 16), false)
		# State-colored outline
		draw_rect(Rect2(item_pos.x, item_pos.y, 16, 16), ghost.carrying.state_color(), false, 1)

	# Bottom hint text
	var hint := "WASD: move | E: interact | Pick gear from pit, repair at stations, deliver to adventurers"
	draw_string(ThemeDB.get_default_theme().default_font, Vector2(ROOM_W / 2 - 80, ROOM_H - 4), hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 5, Color(0.55, 0.55, 0.65))
