class_name GearItem
extends RefCounted
## A single piece of gear with a state, history, and quality.
## Used by GameState.salvage_pit and adventurer.equipped.

enum State { PRISTINE, BLOODIED, RUSTED, HAUNTED, CURSED, SHATTERED }

const STATE_NAMES := {
	State.PRISTINE: "Pristine",
	State.BLOODIED: "Bloodied",
	State.RUSTED: "Rusted",
	State.HAUNTED: "Haunted",
	State.CURSED: "Cursed",
	State.SHATTERED: "Shattered",
}

const STATE_COLORS := {
	State.PRISTINE: Color(0.85, 0.95, 0.85),    # pale green
	State.BLOODIED: Color(0.85, 0.45, 0.45),    # red
	State.RUSTED:   Color(0.75, 0.55, 0.30),    # orange-brown
	State.HAUNTED:  Color(0.55, 0.75, 0.95),    # icy blue
	State.CURSED:   Color(0.65, 0.40, 0.85),    # purple
	State.SHATTERED: Color(0.45, 0.45, 0.45),   # gray
}

const STATE_EMOJI := {
	State.PRISTINE: "OK",
	State.BLOODIED: "BLD",
	State.RUSTED:   "RST",
	State.HAUNTED:  "HNT",
	State.CURSED:   "CRS",
	State.SHATTERED: "SHT",
}

# Which repair station handles this state -> what state it transitions to
const REPAIR_TARGETS := {
	State.BLOODIED:  "polish",
	State.RUSTED:    "oil_grind",
	State.HAUNTED:   "exorcise",
	State.CURSED:    "exorcise",   # same minigame, harder variant (trace in reverse)
	State.SHATTERED: "reforge",
}

var type: String = "sword"   # "sword" | "staff" | "helm" | "robe"
var state: int = State.PRISTINE
var quality: float = 1.0     # 0.0–1.0, set by last repair minigame score
var display_name: String = "Item"
var history: Array = []      # Array[String] — flavor log
var last_owner: String = ""

func _init(p_type: String = "sword", p_state: int = State.PRISTINE, p_name: String = "Item", p_history: String = "") -> void:
	type = p_type
	state = p_state
	display_name = p_name
	if p_history != "":
		history.append(p_history)

func state_name() -> String:
	return STATE_NAMES[state]

func state_color() -> Color:
	return STATE_COLORS[state]

func stat_multiplier() -> float:
	match state:
		State.PRISTINE:  return 1.0
		State.BLOODIED:  return 0.8
		State.RUSTED:    return 0.7
		State.HAUNTED:   return 0.9
		State.CURSED:    return 0.6
		State.SHATTERED: return 0.0
		_:               return 1.0

func repair_target_station() -> String:
	return REPAIR_TARGETS.get(state, "")

func is_cursed_variant() -> bool:
	# Cursed uses the same exorcise minigame but with reverse-trace twist
	return state == State.CURSED

func apply_combat_damage(owner_died: bool) -> void:
	# Called when used in battle. If owner died, gear degrades more.
	if owner_died:
		match state:
			State.PRISTINE: state = State.HAUNTED
			State.BLOODIED: state = State.HAUNTED
			State.RUSTED:   state = State.SHATTERED
			State.HAUNTED:  state = State.CURSED
			State.CURSED:   state = State.SHATTERED
			State.SHATTERED: pass
		history.append("Worn during a death on Day %d. Now %s." % [GameState.day, state_name()])
	else:
		match state:
			State.PRISTINE: state = State.BLOODIED
			State.BLOODIED: pass
			State.RUSTED:   pass
			State.HAUNTED:  pass
			State.CURSED:   pass
			State.SHATTERED: pass
		if state == State.BLOODIED:
			history.append("Damaged in combat on Day %d." % GameState.day)

func deliver_to(adventurer: Dictionary) -> void:
	# Move this gear into an adventurer's equipped slot.
	last_owner = adventurer.get("name", "")
	if not adventurer.has("equipped"):
		adventurer["equipped"] = {}
	# Determine slot by type
	var slot: String = "weapon"
	match type:
		"helm", "robe": slot = "armor"
		_: slot = "weapon"
	adventurer["equipped"][slot] = self

func serialize() -> Dictionary:
	return {
		"type": type,
		"state": state,
		"quality": quality,
		"display_name": display_name,
		"history": history,
		"last_owner": last_owner,
	}
