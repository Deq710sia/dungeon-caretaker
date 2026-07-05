extends Node
## GameState V3 — weapon-centric model.
## The weapon is the persistent, named, degrading object the player invests in.
## Structure: 5 stages, each with a planning -> salvage -> workshop -> battle -> results loop.

signal stage_changed(new_stage: int)
signal wave_changed(new_wave: int)
signal shards_changed(new_count: int)
signal phase_changed(new_phase: String)
signal party_changed
signal arsenal_changed

const MAX_STAGE: int = 5
const WAVES_PER_STAGE: int = 3
const SAVE_PATH: String = "user://save_v3.json"

# --- Run state ---
var stage: int = 1
var wave: int = 1
var soul_shards: int = 0
var current_phase: String = "menu"
var arsenal: Array = []  # Array[Weapon] — the player's persistent weapon inventory
var party: Array = []
var last_battle_result: Dictionary = {}
var run_log: Array = []

# --- Meta state (persists) ---
var meta_upgrades: Dictionary = {
	"fleet_shade": 0,
	"master_forge": 0,
	"sturdy_grip": 0,
	"adventurer_training": 0,
	"salvage_expert": 0,
}

const UPGRADE_DEFS: Dictionary = {
	"fleet_shade": {"name": "Fleet Shade", "desc": "+15% ghost speed in salvage", "max": 5, "cost_base": 30, "cost_growth": 20},
	"master_forge": {"name": "Master Forge", "desc": "+10% repair quality", "max": 5, "cost_base": 40, "cost_growth": 25},
	"sturdy_grip": {"name": "Sturdy Grip", "desc": "+25 weapon max durability", "max": 5, "cost_base": 50, "cost_growth": 30},
	"adventurer_training": {"name": "Adventurer Training", "desc": "+5% party combat skill", "max": 5, "cost_base": 60, "cost_growth": 35},
	"salvage_expert": {"name": "Salvage Expert", "desc": "+1 salvage slot, better finds", "max": 3, "cost_base": 45, "cost_growth": 25},
}

func _ready() -> void:
	load_meta()

# === RUN LIFECYCLE ===
func start_new_run() -> void:
	stage = 1
	wave = 1
	soul_shards = 100
	arsenal.clear()
	party.clear()
	last_battle_result.clear()
	run_log.clear()
	# Starter weapons — each named, day-stamped, with personality
	arsenal.append(Weapon.new("sword", "Rusted Longsword", "Found at the dungeon entrance, blood still wet."))
	arsenal.append(Weapon.new("staff", "Whispering Staff", "Last wielder screams faintly at night."))
	arsenal.append(Weapon.new("helm", "Pitted Helm", "Sat in standing water for a season."))
	arsenal.append(Weapon.new("robe", "Traveler's Robe", "Miraculously intact. Smells of lavender."))
	# Apply upgrades
	for w in arsenal:
		w.durability_max = Weapon.BASE_DURABILITY + meta_upgrades["sturdy_grip"] * 25
		w.durability = int(w.durability_max * 0.6)
	run_log.append("Stage 1, Wave 1 — A new run begins.")
	stage_changed.emit(stage)
	wave_changed.emit(wave)
	shards_changed.emit(soul_shards)
	arsenal_changed.emit()

func next_wave() -> void:
	wave += 1
	if wave > WAVES_PER_STAGE:
		stage += 1
		wave = 1
		if stage > MAX_STAGE:
			return
		run_log.append("Stage %d cleared! Descending..." % (stage - 1))
	else:
		run_log.append("Wave %d begins." % wave)
	party.clear()
	wave_changed.emit(wave)
	stage_changed.emit(stage)
	arsenal_changed.emit()

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
	var count := 2 + int(stage / 2)
	count = min(count, 4)
	for i in count:
		var cls: String = classes[i % classes.size()]
		var hp_max := (100 if cls == "knight" else 70) + (stage - 1) * 15
		party.append({
			"class": cls,
			"name": _random_name(i),
			"hp_max": hp_max,
			"hp": hp_max,
			"atk": (18 if cls == "knight" else 22) + (stage - 1) * 3,
			"def": (12 if cls == "knight" else 6) + (stage - 1) * 2,
			"equipped_weapon": null,  # Weapon
			"equipped_armor": null,  # Weapon (armor is also a Weapon type)
			"alive": true,
		})
	party_changed.emit()

func _random_name(seed_i: int) -> String:
	var names := ["Bram", "Wren", "Cael", "Mira", "Edric", "Solis", "Thora", "Quill"]
	return names[(stage + wave + seed_i) % names.size()]

# === ARSENAL ===
func add_weapon(w: Weapon) -> void:
	arsenal.append(w)
	arsenal_changed.emit()

func remove_weapon(w: Weapon) -> void:
	arsenal.erase(w)
	arsenal_changed.emit()

# === UPGRADES ===
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
