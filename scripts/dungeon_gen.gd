class_name DungeonGen
extends RefCounted
## DungeonGen — single source of truth for all dungeon generation.
## Handles: corridor length, width segments (wide/narrow zones), hazard
## placement, noise seeds for floor detail, and first-party death simulation.
##
## The generation persists for an entire stage — battle and salvage both
## read from the same DungeonGen instance so the player runs through the
## SAME physical space in both phases. A new generation is created when
## the stage changes.
##
## Usage:
##   var gen := DungeonGen.new(stage, fallen_count, salvage_expert_level)
##   var corridor_h: int = gen.corridor_h
##   var bounds: Vector2i = gen.get_width_bounds_at_y(tile_y)
##   var noise_val: float = gen.get_floor_noise(x, y)

var stage: int = 1
var corridor_w: int = 18
var corridor_h: int = 60
var narrow_zones: Array = []  # [{y_center, y_half, width_left, width_right}]
var hazards: Array = []       # [{pos (Vector2 in tile coords), type, active, cooldown}]
var noise_seed: int = 0
var _noise: FastNoiseLite

func _init(p_stage: int = 1, fallen_count: int = 0, salvage_expert: int = 0) -> void:
	stage = p_stage
	_generate(fallen_count, salvage_expert)

## Main generation entry point. Called once per stage.
func _generate(fallen_count: int, salvage_expert: int) -> void:
	# --- Corridor length: clamped to weapon count + variance ---
	# More weapons to salvage = longer corridor. Min 20, max 80.
	var bonus_count: int = 1 + int(stage / 3) + salvage_expert
	var weapon_count: int = fallen_count + bonus_count
	if weapon_count < 2:
		weapon_count = 2 + int(stage / 2)  # first-run fallback
	corridor_h = clampi(20 + weapon_count * 6 + randi() % 8, 20, 80)
	# --- Width segments: 2-3 narrow zones at random y-levels ---
	# Wide zones use the full 18-tile width; narrow zones are 8-12 tiles.
	# Connected by diagonal transitions (drawn by the phase).
	narrow_zones.clear()
	var zone_count: int = 2 + randi() % 2
	var zone_spacing: int = corridor_h / (zone_count + 1)
	for i in zone_count:
		var y_center: int = zone_spacing * (i + 1) + randi() % maxi(1, zone_spacing / 2)
		var narrow_w: int = 8 + randi() % 5  # 8-12 tiles wide
		var narrow_left: int = (corridor_w - narrow_w) / 2 + randi() % 4 - 2
		narrow_zones.append({
			"y_center": y_center,
			"y_half": 3 + randi() % 2,  # zone height (6-10 tiles)
			"width_left": narrow_left,
			"width_right": narrow_left + narrow_w,
		})
	# --- Hazards: placed in/near narrow zones (harder to avoid) ---
	hazards.clear()
	var hazard_count: int = 4 + stage * 2
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
			y = 6 + i * 4
			x = 2 + randi() % 14
		hazards.append({
			"pos": Vector2(x, y),  # tile coords
			"type": htypes[i % htypes.size()],
			"active": true,
			"cooldown": 0.0,
		})
	# --- Noise seed for floor detail ---
	noise_seed = randi()
	_noise = FastNoiseLite.new()
	_noise.seed = noise_seed
	_noise.frequency = 0.3
	_noise.noise_type = FastNoiseLite.TYPE_CELLULAR

## Returns the left/right bounds (in tile coords) of the corridor at the
## given y. Wide zones = full width (0, corridor_w). Narrow zones return
## their (width_left, width_right). Used by both battle and salvage to
## render the same physical space.
func get_width_bounds_at_y(tile_y: int) -> Vector2i:
	for nz in narrow_zones:
		if abs(tile_y - nz.y_center) < nz.y_half:
			return Vector2i(nz.width_left, nz.width_right)
	return Vector2i(0, corridor_w)

## Returns the corridor width (in tiles) at the given y.
func get_width_at_y(tile_y: int) -> int:
	var bounds := get_width_bounds_at_y(tile_y)
	return bounds.y - bounds.x

## Returns the noise value at the given tile coords. Used for floor detail
## (moss/cracks/blood) — same seed for battle and salvage so details match.
func get_floor_noise(x: int, y: int) -> float:
	return _noise.get_noise_2d(x, y)

## Returns the noise texture (for phases that need direct access).
func get_noise() -> FastNoiseLite:
	return _noise

## Converts a tile-coord hazard position to pixel coords.
func hazard_pixel_pos(hazard: Dictionary) -> Vector2:
	var pos: Vector2 = hazard.pos
	return Vector2(pos.x * 16 + 8, pos.y * 16 + 8)
