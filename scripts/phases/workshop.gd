extends Node2D
## Phase: workshop (V2)
## Top-down room. Ghost walks between stations to repair gear.
## Repair minigames show the WEAPON as the centerpiece (large, visible).
## Bell timer counts down; ringing it triggers the battle phase.
## Also shows "next battle intel" — enemy types/count for the upcoming wave.

const ROOM_W: int = 320
const ROOM_H: int = 180
const HUD_H: int = 22
const STATION_RADIUS: float = 22.0
const ADVENTURER_RADIUS: float = 18.0

const STATIONS := [
	{"key": "salvage",  "name": "Salvage Pit",        "sprite": "pit",        "pos": Vector2(40, 70)},
	{"key": "polish",   "name": "Polish Bench",       "sprite": "bench",      "pos": Vector2(100, 70),  "states": [GearItem.State.BLOODIED]},
	{"key": "oil_grind","name": "Oil & Grindstone",   "sprite": "grindstone", "pos": Vector2(160, 70),  "states": [GearItem.State.RUSTED]},
	{"key": "exorcise", "name": "Exorcise Altar",     "sprite": "altar",      "pos": Vector2(220, 70),  "states": [GearItem.State.HAUNTED, GearItem.State.CURSED]},
	{"key": "reforge",  "name": "Reforge Furnace",    "sprite": "furnace",    "pos": Vector2(280, 70),  "states": [GearItem.State.SHATTERED]},
]

var ghost: Dictionary = {
	"pos": Vector2(160, 130),
	"speed": 65.0,
	"carrying": null,
	"bob": 0.0,
}
var adventurers: Array = []
var bell_timer: float = 75.0
var bell_rang: bool = false
var minigame_active: bool = false
var gauntlet_active: bool = false
var active_minigame: Node2D = null
var current_gear_for_minigame: GearItem = null
var near_station_key: String = ""
var interact_pressed: bool = false
var particles: Array = []

# HUD
var hud_stage: Label
var hud_bell: Label
var hud_shards: Label
var hud_carrying: Label
var hud_intel: Label
var prompt_label: Label
var ring_bell_btn: Button

func _ready() -> void:
	if GameState.party.is_empty():
		GameState.spawn_party()
	_adventurers_arrive()
	_build_hud()
	bell_timer = max(50.0, 90.0 - GameState.stage * 5)

func _adventurers_arrive() -> void:
	adventurers.clear()
	var n := GameState.party.size()
	var spacing: float = 200.0 / float(max(1, n))
	var start_x: float = 60.0 + spacing / 2.0
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
	var panel := Panel.new()
	panel.position = Vector2(0, 0)
	panel.size = Vector2(ROOM_W, HUD_H)
	add_child(panel)

	hud_stage = Label.new()
	hud_stage.text = "Stage %d Wave %d/%d" % [GameState.stage, GameState.wave, GameState.WAVES_PER_STAGE]
	hud_stage.add_theme_font_size_override("font_size", 8)
	hud_stage.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	hud_stage.position = Vector2(3, 3)
	hud_stage.size = Vector2(110, 14)
	panel.add_child(hud_stage)

	hud_bell = Label.new()
	hud_bell.text = "Bell: 75s"
	hud_bell.add_theme_font_size_override("font_size", 8)
	hud_bell.add_theme_color_override("font_color", Color(0.95, 0.55, 0.40))
	hud_bell.position = Vector2(115, 3)
	hud_bell.size = Vector2(60, 14)
	panel.add_child(hud_bell)

	hud_shards = Label.new()
	hud_shards.text = "Shards: 0"
	hud_shards.add_theme_font_size_override("font_size", 8)
	hud_shards.add_theme_color_override("font_color", Color(0.65, 0.85, 0.95))
	hud_shards.position = Vector2(178, 3)
	hud_shards.size = Vector2(70, 14)
	panel.add_child(hud_shards)

	hud_carrying = Label.new()
	hud_carrying.text = "Carrying: -"
	hud_carrying.add_theme_font_size_override("font_size", 7)
	hud_carrying.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
	hud_carrying.position = Vector2(250, 3)
	hud_carrying.size = Vector2(70, 14)
	panel.add_child(hud_carrying)

	# Next battle intel (right side)
	hud_intel = Label.new()
	var enemy_count := GameState.get_enemy_count()
	hud_intel.text = "Next: %d enemies" % enemy_count
	hud_intel.add_theme_font_size_override("font_size", 7)
	hud_intel.add_theme_color_override("font_color", Color(0.85, 0.55, 0.55))
	hud_intel.position = Vector2(ROOM_W - 100, 24)
	hud_intel.size = Vector2(100, 12)
	hud_intel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(hud_intel)

	# Prompt
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

	# Ring bell button
	ring_bell_btn = Button.new()
	ring_bell_btn.text = "Ring Bell"
	ring_bell_btn.add_theme_font_size_override("font_size", 7)
	ring_bell_btn.position = Vector2(ROOM_W - 70, 158)
	ring_bell_btn.size = Vector2(60, 16)
	ring_bell_btn.pressed.connect(_on_ring_bell)
	add_child(ring_bell_btn)

	GameState.shards_changed.connect(_on_shards_changed)
	_update_hud()

func _update_hud() -> void:
	hud_stage.text = "Stage %d Wave %d/%d" % [GameState.stage, GameState.wave, GameState.WAVES_PER_STAGE]
	hud_bell.text = "Bell: %.0fs" % bell_timer
	hud_shards.text = "Shards: %d" % GameState.soul_shards
	if ghost.carrying != null:
		var g: GearItem = ghost.carrying
		hud_carrying.text = "Carry: %s" % g.display_name
		hud_carrying.add_theme_color_override("font_color", g.state_color())
	else:
		hud_carrying.text = "Carrying: -"
		hud_carrying.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))

func _on_shards_changed(new_count: int) -> void:
	hud_shards.text = "Shards: %d" % new_count

func _process(delta: float) -> void:
	if minigame_active or gauntlet_active:
		ghost.bob += delta * 6
		_update_hud()
		return
	bell_timer -= delta
	if bell_timer <= 0:
		bell_timer = 0
		_bell_tolls()
		return
	ghost.bob += delta * 6
	# Movement
	var move := Vector2.ZERO
	if Input.is_action_pressed("move_left"):  move.x -= 1
	if Input.is_action_pressed("move_right"): move.x += 1
	if Input.is_action_pressed("move_up"):    move.y -= 1
	if Input.is_action_pressed("move_down"):  move.y += 1
	if move != Vector2.ZERO:
		move = move.normalized() * ghost.speed * delta
		ghost.pos += move
		ghost.pos.x = clampf(ghost.pos.x, 16, ROOM_W - 16)
		ghost.pos.y = clampf(ghost.pos.y, HUD_H + 30, ROOM_H - 24)
	# Patience decay
	for a in adventurers:
		a.patience = max(0, a.patience - delta)
	_find_nearest_interactive()
	if Input.is_action_just_pressed("interact") and not interact_pressed:
		interact_pressed = true
		_handle_interact()
	if not Input.is_action_pressed("interact"):
		interact_pressed = false
	# Update particles
	for p in particles:
		p.pos += p.vel * delta
		p.life -= delta
	particles = particles.filter(func(p): return p.life > 0)
	_update_hud()
	queue_redraw()

func _find_nearest_interactive() -> void:
	near_station_key = ""
	var best_dist: float = STATION_RADIUS
	for st in STATIONS:
		var d: float = ghost.pos.distance_to(st.pos)
		if d < best_dist:
			best_dist = d
			near_station_key = st.key
	for a in adventurers:
		if ghost.pos.distance_to(a.pos) < ADVENTURER_RADIUS:
			near_station_key = "adventurer_" + str(a.adv.name)
			break
	prompt_label.text = ""
	prompt_label.position = Vector2(0, 0)
	if near_station_key.begins_with("adventurer_"):
		var adv_name := near_station_key.substr(12)
		if ghost.carrying != null:
			prompt_label.text = "[E] Deliver to %s" % adv_name
		else:
			prompt_label.text = "%s waits" % adv_name
	elif near_station_key == "salvage":
		if ghost.carrying == null:
			if GameState.salvage_pit.size() > 0:
				prompt_label.text = "[E] Pick up gear (%d in pit)" % GameState.salvage_pit.size()
			else:
				prompt_label.text = "Salvage pit empty"
		else:
			prompt_label.text = "[E] Drop gear in pit"
	elif near_station_key != "":
		var st_def: Dictionary = _get_station_def(near_station_key)
		if ghost.carrying != null:
			if ghost.carrying.state in st_def.get("states", []):
				prompt_label.text = "[E] Repair at %s" % st_def.name
			else:
				prompt_label.text = "%s — wrong state" % st_def.name
		else:
			prompt_label.text = st_def.name
	if prompt_label.text != "":
		prompt_label.position = Vector2(0, ghost.pos.y - 30)

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
				GameState.add_gear_to_pit(ghost.carrying)
				ghost.carrying = null
		_:
			if ghost.carrying != null:
				var st_def: Dictionary = _get_station_def(near_station_key)
				if ghost.carrying.state in st_def.get("states", []):
					_start_repair(near_station_key)

func _pick_up_from_pit() -> void:
	if GameState.salvage_pit.is_empty():
		return
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
	# Master polisher bonus
	var bonus: float = float(GameState.meta_upgrades["master_polisher"]) * 0.10
	quality = clampf(quality + bonus, 0.0, 1.0)
	if quality >= 0.6:
		current_gear_for_minigame.quality = quality
		current_gear_for_minigame.state = GearItem.State.PRISTINE
		current_gear_for_minigame.history.append("Revitalized (q=%.0f%%)." % (quality * 100))
		# Repair also restores durability
		current_gear_for_minigame.durability = current_gear_for_minigame.durability_max
		# Spark particles
		for i in 8:
			particles.append({
				"pos": ghost.pos,
				"vel": Vector2(randf_range(-40, 40), randf_range(-40, 40)),
				"color": Color(0.95, 0.95, 0.40),
				"life": 0.6,
				"max_life": 0.6,
			})
	elif quality >= 0.3:
		current_gear_for_minigame.quality = quality
		current_gear_for_minigame.state = GearItem.State.PRISTINE
		current_gear_for_minigame.history.append("Hastily revitalized (q=%.0f%%)." % (quality * 100))
		current_gear_for_minigame.durability = int(current_gear_for_minigame.durability_max * 0.7)
	else:
		current_gear_for_minigame.history.append("Repair attempt failed.")
	GameState.salvage_changed.emit()
	current_gear_for_minigame = null

func _try_deliver(adv_name: String) -> void:
	if ghost.carrying == null:
		return
	var a: Dictionary = {}
	for adv in adventurers:
		if str(adv.adv.name) == adv_name:
			a = adv
			break
	if a.is_empty():
		return
	var adv: Dictionary = a.adv
	var gear: GearItem = ghost.carrying
	var ticket_idx := -1
	for i in GameState.pending_deliveries.size():
		if GameState.pending_deliveries[i].adventurer == adv:
			ticket_idx = i
			break
	if ticket_idx < 0:
		return
	var ticket: Dictionary = GameState.pending_deliveries[ticket_idx]
	var matched_slot: String = ""
	for slot in ticket.needs.keys():
		if ticket.fulfilled.has(slot):
			continue
		if ticket.needs[slot] == gear.type:
			matched_slot = slot
			break
	if matched_slot == "":
		a.patience = max(0, a.patience - 10)
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
			3: pass
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
		GameState.run_log.append("Delivered %s to %s." % [gear.display_name, a.adv.name])
	else:
		gear.state = GearItem.State.SHATTERED
		GameState.add_gear_to_pit(gear)
		ghost.carrying = null
		a.patience = max(0, a.patience - 30)

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
	# Floor
	for y in range(HUD_H + 10, ROOM_H - 16, 32):
		for x in range(0, ROOM_W, 32):
			draw_texture(Sprites.get_sprite("floor"), Vector2(x, y))
	# Walls
	for x in range(0, ROOM_W, 32):
		draw_texture(Sprites.get_sprite("wall"), Vector2(x, HUD_H))
		draw_texture(Sprites.get_sprite("wall"), Vector2(x, ROOM_H - 16))
	# Stations
	for st in STATIONS:
		var tex := Sprites.get_sprite(st.sprite)
		var p: Vector2 = st.pos
		# Shadow
		draw_rect(Rect2(p.x - 18, p.y - 14, 36, 36), Color(0, 0, 0, 0.3), true)
		# Station sprite (32x32)
		draw_texture_rect(tex, Rect2(p.x - 16, p.y - 16, 32, 32), false)
		# Highlight
		if near_station_key == st.key:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
			draw_rect(Rect2(p.x - 20, p.y - 20, 40, 40), Color(0.95, 0.95, 0.40, pulse), false, 1)
		# Label
		draw_string(ThemeDB.get_default_theme().default_font, Vector2(p.x - 28, p.y + 28), st.name, HORIZONTAL_ALIGNMENT_CENTER, -1, 7, Color(0.75, 0.75, 0.85))
		# Salvage pit gear pile
		if st.key == "salvage" and GameState.salvage_pit.size() > 0:
			var pile_count: int = min(GameState.salvage_pit.size(), 3)
			for i in pile_count:
				var gear: GearItem = GameState.salvage_pit[i]
				var gear_tex := Sprites.get_weapon_sprite(gear.type, gear.state)
				var offset := Vector2(-12 + i * 12, -28 - i * 4)
				draw_texture_rect(gear_tex, Rect2(p.x + offset.x, p.y + offset.y, 16, 16), false)
			if GameState.salvage_pit.size() > 3:
				draw_string(ThemeDB.get_default_theme().default_font, Vector2(p.x - 8, p.y - 38), "+%d" % (GameState.salvage_pit.size() - 3), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.85, 0.85, 0.90))
	# Adventurers
	for a in adventurers:
		var tex := Sprites.get_sprite(a.sprite)
		var p: Vector2 = a.pos
		draw_rect(Rect2(p.x - 8, p.y + 12, 16, 4), Color(0, 0, 0, 0.3), true)
		draw_texture_rect(tex, Rect2(p.x - 16, p.y - 16, 32, 32), false)
		if near_station_key == "adventurer_" + str(a.adv.name):
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
			draw_rect(Rect2(p.x - 20, p.y - 20, 40, 40), Color(0.55, 0.95, 0.55, pulse), false, 1)
		# Patience bar
		var pct: float = float(a.patience) / float(a.patience_max)
		var bar_w: float = 28.0
		var bar_x: float = p.x - bar_w / 2.0
		var bar_y: float = p.y - 22
		draw_rect(Rect2(bar_x, bar_y, bar_w, 3), Color(0.20, 0.20, 0.20), true)
		var bar_c: Color = Color(0.55, 0.95, 0.55) if pct > 0.5 else (Color(0.95, 0.85, 0.30) if pct > 0.25 else Color(0.95, 0.40, 0.40))
		draw_rect(Rect2(bar_x, bar_y, bar_w * pct, 3), bar_c, true)
		# Ticket text
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
					ticket_text = "needs: " + ", ".join(unmet)
				break
		var name_c: Color = Color(0.55, 0.95, 0.55) if ticket_text == "READY" else Color(0.85, 0.85, 0.90)
		draw_string(ThemeDB.get_default_theme().default_font, Vector2(p.x - 36, p.y + 28), "%s (%s)" % [a.adv.name, a.adv.class], HORIZONTAL_ALIGNMENT_CENTER, -1, 7, name_c)
		draw_string(ThemeDB.get_default_theme().default_font, Vector2(p.x - 36, p.y + 38), ticket_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 6, name_c)
	# Ghost
	var bob := sin(ghost.bob) * 1.5
	var gp: Vector2 = ghost.pos + Vector2(0, bob)
	draw_rect(Rect2(gp.x - 8, ghost.pos.y + 12, 16, 3), Color(0, 0, 0, 0.25), true)
	var ghost_tex := Sprites.get_sprite("ghost")
	draw_texture_rect(ghost_tex, Rect2(gp.x - 16, gp.y - 16, 32, 32), false)
	# Carried gear
	if ghost.carrying != null:
		var item_tex := Sprites.get_weapon_sprite(ghost.carrying.type, ghost.carrying.state)
		var item_pos := gp + Vector2(-12, -32)
		draw_texture_rect(item_tex, Rect2(item_pos.x, item_pos.y, 24, 24), false)
		draw_rect(Rect2(item_pos.x, item_pos.y, 24, 24), ghost.carrying.state_color(), false, 1)
	# Particles
	for p in particles:
		var alpha: float = p.life / p.max_life
		var c: Color = p.color
		c.a = alpha
		draw_circle(p.pos, 3 * alpha, c)
	# Bottom hint
	draw_string(ThemeDB.get_default_theme().default_font, Vector2(ROOM_W / 2 - 100, ROOM_H - 4), "WASD: move | E: interact | Repair gear, deliver to adventurers", HORIZONTAL_ALIGNMENT_CENTER, -1, 6, Color(0.55, 0.55, 0.65))
