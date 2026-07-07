class_name DungeonGen
extends RefCounted
## DungeonGen — single source of truth for all dungeon generation.
## Handles: corridor length, width segments (wide/narrow zones), hazard
## placement, noise seeds for floor detail, and BRANCHING PATHS.
##
## The dungeon has a fork point at `fork_y`. Above the fork is the main
## corridor. At the fork, the player chooses:
##   - Continue to the EXIT (safe path, main exit at fork_y)
##   - Enter the DEEPER gate (risky path, one-way commitment)
##
## The deeper path is a separate corridor segment below the fork with:
##   - Narrower width (6-8 tiles, not 18)
##   - Denser hazards (2x the hazard density)
##   - Better gear (special corpses with legendary/cursed weapons)
##   - A separate exit at the bottom (the only way out once you commit)
##
## The generation persists for an entire stage — battle and salvage both
## read from the same DungeonGen instance.

var stage: int = 1
var corridor_w: int = 12  # was 18 — narrower main corridor makes hazards harder to avoid
var corridor_h: int = 60
var narrow_zones: Array = []
var hazards: Array = []
var noise_seed: int = 0
var _noise: FastNoiseLite

# --- Branching path data ---
var fork_y: int = 30            # y-tile where the fork occurs (main exit is here)
var deeper_h: int = 20          # length of the deeper corridor segment
var deeper_w: int = 8           # width of the deeper corridor (narrow)
var deeper_offset: int = 5      # x-offset of the deeper corridor (shifted right)
var deeper_hazards: Array = []  # hazards in the deeper section (denser)
var deeper_gate_pos: Vector2    # tile coords of the one-way gate to deeper
var deeper_exit_pos: Vector2    # tile coords of the deeper exit (bottom)

func _init(p_stage: int = 1, fallen_count: int = 0, salvage_expert: int = 0) -> void:
	stage = p_stage
	_generate(fallen_count, salvage_expert)

func _generate(fallen_count: int, salvage_expert: int) -> void:
	# --- Corridor length: clamped to weapon count + variance ---
	var bonus_count: int = 1 + int(stage / 3) + salvage_expert
	var weapon_count: int = fallen_count + bonus_count
	if weapon_count < 2:
		weapon_count = 2 + int(stage / 2)
	# Main corridor is shorter now (exit is at midpoint). The deeper
	# section adds length below the fork.
	var main_h: int = clampi(15 + weapon_count * 4 + randi() % 6, 15, 40)
	deeper_h = clampi(10 + stage * 3 + randi() % 5, 10, 30)
	corridor_h = main_h + deeper_h
	fork_y = main_h
	# --- Deeper path geometry ---
	deeper_w = 6 + randi() % 3  # 6-8 tiles wide (very narrow)
	deeper_offset = 3 + randi() % (corridor_w - deeper_w - 3)
	deeper_gate_pos = Vector2(corridor_w / 2, fork_y)
	deeper_exit_pos = Vector2(deeper_offset + deeper_w / 2, corridor_h - 2)
	# --- Width segments: 2-3 narrow zones in the MAIN corridor ---
	narrow_zones.clear()
	var zone_count: int = 2 + randi() % 2
	var zone_spacing: int = fork_y / (zone_count + 1)
	for i in zone_count:
		var y_center: int = zone_spacing * (i + 1) + randi() % maxi(1, zone_spacing / 2)
		var narrow_w: int = 5 + randi() % 3  # 5-7 tiles (was 8-12) — genuinely tight
		var narrow_left: int = (corridor_w - narrow_w) / 2 + randi() % 4 - 2
		narrow_zones.append({
			"y_center": y_center,
			"y_half": 3 + randi() % 2,
			"width_left": narrow_left,
			"width_right": narrow_left + narrow_w,
		})
	# --- Main corridor hazards (moderate density) ---
	hazards.clear()
	var hazard_count: int = 3 + stage
	var htypes: Array[String] = ["pit", "fire", "spikes", "debris"]
	for i in hazard_count:
		var narrow_idx: int = i % narrow_zones.size() if not narrow_zones.is_empty() else -1
		var y: int
		var x: int
		if narrow_idx >= 0:
			var nz: Dictionary = narrow_zones[narrow_idx]
			y = nz.y_center + randi() % (nz.y_half * 2) - nz.y_half
			x = nz.width_left + randi() % maxi(1, nz.width_right - nz.width_left)
		else:
			y = 4 + i * 4
			x = 2 + randi() % (corridor_w - 4)
		hazards.append({
			"pos": Vector2(x, y),
			"type": htypes[i % htypes.size()],
			"active": true,
			"cooldown": 0.0,
			"is_deeper": false,
		})
	# --- Deeper hazards (DENSE — 2x density, all in narrow corridor) ---
	deeper_hazards.clear()
	var deeper_hazard_count: int = 4 + stage * 2
	for i in deeper_hazard_count:
		# Pack hazards tightly in the deeper corridor
		var y: int = fork_y + 2 + (i * 2) % deeper_h
		var x: int = deeper_offset + 1 + randi() % maxi(1, deeper_w - 2)
		deeper_hazards.append({
			"pos": Vector2(x, y),
			"type": htypes[randi() % htypes.size()],
			"active": true,
			"cooldown": 0.0,
			"is_deeper": true,
		})
	# --- Noise seed ---
	noise_seed = randi()
	_noise = FastNoiseLite.new()
	_noise.seed = noise_seed
	_noise.frequency = 0.3
	_noise.noise_type = FastNoiseLite.TYPE_CELLULAR

const FORK_TAPER_TILES: int = 4  # rows over which the corridor narrows after the fork

## The exact, non-interpolated bounds for a single tile row. This is the
## real shape of the dungeon at that row — used as the two endpoints that
## get_width_bounds_at_y() blends between during the fork taper.
func _hard_bounds_at_y(tile_y: int) -> Vector2i:
	if tile_y > fork_y:
		return Vector2i(deeper_offset, deeper_offset + deeper_w)
	for nz in narrow_zones:
		if abs(tile_y - nz.y_center) < nz.y_half:
			return Vector2i(nz.width_left, nz.width_right)
	return Vector2i(0, corridor_w)

## Returns the left/right bounds at the given y, as floats. Used by BOTH
## movement clamping and rendering (salvage.gd's wall/floor draw), so the
## two can never disagree about where the walls are.
##
## Narrow zones already read fine as a hard edge (18 -> 8-12 tiles). The
## fork is the one truly abrupt transition (18 -> 6-8, and offset to one
## side), so it's the one that gets a taper: over FORK_TAPER_TILES rows
## just past fork_y, this blends from the main corridor's width at the
## fork down to the deeper section's narrow strip, so the corridor visibly
## closes in around the player as they commit instead of cutting instantly.
func get_width_bounds_at_y(tile_y: int) -> Vector2:
	var dist_past_fork: int = tile_y - fork_y
	if dist_past_fork > 0 and dist_past_fork <= FORK_TAPER_TILES:
		var main_bounds: Vector2i = _hard_bounds_at_y(fork_y)
		var deeper_bounds := Vector2i(deeper_offset, deeper_offset + deeper_w)
		var t: float = float(dist_past_fork) / float(FORK_TAPER_TILES)
		return Vector2(
			lerpf(main_bounds.x, deeper_bounds.x, t),
			lerpf(main_bounds.y, deeper_bounds.y, t)
		)
	var hard: Vector2i = _hard_bounds_at_y(tile_y)
	return Vector2(hard.x, hard.y)

func get_width_at_y(tile_y: int) -> float:
	var bounds := get_width_bounds_at_y(tile_y)
	return bounds.y - bounds.x

func get_floor_noise(x: int, y: int) -> float:
	return _noise.get_noise_2d(x, y)

func get_noise() -> FastNoiseLite:
	return _noise

## Returns ALL hazards (main + deeper) for battle to use.
func get_all_hazards() -> Array:
	var all := hazards.duplicate(true)
	all.append_array(deeper_hazards.duplicate(true))
	return all

## Returns true if the given tile y is in the deeper section.
func is_deeper(tile_y: int) -> bool:
	return tile_y > fork_y
