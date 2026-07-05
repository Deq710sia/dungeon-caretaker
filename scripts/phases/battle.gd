extends Node2D
## Phase: battle (V2)
## Top-down scroller. Camera follows the party as they walk through the dungeon.
## Enemies spawn in waves. Party auto-fights. Ghost support ability (key 1).
## Party must reach the exit to clear the wave.

const TILE: int = 32
const CORRIDOR_W: int = 7
const CORRIDOR_H: int = 40
const VIEW_W: int = 320
const VIEW_H: int = 180

var party_units: Array = []
var enemies: Array = []
var camera_y: float = 0.0
var cam: Camera2D
var battle_over: bool = false
var battle_won: bool = false
var elapsed: float = 0.0
var ghost_ability_cd: float = 0.0
var ghost_ability_active: float = 0.0
var damage_numbers: Array = []
var particles: Array = []
var continue_btn: Button
var log_label: Label
var wave_progress: float = 0.0  # 0 to 1, how far party has traveled
var wave_spawned: bool = false
var wave_index: int = 0  # which wave of enemies (within this battle)

const GHOST_ABILITY_CD: float = 25.0
const GHOST_ABILITY_DURATION: float = 5.0

func _ready() -> void:
	cam = Camera2D.new()
	cam.position = Vector2(CORRIDOR_W * TILE / 2, 0)
	cam.enabled = true
	add_child(cam)
	_spawn_party_units()
	_spawn_enemies()
	_build_hud()

func _spawn_party_units() -> void:
	party_units.clear()
	for i in GameState.party.size():
		var adv: Dictionary = GameState.party[i]
		if not adv.get("alive", true):
			continue
		var hp := int(adv.get("hp", 100))
		var atk := int(adv.get("atk", 18))
		var def_ := int(adv.get("def", 12))
		var equipped: Dictionary = adv.get("equipped", {})
		for slot in equipped.keys():
			var gear: GearItem = equipped[slot]
			var mult: float = gear.stat_multiplier()
			atk = int(atk * (0.7 + mult * 0.5))
			def_ = int(def_ * (0.7 + mult * 0.5))
			if gear.state == GearItem.State.CURSED:
				atk = int(atk * 0.7)
				def_ = int(def_ * 0.7)
		var iq_mult: float = 1.0 + float(GameState.meta_upgrades["adventurer_training"]) * 0.05
		atk = int(atk * iq_mult)
		party_units.append({
			"pos": Vector2(CORRIDOR_W * TILE / 2 + (i - 1) * 24, (CORRIDOR_H - 2) * TILE),
			"hp": hp,
			"hp_max": hp,
			"atk": atk,
			"def": def_,
			"sprite": "knight" if adv["class"] == "knight" else "mage",
			"adv": adv,
			"atk_cd": 1.5,
			"alive": true,
			"walk_anim": 0.0,
		})

func _spawn_enemies() -> void:
	enemies.clear()
	var count: int = GameState.get_enemy_count()
	# Place enemies in a long line down the corridor
	for i in count:
		var x := (1 + (i * 3) % (CORRIDOR_W - 2)) * TILE + TILE / 2
		var y := (2 + i * 3) * TILE
		var sprite_name := "slime"
		var hp: int = GameState.get_enemy_hp()
		var atk: int = GameState.get_enemy_atk()
		match i % 3:
			0: sprite_name = "slime"
			1: sprite_name = "skeleton"
			2: sprite_name = "bat"
		enemies.append({
			"pos": Vector2(x, y),
			"hp": hp,
			"hp_max": hp,
			"atk": atk,
			"def": 4,
			"sprite": sprite_name,
			"atk_cd": 2.0,
			"alive": true,
			"walk_anim": randf() * TAU,
		})

func _build_hud() -> void:
	var panel := Panel.new()
	panel.position = Vector2(0, 0)
	panel.size = Vector2(VIEW_W, 22)
	add_child(panel)
	var lbl := Label.new()
	lbl.text = "Stage %d Wave %d — Battle!  [1] Haunt Enemy" % [GameState.stage, GameState.wave]
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	lbl.position = Vector2(4, 4)
	lbl.size = Vector2(VIEW_W, 14)
	panel.add_child(lbl)
	continue_btn = Button.new()
	continue_btn.text = "Continue >"
	continue_btn.add_theme_font_size_override("font_size", 8)
	continue_btn.position = Vector2(VIEW_W / 2 - 40, VIEW_H / 2 + 30)
	continue_btn.size = Vector2(80, 22)
	continue_btn.visible = false
	continue_btn.pressed.connect(_on_continue)
	add_child(continue_btn)
	log_label = Label.new()
	log_label.text = "The party descends..."
	log_label.add_theme_font_size_override("font_size", 7)
	log_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
	log_label.position = Vector2(4, VIEW_H - 14)
	log_label.size = Vector2(VIEW_W, 12)
	add_child(log_label)

func _process(delta: float) -> void:
	if battle_over:
		return
	elapsed += delta
	ghost_ability_cd = max(0, ghost_ability_cd - delta)
	ghost_ability_active = max(0, ghost_ability_active - delta)
	# Party auto-walks forward (up the corridor toward y=0)
	var any_alive := false
	for u in party_units:
		if u.alive:
			any_alive = true
			u.walk_anim += delta * 8
			# Find nearest alive enemy
			var nearest: Dictionary = {}
			var nearest_dist: float = 9999
			for e in enemies:
				if e.alive:
					var d: float = u.pos.distance_to(e.pos)
					if d < nearest_dist:
						nearest_dist = d
						nearest = e
			if not nearest.is_empty():
				# Move toward enemy
				if nearest_dist > 28:
					var dir: Vector2 = (nearest.pos - u.pos).normalized()
					u.pos += dir * 30 * delta
				else:
					# Attack
					u.atk_cd -= delta
					if u.atk_cd <= 0:
						u.atk_cd = 1.5
						_attack_enemy(u, nearest)
			else:
				# No enemies — walk toward exit (top of corridor)
				if u.pos.y > TILE * 2:
					u.pos.y -= 25 * delta
	# Enemy AI
	for e in enemies:
		if not e.alive:
			continue
		e.walk_anim += delta * 5
		# Find nearest party member
		var nearest: Dictionary = {}
		var nearest_dist: float = 9999
		for u in party_units:
			if u.alive:
				var d: float = e.pos.distance_to(u.pos)
				if d < nearest_dist:
					nearest_dist = d
					nearest = u
		if not nearest.is_empty():
			if nearest_dist > 24:
				var spd := 18.0
				if ghost_ability_active > 0:
					spd = 7.0
				var dir: Vector2 = (nearest.pos - e.pos).normalized()
				e.pos += dir * spd * delta
			else:
				e.atk_cd -= delta
				var spd_mult := 1.0
				if ghost_ability_active > 0:
					spd_mult = 0.4
				e.atk_cd -= delta * (spd_mult - 1)
				if e.atk_cd <= 0:
					e.atk_cd = 2.5
					_attack_party(e, nearest)
	# Camera follows the frontmost alive party member
	var front_y: float = CORRIDOR_H * TILE
	for u in party_units:
		if u.alive and u.pos.y < front_y:
			front_y = u.pos.y
	camera_y = lerp(camera_y, front_y, 0.08)
	cam.position = Vector2(CORRIDOR_W * TILE / 2, camera_y)
	cam.offset = Vector2(0, -20)
	# Wave progress (how far party has traveled)
	wave_progress = 1.0 - clampf(front_y / (CORRIDOR_H * TILE), 0, 1)
	# Check win/lose
	var party_alive := false
	for u in party_units:
		if u.alive:
			party_alive = true
			break
	var enemies_alive := false
	for e in enemies:
		if e.alive:
			enemies_alive = true
			break
	if not enemies_alive:
		battle_over = true
		battle_won = true
		_end_battle()
	elif not party_alive:
		battle_over = true
		battle_won = false
		_end_battle()
	# Update particles + damage numbers
	for p in particles:
		p.pos += p.vel * delta
		p.life -= delta
	particles = particles.filter(func(p): return p.life > 0)
	for d in damage_numbers:
		d.life -= delta
		d.pos.y -= 20 * delta
	damage_numbers = damage_numbers.filter(func(d): return d.life > 0)
	queue_redraw()

func _attack_enemy(unit: Dictionary, enemy: Dictionary) -> void:
	var dmg: int = max(1, int(unit.atk * (0.8 + randf() * 0.4) - enemy.def))
	enemy.hp -= dmg
	damage_numbers.append({"pos": enemy.pos + Vector2(0, -16), "text": str(dmg), "color": Color(0.95, 0.85, 0.40), "life": 0.8, "max_life": 0.8})
	# Hit particles
	for i in 4:
		particles.append({
			"pos": enemy.pos,
			"vel": Vector2(randf_range(-40, 40), randf_range(-40, 40)),
			"color": Color(0.95, 0.40, 0.40),
			"life": 0.3,
			"max_life": 0.3,
		})
	# Durability damage to weapon
	var equipped: Dictionary = unit.adv.get("equipped", {})
	if equipped.has("weapon"):
		var g: GearItem = equipped["weapon"]
		g.take_durability_damage(8)
	if enemy.hp <= 0:
		enemy.alive = false
		enemy.hp = 0
		# Death particles
		for i in 8:
			particles.append({
				"pos": enemy.pos,
				"vel": Vector2(randf_range(-50, 50), randf_range(-50, 50)),
				"color": Color(0.65, 0.65, 0.65),
				"life": 0.6,
				"max_life": 0.6,
			})

func _attack_party(enemy: Dictionary, unit: Dictionary) -> void:
	var dmg: int = max(1, int(enemy.atk * (0.8 + randf() * 0.4) - unit.def))
	unit.hp -= dmg
	damage_numbers.append({"pos": unit.pos + Vector2(0, -16), "text": str(dmg), "color": Color(0.95, 0.40, 0.40), "life": 0.8, "max_life": 0.8})
	for i in 3:
		particles.append({
			"pos": unit.pos,
			"vel": Vector2(randf_range(-30, 30), randf_range(-30, 30)),
			"color": Color(0.85, 0.30, 0.30),
			"life": 0.3,
			"max_life": 0.3,
		})
	# Armor durability damage
	var equipped: Dictionary = unit.adv.get("equipped", {})
	if equipped.has("armor"):
		var g: GearItem = equipped["armor"]
		g.take_durability_damage(5)
	if unit.hp <= 0:
		unit.alive = false
		unit.hp = 0
		unit.adv.alive = false
		# Death particles
		for i in 10:
			particles.append({
				"pos": unit.pos,
				"vel": Vector2(randf_range(-50, 50), randf_range(-50, 50)),
				"color": Color(0.55, 0.10, 0.10),
				"life": 0.8,
				"max_life": 0.8,
			})

func _end_battle() -> void:
	# Damage gear based on outcome
	for adv in GameState.party:
		var equipped: Dictionary = adv.get("equipped", {})
		for slot in equipped.keys():
			var gear: GearItem = equipped[slot]
			var owner_died: bool = not adv.get("alive", true)
			gear.apply_combat_damage(owner_died)
			GameState.add_gear_to_pit(gear)
	for adv in GameState.party:
		adv.erase("equipped")
	var survivors := 0
	for adv in GameState.party:
		if adv.get("alive", false):
			survivors += 1
	GameState.last_battle_result = {
		"won": battle_won,
		"survivors": survivors,
		"party_size": GameState.party.size(),
		"shards_earned": 0,
		"stage": GameState.stage,
		"wave": GameState.wave,
	}
	var shards := 0
	if battle_won:
		shards += 30 + GameState.stage * 5 + GameState.wave * 3
		shards += survivors * 25
		GameState.run_log.append("Stage %d Wave %d — Victory! %d survivors." % [GameState.stage, GameState.wave, survivors])
	else:
		shards += 10 + GameState.stage
		shards += (GameState.party.size() - survivors) * 8
		GameState.run_log.append("Stage %d Wave %d — Party wiped." % [GameState.stage, GameState.wave])
	GameState.last_battle_result.shards_earned = shards
	GameState.add_shards(shards)
	continue_btn.visible = true
	log_label.text = "Battle %s! +%d shards." % ["won" if battle_won else "lost", shards]

func _draw() -> void:
	# Floor
	var cam_top := int((camera_y - VIEW_H / 2) / TILE) - 1
	var cam_bot := int((camera_y + VIEW_H / 2) / TILE) + 1
	cam_top = max(0, cam_top)
	cam_bot = min(CORRIDOR_H - 1, cam_bot)
	for y in range(cam_top, cam_bot + 1):
		for x in CORRIDOR_W:
			var p := Vector2(x * TILE, y * TILE)
			if (x + y) % 7 == 0 and y > 5:
				draw_texture(Sprites.get_sprite("floor_cracked"), p)
			elif (x + y) % 11 == 0 and y > 8:
				draw_texture(Sprites.get_sprite("floor_blood"), p)
			else:
				draw_texture(Sprites.get_sprite("floor"), p)
	# Side walls
	for y in range(cam_top, cam_bot + 1):
		draw_texture(Sprites.get_sprite("wall"), Vector2(-TILE, y * TILE))
		draw_texture(Sprites.get_sprite("wall_mossy"), Vector2(CORRIDOR_W * TILE, y * TILE))
		if y % 4 == 0:
			draw_texture_rect(Sprites.get_sprite("torch"), Rect2(-TILE - 12, y * TILE + 8, 24, 24), false)
			draw_texture_rect(Sprites.get_sprite("torch"), Rect2(CORRIDOR_W * TILE + 4, y * TILE + 8, 24, 24), false)
	# Exit (top of corridor)
	draw_texture_rect(Sprites.get_sprite("door"), Rect2((CORRIDOR_W * TILE / 2) - 16, -TILE - 16, 32, 32), false)
	draw_string(ThemeDB.get_default_theme().default_font, Vector2(CORRIDOR_W * TILE / 2 - 30, -TILE - 24), "EXIT", HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.55, 0.95, 0.75))
	# Enemies
	for e in enemies:
		if e.alive:
			var tex := Sprites.get_sprite(e.sprite)
			# Bobbing animation
			var bob := sin(e.walk_anim) * 2
			var ep: Vector2 = e.pos + Vector2(0, bob)
			# Shadow
			draw_rect(Rect2(ep.x - 8, e.pos.y + 10, 16, 3), Color(0, 0, 0, 0.3), true)
			draw_texture_rect(tex, Rect2(ep.x - 16, ep.y - 16, 32, 32), false)
			# HP bar
			var pct: float = float(e.hp) / float(e.hp_max)
			draw_rect(Rect2(ep.x - 12, ep.y - 20, 24, 2), Color(0.20, 0.20, 0.20), true)
			draw_rect(Rect2(ep.x - 12, ep.y - 20, 24 * pct, 2), Color(0.95, 0.40, 0.40), true)
	# Party
	for u in party_units:
		if u.alive:
			var tex := Sprites.get_sprite(u.sprite)
			var bob := sin(u.walk_anim) * 2
			var up: Vector2 = u.pos + Vector2(0, bob)
			draw_rect(Rect2(up.x - 8, u.pos.y + 10, 16, 3), Color(0, 0, 0, 0.3), true)
			draw_texture_rect(tex, Rect2(up.x - 16, up.y - 16, 32, 32), false)
			# HP bar
			var pct: float = float(u.hp) / float(u.hp_max)
			draw_rect(Rect2(up.x - 12, up.y - 20, 24, 2), Color(0.20, 0.20, 0.20), true)
			var c: Color = Color(0.55, 0.95, 0.55) if pct > 0.5 else (Color(0.95, 0.85, 0.30) if pct > 0.25 else Color(0.95, 0.40, 0.40))
			draw_rect(Rect2(up.x - 12, up.y - 20, 24 * pct, 2), c, true)
			# Show equipped weapon (small, above)
			var equipped: Dictionary = u.adv.get("equipped", {})
			if equipped.has("weapon"):
				var g: GearItem = equipped["weapon"]
				var wt := Sprites.get_weapon_sprite(g.type, g.state)
				draw_texture_rect(wt, Rect2(up.x + 10, up.y - 6, 16, 16), false)
	# Particles
	for p in particles:
		var alpha: float = p.life / p.max_life
		var c: Color = p.color
		c.a = alpha
		draw_circle(p.pos, 3 * alpha, c)
	# Damage numbers
	for d in damage_numbers:
		var alpha: float = d.life / d.max_life
		var c: Color = d.color
		c.a = alpha
		draw_string(ThemeDB.get_default_theme().default_font, d.pos, d.text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, c)
	# Ghost ability indicator (HUD overlay)
	var cd_pct: float = 1.0 - (ghost_ability_cd / GHOST_ABILITY_CD) if ghost_ability_cd > 0 else 1.0
	var cd_c := Color(0.55, 0.95, 0.55) if ghost_ability_cd <= 0 else Color(0.55, 0.55, 0.65)
	# Convert screen position to world for HUD (use draw_rect in screen space via CanvasItem)
	# Actually, since we have a camera, we draw HUD relative to camera by using cam.get_screen_center_position()
	var hud_pos := cam.get_screen_center_position() - Vector2(VIEW_W / 2, VIEW_H / 2)
	draw_rect(Rect2(hud_pos + Vector2(8, 150), Vector2(40, 8)), Color(0.20, 0.20, 0.20), true)
	draw_rect(Rect2(hud_pos + Vector2(8, 150), Vector2(40 * cd_pct, 8)), cd_c, true)
	draw_string(ThemeDB.get_default_theme().default_font, hud_pos + Vector2(8, 145), "[1] Haunt", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, cd_c)
	if ghost_ability_active > 0:
		draw_string(ThemeDB.get_default_theme().default_font, hud_pos + Vector2(VIEW_W / 2 - 30, 145), "HAUNTING!", HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.55, 0.75, 0.95))
	# Progress bar (right side)
	var pb_x: float = hud_pos.x + VIEW_W - 8
	var pb_y: float = hud_pos.y + 26
	draw_rect(Rect2(Vector2(pb_x, pb_y), Vector2(4, VIEW_H - 50)), Color(0.20, 0.20, 0.25), true)
	draw_rect(Rect2(Vector2(pb_x, pb_y + (VIEW_H - 50) * (1 - wave_progress)), Vector2(4, (VIEW_H - 50) * wave_progress)), Color(0.55, 0.95, 0.55), true)

func _input(event: InputEvent) -> void:
	if battle_over:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_1:
		if ghost_ability_cd <= 0:
			ghost_ability_cd = GHOST_ABILITY_CD
			ghost_ability_active = GHOST_ABILITY_DURATION
			log_label.text = "Ghost haunts the enemies — they slow!"

func _on_continue() -> void:
	GameState.set_phase("results")
