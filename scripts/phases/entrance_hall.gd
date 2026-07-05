extends Node2D
## Phase: entrance_hall — top-down room where the ghost player runs gear
## from the workshop output (left) to waiting adventurers (right).
## Triggering delivery spawns a DeliveryGauntlet overlay (Dumb Ways to Die style).

const TILE_SIZE: int = 16
const GRID_W: int = 20
const GRID_H: int = 12

var ghost: Dictionary = {
	"pos": Vector2(60, 90),
	"speed": 80.0,
	"carrying": null,  # GearItem or null
}
var adventurers: Array = []  # Array[Dictionary] {pos, ticket, adv, sprite, patience, patience_max}
var pickup_pos: Vector2 = Vector2(40, 90)  # workshop output

var bell_timer: float = 90.0  # seconds before bell tolls
var bell_rang: bool = false
var gauntlet_active: bool = false

var hud_shards: Label
var hud_timer: Label
var hud_ticket: Label

func _ready() -> void:
	# Initialize adventurers from GameState.party
	_adventurers_arrive()
	# UI
	_build_hud()
	# Bell timer (scales down with day)
	bell_timer = max(45.0, 120.0 - GameState.day * 2.5)

func _adventurers_arrive() -> void:
	adventurers.clear()
	if GameState.party.is_empty():
		GameState.spawn_party()
	var base_x := 200
	for i in GameState.party.size():
		var adv: Dictionary = GameState.party[i]
		var a := {
			"pos": Vector2(base_x + i * 40, 90),
			"sprite": "knight" if adv["class"] == "knight" else "mage",
			"adv": adv,
			"patience": 60.0 + GameState.meta_upgrades["patient_adventurers"] * 12.0,
			"patience_max": 60.0 + GameState.meta_upgrades["patient_adventurers"] * 12.0,
		}
		adventurers.append(a)

func _build_hud() -> void:
	var panel := Panel.new()
	panel.position = Vector2(0, 0)
	panel.size = Vector2(640, 16)
	add_child(panel)

	hud_timer = Label.new()
	hud_timer.text = "Bell: %.0fs" % bell_timer
	hud_timer.add_theme_font_size_override("font_size", 10)
	hud_timer.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	hud_timer.position = Vector2(4, 2)
	hud_timer.size = Vector2(80, 12)
	panel.add_child(hud_timer)

	hud_shards = Label.new()
	hud_shards.text = "Shards: %d" % GameState.soul_shards
	hud_shards.add_theme_font_size_override("font_size", 10)
	hud_shards.add_theme_color_override("font_color", Color(0.65, 0.85, 0.95))
	hud_shards.position = Vector2(90, 2)
	hud_shards.size = Vector2(80, 12)
	panel.add_child(hud_shards)

	hud_ticket = Label.new()
	hud_ticket.text = "Pick up gear at LEFT, deliver to adventurer on RIGHT"
	hud_ticket.add_theme_font_size_override("font_size", 9)
	hud_ticket.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	hud_ticket.position = Vector2(180, 2)
	hud_ticket.size = Vector2(460, 12)
	panel.add_child(hud_ticket)

func _process(delta: float) -> void:
	if gauntlet_active:
		return
	# Bell timer
	bell_timer -= delta
	if bell_timer <= 0:
		bell_timer = 0
		_bell_tolls()
		return
	hud_timer.text = "Bell: %.0fs" % bell_timer
	# Movement
	var move := Vector2.ZERO
	if Input.is_action_pressed("move_left"):  move.x -= 1
	if Input.is_action_pressed("move_right"): move.x += 1
	if Input.is_action_pressed("move_up"):	  move.y -= 1
	if Input.is_action_pressed("move_down"):  move.y += 1
	if move != Vector2.ZERO:
		move = move.normalized() * ghost.speed * delta
		ghost.pos += move
		ghost.pos.x = clampf(ghost.pos.x, 16, 320 - 16)
		ghost.pos.y = clampf(ghost.pos.y, 32, 180 - 16)
	# Patience decay
	for a in adventurers:
		a.patience -= delta
		if a.patience < 0:
			a.patience = 0
	# Check pickup
	if ghost.carrying == null and ghost.pos.distance_to(pickup_pos) < 16:
		# Pick up the first available gear from salvage pit
		if not GameState.salvage_pit.is_empty():
			# Pick the next piece that matches an outstanding ticket
			var picked: GearItem = null
			for gear in GameState.salvage_pit:
				# Find a ticket that wants this type
				for ticket in GameState.pending_deliveries:
					if ticket.fulfilled.has(gear.type):
						continue
					if ticket.needs.values().has(gear.type):
						picked = gear
						break
				if picked:
					break
			if picked == null:
				# No matching ticket — pick any
				picked = GameState.salvage_pit[0]
			ghost.carrying = picked
			GameState.salvage_pit.erase(picked)
			GameState.salvage_changed.emit()
	# Check delivery to adventurer
	if ghost.carrying != null:
		for a in adventurers:
			if ghost.pos.distance_to(a.pos) < 20:
				_try_deliver(a)
				break
	queue_redraw()

func _try_deliver(a: Dictionary) -> void:
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
		# Wrong item — flash adventurer, send item back
		a.patience = max(0, a.patience - 10)
		ghost.carrying = null
		GameState.salvage_pit.push_back(gear)
		GameState.salvage_changed.emit()
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
	# Remove gauntlet
	var g := get_node_or_null("DeliveryGauntlet")
	if g:
		g.queue_free()
	gauntlet_active = false
	if success:
		# Apply integrity damage to gear state (3 pips = no damage; lose 1 = drop one tier, etc.)
		match integrity:
			3:
				pass  # pristine
			2:
				if gear.state == GearItem.State.PRISTINE:
					gear.state = GearItem.State.BLOODIED
			1:
				if gear.state == GearItem.State.PRISTINE:
					gear.state = GearItem.State.RUSTED
				elif gear.state == GearItem.State.BLOODIED:
					gear.state = GearItem.State.RUSTED
			0:
				# Catastrophic — item drops back to pit shattered, adventurer mad
				gear.state = GearItem.State.SHATTERED
				GameState.add_gear_to_pit(gear)
				ghost.carrying = null
				a.patience = max(0, a.patience - 20)
				return
		# Mark ticket fulfilled
		var ticket: Dictionary = GameState.pending_deliveries[ticket_idx]
		ticket.fulfilled[matched_slot] = gear
		gear.deliver_to(a.adv)
		ghost.carrying = null
		GameState.run_log.append("Day %d — Delivered %s to %s." % [GameState.day, gear.display_name, a.adv.name])
	else:
		# Gauntlet failed catastrophically
		gear.state = GearItem.State.SHATTERED
		GameState.add_gear_to_pit(gear)
		ghost.carrying = null
		a.patience = max(0, a.patience - 30)

func _bell_tolls() -> void:
	if bell_rang:
		return
	bell_rang = true
	# Force the ghost to drop any carried gear back into the pit
	if ghost.carrying != null:
		ghost.carrying.state = GearItem.State.BLOODIED if ghost.carrying.state == GearItem.State.PRISTINE else ghost.carrying.state
		GameState.add_gear_to_pit(ghost.carrying)
		ghost.carrying = null
	# Move to battle phase
	GameState.set_phase("battle")

func _draw() -> void:
	# Draw floor tiles
	for y in GRID_H:
		for x in GRID_W:
			var p := Vector2(x * TILE_SIZE, y * TILE_SIZE + 16)  # offset for HUD
			draw_texture(Sprites.get_sprite("floor"), p)
	# Top wall
	for x in GRID_W:
		draw_texture(Sprites.get_sprite("wall"), Vector2(x * TILE_SIZE, 16))
	# Pickup station marker
	draw_rect(Rect2(pickup_pos - Vector2(12, 12), Vector2(24, 24)), Color(0.30, 0.40, 0.55, 0.5), true)
	draw_rect(Rect2(pickup_pos - Vector2(12, 12), Vector2(24, 24)), Color(0.55, 0.75, 0.95), false, 1)
	draw_string(ThemeDB.get_default_theme().default_font, pickup_pos + Vector2(-20, -18), "WORKSHOP", HORIZONTAL_ALIGNMENT_CENTER, -1, 7, Color(0.75, 0.85, 0.95))
	# Adventurers
	for a in adventurers:
		var tex := Sprites.get_sprite(a.sprite)
		draw_texture(tex, a.pos - Vector2(8, 8))
		# Patience bar above
		var pct: float = float(a.patience) / float(a.patience_max)
		var bar_w := 16
		var bar_x: float = a.pos.x - bar_w / 2
		var bar_y: float = a.pos.y - 16
		draw_rect(Rect2(bar_x, bar_y, bar_w, 2), Color(0.20, 0.20, 0.20), true)
		var c: Color = Color(0.55, 0.95, 0.55) if pct > 0.5 else (Color(0.95, 0.85, 0.30) if pct > 0.25 else Color(0.95, 0.40, 0.40))
		draw_rect(Rect2(bar_x, bar_y, bar_w * pct, 2), c, true)
		# Adventurer name + ticket
		var ticket_text := ""
		for t in GameState.pending_deliveries:
			if t.adventurer == a.adv:
				var needs_keys: Array = t.needs.keys()
				var unmet := []
				for k in needs_keys:
					if not t.fulfilled.has(k):
						unmet.append(t.needs[k])
				ticket_text = ", ".join(unmet)
				break
		draw_string(ThemeDB.get_default_theme().default_font, a.pos + Vector2(-16, 22), "%s wants: %s" % [a.adv.name, ticket_text], HORIZONTAL_ALIGNMENT_CENTER, -1, 6, Color(0.85, 0.85, 0.90))
	# Ghost
	var ghost_tex := Sprites.get_sprite("ghost")
	draw_texture(ghost_tex, ghost.pos - Vector2(8, 8))
	# Carried item above ghost
	if ghost.carrying != null:
		var item_tex := Sprites.get_sprite(ghost.carrying.type)
		draw_texture(item_tex, ghost.pos + Vector2(-8, -20))
		draw_rect(Rect2(ghost.pos + Vector2(-8, -20), Vector2(16, 16)), ghost.carrying.state_color(), false, 1)

	# Bottom hint
	if ghost.carrying == null:
		draw_string(ThemeDB.get_default_theme().default_font, Vector2(60, 178), "Walk to the WORKSHOP box (left) to pick up gear.", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.75, 0.75, 0.85))
	else:
		draw_string(ThemeDB.get_default_theme().default_font, Vector2(60, 178), "Carrying %s [%s] — find the matching adventurer!" % [ghost.carrying.display_name, ghost.carrying.state_name()], HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.85, 0.95, 0.85))
