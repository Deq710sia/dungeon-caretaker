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

# --- Gear state — FLAVOR ONLY. This does not gate repair anymore (see
# can_repair_at()). It exists purely to color history text and the dossier,
# tracking *what kind* of damage a weapon has narratively taken. The single
# mechanical truth for "can this be repaired, and how badly" is
# wear_state/durability above. Keeping these fully separate used to produce
# weapons stuck with no station willing to touch them: a weapon could be
# dinged down in wear_state/durability while this field never moved off
# Pristine, and every station used to gate on THIS field. Nothing gates on
# it now.
enum State { PRISTINE, BLOODIED, RUSTED, HAUNTED, CURSED, SHATTERED }
var state: int = State.PRISTINE

# How many deaths this weapon has witnessed without being cleansed at the
# Exorcise Altar. This is the one place "state" flavor DOES have a real
# mechanical consequence — see stat_multiplier() — and it's what makes the
# Altar meaningful independent of physical wear repair: a weapon can be
# fully repaired (wear_state PRISTINE) and still carry unexorcised dread.
var unexorcised_deaths: int = 0

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

## Rolls a death-cause-influenced affliction for a weapon whose wielder
## just died. This is LAYER 2 — applied ON TOP of the weapon's existing
## state when the owner dies in combat. The enemy type that killed the
## wielder influences which affliction the weapon picks up:
##
##   slime  — corrosive → skews DAMAGED (acid etches the metal)
##   skeleton — blunt trauma → skews BROKEN (bone weapons shatter gear)
##   bat    — swarm → skews BLOODIED (many small cuts, blood everywhere)
##
## The death also ALWAYS adds 1 unexorcised_death (the weapon was present
## for a death — it carries dread regardless of enemy type). So a weapon
## recovered from a slime kill is likely to need grind (corrosion) AND
## the Altar (haunt). This gives salvage a tactical read: different
## enemies leave different marks on the gear.
##
## Returns a dict with wear_state, unexorcised_deaths, durability_damage.
static func roll_affliction_from_death(enemy_type: String, current_wear: int) -> Dictionary:
	# Death always adds haunt — the weapon witnessed its wielder's end.
	var deaths := 1
	# Wear shift weights by enemy type. Death always pushes toward worse
	# wear, but the DIRECTION depends on the enemy.
	var wear_shift_weights: Dictionary = {
		"slime":     {WearState.WORN: 20, WearState.DAMAGED: 50, WearState.BROKEN: 30},
		"skeleton":  {WearState.WORN: 10, WearState.DAMAGED: 30, WearState.BROKEN: 60},
		"bat":       {WearState.WORN: 40, WearState.DAMAGED: 40, WearState.BROKEN: 20},
	}
	var weights: Dictionary = wear_shift_weights.get(enemy_type, wear_shift_weights["slime"])
	# Only roll shifts that are WORSE than current wear — a death can't
	# improve a weapon. Filter the weights to only include >= current.
	var filtered: Dictionary = {}
	var total := 0
	for ws in weights:
		if ws >= current_wear:
			filtered[ws] = weights[ws]
			total += weights[ws]
	if total == 0:
		# Already at max wear — death just confirms BROKEN.
		return {"wear_state": WearState.BROKEN, "unexorcised_deaths": deaths, "durability_damage_pct": 0.0}
	var roll := randi() % total
	var accumulated := 0
	var new_wear: int = current_wear
	for ws in filtered:
		accumulated += filtered[ws]
		if roll < accumulated:
			new_wear = ws
			break
	# Durability damage scales with how many wear tiers the death pushed.
	var tiers_dropped: int = new_wear - current_wear
	var dur_dmg_pct: float = tiers_dropped * 0.20  # 20% of max per tier dropped
	return {"wear_state": new_wear, "unexorcised_deaths": deaths, "durability_damage_pct": dur_dmg_pct}

## Simulates the first party's deaths (mathematically, no rendering) for
## the very first run. Returns an array of death records that the gate
## phase uses to populate grave markers AND to seed the starter weapons'
## afflictions. This replaces the hardcoded "Toren" and "Yselde" graves
## with a simulated party whose deaths explain why the arsenal is full
## of battered gear.
##
## The simulation:
##   1. Generates 2-3 random party members (random names, random classes)
##   2. For each, rolls a random enemy type they died to
##   3. Returns death records with name, class, enemy, and the weapon
##      affliction that death would produce (used to seed starter gear)
static func simulate_first_party_deaths() -> Array:
	var first_names := ["Bram", "Wren", "Cael", "Mira", "Edric", "Solis", "Thora", "Quill",
		"Harlan", "Isolde", "Corwin", "Vashti", "Petra", "Ambrose", "Sasha", "Lyra",
		"Gareth", "Eluned", "Roderick", "Fenella"]
	first_names.shuffle()
	var count := 2 + (randi() % 2)  # 2 or 3 predecessors
	var enemies: Array[String] = ["slime", "skeleton", "bat"]
	var deaths: Array = []
	for i in count:
		var cls := "knight" if i % 2 == 0 else "mage"
		var enemy: String = enemies[randi() % enemies.size()]
		var gear_type := "sword" if cls == "knight" else "staff"
		# The predecessor's gear is what the player will salvage — so its
		# affliction is determined by what killed its wielder.
		var affliction := roll_affliction_from_death(enemy, WearState.WORN)
		deaths.append({
			"name": first_names[i],
			"class": cls,
			"enemy": enemy,
			"gear_type": gear_type,
			"affliction": affliction,
		})
	return deaths

func _init(p_type: String = "sword", p_name: String = "Weapon", p_history: String = "") -> void:
	type = p_type
	display_name = p_name
	day_forged = GameState.stage if GameState else 1
	durability_max = BASE_DURABILITY
	durability = durability_max
	if p_history != "":
		history.append(p_history)

## Rolls a type-weighted affliction for a weapon. Returns a dict with:
##   state: int (flavor State enum)
##   wear_state: int (WearState enum — the mechanical truth that gates stations)
##   unexorcised_deaths: int (0 or 1 — whether it needs the Altar)
##   durability_pct: float (0.0-1.0 — starting durability as fraction of max)
##
## Type weights (player feedback polish):
##   - Everything has a baseline ~30% chance to be DAMAGED (needs grind).
##     This is the consistent baseline across all items — the player can
##     always expect some grind work.
##   - Weapons (sword, staff) skew toward BLOODIED flavor.
##   - Armor (helm, robe) skew slightly toward BROKEN/shattered (low-ish
##     chance, but higher than weapons).
##   - Mage gear (staff, robe) skews toward HAUNTED (needs Altar) —
##     magical gear holds more dread.
##   - Warrior gear (sword, helm) skews toward BLOODIED.
##
## Haunt is rolled ORTHOGONALLY — a weapon can be DAMAGED (needs grind)
## AND haunted (needs Altar). The blue wisps overlay on the sprite
## communicates this dual need.
static func roll_affliction(p_type: String) -> Dictionary:
	# --- Wear state weights (determines primary station need) ---
	# Baseline DAMAGED=30 for all types. Armor gets +5 BROKEN.
	var wear_weights: Dictionary = {
		"sword": {WearState.PRISTINE: 5, WearState.WORN: 15, WearState.DAMAGED: 30, WearState.BROKEN: 10},
		"staff": {WearState.PRISTINE: 5, WearState.WORN: 15, WearState.DAMAGED: 30, WearState.BROKEN: 8},
		"helm":  {WearState.PRISTINE: 5, WearState.WORN: 15, WearState.DAMAGED: 30, WearState.BROKEN: 15},
		"robe":  {WearState.PRISTINE: 5, WearState.WORN: 15, WearState.DAMAGED: 30, WearState.BROKEN: 15},
	}
	var weights: Dictionary = wear_weights.get(p_type, wear_weights["sword"])
	var total := 0
	for w in weights.values():
		total += w
	var roll := randi() % total
	var wear: int = WearState.DAMAGED
	var accumulated := 0
	for ws in weights:
		accumulated += weights[ws]
		if roll < accumulated:
			wear = ws
			break
	# --- Haunt chance (orthogonal — mage gear more likely) ---
	var haunt_chance: Dictionary = {
		"sword": 0.15,
		"staff": 0.35,
		"helm":  0.15,
		"robe":  0.35,
	}
	var haunted: bool = randf() < haunt_chance.get(p_type, 0.20)
	# --- Durability from wear state ---
	var dur_pct: float
	match wear:
		WearState.PRISTINE: dur_pct = 0.85
		WearState.WORN:     dur_pct = 0.50
		WearState.DAMAGED:  dur_pct = 0.35
		WearState.BROKEN:   dur_pct = 0.0
		_:                  dur_pct = 0.35
	# --- Flavor state from wear + haunt ---
	var flavor: int
	if wear == WearState.BROKEN:
		flavor = State.SHATTERED
	elif haunted:
		flavor = State.HAUNTED
	elif wear == WearState.PRISTINE:
		flavor = State.PRISTINE
	elif p_type in ["sword", "staff"]:
		flavor = State.BLOODIED
	else:
		flavor = State.RUSTED
	return {
		"state": flavor,
		"wear_state": wear,
		"unexorcised_deaths": 1 if haunted else 0,
		"durability_pct": dur_pct,
	}

func state_name() -> String:
	return STATE_NAMES[state]

func state_color() -> Color:
	return STATE_COLORS[state]

func wear_name() -> String:
	return WEAR_NAMES[wear_state]

func wear_color() -> Color:
	return WEAR_COLORS[wear_state]

## The single source of truth for "which stations can touch this weapon right
## now." Wear-tier stations (polish/oil_grind/reforge) are mutually exclusive
## — a weapon is at exactly one wear tier. The Altar is orthogonal: it's
## available any time the weapon carries unexorcised deaths, regardless of
## wear tier, so it never competes with physical repair for the player's
## attention.
func can_repair_at(station_key: String) -> bool:
	match station_key:
		"polish": return wear_state == WearState.WORN
		"oil_grind": return wear_state == WearState.DAMAGED
		"reforge": return wear_state == WearState.BROKEN
		"exorcise": return is_haunted()
	return false

## Which fingerprint stat a given station's minigame quality should write to.
func fingerprint_stat_for_station(station_key: String) -> String:
	match station_key:
		"polish": return "sharpness"
		"oil_grind": return "balance"
		"reforge": return "power"
		"exorcise": return "mystic"
	return ""

func is_haunted() -> bool:
	return unexorcised_deaths > 0

func stat_multiplier() -> float:
	# Combined multiplier from wear + authoring + unexorcised dread.
	# `state` no longer gates or scales anything mechanically — it's flavor
	# text only, tracked so history/dossier prose reads correctly. The one
	# real mechanical cost of a weapon's violent past is the haunting
	# penalty below, which ONLY the Altar clears.
	var wear_mult := 1.0
	match wear_state:
		WearState.PRISTINE: wear_mult = 1.0
		WearState.WORN: wear_mult = 0.85
		WearState.DAMAGED: wear_mult = 0.6
		WearState.BROKEN: wear_mult = 0.0
	# Authoring bonus (average of the 4 fingerprints, weighted)
	var authoring := (sharpness + balance + power + mystic) / 4.0
	var legendary_bonus := 0.05 if is_legendary else 0.0
	# -6% per unexorcised death, capped at -30% — real but never crippling,
	# and always fully recoverable at the Altar in one visit.
	var dread_penalty := clampf(float(unexorcised_deaths) * 0.06, 0.0, 0.30)
	return wear_mult * (0.7 + authoring * 0.3 + legendary_bonus) * (1.0 - dread_penalty)

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
	recalculate_wear(cause)

## Single source of truth for deriving wear_state from current durability_pct.
## Called after ANY durability change (damage OR repair) so the two can never
## drift out of sync with each other.
func recalculate_wear(cause: String = "") -> void:
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
	var was_broken := is_broken
	wear_state = new_wear
	if wear_state == WearState.BROKEN:
		if not is_broken:
			break_weapon(cause)
	elif was_broken:
		# Repaired back above 0% durability — it's no longer broken, though
		# the chronicle keeps the record of having shattered once.
		is_broken = false
		history.append("%s has been mended — no longer shattered, though it remembers." % display_name)

func break_weapon(cause: String = "") -> void:
	is_broken = true
	wear_state = WearState.BROKEN
	durability = 0
	var cause_text := cause if cause != "" else "catastrophic damage"
	history.append("SHATTERED on Stage %d Wave %d from %s!" % [GameState.stage, GameState.wave, cause_text])
	# Flavor only — does not gate anything.
	if state != State.SHATTERED:
		state = State.SHATTERED

## Graduated repair: how much of durability_max a single minigame pass
## restores, as a function of minigame quality (0-1) and the weapon's
## CURRENT condition. Shaped as a logistic curve (steep through the middle,
## flattening near both ends) rather than a binary threshold, so:
##  - a poor pass (low quality) never fully saves a bad weapon in one go
##  - a great pass still can't fully restore a heavily damaged weapon in a
##    single visit — durability accumulates real cost across a run instead
##    of resetting to full on any decent roll
## Capped at 0.6 (60 percentage points of durability_max) per pass, and
## further reduced when the weapon is nearly destroyed, so a Shattered
## weapon realistically takes more than one trip to the Forge.
func repair_curve(quality: float) -> float:
	var q := clampf(quality, 0.0, 1.0)
	var logistic := 1.0 / (1.0 + exp(-10.0 * (q - 0.5)))
	var restore := logistic * 0.6
	if durability_pct() < 0.15:
		restore *= 0.7
	return restore

## Applies one repair pass at the given quality, restoring durability along
## repair_curve() rather than snapping to full. Returns the actual amount of
## durability restored (for feedback/juice scaling).
func apply_repair(quality: float) -> int:
	var restore_pct := repair_curve(quality)
	var restored: int = int(durability_max * restore_pct)
	durability = min(durability_max, durability + restored)
	recalculate_wear()
	return restored

## Clears unexorcised dread — the Altar's actual job now that "exorcise"
## doesn't gate on the old CURSED/HAUNTED state.
func exorcise() -> void:
	if unexorcised_deaths > 0:
		history.append("Cleansed of %d unexorcised death(s) at the Altar." % unexorcised_deaths)
		unexorcised_deaths = 0

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

func apply_combat_damage(owner_died: bool, enemy_type: String = "") -> void:
	if owner_died:
		# Layer 2: death-cause-influenced affliction. The enemy type that
		# killed the wielder shifts the weapon's wear state in a direction
		# that matches that enemy's damage style (slime=corrosive→DAMAGED,
		# skeleton=blunt→BROKEN, bat=swarm→BLOODIED). Always adds 1
		# unexorcised_death regardless of enemy — the weapon witnessed a
		# death, so it carries dread.
		var death_affliction := roll_affliction_from_death(enemy_type, wear_state)
		unexorcised_deaths += death_affliction.unexorcised_deaths
		wear_state = death_affliction.wear_state
		if death_affliction.durability_damage_pct > 0.0:
			var dmg := int(durability_max * death_affliction.durability_damage_pct)
			durability = max(0, durability - dmg)
		if wear_state == WearState.BROKEN and not is_broken:
			break_weapon(enemy_type if enemy_type != "" else "slain in battle")
		# Flavor state from the death
		match wear_state:
			WearState.BROKEN: state = State.SHATTERED
			_:
				if unexorcised_deaths > 0:
					state = State.HAUNTED
				elif type in ["sword", "staff"]:
					state = State.BLOODIED
				else:
					state = State.RUSTED
		var enemy_label := enemy_type if enemy_type != "" else "the enemy"
		history.append("Worn during a death on Stage %d Wave %d — slain by %s. Now %s." % [GameState.stage, GameState.wave, enemy_label, state_name()])
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
	if is_haunted():
		lines.append("[%d unexorcised death(s) — Altar]" % unexorcised_deaths)
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
