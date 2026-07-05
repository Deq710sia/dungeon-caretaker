extends Node
## GameState — V2 singleton autoload.
## Structure: Multiple STAGES, each with multiple WAVES of adventurers.
## Player persists gear across waves within a stage; stages reset party.

signal stage_changed(new_stage: int)
signal wave_changed(new_wave: int)
signal shards_changed(new_count: int)
signal phase_changed(new_phase: String)
signal party_changed
signal salvage_changed

const MAX_STAGE: int = 5        # 5 stages = full run
const WAVES_PER_STAGE: int = 3  # 3 waves of adventurers per stage
const SAVE_PATH: String = "user://save_v2.json"

# --- Run state ---
var stage: int = 1
var wave: int = 1               # current wave within stage
var soul_shards: int = 0
var current_phase: String = "menu"
var salvage_pit: Array = []
var party: Array = []
var pending_deliveries: Array = []
var last_battle_result: Dictionary = {}
var last_wave_result: Dictionary = {}
var stage_cleared: bool = false
var run_log: Array = []

# --- Meta state (persists) ---
var meta_upgrades: Dictionary = {
	"fleet_shade": 0,
	"master_polisher": 0,
	"patient_adventurers": 0,
	"sturdy_grip": 0,       # +weapon durability per level
	"adventurer_training": 0,
	"spirit_cannons": 0,
}

const UPGRADE_DEFS: Dictionary = {
	"fleet_shade": {"name": "Fleet Shade", "desc": "+15% ghost speed", "max": 5, "cost_base": 30, "cost_growth": 20},
	"master_polisher": {"name": "Master Polisher", "desc": "+10% repair quality", "max": 5, "cost_base": 40, "cost_growth": 25},
	"patient_adventurers": {"name": "Patient Adventurers", "desc": "+20% order patience", "max": 5, "cost_base": 35, "cost_growth": 20},
	"sturdy_grip": {"name": "Sturdy Grip", "desc": "+25 weapon durability", "max": 5, "cost_base": 50, "cost_growth": 30},
	"adventurer_training": {"name": "Adventurer Training", "desc": "+5% party combat IQ", "max": 5, "cost_base": 60, "cost_growth": 35},
	"spirit_cannons": {"name": "Spirit Cannons", "desc": "Unlock ghost abilities", "max": 3, "cost_base": 80, "cost_growth": 60},
}

func _ready() -> void:
	load_meta()

# === RUN LIFECYCLE ===
func start_new_run() -> void:
	stage = 1
	wave = 1
	soul_shards = 80
	salvage_pit.clear()
	party.clear()
	pending_deliveries.clear()
	last_battle_result.clear()
	last_wave_result.clear()
	stage_cleared = false
	run_log.clear()
	# Starter gear pool
	salvage_pit.append(GearItem.new("sword",  GearItem.State.BLOODIED, "Rusted Longsword",  "Found at dungeon entrance, blood still wet."))
	salvage_pit.append(GearItem.new("helm",   GearItem.State.RUSTED,   "Pitted Helm",        "Sat in standing water for a season."))
	salvage_pit.append(GearItem.new("staff",  GearItem.State.HAUNTED,  "Whispering Staff",   "Last wielder screams faintly at night."))
	salvage_pit.append(GearItem.new("robe",   GearItem.State.PRISTINE, "Traveler's Robe",    "Miraculously intact."))
	salvage_pit.append(GearItem.new("sword",  GearItem.State.CURSED,   "Knight's Bane",      "Cursed after Sir Galford's wipe."))
	# Apply sturdy_grip durability bonus to all starter gear
	for g in salvage_pit:
		g.durability_max = GearItem.BASE_DURABILITY + meta_upgrades["sturdy_grip"] * 25
		g.durability = g.durability_max
	run_log.append("Stage 1, Wave 1 — A new run begins. The dungeon stirs.")
	stage_changed.emit(stage)
	wave_changed.emit(wave)
	shards_changed.emit(soul_shards)
	salvage_changed.emit()

func next_wave() -> void:
	wave += 1
	if wave > WAVES_PER_STAGE:
		# Stage cleared!
		stage_cleared = true
		wave = 1
		stage += 1
		if stage > MAX_STAGE:
			# Run complete (win)
			return
		run_log.append("Stage %d cleared! Descending to stage %d..." % [stage - 1, stage])
	else:
		run_log.append("Wave %d of stage %d begins." % [wave, stage])
	# Clear party & tickets for next wave
	party.clear()
	pending_deliveries.clear()
	wave_changed.emit(wave)
	stage_changed.emit(stage)
	salvage_changed.emit()

# === CURRENCY ===
func add_shards(amount: int) -> void:
	soul_shards += amount
	shards_changed.emit(soul_shards)

func spend_shards(amount: int) -> bool:
	if soul_shards >= amount:
		soul_shards -= amount
		shards_changed.emit(soul_shards)
		return true
	return false

# === PHASE ===
func set_phase(p: String) -> void:
	current_phase = p
	phase_changed.emit(p)

# === PARTY ===
func spawn_party() -> void:
	party.clear()
	var classes := ["knight", "mage"]
	# Party size scales with stage
	var count := 2 + int(stage / 2)
	count = min(count, 4)
	for i in count:
		var cls: String = classes[i % classes.size()]
		var hp_max := 100 if cls == "knight" else 70
		# Scale HP with stage
		hp_max += (stage - 1) * 15
		party.append({
			"class": cls,
			"name": _random_name(i),
			"hp_max": hp_max,
			"hp": hp_max,
			"atk": (18 if cls == "knight" else 22) + (stage - 1) * 3,
			"def": (12 if cls == "knight" else 6) + (stage - 1) * 2,
			"equipped": {},
			"alive": true,
		})
	pending_deliveries.clear()
	for adv in party:
		var ticket := {}
		match adv["class"]:
			"knight": ticket = {"weapon": "sword", "armor": "helm"}
			"mage":   ticket = {"weapon": "staff", "armor": "robe"}
			_:        ticket = {"weapon": "sword", "armor": "helm"}
		pending_deliveries.append({
			"adventurer": adv,
			"needs": ticket,
			"patience": 60.0 + meta_upgrades["patient_adventurers"] * 12.0,
			"patience_max": 60.0 + meta_upgrades["patient_adventurers"] * 12.0,
			"fulfilled": {},
		})
	party_changed.emit()

func _random_name(seed_i: int) -> String:
	var names := ["Bram", "Wren", "Cael", "Mira", "Edric", "Solis", "Thora", "Quill", "Aldric", "Nyx"]
	return names[(stage + wave + seed_i) % names.size()]

# === GEAR POOL ===
func add_gear_to_pit(gear: GearItem) -> void:
	salvage_pit.append(gear)
	salvage_changed.emit()

func remove_gear_from_pit(gear: GearItem) -> void:
	salvage_pit.erase(gear)
	salvage_changed.emit()

func find_gear_in_pit(type: String, min_state: int = -1) -> GearItem:
	var best: Variant = null
	for g in salvage_pit:
		if g.type != type:
			continue
		if min_state >= 0 and g.state > min_state:
			continue
		if best == null or g.state < best.state:
			best = g
	return best

# === UPGRADE SHOP ===
func upgrade_cost(key: String) -> int:
	var def: Dictionary = UPGRADE_DEFS[key]
	var lvl: int = meta_upgrades[key]
	if lvl >= def["max"]:
		return -1
	return int(def["cost_base"]) + int(def["cost_growth"]) * lvl

func buy_upgrade(key: String) -> bool:
	var cost := upgrade_cost(key)
	if cost < 0:
		return false
	if not spend_shards(cost):
		return false
	meta_upgrades[key] += 1
	save_meta()
	return true

# === SAVE/LOAD ===
func save_meta() -> void:
	var data := {"meta_upgrades": meta_upgrades}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func load_meta() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("meta_upgrades"):
		meta_upgrades.merge(parsed["meta_upgrades"], true)

# === WIN/LOSE ===
func is_run_over() -> String:
	if stage > MAX_STAGE:
		return "win"
	return ""

# === ENEMY DIFFICULTY ===
func get_enemy_hp() -> int:
	return 25 + stage * 8 + wave * 3

func get_enemy_atk() -> int:
	return 8 + stage * 2 + wave

func get_enemy_count() -> int:
	return 2 + stage + int(wave / 2)
