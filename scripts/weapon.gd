class_name Weapon
extends RefCounted
## Weapon V3 — the persistent, named, degrading object the player invests in.
## This is the emotional anchor of the game. Each weapon has:
## - A unique name (procedurally generated with personality)
## - A day-stamp (when it was forged/found)
## - A wielder binding (who it's assigned to)
## - 4 discrete wear states with distinct art
## - A kill log (enemies slain, waves survived)
## - Authoring scores (fingerprint of how it was crafted)
## - Retained as memento when broken (never deleted)

enum WearState { PRISTINE = 0, WORN = 1, DAMAGED = 2, BROKEN = 3 }

const WEAR_NAMES := {
	WearState.PRISTINE: "Pristine",
	WearState.WORN: "Worn",
	WearState.DAMAGED: "Damaged",
	WearState.BROKEN: "Shattered",
}

const WEAR_COLORS := {
	WearState.PRISTINE: Color(0.55, 0.95, 0.55),
	WearState.WORN: Color(0.95, 0.85, 0.40),
	WearState.DAMAGED: Color(0.95, 0.55, 0.30),
	WearState.BROKEN: Color(0.55, 0.30, 0.30),
}

const BASE_DURABILITY: int = 100

# --- Identity (persistent) ---
var type: String = "sword"  # "sword" | "staff" | "helm" | "robe"
var display_name: String = "Weapon"
var day_forged: int = 1
var wielder: String = ""  # adventurer name
var is_broken: bool = false
var kill_log: Array = []  # Array[String] — enemies slain
var waves_survived: int = 0
var history: Array = []  # Array[String] — flavor log

# --- Condition (degrades, repairable) ---
var wear_state: int = WearState.PRISTINE
var durability_max: int = 100
var durability: int = 100

# --- Authoring fingerprint (set by crafting minigames) ---
var sharpness: float = 0.5     # 0-1, from polish/hone minigame
var balance: float = 0.5       # 0-1, from oil/grindstone minigame
var power: float = 0.5         # 0-1, from reforge minigame
var mystic: float = 0.5        # 0-1, from exorcise minigame

# --- Gear state (V2 compat — used for repair station routing) ---
enum State { PRISTINE, BLOODIED, RUSTED, HAUNTED, CURSED, SHATTERED }
var state: int = State.PRISTINE

const STATE_NAMES := {
	State.PRISTINE: "Pristine",
	State.BLOODIED: "Bloodied",
	State.RUSTED: "Rusted",
	State.HAUNTED: "Haunted",
	State.CURSED: "Cursed",
	State.SHATTERED: "Shattered",
}

const STATE_COLORS := {
	State.PRISTINE: Color(0.85, 0.95, 0.85),
	State.BLOODIED: Color(0.85, 0.45, 0.45),
	State.RUSTED: Color(0.75, 0.55, 0.30),
	State.HAUNTED: Color(0.55, 0.75, 0.95),
	State.CURSED: Color(0.65, 0.40, 0.85),
	State.SHATTERED: Color(0.45, 0.45, 0.45),
}

const STATE_EMOJI := {
	State.PRISTINE: "OK",
	State.BLOODIED: "BLD",
	State.RUSTED: "RST",
	State.HAUNTED: "HNT",
	State.CURSED: "CRS",
	State.SHATTERED: "SHT",
}

const REPAIR_TARGETS := {
	State.BLOODIED: "polish",
	State.RUSTED: "oil_grind",
	State.HAUNTED: "exorcise",
	State.CURSED: "exorcise",
	State.SHATTERED: "reforge",
}

func _init(p_type: String = "sword", p_name: String = "Weapon", p_history: String = "") -> void:
	type = p_type
	display_name = p_name
	day_forged = GameState.stage if GameState else 1
	durability_max = BASE_DURABILITY
	durability = durability_max
	if p_history != "":
		history.append(p_history)

func state_name() -> String:
	return STATE_NAMES[state]

func state_color() -> Color:
	return STATE_COLORS[state]

func wear_name() -> String:
	return WEAR_NAMES[wear_state]

func wear_color() -> Color:
	return WEAR_COLORS[wear_state]

func repair_target_station() -> String:
	return REPAIR_TARGETS.get(state, "")

func is_cursed_variant() -> bool:
	return state == State.CURSED

func stat_multiplier() -> float:
	# Combined multiplier from state + wear + authoring
	var state_mult := 1.0
	match state:
		State.PRISTINE: state_mult = 1.0
		State.BLOODIED: state_mult = 0.8
		State.RUSTED: state_mult = 0.7
		State.HAUNTED: state_mult = 0.9
		State.CURSED: state_mult = 0.6
		State.SHATTERED: state_mult = 0.0
	var wear_mult := 1.0
	match wear_state:
		WearState.PRISTINE: wear_mult = 1.0
		WearState.WORN: wear_mult = 0.85
		WearState.DAMAGED: wear_mult = 0.6
		WearState.BROKEN: wear_mult = 0.0
	# Authoring bonus (average of the 4 fingerprints, weighted)
	var authoring := (sharpness + balance + power + mystic) / 4.0
	return state_mult * wear_mult * (0.7 + authoring * 0.3)

func durability_pct() -> float:
	if durability_max <= 0:
		return 0.0
	return float(durability) / float(durability_max)

func take_durability_damage(amount: int, cause: String = "") -> void:
	if is_broken:
		return
	durability = max(0, durability - amount)
	if cause != "":
		history.append("Took %d durability damage: %s" % [amount, cause])
	# Update wear state based on durability pct
	var pct := durability_pct()
	var new_wear: int
	if pct > 0.75:
		new_wear = WearState.PRISTINE
	elif pct > 0.40:
		new_wear = WearState.WORN
	elif pct > 0.0:
		new_wear = WearState.DAMAGED
	else:
		new_wear = WearState.BROKEN
	if new_wear != wear_state:
		wear_state = new_wear
		if wear_state == WearState.BROKEN and not is_broken:
			break_weapon(cause)

func break_weapon(cause: String = "") -> void:
	is_broken = true
	wear_state = WearState.BROKEN
	durability = 0
	var cause_text := cause if cause != "" else "catastrophic damage"
	history.append("SHATTERED on Stage %d Wave %d from %s!" % [GameState.stage, GameState.wave, cause_text])
	# Degrade state too
	if state != State.SHATTERED:
		state = State.SHATTERED

func record_kill(enemy_type: String) -> void:
	kill_log.append(enemy_type)

func survive_wave() -> void:
	waves_survived += 1

func deliver_to(adventurer: Dictionary) -> void:
	wielder = adventurer.get("name", "")
	# Determine slot by type
	var slot: String = "weapon"
	match type:
		"helm", "robe": slot = "armor"
		_: slot = "weapon"
	adventurer[slot] = self

func apply_combat_damage(owner_died: bool) -> void:
	if owner_died:
		match state:
			State.PRISTINE: state = State.HAUNTED
			State.BLOODIED: state = State.HAUNTED
			State.RUSTED: state = State.SHATTERED
			State.HAUNTED: state = State.CURSED
			State.CURSED: state = State.SHATTERED
			State.SHATTERED: pass
		history.append("Worn during a death on Stage %d Wave %d. Now %s." % [GameState.stage, GameState.wave, state_name()])
	else:
		if state == State.PRISTINE:
			state = State.BLOODIED
			history.append("Damaged in combat on Stage %d Wave %d." % [GameState.stage, GameState.wave])

func get_dossier_text() -> String:
	# A short summary for the dossier card
	var lines := []
	lines.append("%s — %s" % [display_name, wear_name()])
	lines.append("Forged Stage %d | Wielder: %s" % [day_forged, wielder if wielder != "" else "unassigned"])
	lines.append("Kills: %d | Waves survived: %d" % [kill_log.size(), waves_survived])
	if is_broken:
		lines.append("[BROKEN — reforgable]")
	return "\n".join(lines)
