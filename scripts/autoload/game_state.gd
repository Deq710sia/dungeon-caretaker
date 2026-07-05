extends Node
## GameState — singleton autoload that owns all run + meta state.
## Persists between scenes. Save/load for meta-upgrades only.

signal day_changed(new_day: int)
signal shards_changed(new_count: int)
signal phase_changed(new_phase: String)
signal party_changed
signal salvage_changed

const MAX_DAY: int = 30
const SAVE_PATH: String = "user://save.json"

# --- Run state (resets each run) ---
var day: int = 1
var soul_shards: int = 0
var current_phase: String = "menu"
var salvage_pit: Array = []   # Array[GearItem]
var party: Array = []          # Array[Dictionary] (adventurer specs + equipped gear)
var pending_deliveries: Array = []  # tickets still open today
var last_battle_result: Dictionary = {}

# --- Meta state (persists) ---
var meta_upgrades: Dictionary = {
        "fleet_shade": 0,
        "master_polisher": 0,
        "patient_adventurers": 0,
        "trap_clearance": 0,
        "adventurer_training": 0,
        "spirit_cannons": 0,
}

const UPGRADE_DEFS: Dictionary = {
        "fleet_shade": {"name": "Fleet Shade", "desc": "+15% ghost move speed per level", "max": 5, "cost_base": 30, "cost_growth": 20},
        "master_polisher": {"name": "Master Polisher", "desc": "+10% quality on Polish Bench", "max": 5, "cost_base": 40, "cost_growth": 25},
        "patient_adventurers": {"name": "Patient Adventurers", "desc": "+20% order patience per level", "max": 5, "cost_base": 35, "cost_growth": 20},
        "trap_clearance": {"name": "Trap Clearance", "desc": "-1 trap per dungeon level", "max": 5, "cost_base": 50, "cost_growth": 30},
        "adventurer_training": {"name": "Adventurer Training", "desc": "+5% party combat IQ per level", "max": 5, "cost_base": 60, "cost_growth": 35},
        "spirit_cannons": {"name": "Spirit Cannons", "desc": "Unlock ghost support abilities", "max": 3, "cost_base": 80, "cost_growth": 60},
}

# --- Run history / flavor ---
var run_log: Array = []

func _ready() -> void:
        load_meta()

# --- Run lifecycle ---
func start_new_run() -> void:
        day = 1
        soul_shards = 50
        salvage_pit.clear()
        party.clear()
        pending_deliveries.clear()
        last_battle_result.clear()
        run_log.clear()
        # Starter gear — a mix of states so the player sees every minigame early
        salvage_pit.append(GearItem.new("sword",  GearItem.State.BLOODIED, "Rusted Longsword", "Found near the entrance, dried blood on the edge."))
        salvage_pit.append(GearItem.new("helm",   GearItem.State.RUSTED,   "Pitted Helm",       "Sat in standing water for a season."))
        salvage_pit.append(GearItem.new("staff",  GearItem.State.HAUNTED,  "Whispering Staff",  "Last wielder screams faintly at night."))
        salvage_pit.append(GearItem.new("robe",   GearItem.State.PRISTINE, "Traveler's Robe",   "Miraculously intact. Smells of lavender."))
        salvage_pit.append(GearItem.new("sword",  GearItem.State.CURSED,   "Knight's Bane",     "Cursed after Sir Galford's party wiped on Day 3."))
        run_log.append("Day 1 — A new party arrives. The dungeon stirs.")
        day_changed.emit(day)
        shards_changed.emit(soul_shards)
        salvage_changed.emit()

func next_day() -> void:
        day += 1
        # Daily decay: any unrevitalized Bloodied/Rusted gear gets worse
        for gear in salvage_pit:
                if gear.state == GearItem.State.BLOODIED:
                        gear.state = GearItem.State.RUSTED
                        gear.history.append("Decayed to rusted on Day %d." % day)
                elif gear.state == GearItem.State.RUSTED:
                        gear.state = GearItem.State.SHATTERED
                        gear.history.append("Crumbled to shattered on Day %d." % day)
        # Clear party & tickets for the new day
        party.clear()
        pending_deliveries.clear()
        day_changed.emit(day)
        salvage_changed.emit()

# --- Currency ---
func add_shards(amount: int) -> void:
        soul_shards += amount
        shards_changed.emit(soul_shards)

func spend_shards(amount: int) -> bool:
        if soul_shards >= amount:
                soul_shards -= amount
                shards_changed.emit(soul_shards)
                return true
        return false

# --- Phase ---
func set_phase(p: String) -> void:
        current_phase = p
        phase_changed.emit(p)

# --- Party management ---
func spawn_party() -> void:
        # 3-4 adventurers; mix of knight/mage based on day
        party.clear()
        var classes := ["knight", "mage"]
        var count := 3 + (1 if day >= 15 else 0)
        for i in count:
                var cls: String = classes[i % classes.size()]
                party.append({
                        "class": cls,
                        "name": _random_name(i),
                        "hp_max": 100 if cls == "knight" else 70,
                        "hp": 100 if cls == "knight" else 70,
                        "atk": 18 if cls == "knight" else 22,
                        "def": 12 if cls == "knight" else 6,
                        "equipped": {},   # type -> GearItem
                        "alive": true,
                })
        # Build order tickets
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
        return names[(day + seed_i) % names.size()]

# --- Gear pool helpers ---
func add_gear_to_pit(gear: GearItem) -> void:
        salvage_pit.append(gear)
        salvage_changed.emit()

func remove_gear_from_pit(gear: GearItem) -> void:
        salvage_pit.erase(gear)
        salvage_changed.emit()

func find_gear_in_pit(type: String, min_state: int = -1) -> GearItem:
        # Returns first matching gear (lowest state first if min_state not specified)
        var best: Variant = null
        for g in salvage_pit:
                if g.type != type:
                        continue
                if min_state >= 0 and g.state > min_state:
                        continue
                if best == null or g.state < best.state:
                        best = g
        return best

# --- Upgrade shop ---
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

# --- Save/Load (meta only) ---
func save_meta() -> void:
        var data := {
                "meta_upgrades": meta_upgrades,
        }
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

# --- Win/Lose ---
func is_run_over() -> String:
        # Returns "" if running, "win" / "lose" if over
        if day > MAX_DAY:
                var survivors := 0
                for adv in party:
                        if adv.get("alive", false):
                                survivors += 1
                return "win" if survivors > 0 else "lose"
        return ""
