extends Node2D
## Phase: battle — auto-battler viewer.
## Party auto-fights dungeon enemies. Player has 1 support ability (Haunt Enemy = slow).
## Top-down view with HP bars and floating damage.

var enemies: Array = []  # Array[Dictionary] {pos, hp, hp_max, atk, def, sprite, atk_cd, alive}
var party_units: Array = []  # Array[Dictionary] {pos, hp, hp_max, atk, def, sprite, adv, alive}
var ghost_ability_cd: float = 0.0
var ghost_ability_active: float = 0.0  # duration remaining
var battle_over: bool = false
var battle_won: bool = false
var elapsed: float = 0.0
var continue_btn: Button
var log_label: Label
var damage_numbers: Array = []  # {pos, text, color, life}

const GHOST_ABILITY_CD: float = 30.0
const GHOST_ABILITY_DURATION: float = 5.0

func _ready() -> void:
	# Spawn enemies based on day
	_spawn_enemies()
	# Convert party to battle units
	_spawn_party_units()
	# HUD
	var panel := Panel.new()
	panel.position = Vector2(0, 0)
	panel.size = Vector2(640, 16)
	add_child(panel)

	var lbl := Label.new()
	lbl.text = "Day %d — Battle!  Press 1 to Haunt Enemy (slow)" % GameState.day
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	lbl.position = Vector2(4, 2)
	lbl.size = Vector2(500, 12)
	panel.add_child(lbl)

	# Continue button (hidden until battle over)
	continue_btn = Button.new()
	continue_btn.text = "Continue >"
	continue_btn.add_theme_font_size_override("font_size", 12)
	continue_btn.position = Vector2(280, 150)
	continue_btn.size = Vector2(80, 24)
	continue_btn.visible = false
	continue_btn.pressed.connect(_on_continue)
	add_child(continue_btn)

	log_label = Label.new()
	log_label.text = "Battle begins..."
	log_label.add_theme_font_size_override("font_size", 9)
	log_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
	log_label.position = Vector2(4, 170)
	log_label.size = Vector2(640, 10)
	add_child(log_label)

func _spawn_enemies() -> void:
	enemies.clear()
	# Number scales with day
	var count: int = 2 + int(GameState.day) / 5
	count = min(count, 5)
	for i in count:
		var sprite_name := "slime"
		var hp := 30 + GameState.day * 5
		var atk := 8 + GameState.day * 1.5
		if i % 3 == 1:
			sprite_name = "skeleton"
			hp = 40 + GameState.day * 4
			atk = 12 + GameState.day * 1.5
		elif i % 3 == 2:
			sprite_name = "bat"
			hp = 20 + GameState.day * 3
			atk = 10 + GameState.day * 2
		enemies.append({
			"pos": Vector2(220 + i * 28, 60 + (i % 2) * 30),
			"hp": hp,
			"hp_max": hp,
			"atk": atk,
			"def": 5 + GameState.day * 0.5,
			"sprite": sprite_name,
			"atk_cd": 2.0,
			"alive": true,
		})

func _spawn_party_units() -> void:
	party_units.clear()
	for i in GameState.party.size():
		var adv: Dictionary = GameState.party[i]
		if not adv.get("alive", true):
			continue
		var hp := int(adv.get("hp", 100))
		var atk := int(adv.get("atk", 18))
		var def_ := int(adv.get("def", 12))
		# Apply gear stat multipliers
		var equipped: Dictionary = adv.get("equipped", {})
		for slot in equipped.keys():
			var gear: GearItem = equipped[slot]
			var mult := gear.stat_multiplier()
			atk = int(atk * (0.7 + mult * 0.5))
			def_ = int(def_ * (0.7 + mult * 0.5))
			# Cursed gear debuff
			if gear.state == GearItem.State.CURSED:
				atk = int(atk * 0.7)
				def_ = int(def_ * 0.7)
		# Adventurer training upgrade
		var iq_mult: float = 1.0 + float(GameState.meta_upgrades["adventurer_training"]) * 0.05
		atk = int(atk * iq_mult)
		party_units.append({
			"pos": Vector2(60 + i * 28, 60 + (i % 2) * 30),
			"hp": hp,
			"hp_max": hp,
			"atk": atk,
			"def": def_,
			"sprite": "knight" if adv["class"] == "knight" else "mage",
			"adv": adv,
			"atk_cd": 1.5,
			"alive": true,
		})

func _process(delta: float) -> void:
	if battle_over:
		return
	elapsed += delta
	ghost_ability_cd = max(0, ghost_ability_cd - delta)
	ghost_ability_active = max(0, ghost_ability_active - delta)

	# Auto-attacks
	for u in party_units:
		if not u.alive:
			continue
		u.atk_cd -= delta
		if u.atk_cd <= 0:
			u.atk_cd = 1.8
			_attack_enemy(u)
	for e in enemies:
		if not e.alive:
			continue
		e.atk_cd -= delta
		# Slow effect if ghost ability active
		var spd := 1.0
		if ghost_ability_active > 0:
			spd = 0.4
		e.atk_cd -= delta * (spd - 1)  # adjust by speed
		if e.atk_cd <= 0:
			e.atk_cd = 2.5
			_attack_party(e)

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

	# Update damage numbers
	for d in damage_numbers:
		d.life -= delta
		d.pos.y -= 10 * delta
	damage_numbers = damage_numbers.filter(func(d): return d.life > 0)

	queue_redraw()

func _attack_enemy(unit: Dictionary) -> void:
	# Find first alive enemy
	for e in enemies:
		if e.alive:
			var dmg: int = max(1, int(unit.atk * (0.8 + randf() * 0.4) - e.def))
			e.hp -= dmg
			damage_numbers.append({"pos": e.pos + Vector2(0, -10), "text": str(dmg), "color": Color(0.95, 0.85, 0.40), "life": 0.8})
			if e.hp <= 0:
				e.alive = false
				e.hp = 0
			break

func _attack_party(enemy: Dictionary) -> void:
	for u in party_units:
		if u.alive:
			var dmg: int = max(1, int(enemy.atk * (0.8 + randf() * 0.4) - u.def))
			u.hp -= dmg
			damage_numbers.append({"pos": u.pos + Vector2(0, -10), "text": str(dmg), "color": Color(0.95, 0.40, 0.40), "life": 0.8})
			if u.hp <= 0:
				u.alive = false
				u.hp = 0
				u.adv.alive = false
			break

func _end_battle() -> void:
	# Damage gear based on outcome
	for adv in GameState.party:
		var equipped: Dictionary = adv.get("equipped", {})
		for slot in equipped.keys():
			var gear: GearItem = equipped[slot]
			var owner_died: bool = not adv.get("alive", true)
			gear.apply_combat_damage(owner_died)
			# Return gear to pit (survivors leave with it OR dead drop it — handled below)
			# For now, all gear goes back to pit; we'll filter at results screen for survivors.
			GameState.add_gear_to_pit(gear)
	# Clear equipped
	for adv in GameState.party:
		adv.erase("equipped")

	# Compute rewards
	var survivors := 0
	for adv in GameState.party:
		if adv.get("alive", false):
			survivors += 1
	# Build last_battle_result
	GameState.last_battle_result = {
		"won": battle_won,
		"survivors": survivors,
		"party_size": GameState.party.size(),
		"shards_earned": 0,  # filled in below
		"day": GameState.day,
	}
	var shards := 0
	if battle_won:
		shards += 30 + GameState.day * 2  # win bonus
		shards += survivors * 20  # survivor bonus
		GameState.run_log.append("Day %d — Victory! %d survivors." % [GameState.day, survivors])
	else:
		shards += 10 + GameState.day  # pity shards
		shards += (GameState.party.size() - survivors) * 5  # dead-drop shards
		GameState.run_log.append("Day %d — Party wiped. %d dead." % [GameState.day, GameState.party.size() - survivors])
	GameState.last_battle_result.shards_earned = shards
	GameState.add_shards(shards)
	continue_btn.visible = true
	log_label.text = "Battle %s! +%d shards." % ["won" if battle_won else "lost", shards]

func _draw() -> void:
	# Floor
	for y in 10:
		for x in 40:
			draw_texture(Sprites.get_sprite("floor"), Vector2(x * 16, y * 16 + 16))
	# Party
	for u in party_units:
		if u.alive:
			draw_texture(Sprites.get_sprite(u.sprite), u.pos - Vector2(8, 8))
		else:
			draw_string(ThemeDB.get_default_theme().default_font, u.pos - Vector2(8, 4), "X", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.95, 0.30, 0.30))
		# HP bar
		var pct: float = float(u.hp) / float(u.hp_max)
		draw_rect(Rect2(u.pos.x - 10, u.pos.y - 14, 20, 2), Color(0.20, 0.20, 0.20), true)
		var c: Color = Color(0.55, 0.95, 0.55) if pct > 0.5 else (Color(0.95, 0.85, 0.30) if pct > 0.25 else Color(0.95, 0.40, 0.40))
		draw_rect(Rect2(u.pos.x - 10, u.pos.y - 14, 20 * pct, 2), c, true)
	# Enemies
	for e in enemies:
		if e.alive:
			draw_texture(Sprites.get_sprite(e.sprite), e.pos - Vector2(8, 8))
		else:
			draw_string(ThemeDB.get_default_theme().default_font, e.pos - Vector2(8, 4), "X", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.30, 0.95, 0.30))
		# HP bar
		if e.alive:
			var pct: float = float(e.hp) / float(e.hp_max)
			draw_rect(Rect2(e.pos.x - 10, e.pos.y - 14, 20, 2), Color(0.20, 0.20, 0.20), true)
			draw_rect(Rect2(e.pos.x - 10, e.pos.y - 14, 20 * pct, 2), Color(0.95, 0.40, 0.40), true)
	# Damage numbers
	for d in damage_numbers:
		var alpha := clampf(d.life / 0.8, 0, 1)
		var col: Color = d.color
		col.a = alpha
		draw_string(ThemeDB.get_default_theme().default_font, d.pos, d.text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, col)
	# Ghost ability indicator
	var cd_pct := 1.0 - (ghost_ability_cd / GHOST_ABILITY_CD) if ghost_ability_cd > 0 else 1.0
	var cd_color := Color(0.55, 0.95, 0.55) if ghost_ability_cd <= 0 else Color(0.55, 0.55, 0.65)
	draw_rect(Rect2(8, 150, 40, 8), Color(0.20, 0.20, 0.20), true)
	draw_rect(Rect2(8, 150, 40 * cd_pct, 8), cd_color, true)
	draw_string(ThemeDB.get_default_theme().default_font, Vector2(8, 145), "[1] Haunt", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, cd_color)
	if ghost_ability_active > 0:
		draw_string(ThemeDB.get_default_theme().default_font, Vector2(280, 145), "HAUNTING!", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.55, 0.75, 0.95))

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
