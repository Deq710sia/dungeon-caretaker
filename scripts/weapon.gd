class_name Weapon
extends RefCounted
## Weapon V5 — the persistent, named, degrading object the player invests in.
## This is the emotional anchor of the game. Each weapon has:
## - A unique name (procedurally generated with personality)
## - A day-stamp (when it was forged/found)
## - A wielder binding (who it's assigned to)
## - 4 discrete wear states with distinct art
## - A kill log (enemies slain, waves survived)
## - Authoring scores (fingerprint of how it was crafted)
## - A full narrative history (see get_full_history()) — retained as a memento
##   when broken, never deleted.

enum WearState { PRISTINE = 0, WORN = 1, DAMAGED = 2, BROKEN = 3 }

const WEAR_NAMES := {
	WearState.PRISTINE: "Pristine",
	WearState.WORN: "Worn",
	WearState.DAMAGED: "Damaged",
	WearState.BROKEN: "Shattered",
}

# Colors are sourced from Palette (single source of truth) rather than
# duplicated here, so retuning the palette can't silently drift out of sync.
const WEAR_COLORS := {
	WearState.PRISTINE: Palette.WEAR_PRISTINE,
	WearState.WORN: Palette.WEAR_WORN,
	WearState.DAMAGED: Palette.WEAR_DAMAGED,
	WearState.BROKEN: Palette.WEAR_BROKEN,
}

const BASE_DURABILITY: int = 100
const LEGENDARY_KILL_THRESHOLD: int = 8  # kills at which a weapon earns an epithet

# --- Identity (persistent) ---
var type: String = "sword"  # "sword" | "staff" | "helm" | "robe"
var display_name: String = "Weapon"
var day_forged: int = 1
var wielder: String = ""  # adventurer name
var is_broken: bool = false
var kill_log: Array = []  # Array[String] — enemies slain
var waves_survived: int = 0
var history: Array = []  # Array[String] — flavor log, shown in the dossier detail view
var break_announced: bool = false  # internal flag; kept OUT of history so the
                                    # player-facing chronicle never leaks bookkeeping text
var is_legendary: bool = false

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
	State.BLOODIED: Palette.STATE_BLOODIED,
	State.RUSTED: Palette.STATE_RUSTED,
	State.HAUNTED: Palette.STATE_HAUNTED,
	State.CURSED: Palette.STATE_CURSED,
	State.SHATTERED: Palette.STATE_SHATTERED,
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
	var legendary_bonus := 0.05 if is_legendary else 0.0
	return state_mult * wear_mult * (0.7 + authoring * 0.3 + legendary_bonus)

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
	if not is_legendary and kill_log.size() >= LEGENDARY_KILL_THRESHOLD:
		is_legendary = true
		history.append("%s has drunk enough blood to earn a legend. It will not be forgotten." % display_name)

func survive_wave() -> void:
	waves_survived += 1

## Assigns this weapon to an adventurer, unequipping it from whoever held it
## before (if anyone). Encapsulated here so callers never have to touch
## adventurer dict keys directly (and can't typo "weapon" vs "equipped_weapon").
func deliver_to(adventurer: Dictionary, all_party: Array = []) -> void:
	var slot := "armor" if type in ["helm", "robe"] else "weapon"
	var slot_key := "equipped_" + slot
	# Unequip from whoever had it before (search the given party, if provided)
	if wielder != "":
		for other in all_party:
			if other.get(slot_key) == self:
				other[slot_key] = null
	adventurer[slot_key] = self
	wielder = adventurer.get("name", "")

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

## A one-line flavor descriptor from the authoring fingerprints, so sharpness/
## balance/power/mystic actually surface somewhere instead of being an
## invisible multiplier. Used in the dossier detail view.
func authoring_blurb() -> String:
	var traits := []
	if sharpness >= 0.75: traits.append("razor-sharp")
	elif sharpness <= 0.25: traits.append("dull")
	if balance >= 0.75: traits.append("perfectly balanced")
	elif balance <= 0.25: traits.append("clumsy in the hand")
	if power >= 0.75: traits.append("powerfully forged")
	elif power <= 0.25: traits.append("weakly tempered")
	if mystic >= 0.75: traits.append("humming with old magic")
	elif mystic <= 0.25: traits.append("spiritually inert")
	if traits.is_empty():
		return "An unremarkable piece of work — competent, forgettable."
	return "This piece is " + ", ".join(traits) + "."

func get_dossier_text() -> String:
	# A short summary for the dossier card
	var lines := []
	var name_line := display_name
	if is_legendary:
		name_line = "★ " + display_name + " ★"
	lines.append("%s — %s" % [name_line, wear_name()])
	lines.append("Forged Stage %d | Wielder: %s" % [day_forged, wielder if wielder != "" else "unassigned"])
	lines.append("Kills: %d | Waves survived: %d" % [kill_log.size(), waves_survived])
	if is_broken:
		lines.append("[BROKEN — reforgable]")
	return "\n".join(lines)

## The FULL narrative log for the detail popup — every line ever appended to
## history, in order, plus the authoring blurb and kill log. This is where all
## that flavor text players never used to see actually gets read.
func get_full_history() -> String:
	var lines := []
	lines.append(get_dossier_text())
	lines.append("")
	lines.append(authoring_blurb())
	if kill_log.size() > 0:
		lines.append("")
		lines.append("Kill log: " + ", ".join(kill_log))
	if history.size() > 0:
		lines.append("")
		lines.append("Chronicle:")
		for h in history:
			lines.append("- " + h)
	return "\n".join(lines)
