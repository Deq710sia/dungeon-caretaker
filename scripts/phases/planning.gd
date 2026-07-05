extends Node2D
## Phase: planning V4 — DIEGETIC. No menus. Walk to map table, weapon rack, adventurers.
## Everything is physical. Carry weapons to adventurers. Ring bell to begin.

const ROOM_W: int = 320
const ROOM_H: int = 180
const HUD_H: int = 14
const STATION_RADIUS: float = 16.0
const ADVENTURER_RADIUS: float = 14.0

# Station positions (all physical objects in the room)
const MAP_TABLE_POS := Vector2(160, 50)
const WEAPON_RACK_POS := Vector2(40, 50)
const BELL_POS := Vector2(280, 50)
# Adventurers stand in a row at the bottom
const ADVENTURER_Y: float = 130

var ghost: Dictionary = {
	"pos": Vector2(160, 90),
	"speed": 50.0,
	"carrying": null,  # Weapon or null
	"bob": 0.0,
	"squash": 1.0,
}
var adventurers: Array = []
var near_interactive: String = ""  # "map", "rack", "bell", "adv_<name>", ""
var interact_pressed: bool = false
var map_view_active: bool = false
var rack_page: int = 0
var particles: Array = []

# HUD
var hud_stage: Label
var hud_shards: Label
var prompt_label: Label

func _ready() -> void:
	if GameState.party.is_empty():
		GameState.spawn_party()
	_adventurers_arrive()
	_build_hud()

func _adventurers_arrive() -> void:
	adventurers.clear()
	var n := GameState.party.size()
	var spacing: float = 180.0 / float(max(1, n))
	var start_x: float = 70.0 + spacing / 2.0
	for i in n:
		var adv: Dictionary = GameState.party[i]
		adventurers.append({
			"pos": Vector2(start_x + i * spacing, ADVENTURER_Y),
			"sprite": "knight" if adv["class"] == "knight" else "mage",
			"adv": adv,
		})

func _build_hud() -> void:
	var panel := Panel.new()
	panel.position = Vector2(0, 0)
	panel.size = Vector2(ROOM_W, HUD_H)
	add_child(panel)

	hud_stage = Label.new()
	hud_stage.text = "S%d W%d PLANNING" % [GameState.stage, GameState.wave]
	hud_stage.add_theme_font_size_override("font_size", 8)
	hud_stage.add_theme_color_override("font_color", Palette.TEXT_GOLD)
	hud_stage.position = Vector2(2, 2)
	hud_stage.size = Vector2(140, 10)
	panel.add_child(hud_stage)

	hud_shards = Label.new()
	hud_shards.text = "Shards: %d" % GameState.soul_shards
	hud_shards.add_theme_font_size_override("font_size", 8)
	hud_shards.add_theme_color_override("font_color", Palette.TEXT_BLUE)
	hud_shards.position = Vector2(200, 2)
	hud_shards.size = Vector2(116, 10)
	hud_shards.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(hud_shards)

	prompt_label = Label.new()
	prompt_label.text = ""
	prompt_label.add_theme_font_size_override("font_size", 7)
	prompt_label.add_theme_color_override("font_color", Palette.TEXT_GOLD)
	prompt_label.add_theme_color_override("font_outline_color", Palette.VOID)
	prompt_label.add_theme_constant_override("outline_size", 1)
	prompt_label.position = Vector2(0, 0)
	prompt_label.size = Vector2(ROOM_W, 10)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(prompt_label)

func _process(delta: float) -> void:
	if Juice.is_hit_stopped():
		return
	ghost.bob += delta * 6.0
	ghost.squash = lerp(ghost.squash, 1.0, 1.0 - exp(-delta * 8.0))
	# Movement (full WASD)
	var move := Vector2.ZERO
	if not map_view_active:  # can't move while viewing map
		if Input.is_action_pressed("move_left"):  move.x -= 1
		if Input.is_action_pressed("move_right"): move.x += 1
		if Input.is_action_pressed("move_up"):    move.y -= 1
		if Input.is_action_pressed("move_down"):  move.y += 1
	if move != Vector2.ZERO:
		move = move.normalized() * ghost.speed * delta
		ghost.pos += move
		ghost.pos.x = clampf(ghost.pos.x, 12, ROOM_W - 12)
		ghost.pos.y = clampf(ghost.pos.y, HUD_H + 20, ROOM_H - 12)
	_find_nearest_interactive()
	if Input.is_action_just_pressed("interact") and not interact_pressed:
		interact_pressed = true
		_handle_interact()
	if not Input.is_action_pressed("interact"):
		interact_pressed = false
	# Map view controls
	if map_view_active:
		if Input.is_action_just_pressed("interact") and not interact_pressed:
			map_view_active = false
	# Update particles
	Juice.update_particles(delta)
	queue_redraw()

func _find_nearest_interactive() -> void:
	near_interactive = ""
	if map_view_active:
		return
	var best_dist: float = STATION_RADIUS
	# Map table
	if ghost.pos.distance_to(MAP_TABLE_POS) < best_dist:
		best_dist = ghost.pos.distance_to(MAP_TABLE_POS)
		near_interactive = "map"
	# Weapon rack
	if ghost.pos.distance_to(WEAPON_RACK_POS) < best_dist:
		best_dist = ghost.pos.distance_to(WEAPON_RACK_POS)
		near_interactive = "rack"
	# Bell
	if ghost.pos.distance_to(BELL_POS) < best_dist:
		best_dist = ghost.pos.distance_to(BELL_POS)
		near_interactive = "bell"
	# Adventurers
	for a in adventurers:
		if ghost.pos.distance_to(a.pos) < ADVENTURER_RADIUS:
			near_interactive = "adv_" + str(a.adv.name)
			break
	# Build prompt
	prompt_label.position = Vector2(0, 0)
	match near_interactive:
		"map":
			prompt_label.text = "[E] View wave map & intel"
		"rack":
			if ghost.carrying == null:
				prompt_label.text = "[E] Pick up weapon (page %d)" % rack_page
			else:
				prompt_label.text = "[E] Put weapon back"
		"bell":
			prompt_label.text = "[E] RING BELL — begin wave!"
		"":
			if ghost.carrying != null:
				var w: Weapon = ghost.carrying
				prompt_label.text = "Carrying: %s [%s] — take to an adventurer" % [w.display_name, w.wear_name()]
			else:
				prompt_label.text = "Walk to rack (left), map (center), or bell (right)"
		_:
			if near_interactive.begins_with("adv_"):
				var adv_name := near_interactive.substr(4)
				if ghost.carrying != null:
					var w: Weapon = ghost.carrying
					var expected := "sword" if _get_adv(adv_name).class == "knight" else "staff"
					if w.type == expected or w.type in ["helm", "robe"]:
						prompt_label.text = "[E] Give %s to %s" % [w.display_name, adv_name]
					else:
						prompt_label.text = "Wrong weapon type for %s" % adv_name
				else:
					prompt_label.text = "%s (%s) — HP %d/%d" % [adv_name, _get_adv(adv_name).class, _get_adv(adv_name).hp, _get_adv(adv_name).hp_max]
	if prompt_label.text != "":
		prompt_label.position = Vector2(0, ghost.pos.y - 24)

func _get_adv(name: String) -> Dictionary:
	for a in adventurers:
		if str(a.adv.name) == name:
			return a.adv
	return {}

func _handle_interact() -> void:
	if map_view_active:
		map_view_active = false
		return
	match near_interactive:
		"map":
			map_view_active = true
		"rack":
			if ghost.carrying == null:
				_pick_up_from_rack()
			else:
				GameState.add_weapon(ghost.carrying)
				ghost.carrying = null
		"bell":
			_ring_bell()
		_:
			if near_interactive.begins_with("adv_"):
				_assign_weapon(near_interactive.substr(4))

func _pick_up_from_rack() -> void:
	if GameState.arsenal.is_empty():
		return
	# Pick weapon from current page (3 per page)
	var page_start := rack_page * 3
	if page_start >= GameState.arsenal.size():
		rack_page = 0
		page_start = 0
	var w: Weapon = GameState.arsenal[page_start]
	ghost.carrying = w
	GameState.arsenal.erase(w)
	GameState.arsenal_changed.emit()
	Juice.spawn_particles(WEAPON_RACK_POS, 6, Palette.TEXT_GOLD, 25.0, 0.3)

func _assign_weapon(adv_name: String) -> void:
	if ghost.carrying == null:
		return
	var adv := _get_adv(adv_name)
	var w: Weapon = ghost.carrying
	# Determine slot
	var slot: String = "weapon"
	match w.type:
		"helm", "robe": slot = "armor"
		_: slot = "weapon"
	# Check type compatibility
	var expected_weapon := "sword" if adv.class == "knight" else "staff"
	var expected_armor := "helm" if adv.class == "knight" else "robe"
	if slot == "weapon" and w.type != expected_weapon:
		Juice.spawn_particles(ghost.pos, 4, Palette.TEXT_RED, 20.0, 0.3)
		return
	if slot == "armor" and w.type != expected_armor:
		Juice.spawn_particles(ghost.pos, 4, Palette.TEXT_RED, 20.0, 0.3)
		return
	# Remove from previous owner
	if w.wielder != "":
		for other in GameState.party:
			if other.get("name", "") == w.wielder:
				if other.get("equipped_weapon") == w:
					other.equipped_weapon = null
				if other.get("equipped_armor") == w:
					other.equipped_armor = null
	# Assign
	match slot:
		"weapon": adv.equipped_weapon = w
		"armor": adv.equipped_armor = w
	w.wielder = adv.name
	ghost.carrying = null
	# JUICE
	Juice.add_trauma(0.2)
	Juice.hit_stop(0.05)
	Juice.spawn_particles(ghost.pos, 8, Palette.TEXT_GREEN, 30.0, 0.4)
	ghost.squash = 1.2

func _ring_bell() -> void:
	# JUICE: big shake, particles
	Juice.add_trauma(0.5)
	Juice.hit_stop(0.1)
	Juice.spawn_particles(BELL_POS, 12, Palette.TEXT_GOLD, 40.0, 0.6)
	await get_tree().create_timer(0.3).timeout
	GameState.set_phase("salvage")

func _draw() -> void:
	# Floor
	for y in range(HUD_H + 8, ROOM_H - 8, 16):
		for x in range(0, ROOM_W, 16):
			draw_texture(Sprites.get_sprite("floor"), Vector2(x, y))
	# Walls
	for x in range(0, ROOM_W, 16):
		draw_texture(Sprites.get_sprite("wall"), Vector2(x, HUD_H))
		draw_texture(Sprites.get_sprite("wall"), Vector2(x, ROOM_H - 8))
	# Map table
	draw_texture(Sprites.get_sprite("map_table"), MAP_TABLE_POS - Vector2(8, 8))
	if near_interactive == "map":
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		draw_rect(Rect2(MAP_TABLE_POS.x - 12, MAP_TABLE_POS.y - 12, 24, 24), Color(0.95, 0.85, 0.40, pulse), false, 1)
	GameFont.draw_string_centered(self, MAP_TABLE_POS + Vector2(0, 22), "MAP", 6, Palette.TEXT)
	# Weapon rack
	draw_texture(Sprites.get_sprite("weapon_rack"), WEAPON_RACK_POS - Vector2(8, 8))
	if near_interactive == "rack":
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		draw_rect(Rect2(WEAPON_RACK_POS.x - 12, WEAPON_RACK_POS.y - 12, 24, 24), Color(0.95, 0.85, 0.40, pulse), false, 1)
	# Show 3 weapons on rack (page)
	var page_start := rack_page * 3
	for i in min(3, GameState.arsenal.size() - page_start):
		var w: Weapon = GameState.arsenal[page_start + i]
		var wp := WEAPON_RACK_POS + Vector2(-8 + i * 8, -12)
		draw_texture(Sprites.get_weapon_sprite(w.type, w.state), wp)
	GameFont.draw_string_centered(self, WEAPON_RACK_POS + Vector2(0, 22), "RACK", 6, Palette.TEXT)
	# Bell
	draw_texture(Sprites.get_sprite("bell"), BELL_POS - Vector2(8, 8))
	if near_interactive == "bell":
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		draw_rect(Rect2(BELL_POS.x - 12, BELL_POS.y - 12, 24, 24), Color(0.95, 0.85, 0.40, pulse), false, 1)
	GameFont.draw_string_centered(self, BELL_POS + Vector2(0, 22), "BELL", 6, Palette.TEXT)
	# Adventurers
	for a in adventurers:
		var tex := Sprites.get_sprite(a.sprite)
		# Shadow
		draw_rect(Rect2(int(a.pos.x) - 5, int(a.pos.y) + 6, 10, 2), Color(0, 0, 0, 0.3), true)
		draw_texture(tex, a.pos - Vector2(8, 8))
		if near_interactive == "adv_" + str(a.adv.name):
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
			draw_rect(Rect2(a.pos.x - 12, a.pos.y - 12, 24, 24), Color(0.55, 0.95, 0.55, pulse), false, 1)
		# Name
		GameFont.draw_string_centered(self, a.pos + Vector2(0, -14), a.adv.name, 6, Palette.TEXT)
		# Equipped weapon indicator
		var adv: Dictionary = a.adv
		if adv.get("equipped_weapon") != null:
			var w: Weapon = adv.equipped_weapon
			draw_texture(Sprites.get_weapon_sprite(w.type, w.state), a.pos + Vector2(8, -4))
		if adv.get("equipped_armor") != null:
			var ar: Weapon = adv.equipped_armor
			draw_texture(Sprites.get_weapon_sprite(ar.type, ar.state), a.pos + Vector2(-12, -4))
	# Ghost (with squash/stretch)
	var bob := sin(ghost.bob) * 1.5
	var gp: Vector2 = ghost.pos + Vector2(0, bob)
	draw_rect(Rect2(int(gp.x) - 5, int(ghost.pos.y) + 6, 10, 2), Color(0, 0, 0, 0.3), true)
	var ghost_tex := Sprites.get_sprite("ghost")
	var sw := int(16 / ghost.squash)
	var sh := int(16 * ghost.squash)
	draw_texture_rect(ghost_tex, Rect2(int(gp.x) - sw / 2, int(gp.y) - sh / 2, sw, sh), false)
	# Carried weapon
	if ghost.carrying != null:
		var item_tex := Sprites.get_weapon_sprite(ghost.carrying.type, ghost.carrying.state)
		draw_texture(item_tex, gp + Vector2(-8, -18))
	# Particles
	Juice.draw_particles(self)
	# Map view overlay
	if map_view_active:
		_draw_map_view()
	# Bottom hint
	GameFont.draw_string_centered(self, Vector2(ROOM_W / 2, ROOM_H - 2), "WASD: move | E: interact", 6, Palette.TEXT_DIM)

func _draw_map_view() -> void:
	# Dim background
	draw_rect(Rect2(0, 0, ROOM_W, ROOM_H), Color(0, 0, 0, 0.8), true)
	# Title
	GameFont.draw_string_centered(self, Vector2(ROOM_W / 2, 20), "WAVE MAP & INTEL", 8, Palette.TEXT_GOLD)
	# Wave path
	var path_y: float = 50
	var path_x: float = 40
	var node_spacing: float = 80
	for i in 3:
		var wave_num := GameState.wave + i
		if wave_num > GameState.WAVES_PER_STAGE:
			GameFont.draw_string_centered(self, Vector2(ROOM_W / 2, path_y + i * 20), "STAGE BOSS", 8, Palette.TEXT_RED)
			break
		var is_boss := (wave_num == GameState.WAVES_PER_STAGE)
		var label := "WAVE %d" % wave_num
		var color := Palette.TEXT_RED if is_boss else Palette.TEXT_GREEN
		if i == 0:
			color = Palette.TEXT_GOLD
		GameFont.draw_string_centered(self, Vector2(path_x + i * node_spacing, path_y), label, 7, color)
		if i < 2:
			GameFont.draw_string(self, Vector2(path_x + i * node_spacing + 30, path_y), "->", 7, Palette.TEXT_DIM)
	# Intel
	var intel_y: float = 90
	var enemy_count := GameState.get_enemy_count()
	var enemy_hp := GameState.get_enemy_hp()
	GameFont.draw_string(self, Vector2(20, intel_y), "ENEMIES: %d" % enemy_count, 7, Palette.TEXT_RED)
	GameFont.draw_string(self, Vector2(20, intel_y + 12), "HP: ~%d each" % enemy_hp, 7, Palette.TEXT)
	GameFont.draw_string(self, Vector2(20, intel_y + 24), "ATK: ~%d each" % GameState.get_enemy_atk(), 7, Palette.TEXT)
	# Enemy types
	var types := []
	if GameState.stage >= 1: types.append("Slime")
	if GameState.stage >= 2: types.append("Skeleton")
	if GameState.stage >= 3: types.append("Bat")
	GameFont.draw_string(self, Vector2(160, intel_y), "TYPES:", 7, Palette.TEXT_BLUE)
	GameFont.draw_string(self, Vector2(160, intel_y + 12), ", ".join(types), 7, Palette.TEXT)
	# Arsenal count
	GameFont.draw_string(self, Vector2(160, intel_y + 24), "ARSENAL: %d weapons" % GameState.arsenal.size(), 7, Palette.TEXT)
	# Close hint
	GameFont.draw_string_centered(self, Vector2(ROOM_W / 2, ROOM_H - 14), "[E] Close map", 7, Palette.TEXT_GOLD)
