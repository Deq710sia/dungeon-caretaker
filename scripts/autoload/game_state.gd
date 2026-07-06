extends Node
## GameState V6 — weapon-centric model with persistent party + recruit system.
## The weapon is the persistent, named, degrading object the player invests in.
## Structure: 5 stages, each wave running a battle -> results -> aftermath ->
## salvage -> workshop -> upgrade -> planning loop (gear is collected and
## repaired BEFORE it's assigned and taken into the next battle).
##
## V5 changes:
## - Party persists across waves (no more party.clear() in next_wave()).
## - is_run_over() returns "lose" when the whole party is wiped.
## - spawn_party() only spawns if the party has no living members.
## - New: can_recruit(), recruit_cost(), recruit_adventurer(), living_party_count().

signal stage_changed(new_stage: int)
signal wave_changed(new_wave: int)
signal shards_changed(new_count: int)
signal phase_changed(new_phase: String)
signal party_changed
signal arsenal_changed

const MAX_STAGE: int = 5
const WAVES_PER_STAGE: int = 3
const MAX_PARTY_SIZE: int = 4
const SAVE_PATH: String = "user://save_v3.json"

# --- Run state ---
var stage: int = 1
var wave: int = 1
var soul_shards: int = 0
var current_phase: String = "menu"
var arsenal: Array = []  # Array[Weapon] — the player's persistent weapon inventory
var party: Array = []     # Array[Dictionary] — persists across waves; dead members stay dead
var last_battle_result: Dictionary = {}
var run_log: Array = []

# --- Meta state (persists) ---
var meta_upgrades: Dictionary = {
        "fleet_shade": 0,
        "master_forge": 0,
        "sturdy_grip": 0,
        "adventurer_training": 0,
        "salvage_expert": 0,
        "ghost_resilience": 0,
}

const UPGRADE_DEFS: Dictionary = {
        "fleet_shade": {"name": "Fleet Shade", "desc": "+15% ghost speed", "max": 5, "cost_base": 30, "cost_growth": 20},
        "master_forge": {"name": "Master Forge", "desc": "+10% repair quality", "max": 5, "cost_base": 40, "cost_growth": 25},
        "sturdy_grip": {"name": "Sturdy Grip", "desc": "+25 max durability", "max": 5, "cost_base": 50, "cost_growth": 30},
        "adventurer_training": {"name": "Adventurer Training", "desc": "+5% combat skill", "max": 5, "cost_base": 60, "cost_growth": 35},
        "salvage_expert": {"name": "Salvage Expert", "desc": "+1 salvage slot", "max": 3, "cost_base": 45, "cost_growth": 25},
        "ghost_resilience": {"name": "Ghost Resilience", "desc": "+1 max ghost HP in salvage", "max": 3, "cost_base": 35, "cost_growth": 20},
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
        # Starter weapons — use the weighted roll_affliction system.
        # No more hardcoded states or guaranteed haunts. Each starter rolls
        # independently, so every run starts with a different mix of stations
        # to visit. The roll biases toward bad states (PRISTINE is rare), so
        # starters will always need repair — just different stations each run.
        #
        # Type weights (see Weapon.roll_affliction):
        #   - All types: ~30% baseline DAMAGED (needs grind)
        #   - Weapons (sword, staff): skew BLOODIED flavor
        #   - Armor (helm, robe): slightly more BROKEN (shattered)
        #   - Mage gear (staff, robe): 35% haunt chance (needs Altar)
        #   - Warrior gear (sword, helm): 15% haunt chance
        var w1 := Weapon.new("sword", "Rusted Longsword", "Found at the dungeon entrance, blood still wet.")
        var a1 := Weapon.roll_affliction("sword")
        w1.state = a1.state
        w1.wear_state = a1.wear_state
        w1.unexorcised_deaths = a1.unexorcised_deaths
        w1.sharpness = 0.2
        w1.balance = 0.3
        w1.power = 0.2
        w1.mystic = 0.2
        var w2 := Weapon.new("staff", "Whispering Staff", "Last wielder screams faintly at night.")
        var a2 := Weapon.roll_affliction("staff")
        w2.state = a2.state
        w2.wear_state = a2.wear_state
        w2.unexorcised_deaths = a2.unexorcised_deaths
        w2.sharpness = 0.3
        w2.balance = 0.2
        w2.power = 0.3
        w2.mystic = 0.2
        var w3 := Weapon.new("helm", "Pitted Helm", "Sat in standing water for a season.")
        var a3 := Weapon.roll_affliction("helm")
        w3.state = a3.state
        w3.wear_state = a3.wear_state
        w3.unexorcised_deaths = a3.unexorcised_deaths
        w3.sharpness = 0.2
        w3.balance = 0.2
        w3.power = 0.2
        w3.mystic = 0.3
        var w4 := Weapon.new("robe", "Traveler's Robe", "Miraculously intact. Smells of lavender.")
        var a4 := Weapon.roll_affliction("robe")
        w4.state = a4.state
        w4.wear_state = a4.wear_state
        w4.unexorcised_deaths = a4.unexorcised_deaths
        w4.sharpness = 0.3
        w4.balance = 0.3
        w4.power = 0.2
        w4.mystic = 0.3
        arsenal.append(w1)
        arsenal.append(w2)
        arsenal.append(w3)
        arsenal.append(w4)
        # Apply durability from the rolled affliction. Set is_broken directly
        # for BROKEN weapons (avoids the break_weapon history entry which
        # would say "SHATTERED on Stage 1 Wave 1 from catastrophic damage" —
        # these weapons START broken, they didn't break in combat).
        var afflictions := [a1, a2, a3, a4]
        for i in arsenal.size():
                var w: Weapon = arsenal[i]
                var a: Dictionary = afflictions[i]
                w.durability_max = Weapon.BASE_DURABILITY + meta_upgrades["sturdy_grip"] * 25
                w.durability = int(w.durability_max * a.durability_pct)
                if a.wear_state == Weapon.WearState.BROKEN:
                        w.is_broken = true
        # Spawn the initial party
        spawn_party()
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
        # NOTE: party is NOT cleared — it persists across waves. Dead members stay
        # dead; survivors keep their HP and gear assignments. The player must
        # recruit at the shrine (planning phase) to replace the fallen.
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
func living_party_count() -> int:
        var count := 0
        for adv in party:
                if adv.get("alive", false):
                        count += 1
        return count

func spawn_party() -> void:
        # Only spawn if there are no living members — this preserves survivors
        # across waves and after recruits. Called by start_new_run() for a fresh
        # party, and defensively by phases if something went wrong.
        if living_party_count() > 0:
                return
        # Clear out any dead entries so we start fresh
        party.clear()
        var classes := ["knight", "mage"]
        var count := 2 + int(stage / 2)
        count = min(count, MAX_PARTY_SIZE)
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
                        "equipped_armor": null,   # Weapon (armor is also a Weapon type)
                        "alive": true,
                })
        party_changed.emit()

func _random_name(seed_i: int) -> String:
        var names := ["Bram", "Wren", "Cael", "Mira", "Edric", "Solis", "Thora", "Quill"]
        return names[(stage + wave + seed_i) % names.size()]

# === RECRUITING ===
## Can recruit if: at least one living member (to vouch) AND party isn't full.
## A wiped party can't recruit — that's the lose condition.
func can_recruit() -> bool:
        return living_party_count() > 0 and living_party_count() < MAX_PARTY_SIZE

func recruit_cost() -> int:
        # Scales with stage so late-game recruits feel like an investment.
        return 40 + stage * 10

func recruit_adventurer() -> bool:
        if not can_recruit():
                return false
        var cost := recruit_cost()
        if not spend_shards(cost):
                return false
        # Add a fresh adventurer (alternates class to keep balance)
        var living := living_party_count()
        var cls: String = "knight" if living % 2 == 0 else "mage"
        var hp_max := (100 if cls == "knight" else 70) + (stage - 1) * 15
        party.append({
                "class": cls,
                "name": _random_name(party.size()),
                "hp_max": hp_max,
                "hp": hp_max,
                "atk": (18 if cls == "knight" else 22) + (stage - 1) * 3,
                "def": (12 if cls == "knight" else 6) + (stage - 1) * 2,
                "equipped_weapon": null,
                "equipped_armor": null,
                "alive": true,
        })
        run_log.append("Recruited a new %s to the party." % cls)
        party_changed.emit()
        return true

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
        # A fully wiped party ends the run — the shrine can't recruit without a
        # living vouch, so there's no recovery.
        if living_party_count() == 0:
                return "lose"
        return ""

# === ENEMY DIFFICULTY ===
# Tuned so Stage 1 is a real fight against starter gear, not a formality —
# the whole loop is built around losing crew and gradually improving weapons
# across several attempts, so the first breakthrough should take a few
# failed (or retreated-from) waves, not one clean run.
func get_enemy_hp() -> int:
        return 100 + stage * 20 + wave * 10

func get_enemy_atk() -> int:
        return 20 + stage * 5 + wave * 3

func get_enemy_count() -> int:
        return 5 + stage + int(wave / 2)
