extends Node2D
## Phase: battle V4 — 320x180, spectator, weapons degrade visibly.

const TILE: int = 16
const CORRIDOR_W: int = 18
const CORRIDOR_H: int = 60
const VIEW_W: int = 480
const VIEW_H: int = 270

var party_units: Array = []
var enemies: Array = []
var camera_y: float = 0.0
var cam: Camera2D
var battle_over: bool = false
var battle_won: bool = false
var retreated: bool = false
var starting_party_count: int = 0
var elapsed: float = 0.0
# DESIGN_PLAN 1B: Phase verb (replaces the old '1'-key Haunt ability).
# Same mechanical effect — slows all enemies while active — but now
# unified with the salvage/workshop/planning verb: SPACE to activate,
# 1.5s duration, 4s cooldown, 1 soul shard cost. The verb and the
# character concept are the same fact: a ghost that goes incorporeal.
var phase_cd: float = 0.0
var phase_active: float = 0.0
var damage_numbers: Array = []
var continue_btn: Button
var log_label: Label
var hud_layer: CanvasLayer

# DESIGN_PLAN 1B: Phase verb timings. Was 20s cd / 4s duration for the
# old Haunt — too long for a 15-20s battle. Now 4s cd / 1.5s duration,
# matched to salvage so the verb feels the same everywhere.
const PHASE_CD: float = 4.0
const PHASE_DURATION: float = 1.5
const PHASE_COST: int = 1

func _ready() -> void:
	cam = Camera2D.new()
	cam.position = Vector2(CORRIDOR_W * TILE / 2, 0)
	cam.enabled = true
	# IMPORTANT: Camera2D's own smoothing is OFF on purpose. We already do our
	# own exponential smoothing on camera_y below and int-snap the result before
	# handing it to the camera. If Camera2D smoothing were also enabled, it would
	# add a SECOND, independently-timed interpolation on top of ours (and on top
	# of the engine's global pixel snapping), which is what caused sprites/HUD
	# text to visibly jitter/disconnect from the background — the two smoothing
	# passes drift out of phase with each other across frames.
	cam.position_smoothing_enabled = false
	add_child(cam)
	_spawn_party_units()
	_spawn_enemies()
	_build_hud()

func _spawn_party_units() -> void:
	party_units.clear()
	retreated = false
	for i in GameState.party.size():
		var adv: Dictionary = GameState.party[i]
		if not adv.get("alive", true):
			continue
		var hp := int(adv.get("hp", 100))
		# REBALANCED: base stats are near-zero. Weapons/armor are the PRIMARY
		# source of damage and defense, not a small bonus. An unarmed adventurer
		# does 3-5 damage and has 2 defense — they can't win fights alone.
		var base_atk := 4  # was 18 — fists only
		var base_def := 2  # was 12 — clothes only
		var atk := base_atk
		var def_ := base_def
		if adv.get("equipped_weapon") != null:
			var w: Weapon = adv.equipped_weapon
			var mult: float = w.stat_multiplier()
			# Weapon adds 10-30 damage based on quality (was 0.7 + mult*0.5 on top of 18)
			atk = base_atk + int(25 * mult)
		if adv.get("equipped_armor") != null:
			var a: Weapon = adv.equipped_armor
			var mult: float = a.stat_multiplier()
			# Armor adds 5-15 defense based on quality
			def_ = base_def + int(12 * mult)
		var iq_mult: float = 1.0 + float(GameState.meta_upgrades["adventurer_training"]) * 0.05
		atk = int(atk * iq_mult)
		party_units.append({
			"pos": Vector2(CORRIDOR_W * TILE / 2 + (i - 1) * 24, (CORRIDOR_H - 3) * TILE),
			"hp": hp,
			"hp_max": hp,
			"atk": atk,
			"def": def_,
			"sprite": "knight" if adv["class"] == "knight" else "mage",
			"adv": adv,
			"atk_cd": 1.5,
			"alive": true,
			"walk_anim": 0.0,
			"flash": 0.0,
		})
	starting_party_count = party_units.size()

func _spawn_enemies() -> void:
	enemies.clear()
	var count: int = GameState.get_enemy_count()
	for i in count:
		var x := (2 + (i * 5) % (CORRIDOR_W - 4)) * TILE + TILE / 2
		var y := (3 + i * 5) * TILE
		var sprite_name := "slime"
		match i % 3:
			0: sprite_name = "slime"
			1: sprite_name = "skeleton"
			2: sprite_name = "bat"
		enemies.append({
			"pos": Vector2(x, y),
			"hp": GameState.get_enemy_hp(),
			"hp_max": GameState.get_enemy_hp(),
			"atk": GameState.get_enemy_atk(),
			"def": 4,
			"sprite": sprite_name,
			# Randomized so enemy attacks don't land in lockstep. With every
			# enemy starting on the exact same cooldown, several of them would
			# reach melee range around the same time and then land killing
			# blows on multiple party members in the same instant — which is
			# what made a single bad moment look like the whole party dying
			# from "one hit."
			"atk_cd": 2.0 + randf() * 1.5,
			"alive": true,
			"walk_anim": randf() * TAU,
		})

func _build_hud() -> void:
	# Everything here goes into a CanvasLayer. Without one, these Control nodes
	# are just regular children of this Node2D, so the Camera2D transform drags
	# them along with the world exactly like the floor and sprites — meaning as
	# soon as the camera scrolls away from its starting position (which happens
	# in every real battle as the party chases enemies down the corridor), the
	# status bar, log text, and — critically — the Continue button scroll off
	# screen with it. That's what made the end-of-battle screen look "frozen":
	# the button was still there and still worked, just no longer visible or
	# reachable. A CanvasLayer renders independent of the camera, so this HUD
	# now stays fixed to the screen no matter where the battle has scrolled to.
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	var panel := Panel.new()
	panel.position = Vector2(0, 0)
	panel.size = Vector2(VIEW_W, 20)
	hud_layer.add_child(panel)
	var lbl := Label.new()
	lbl.text = "S%d W%d BATTLE" % [GameState.stage, GameState.wave]
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Palette.TEXT_GOLD)
	lbl.position = Vector2(2, 2)
	lbl.size = Vector2(VIEW_W, 14)
	panel.add_child(lbl)
	continue_btn = Button.new()
	continue_btn.text = "Continue >"
	continue_btn.add_theme_font_size_override("font_size", 8)
	continue_btn.position = Vector2(VIEW_W / 2 - 60, VIEW_H / 2 + 30)
	continue_btn.size = Vector2(120, 20)
	continue_btn.visible = false
	continue_btn.pressed.connect(_on_continue)
	hud_layer.add_child(continue_btn)
	log_label = Label.new()
	log_label.text = "The party descends..."
	log_label.add_theme_font_size_override("font_size", 8)
	log_label.add_theme_color_override("font_color", Palette.TEXT)
	log_label.position = Vector2(2, VIEW_H - 14)
	log_label.size = Vector2(VIEW_W, 12)
	hud_layer.add_child(log_label)

func _process(delta: float) -> void:
	# NOTE: this used to be _physics_process. Everything here is hand-rolled
	# simulation drawn manually via _draw() — there are no RigidBody/CharacterBody
	# physics queries involved. Running it on the fixed physics tick while the
	# Camera2D and Juice's hit-stop timer (see juice.gd) update on the render/idle
	# tick meant the two clocks drifted apart whenever the display refresh rate
	# didn't match the physics FPS, which is what produced the jitter/desync
	# between sprites, HUD text, and the background. Running everything on the
	# same (render) clock keeps it all perfectly in lockstep.
	if battle_over:
		return
	if Juice.is_hit_stopped():
		return
	elapsed += delta
	phase_cd = max(0, phase_cd - delta)
	if phase_active > 0:
		phase_active = max(0, phase_active - delta)
		if phase_active == 0:
			SFX.play("phase_out", 1.0, -3.0)
	# DESIGN_PLAN 1B: Phase verb activation. Checked in _process (not _input)
	# using Input.is_action_just_pressed so it works with ANY input source
	# that maps to the "phase" action — physical keyboard, gamepad, remapped
	# keys, or the PlaytestDriver's Input.action_press. The old _input(event)
	# approach only fired on physical InputEventKey presses, silently
	# breaking gamepad support and playtest automation.
	if Input.is_action_just_pressed("phase") and phase_cd <= 0 and phase_active <= 0:
		if GameState.soul_shards < PHASE_COST:
			SFX.play("deny")
			log_label.text = "Not enough shards to phase (need %d)" % PHASE_COST
		else:
			GameState.soul_shards -= PHASE_COST
			GameState.shards_changed.emit(GameState.soul_shards)
			phase_cd = PHASE_CD
			phase_active = PHASE_DURATION
			Juice.add_trauma(0.2)
			Juice.spawn_particles(Vector2(VIEW_W / 2, VIEW_H / 2), 12, Palette.GLOW_BLUE, 40.0, 0.5)
			SFX.play("phase_in", 1.0, -2.0)
			log_label.text = "Ghost phases — enemies slow!"
	for u in party_units:
		if u.alive:
			u.walk_anim += delta * 8
			u.flash = max(0, u.flash - delta * 4)
			var nearest: Dictionary = {}
			var nearest_dist: float = 9999
			for e in enemies:
				if e.alive:
					var d: float = u.pos.distance_to(e.pos)
					if d < nearest_dist:
						nearest_dist = d
						nearest = e
			if not nearest.is_empty():
				if nearest_dist > 20:
					var dir: Vector2 = (nearest.pos - u.pos).normalized()
					u.pos += dir * 25 * delta
				else:
					u.atk_cd -= delta
					if u.atk_cd <= 0:
						u.atk_cd = 1.5
						_attack_enemy(u, nearest)
			else:
				if u.pos.y > TILE * 3:
					u.pos.y -= 22 * delta
	for e in enemies:
		if not e.alive:
			continue
		e.walk_anim += delta * 5
		var nearest: Dictionary = {}
		var nearest_dist: float = 9999
		for u in party_units:
			if u.alive:
				var d: float = e.pos.distance_to(u.pos)
				if d < nearest_dist:
					nearest_dist = d
					nearest = u
		if not nearest.is_empty():
			if nearest_dist > 16:
				var spd := 15.0
				if phase_active > 0:
					spd = 6.0
				var dir: Vector2 = (nearest.pos - e.pos).normalized()
				e.pos += dir * spd * delta
			else:
				e.atk_cd -= delta
				if phase_active > 0:
					e.atk_cd -= delta * 0.5
				if e.atk_cd <= 0:
					e.atk_cd = 2.5 + randf() * 0.6
					_attack_party(e, nearest)
	var front_y: float = CORRIDOR_H * TILE
	for u in party_units:
		if u.alive and u.pos.y < front_y:
			front_y = u.pos.y
	camera_y = lerp(camera_y, front_y, 1.0 - exp(-delta * 5.0))
	# Snap camera to integers — prevents sub-pixel jitter
	cam.position = Vector2(CORRIDOR_W * TILE / 2, int(camera_y))
	cam.offset = Vector2(0, 30) + Juice.get_shake_offset()
	var party_alive := false
	var alive_count := 0
	for u in party_units:
		if u.alive:
			party_alive = true
			alive_count += 1
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
	elif alive_count == 1 and starting_party_count > 1:
		# Last-standing-survivor retreat: previously, a wave was only ever
		# "lost" once literally every party member had died — meaning any
		# failed wave always wiped the entire active roster and ended the
		# run. That made a single death near the end of a fight feel like it
		# had killed the whole party, and made it impossible to test wave
		# progression across a failed run. Now, once only one fighter is
		# left standing (out of a party that started with more than one)
		# and they're badly hurt, they pull back instead of being forced to
		# fight to the death — the wave is lost, but that survivor lives on
		# into the next planning phase.
		for u in party_units:
			if u.alive:
				var hp_pct: float = float(u.hp) / float(u.hp_max)
				if hp_pct <= 0.3:
					battle_over = true
					battle_won = false
					retreated = true
					log_label.text = "%s retreats — wounded, but alive!" % u.adv.name
				break
		if battle_over:
			_end_battle()
	for d in damage_numbers:
		d.life -= delta
		d.pos.y -= 15 * delta
	damage_numbers = damage_numbers.filter(func(d): return d.life > 0)
	Juice.update_particles(delta)
	queue_redraw()

func _attack_enemy(unit: Dictionary, enemy: Dictionary) -> void:
	var dmg: int = max(1, int(unit.atk * (0.8 + randf() * 0.4) - enemy.def))
	enemy.hp -= dmg
	damage_numbers.append({"pos": enemy.pos + Vector2(0, -12), "text": str(dmg), "color": Palette.TEXT_GOLD, "life": 0.7, "max_life": 0.7})
	Juice.spawn_particles(enemy.pos, 4, Palette.TEXT_RED, 30.0, 0.3)
	SFX.play("hit", 1.0 + randf_range(-0.1, 0.1))
	var adv: Dictionary = unit.adv
	if adv.get("equipped_weapon") != null:
		var w: Weapon = adv.equipped_weapon
		w.take_durability_damage(6, "combat hit")
		if w.is_broken and not w.break_announced:
			w.break_announced = true
			Juice.add_trauma(0.5)
			Juice.hit_stop(0.15)
			Juice.spawn_particles(unit.pos, 12, Palette.STEEL_LT, 50.0, 0.7)
			log_label.text = "%s SHATTERED!" % w.display_name
			SFX.play("shatter")
	if enemy.hp <= 0:
		enemy.alive = false
		enemy.hp = 0
		if adv.get("equipped_weapon") != null:
			adv.equipped_weapon.record_kill(enemy.sprite)
		Juice.spawn_particles(enemy.pos, 8, Palette.TEXT_DIM, 40.0, 0.5)

func _attack_party(enemy: Dictionary, unit: Dictionary) -> void:
	var dmg: int = max(1, int(enemy.atk * (0.8 + randf() * 0.4) - unit.def))
	unit.hp -= dmg
	unit.flash = 1.0
	damage_numbers.append({"pos": unit.pos + Vector2(0, -12), "text": str(dmg), "color": Palette.TEXT_RED, "life": 0.7, "max_life": 0.7})
	Juice.spawn_particles(unit.pos, 3, Palette.BLOOD, 25.0, 0.3)
	var adv: Dictionary = unit.adv
	if adv.get("equipped_armor") != null:
		adv.equipped_armor.take_durability_damage(4, "armor hit")
	if unit.hp <= 0:
		unit.alive = false
		unit.hp = 0
		unit.adv.alive = false
		Juice.add_trauma(0.4)
		Juice.hit_stop(0.12)
		Juice.spawn_particles(unit.pos, 10, Palette.BLOOD, 50.0, 0.7)
		log_label.text = "%s has fallen!" % adv.name
		SFX.play("death")

func _end_battle() -> void:
	# V2: Dead party members' weapons STAY ON THE GROUND for salvage.
	# Living members' weapons go back to arsenal. This is the core loop:
	# death → weapons on ground → salvage picks them up → repair → reassign.
	var fallen_gear: Array = []  # {weapon, armor, name, class, cause}
	for adv in GameState.party:
		var equipped_w: Variant = adv.get("equipped_weapon")
		var equipped_a: Variant = adv.get("equipped_armor")
		var owner_died: bool = not adv.get("alive", true)
		if owner_died:
			# Dead adventurer: their gear stays on the ground
			if equipped_w != null:
				equipped_w.apply_combat_damage(true)
				fallen_gear.append({
					"weapon": equipped_w,
					"name": adv.get("name", "?"),
					"class": adv.get("class", "knight"),
					"slot": "weapon",
					"cause": "slain in battle",
				})
			if equipped_a != null:
				equipped_a.apply_combat_damage(true)
				fallen_gear.append({
					"weapon": equipped_a,
					"name": adv.get("name", "?"),
					"class": adv.get("class", "knight"),
					"slot": "armor",
					"cause": "slain in battle",
				})
		else:
			# Living adventurer: their gear returns to arsenal
			if equipped_w != null:
				equipped_w.apply_combat_damage(false)
				GameState.add_weapon(equipped_w)
			if equipped_a != null:
				equipped_a.apply_combat_damage(false)
				GameState.add_weapon(equipped_a)
	for adv in GameState.party:
		adv.erase("equipped_weapon")
		adv.erase("equipped_armor")
	var survivors := 0
	for adv in GameState.party:
		if adv.get("alive", false):
			survivors += 1
	var fallen_names: Array = []
	for u in party_units:
		if not u.alive:
			fallen_names.append(str(u.adv.name))
	GameState.last_battle_result = {
		"won": battle_won,
		"survivors": survivors,
		"party_size": GameState.party.size(),
		"shards_earned": 0,
		"stage": GameState.stage,
		"wave": GameState.wave,
		"fallen_names": fallen_names,
		"fallen_gear": fallen_gear,
		"retreated": retreated,
	}
	var shards := 0
	if battle_won:
		shards += 30 + GameState.stage * 5 + GameState.wave * 3
		shards += survivors * 25
		GameState.run_log.append("Stage %d Wave %d — Victory! %d survivors." % [GameState.stage, GameState.wave, survivors])
		SFX.play("chime")
	else:
		shards += 10 + GameState.stage
		shards += (GameState.party.size() - survivors) * 8
		if survivors == 0:
			GameState.run_log.append("Stage %d Wave %d — PARTY WIPED. The dungeon claims them all." % [GameState.stage, GameState.wave])
		elif retreated:
			GameState.run_log.append("Stage %d Wave %d — Forced to retreat, %d survivor(s)." % [GameState.stage, GameState.wave, survivors])
		else:
			GameState.run_log.append("Stage %d Wave %d — Party wiped." % [GameState.stage, GameState.wave])
	GameState.last_battle_result.shards_earned = shards
	GameState.add_shards(shards)
	continue_btn.visible = true
	if survivors == 0:
		log_label.text = "PARTY WIPED — the run is over."
	elif retreated:
		log_label.text = "Retreated with %d survivor(s). +%d shards." % [survivors, shards]
	else:
		log_label.text = "Battle %s! +%d shards." % ["WON" if battle_won else "LOST", shards]

func _draw() -> void:
	# Overscan: draw 3 tiles beyond viewport on all sides so edges are never visible
	var cam_top := int((camera_y - VIEW_H / 2) / TILE) - 3
	var cam_bot := int((camera_y + VIEW_H / 2) / TILE) + 3
	cam_top = max(-2, cam_top)
	cam_bot = min(CORRIDOR_H + 1, cam_bot)
	# Floor — extend beyond corridor walls so there's no hard edge
	for y in range(cam_top, cam_bot + 1):
		for x in range(-2, CORRIDOR_W + 2):
			var p := Vector2(x * TILE, y * TILE)
			var hash := (x * 7 + y * 13) % 31
			if x < 0 or x >= CORRIDOR_W:
				# Beyond walls — draw dark stone (cavern background)
				draw_texture(Sprites.get_sprite("wall"), p)
			elif hash < 3 and y > 5:
				draw_texture(Sprites.get_sprite("floor_crack"), p)
			elif hash < 5 and y > 8:
				draw_texture(Sprites.get_sprite("floor_blood"), p)
			elif hash < 7 and y > 10:
				draw_texture(Sprites.get_sprite("floor_moss"), p)
			else:
				draw_texture(Sprites.get_sprite("floor"), p)
	# Side walls (extend beyond viewport)
	for y in range(cam_top, cam_bot + 1):
		draw_texture(Sprites.get_sprite("wall"), Vector2(-TILE, y * TILE))
		draw_texture(Sprites.get_sprite("wall_mossy"), Vector2(CORRIDOR_W * TILE, y * TILE))
		if y % 4 == 0:
			draw_texture(Sprites.get_sprite("torch"), Vector2(-TILE, y * TILE))
			draw_texture(Sprites.get_sprite("torch"), Vector2(CORRIDOR_W * TILE, y * TILE))
			# Ambient torch glow
			_draw_glow(Vector2(-TILE + 8, y * TILE + 8), 18, Palette.LIGHT_TORCH)
			_draw_glow(Vector2(CORRIDOR_W * TILE + 8, y * TILE + 8), 18, Palette.LIGHT_TORCH)
	# Exit
	draw_texture(Sprites.get_sprite("door"), Vector2(CORRIDOR_W * TILE / 2 - 8, -TILE))
	_draw_glow(Vector2(CORRIDOR_W * TILE / 2, -TILE + 8), 16, Palette.LIGHT_EXIT)
	# Enemies — ALL positions snapped to integers
	for e in enemies:
		if e.alive:
			var tex := Sprites.get_sprite(e.sprite)
			var bob := int(sin(e.walk_anim) * 1)
			var ex := int(e.pos.x)
			var ey := int(e.pos.y)
			draw_rect(Rect2(ex - 5, ey + 6, 10, 2), Color(0, 0, 0, 0.3), true)
			draw_texture(tex, Vector2(ex - 8, ey - 8 + bob))
			var pct: float = float(e.hp) / float(e.hp_max)
			draw_rect(Rect2(ex - 8, ey - 14, 16, 1), Palette.DARK, true)
			draw_rect(Rect2(ex - 8, ey - 14, int(16 * pct), 1), Palette.TEXT_RED, true)
	# Party — ALL positions snapped to integers
	for u in party_units:
		if u.alive:
			var tex := Sprites.get_sprite(u.sprite)
			var bob := int(sin(u.walk_anim) * 1)
			var ux := int(u.pos.x)
			var uy := int(u.pos.y)
			draw_rect(Rect2(ux - 5, uy + 6, 10, 2), Color(0, 0, 0, 0.3), true)
			if u.flash > 0:
				draw_rect(Rect2(ux - 8, uy - 8, 16, 16), Color(1, 0.3, 0.3, u.flash * 0.5), true)
			draw_texture(tex, Vector2(ux - 8, uy - 8 + bob))
			var pct: float = float(u.hp) / float(u.hp_max)
			draw_rect(Rect2(ux - 8, uy - 14, 16, 1), Palette.DARK, true)
			var c: Color = Palette.TEXT_GREEN if pct > 0.5 else (Palette.TEXT_GOLD if pct > 0.25 else Palette.TEXT_RED)
			draw_rect(Rect2(ux - 8, uy - 14, int(16 * pct), 1), c, true)
			# Weapon + durability bar
			var adv: Dictionary = u.adv
			if adv.get("equipped_weapon") != null:
				var w: Weapon = adv.equipped_weapon
				draw_texture(Sprites.get_weapon_sprite(w.type, w.state), Vector2(ux + 6, uy - 4))
				var dpct: float = w.durability_pct()
				draw_rect(Rect2(ux + 5, uy - 8, 8, 1), Palette.DARK, true)
				draw_rect(Rect2(ux + 5, uy - 8, int(8 * dpct), 1), w.wear_color(), true)
	# Particles
	Juice.draw_particles(self)
	# Damage numbers — snapped
	for d in damage_numbers:
		var alpha: float = d.life / d.max_life
		var c: Color = d.color
		c.a = alpha
		GameFont.draw_string_centered(self, Vector2(int(d.pos.x), int(d.pos.y)), d.text, 8, c)
	# Ghost ability HUD — snapped
	var hud_pos := cam.get_screen_center_position() - Vector2(VIEW_W / 2, VIEW_H / 2)
	hud_pos = Vector2(int(hud_pos.x), int(hud_pos.y))
	var cd_pct: float = 1.0 - (phase_cd / PHASE_CD) if phase_cd > 0 else 1.0
	var cd_c := Palette.TEXT_GREEN if phase_cd <= 0 else Palette.TEXT_DIM
	draw_rect(Rect2(hud_pos + Vector2(4, 150), Vector2(40, 5)), Palette.DARK, true)
	draw_rect(Rect2(hud_pos + Vector2(4, 150), Vector2(int(40 * cd_pct), 5)), cd_c, true)
	# DESIGN_PLAN 1B: Phase verb — unified verb label, matches salvage.
	# Was "[1]Haunt". Now shows shard cost so the player sees the price.
	var phase_label := "[SPACE]PHASE -%ds" % PHASE_COST if phase_cd <= 0 else "[SPACE]phase %.1fs" % phase_cd
	GameFont.draw_string(self, hud_pos + Vector2(4, 148), phase_label, 8, cd_c)
	if phase_active > 0:
		GameFont.draw_string_centered(self, hud_pos + Vector2(VIEW_W / 2, 148), "PHASING!", 8, Palette.GLOW_BLUE)

func _draw_glow(pos: Vector2, radius: int, color: Color) -> void:
	var center := Vector2(int(pos.x), int(pos.y))
	for r in [radius, int(radius * 0.6), int(radius * 0.3)]:
		var c := color
		c.a = c.a * (1.0 - float(r) / float(radius)) * 0.8
		draw_circle(center, r, c)

func _on_continue() -> void:
	GameState.set_phase("results")
