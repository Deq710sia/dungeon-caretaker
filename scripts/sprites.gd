class_name Sprites
extends RefCounted
## V6 Sprites — 16x16, 3-tone shaded, palette-disciplined.
## Every sprite has shadow/base/highlight for depth.

static var _cache: Dictionary = {}

static func get_sprite(name: String) -> ImageTexture:
	if _cache.has(name):
		return _cache[name]
	var img := _build(name)
	var tex := ImageTexture.create_from_image(img)
	_cache[name] = tex
	return tex

static func _build(name: String) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match name:
		"ghost":       _draw_ghost(img)
		"knight":      _draw_knight(img)
		"mage":        _draw_mage(img)
		"sword":       _draw_sword(img)
		"staff":       _draw_staff(img)
		"helm":        _draw_helm(img)
		"robe":        _draw_robe(img)
		"slime":       _draw_slime(img)
		"skeleton":    _draw_skeleton(img)
		"bat":         _draw_bat(img)
		"floor":       _draw_floor(img)
		"floor_crack": _draw_floor_crack(img)
		"floor_blood": _draw_floor_blood(img)
		"floor_moss":  _draw_floor_moss(img)
		"wall":        _draw_wall(img)
		"wall_mossy":  _draw_wall_mossy(img)
		"altar":       _draw_altar(img)
		"bench":       _draw_bench(img)
		"grindstone":  _draw_grindstone(img)
		"furnace":     _draw_furnace(img)
		"chest":       _draw_chest(img)
		"crate":       _draw_crate(img)
		"barrel":      _draw_barrel(img)
		"pit":         _draw_pit(img)
		"torch":       _draw_torch(img)
		"corpse":      _draw_corpse(img)
		"bones":       _draw_bones(img)
		"door":        _draw_door(img)
		"stairs":      _draw_stairs(img)
		"bell":        _draw_bell(img)
		"map_table":   _draw_map_table(img)
		"weapon_rack": _draw_weapon_rack(img)
		"shrine":      _draw_shrine(img)
		"spark":       _draw_spark(img)
		"cobweb":      _draw_cobweb(img)
		"chain":       _draw_chain(img)
		"skull_pile":  _draw_skull_pile(img)
		_:             _draw_default(img)
	return img

# === PIXEL HELPERS ===
static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < 16 and y >= 0 and y < 16:
		img.set_pixel(x, y, c)

static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for i in range(x, x + w):
		for j in range(y, y + h):
			_px(img, i, j, c)

static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	while true:
		_px(img, x0, y0, c)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy

# === CHARACTERS (16x16, 3-tone) ===
static func _draw_ghost(img: Image) -> void:
	# Ghost: wispy, semi-transparent, with glow
	var body := Palette.GHOST
	var shadow := Palette.GHOST_DK
	var high := Palette.GHOST_LT
	var dark := Palette.VOID
	# Dome (rounded top)
	_rect(img, 5, 2, 6, 1, body)
	_rect(img, 4, 3, 8, 1, high)
	_rect(img, 4, 4, 8, 4, body)
	_rect(img, 4, 8, 8, 3, body)
	# Highlight on left side
	_rect(img, 4, 4, 1, 6, high)
	_px(img, 5, 3, high)
	# Shadow on right
	_rect(img, 11, 4, 1, 6, shadow)
	# Wavy bottom (3 humps)
	_px(img, 4, 11, body); _px(img, 5, 12, shadow)
	_px(img, 6, 11, body); _px(img, 7, 12, shadow)
	_px(img, 8, 11, body); _px(img, 9, 12, shadow)
	_px(img, 10, 11, body); _px(img, 11, 12, shadow)
	# Eyes (dark voids with highlight)
	_rect(img, 6, 5, 2, 2, dark)
	_rect(img, 9, 5, 2, 2, dark)
	_px(img, 6, 5, high); _px(img, 9, 5, high)
	# Mouth (small o)
	_rect(img, 7, 8, 2, 1, dark)
	_px(img, 7, 9, dark); _px(img, 8, 9, dark)

static func _draw_knight(img: Image) -> void:
	var armor := Palette.STEEL
	var shadow := Palette.STEEL_DK
	var high := Palette.STEEL_LT
	var plume := Palette.BLOOD
	var dark := Palette.VOID
	# Plume (flowing)
	_px(img, 7, 0, plume); _px(img, 8, 0, plume)
	_rect(img, 7, 1, 2, 2, plume)
	_px(img, 6, 2, plume)
	# Helmet dome
	_rect(img, 5, 2, 6, 1, high)
	_rect(img, 4, 3, 8, 3, armor)
	_rect(img, 4, 3, 1, 3, high)  # left highlight
	_rect(img, 11, 3, 1, 3, shadow)  # right shadow
	# Visor slit
	_rect(img, 5, 5, 6, 1, dark)
	# Eye glow
	_px(img, 6, 5, Palette.FIRE_CORE)
	_px(img, 9, 5, Palette.FIRE_CORE)
	# Body (armor torso)
	_rect(img, 4, 6, 8, 1, high)
	_rect(img, 4, 7, 8, 5, armor)
	_rect(img, 4, 7, 1, 5, high)  # left highlight
	_rect(img, 11, 7, 1, 5, shadow)  # right shadow
	# Belt
	_rect(img, 4, 10, 8, 1, dark)
	_px(img, 7, 10, Palette.GOLD); _px(img, 8, 10, Palette.GOLD)
	# Shoulder pauldrons
	_rect(img, 3, 6, 1, 2, shadow)
	_rect(img, 12, 6, 1, 2, shadow)
	# Legs
	_rect(img, 5, 12, 3, 3, shadow)
	_rect(img, 8, 12, 3, 3, shadow)
	_rect(img, 5, 12, 1, 3, armor)
	_rect(img, 8, 12, 1, 3, armor)

static func _draw_mage(img: Image) -> void:
	var robe := Palette.GLOW_PURP
	var shadow := Color(0.40, 0.22, 0.55)
	var high := Color(0.80, 0.55, 0.95)
	var hat := Color(0.35, 0.20, 0.50)
	var skin := Palette.BONE
	var gold := Palette.GOLD
	var dark := Palette.VOID
	# Hat (pointed, with brim)
	_px(img, 7, 0, hat)
	_rect(img, 6, 1, 3, 1, hat)
	_rect(img, 5, 2, 5, 1, hat)
	_rect(img, 4, 3, 7, 1, hat)
	# Hat highlight
	_rect(img, 5, 2, 1, 1, high)
	_rect(img, 4, 3, 1, 1, high)
	# Hat star
	_px(img, 6, 2, gold); _px(img, 7, 2, gold)
	# Face
	_rect(img, 5, 4, 6, 3, skin)
	_rect(img, 5, 4, 6, 1, shadow)  # hat brim shadow
	# Eyes
	_px(img, 6, 5, dark); _px(img, 9, 5, dark)
	# Beard
	_rect(img, 6, 6, 4, 1, Palette.BONE_DK)
	# Robe body (flowing)
	_rect(img, 4, 7, 1, 1, high)  # shoulder
	_rect(img, 4, 7, 8, 1, high)
	_rect(img, 4, 8, 8, 5, robe)
	_rect(img, 4, 8, 1, 5, high)  # left fold highlight
	_rect(img, 11, 8, 1, 5, shadow)  # right fold shadow
	# Robe sash (gold)
	_rect(img, 4, 10, 8, 1, gold)
	# Star on robe
	_px(img, 7, 9, gold); _px(img, 8, 9, gold)
	# Bottom flare
	_rect(img, 3, 12, 10, 2, shadow)
	_rect(img, 3, 13, 10, 1, robe)

static func _draw_sword(img: Image) -> void:
	var blade := Palette.STEEL_LT
	var blade_dk := Palette.STEEL_DK
	var blade_mid := Palette.STEEL
	var hilt := Palette.WOOD
	var hilt_dk := Palette.WOOD_DK
	var guard := Palette.GOLD
	var guard_dk := Palette.GOLD_LT
	# Blade (vertical, with fuller)
	_rect(img, 7, 0, 2, 8, blade_mid)
	_rect(img, 7, 0, 1, 8, blade)  # highlight edge
	_rect(img, 8, 0, 1, 8, blade_dk)  # shadow edge
	# Tip
	_px(img, 7, 0, blade)
	# Crossguard
	_rect(img, 5, 8, 6, 1, guard)
	_rect(img, 5, 8, 6, 1, guard_dk)
	_px(img, 4, 8, guard_dk); _px(img, 11, 8, guard_dk)
	# Grip
	_rect(img, 7, 9, 2, 5, hilt)
	_rect(img, 7, 9, 1, 5, hilt_dk)  # shadow
	# Grip wrap
	_px(img, 7, 10, hilt_dk); _px(img, 8, 11, hilt_dk)
	_px(img, 7, 12, hilt_dk); _px(img, 8, 13, hilt_dk)
	# Pommel
	_rect(img, 6, 14, 4, 1, guard)
	_px(img, 7, 14, guard_dk); _px(img, 8, 14, guard_dk)

static func _draw_staff(img: Image) -> void:
	var wood := Palette.WOOD
	var wood_dk := Palette.WOOD_DK
	var wood_lt := Palette.WOOD_LT
	var orb := Palette.GLOW_BLUE
	var orb_lt := Color(0.80, 0.95, 1.00)
	var orb_glow := Color(0.45, 0.78, 1.00, 0.5)
	# Stick (with grain)
	_rect(img, 7, 4, 2, 11, wood)
	_rect(img, 7, 4, 1, 11, wood_lt)  # highlight
	_rect(img, 8, 4, 1, 11, wood_dk)  # shadow
	# Wood grain knots
	_px(img, 7, 8, wood_dk)
	_px(img, 8, 12, wood_dk)
	# Orb holder (claws)
	_px(img, 6, 5, Palette.GOLD); _px(img, 9, 5, Palette.GOLD)
	_rect(img, 6, 4, 4, 1, Palette.GOLD)
	# Orb (glowing)
	_rect(img, 6, 1, 4, 3, orb)
	_px(img, 5, 2, orb_glow); _px(img, 10, 2, orb_glow)
	# Orb highlight
	_px(img, 6, 1, orb_lt)
	_px(img, 7, 1, orb_lt)
	# Sparkle
	_px(img, 6, 2, Color(1, 1, 1, 0.9))

static func _draw_helm(img: Image) -> void:
	var metal := Palette.STEEL
	var shadow := Palette.STEEL_DK
	var high := Palette.STEEL_LT
	var dark := Palette.VOID
	var gold := Palette.GOLD
	# Top spike
	_rect(img, 7, 0, 2, 2, metal)
	_rect(img, 7, 0, 1, 2, high)
	# Dome
	_rect(img, 5, 2, 6, 1, high)
	_rect(img, 4, 3, 8, 4, metal)
	_rect(img, 4, 3, 1, 4, high)  # left highlight
	_rect(img, 11, 3, 1, 4, shadow)  # right shadow
	# Brow ridge
	_rect(img, 4, 6, 8, 1, shadow)
	# Visor (eye slit)
	_rect(img, 5, 7, 6, 1, dark)
	_px(img, 6, 7, Palette.FIRE_CORE)
	_px(img, 9, 7, Palette.FIRE_CORE)
	# Cheek guards
	_rect(img, 4, 8, 1, 3, shadow)
	_rect(img, 11, 8, 1, 3, shadow)
	# Chin
	_rect(img, 5, 10, 6, 1, metal)
	# Gem on forehead
	_rect(img, 7, 4, 2, 1, Palette.SLIME)
	_px(img, 7, 4, Color(0.60, 0.98, 0.60))
	# Rivets
	_px(img, 5, 5, gold); _px(img, 10, 5, gold)

static func _draw_robe(img: Image) -> void:
	var cloth := Palette.GLOW_PURP
	var shadow := Color(0.35, 0.18, 0.50)
	var high := Color(0.75, 0.50, 0.90)
	var gold := Palette.GOLD
	var trim := Palette.GOLD_LT
	# Trapezoid body
	_rect(img, 5, 1, 6, 2, cloth)
	_rect(img, 5, 1, 2, 1, high)  # shoulder highlight
	_rect(img, 4, 3, 8, 5, cloth)
	_rect(img, 4, 3, 1, 5, high)  # left highlight
	_rect(img, 11, 3, 1, 5, shadow)  # right shadow
	_rect(img, 3, 8, 10, 4, cloth)
	_rect(img, 3, 8, 1, 4, high)
	_rect(img, 12, 8, 1, 4, shadow)
	_rect(img, 2, 12, 12, 2, shadow)
	# Gold trim along edges
	_rect(img, 2, 12, 12, 1, gold)
	_rect(img, 5, 1, 6, 1, gold)
	# Center seam
	_rect(img, 7, 3, 1, 9, shadow)
	# Buttons
	_px(img, 7, 5, gold); _px(img, 8, 5, trim)
	_px(img, 7, 8, gold); _px(img, 8, 8, trim)
	# Collar (V shape)
	_line(img, 6, 1, 7, 4, trim)
	_line(img, 9, 1, 8, 4, trim)

# === ENEMIES (16x16, 3-tone) ===
static func _draw_slime(img: Image) -> void:
	var body := Palette.SLIME
	var shadow := Palette.SLIME_DK
	var high := Color(0.70, 1.00, 0.70)
	var dark := Palette.VOID
	# Dome (rounded)
	_rect(img, 5, 5, 6, 1, body)
	_rect(img, 4, 6, 8, 1, high)
	_rect(img, 4, 7, 8, 4, body)
	_rect(img, 4, 7, 1, 4, high)  # left highlight
	_rect(img, 11, 7, 1, 4, shadow)  # right shadow
	# Bottom (flat)
	_rect(img, 4, 11, 8, 2, shadow)
	_rect(img, 4, 12, 8, 1, Palette.WOOD_DK)
	# Shine (top-left)
	_rect(img, 5, 6, 2, 1, high)
	_px(img, 5, 7, high)
	# Eyes
	_rect(img, 6, 8, 2, 2, dark)
	_rect(img, 9, 8, 2, 2, dark)
	_px(img, 6, 8, high); _px(img, 9, 8, high)
	# Mouth (wavy)
	_rect(img, 7, 11, 2, 1, dark)

static func _draw_skeleton(img: Image) -> void:
	var bone := Palette.BONE
	var shadow := Palette.BONE_DK
	var dark := Palette.VOID
	var eye := Palette.FIRE_CORE
	# Skull
	_rect(img, 5, 1, 6, 1, shadow)
	_rect(img, 5, 1, 6, 5, bone)
	_rect(img, 5, 1, 1, 5, shadow)  # left shadow
	_rect(img, 10, 1, 1, 5, shadow)  # right shadow
	# Brow
	_rect(img, 5, 3, 6, 1, shadow)
	# Eye sockets (deep)
	_rect(img, 6, 3, 2, 2, dark)
	_rect(img, 9, 3, 2, 2, dark)
	# Eye glow
	_px(img, 6, 3, eye); _px(img, 9, 3, eye)
	# Nose
	_rect(img, 7, 5, 2, 1, dark)
	# Teeth
	for i in 5:
		_px(img, 6 + i, 6, dark)
	# Jaw
	_rect(img, 6, 6, 4, 1, bone)
	# Spine
	_rect(img, 7, 7, 2, 5, bone)
	_rect(img, 7, 7, 1, 5, shadow)
	# Ribs
	_rect(img, 5, 8, 2, 1, bone)
	_rect(img, 9, 8, 2, 1, bone)
	_rect(img, 5, 10, 2, 1, bone)
	_rect(img, 9, 10, 2, 1, bone)
	# Arms
	_rect(img, 3, 8, 2, 1, bone)
	_rect(img, 11, 8, 2, 1, bone)
	# Pelvis
	_rect(img, 6, 12, 4, 1, bone)
	# Legs
	_rect(img, 6, 13, 1, 2, bone)
	_rect(img, 9, 13, 1, 2, bone)
	_rect(img, 6, 13, 1, 2, shadow)

static func _draw_bat(img: Image) -> void:
	var body := Color(0.25, 0.15, 0.35)
	var wing := Palette.GLOW_PURP
	var wing_dk := Color(0.40, 0.25, 0.55)
	var eye := Palette.FIRE_CORE
	# Body
	_rect(img, 7, 5, 2, 5, body)
	_rect(img, 7, 5, 1, 5, Color(0.35, 0.22, 0.45))  # highlight
	# Head
	_rect(img, 7, 3, 2, 2, body)
	# Ears
	_px(img, 7, 1, body); _px(img, 8, 1, body)
	_px(img, 7, 2, body); _px(img, 8, 2, body)
	# Eyes
	_px(img, 7, 4, eye); _px(img, 8, 4, eye)
	# Fangs
	_px(img, 7, 6, Palette.BONE); _px(img, 8, 6, Palette.BONE)
	# Left wing (spread, with finger lines)
	_rect(img, 2, 6, 5, 2, wing)
	_rect(img, 1, 7, 2, 1, wing)
	_rect(img, 2, 8, 4, 1, wing_dk)
	_line(img, 2, 6, 6, 7, wing_dk)
	_line(img, 2, 8, 5, 8, wing_dk)
	# Right wing
	_rect(img, 9, 6, 5, 2, wing)
	_rect(img, 13, 7, 2, 1, wing)
	_rect(img, 10, 8, 4, 1, wing_dk)
	_line(img, 9, 6, 13, 7, wing_dk)
	_line(img, 10, 8, 13, 8, wing_dk)

# === TILES (16x16, with variation) ===
static func _draw_floor(img: Image) -> void:
	img.fill(Palette.FLOOR)
	# 4 sub-tiles (8x8 each) with subtle variation
	_rect(img, 0, 0, 8, 8, Palette.FLOOR)
	_rect(img, 8, 0, 8, 8, Color(0.17, 0.15, 0.21))  # slightly different
	_rect(img, 0, 8, 8, 8, Color(0.17, 0.15, 0.21))
	_rect(img, 8, 8, 8, 8, Palette.FLOOR)
	# Grout lines (cross)
	_rect(img, 0, 7, 16, 1, Palette.GRIME)
	_rect(img, 7, 0, 1, 16, Palette.GRIME)
	# Highlights (corner of each sub-tile)
	_px(img, 1, 1, Palette.FLOOR_LT)
	_px(img, 9, 1, Palette.FLOOR_LT)
	_px(img, 1, 9, Palette.FLOOR_LT)
	_px(img, 9, 9, Palette.FLOOR_LT)
	# Shadow flecks
	_px(img, 3, 4, Palette.FLOOR_DK)
	_px(img, 11, 6, Palette.FLOOR_DK)
	_px(img, 5, 12, Palette.FLOOR_DK)
	_px(img, 13, 11, Palette.FLOOR_DK)

static func _draw_floor_crack(img: Image) -> void:
	_draw_floor(img)
	# Crack (jagged)
	_line(img, 2, 3, 6, 7, Palette.VOID)
	_line(img, 6, 7, 10, 5, Palette.VOID)
	_line(img, 10, 5, 13, 9, Palette.VOID)
	_line(img, 6, 7, 8, 12, Palette.VOID)

static func _draw_floor_blood(img: Image) -> void:
	_draw_floor(img)
	# Blood pool
	_rect(img, 4, 8, 7, 3, Palette.BLOOD_DK)
	_rect(img, 5, 9, 5, 2, Palette.BLOOD)
	# Highlight
	_px(img, 6, 9, Color(0.75, 0.25, 0.25))
	# Splatter
	_px(img, 2, 6, Palette.BLOOD)
	_px(img, 12, 7, Palette.BLOOD)
	_px(img, 3, 12, Palette.BLOOD)
	_px(img, 13, 13, Palette.BLOOD_DK)

static func _draw_floor_moss(img: Image) -> void:
	_draw_floor(img)
	# Moss patches
	_rect(img, 2, 3, 4, 1, Palette.SLIME_DK)
	_rect(img, 3, 3, 2, 1, Palette.SLIME)
	_rect(img, 9, 10, 5, 1, Palette.SLIME_DK)
	_rect(img, 10, 10, 3, 1, Palette.SLIME)
	_px(img, 6, 12, Palette.SLIME_DK)

static func _draw_wall(img: Image) -> void:
	img.fill(Palette.STONE)
	# Brick pattern (3 rows)
	_rect(img, 0, 0, 16, 1, Palette.STONE_DK)
	_rect(img, 0, 5, 16, 1, Palette.STONE_DK)
	_rect(img, 0, 10, 16, 1, Palette.STONE_DK)
	_rect(img, 0, 15, 16, 1, Palette.STONE_DK)
	# Vertical breaks (offset per row)
	_rect(img, 7, 0, 1, 5, Palette.STONE_DK)
	_rect(img, 3, 6, 1, 4, Palette.STONE_DK)
	_rect(img, 11, 6, 1, 4, Palette.STONE_DK)
	_rect(img, 7, 11, 1, 4, Palette.STONE_DK)
	# Highlights (top-left of each brick)
	_rect(img, 1, 1, 3, 1, Palette.STONE_LT)
	_rect(img, 8, 1, 4, 1, Palette.STONE_LT)
	_rect(img, 1, 6, 2, 1, Palette.STONE_LT)
	_rect(img, 4, 6, 4, 1, Palette.STONE_LT)
	_rect(img, 12, 6, 3, 1, Palette.STONE_LT)
	_rect(img, 1, 11, 4, 1, Palette.STONE_LT)
	_rect(img, 8, 11, 5, 1, Palette.STONE_LT)

static func _draw_wall_mossy(img: Image) -> void:
	_draw_wall(img)
	# Moss patches
	_rect(img, 2, 3, 4, 1, Palette.SLIME_DK)
	_rect(img, 3, 3, 2, 1, Palette.SLIME)
	_rect(img, 9, 8, 5, 1, Palette.SLIME_DK)
	_rect(img, 10, 8, 3, 1, Palette.SLIME)
	_rect(img, 4, 13, 4, 1, Palette.SLIME_DK)
	_px(img, 5, 13, Palette.SLIME)

# === STATIONS (16x16, detailed) ===
static func _draw_altar(img: Image) -> void:
	var stone := Palette.STONE_LT
	var shadow := Palette.STONE_DK
	var high := Color(0.40, 0.38, 0.48)
	var glow := Palette.GLOW_BLUE
	# Top slab
	_rect(img, 2, 5, 12, 1, high)
	_rect(img, 2, 6, 12, 1, stone)
	# Body
	_rect(img, 3, 7, 10, 6, stone)
	_rect(img, 3, 7, 1, 6, high)  # left highlight
	_rect(img, 12, 7, 1, 6, shadow)  # right shadow
	# Base
	_rect(img, 2, 13, 12, 1, shadow)
	_rect(img, 2, 12, 12, 1, stone)
	# Pillars at corners
	_rect(img, 3, 7, 1, 6, shadow)
	_rect(img, 12, 7, 1, 6, shadow)
	# Rune glow on top
	_rect(img, 6, 5, 4, 1, glow)
	_px(img, 5, 5, glow); _px(img, 10, 5, glow)
	# Mystic sparks
	_px(img, 5, 4, Color(0.70, 0.90, 1.00, 0.8))
	_px(img, 10, 4, Color(0.70, 0.90, 1.00, 0.8))
	_px(img, 7, 3, Color(0.80, 0.95, 1.00, 0.6))
	_px(img, 8, 3, Color(0.80, 0.95, 1.00, 0.6))

static func _draw_bench(img: Image) -> void:
	var wood := Palette.WOOD
	var shadow := Palette.WOOD_DK
	var high := Palette.WOOD_LT
	# Top surface
	_rect(img, 1, 5, 14, 1, high)
	_rect(img, 1, 6, 14, 2, wood)
	_rect(img, 1, 8, 14, 1, shadow)
	# Wood grain
	_line(img, 3, 7, 13, 7, shadow)
	# Legs
	_rect(img, 2, 9, 2, 6, wood)
	_rect(img, 12, 9, 2, 6, wood)
	_rect(img, 2, 9, 1, 6, high)
	_rect(img, 13, 9, 1, 6, shadow)
	# Cross-brace
	_rect(img, 2, 12, 12, 1, shadow)
	_rect(img, 2, 13, 12, 1, wood)
	# Metal brackets
	_rect(img, 1, 6, 1, 1, Palette.IRON)
	_rect(img, 14, 6, 1, 1, Palette.IRON)
	# Polish cloth
	_rect(img, 6, 9, 4, 2, Palette.BONE)
	_rect(img, 6, 9, 4, 1, Color(0.95, 0.90, 0.78))

static func _draw_grindstone(img: Image) -> void:
	var stone := Palette.STEEL_DK
	var stone_lt := Palette.STEEL
	var stone_high := Palette.STEEL_LT
	var wood := Palette.WOOD
	# Wheel (3-tone)
	_rect(img, 4, 3, 8, 8, stone)
	_rect(img, 5, 4, 6, 6, stone_lt)
	_rect(img, 6, 5, 4, 4, stone_high)
	# Center hub
	_rect(img, 7, 6, 2, 2, wood)
	_px(img, 7, 6, Palette.WOOD_DK)
	# Spokes
	for i in 4:
		var a := i * (PI / 2.0) + PI / 4.0
		var x1 := int(7.5 + cos(a) * 2)
		var y1 := int(6.5 + sin(a) * 2)
		var x2 := int(7.5 + cos(a) * 4)
		var y2 := int(6.5 + sin(a) * 4)
		_line(img, x1, y1, x2, y2, Palette.IRON)
	# Stand
	_rect(img, 7, 11, 2, 3, wood)
	_rect(img, 7, 11, 1, 3, Palette.WOOD_LT)
	_rect(img, 4, 14, 8, 1, wood)
	_rect(img, 4, 14, 8, 1, Palette.WOOD_DK)
	# Sparks
	_px(img, 12, 5, Palette.FIRE_CORE)
	_px(img, 13, 6, Palette.FIRE)

static func _draw_furnace(img: Image) -> void:
	var stone := Palette.STONE
	var shadow := Palette.STONE_DK
	var high := Palette.STONE_LT
	var fire := Palette.FIRE
	# Body
	_rect(img, 2, 3, 12, 12, stone)
	_rect(img, 2, 3, 12, 1, high)  # top highlight
	_rect(img, 2, 14, 12, 1, shadow)  # bottom shadow
	_rect(img, 2, 3, 1, 12, high)  # left
	_rect(img, 13, 3, 1, 12, shadow)  # right
	# Brick lines
	_rect(img, 2, 7, 12, 1, shadow)
	_rect(img, 2, 11, 12, 1, shadow)
	# Vertical breaks
	_px(img, 6, 4, shadow); _px(img, 10, 4, shadow)
	_px(img, 4, 8, shadow); _px(img, 9, 8, shadow); _px(img, 12, 8, shadow)
	# Opening (arched)
	_rect(img, 4, 8, 8, 5, Palette.VOID)
	# Arch top
	for x in 8:
		var y_off := int(sqrt(max(0, 16 - (x - 4) * (x - 4))) * 0.4)
		_px(img, 4 + x, 8 - y_off, shadow)
	# Fire inside
	_rect(img, 5, 10, 6, 3, Palette.FIRE_DK)
	_rect(img, 6, 11, 4, 2, fire)
	_rect(img, 7, 11, 2, 1, Palette.FIRE_CORE)
	# Flames licking up
	_px(img, 6, 9, fire); _px(img, 8, 8, Palette.FIRE_CORE)
	_px(img, 10, 9, fire)
	# Chimney
	_rect(img, 6, 0, 4, 3, stone)
	_rect(img, 6, 0, 4, 1, high)
	_rect(img, 7, 1, 2, 1, shadow)
	# Smoke
	_px(img, 7, -1 if false else 0, Color(0.45, 0.40, 0.40, 0.5))

static func _draw_chest(img: Image) -> void:
	var wood := Palette.WOOD
	var shadow := Palette.WOOD_DK
	var high := Palette.WOOD_LT
	var gold := Palette.GOLD
	# Lid (curved top)
	for x in 10:
		var h := int(sqrt(max(0, 25 - (x - 5) * (x - 5))) * 0.4)
		_rect(img, 3 + x, 4 - h, 1, h, wood)
	# Lid bottom
	_rect(img, 3, 4, 10, 1, shadow)
	# Body
	_rect(img, 3, 5, 10, 7, wood)
	_rect(img, 3, 5, 1, 7, high)  # left highlight
	_rect(img, 12, 5, 1, 7, shadow)  # right shadow
	_rect(img, 3, 11, 10, 1, shadow)  # bottom
	# Iron bands
	_rect(img, 3, 4, 10, 1, shadow)
	_rect(img, 3, 8, 10, 1, shadow)
	# Lock plate
	_rect(img, 7, 6, 2, 4, gold)
	_rect(img, 7, 6, 2, 1, Palette.GOLD_LT)
	# Keyhole
	_rect(img, 7, 7, 2, 2, Palette.VOID)
	# Corner studs
	_px(img, 3, 4, gold); _px(img, 12, 4, gold)
	_px(img, 3, 11, gold); _px(img, 12, 11, gold)

static func _draw_crate(img: Image) -> void:
	var wood := Palette.WOOD
	var shadow := Palette.WOOD_DK
	var high := Palette.WOOD_LT
	# Body
	_rect(img, 1, 1, 14, 14, wood)
	# Highlights
	_rect(img, 1, 1, 14, 1, high)
	_rect(img, 1, 1, 1, 14, high)
	# Shadows
	_rect(img, 1, 14, 14, 1, shadow)
	_rect(img, 14, 1, 1, 14, shadow)
	# X bracing
	_line(img, 1, 1, 14, 14, shadow)
	_line(img, 1, 14, 14, 1, shadow)
	_line(img, 2, 2, 13, 13, high)

static func _draw_barrel(img: Image) -> void:
	var wood := Palette.WOOD
	var shadow := Palette.WOOD_DK
	var high := Palette.WOOD_LT
	# Body (curved sides)
	_rect(img, 3, 2, 10, 12, wood)
	_rect(img, 2, 4, 12, 8, wood)
	_rect(img, 3, 2, 1, 12, high)  # left highlight
	_rect(img, 12, 2, 1, 12, shadow)  # right shadow
	# Top
	_rect(img, 3, 2, 10, 1, high)
	_rect(img, 3, 3, 10, 1, shadow)
	# Iron bands
	_rect(img, 2, 5, 12, 1, Palette.IRON)
	_rect(img, 2, 10, 12, 1, Palette.IRON)
	# Wood staves
	_line(img, 6, 3, 6, 13, shadow)
	_line(img, 9, 3, 9, 13, shadow)

static func _draw_pit(img: Image) -> void:
	# Dark hole with stone edge
	_rect(img, 2, 2, 12, 12, Palette.STONE_DK)
	_rect(img, 3, 3, 10, 10, Palette.VOID)
	# Edge highlights
	_rect(img, 2, 2, 12, 1, Palette.STONE)
	_rect(img, 2, 2, 1, 12, Palette.STONE)
	# Inner darkness
	_rect(img, 5, 5, 6, 6, Color(0.02, 0.01, 0.03))
	# Glint at bottom
	_px(img, 7, 9, Color(0.15, 0.10, 0.20))
	_px(img, 8, 9, Color(0.15, 0.10, 0.20))

static func _draw_torch(img: Image) -> void:
	var wood := Palette.WOOD
	var wood_dk := Palette.WOOD_DK
	var fire := Palette.FIRE
	var fire_core := Palette.FIRE_CORE
	# Handle
	_rect(img, 7, 8, 2, 7, wood)
	_rect(img, 7, 8, 1, 7, wood_dk)
	# Holder (wrapped)
	_rect(img, 6, 7, 4, 1, wood_dk)
	_rect(img, 6, 6, 4, 1, Palette.IRON)
	# Flame (layered)
	_rect(img, 6, 4, 4, 3, Palette.FIRE_DK)
	_rect(img, 7, 3, 2, 4, fire)
	_rect(img, 7, 2, 2, 1, fire_core)
	# Flame tips
	_px(img, 7, 1, fire_core); _px(img, 8, 1, fire_core)
	# Side glow
	_px(img, 5, 5, Color(0.95, 0.50, 0.15, 0.6))
	_px(img, 10, 5, Color(0.95, 0.50, 0.15, 0.6))

static func _draw_corpse(img: Image) -> void:
	var armor := Palette.STEEL_DK
	var armor_lt := Palette.STEEL
	var blood := Palette.BLOOD
	var blood_dk := Palette.BLOOD_DK
	# Body (lying horizontal)
	_rect(img, 2, 8, 12, 3, armor)
	_rect(img, 2, 8, 12, 1, armor_lt)  # top highlight
	_rect(img, 2, 10, 12, 1, Palette.IRON)  # bottom shadow
	# Helmet (separated, to the left)
	_rect(img, 1, 6, 4, 3, armor)
	_rect(img, 1, 6, 4, 1, armor_lt)
	# Blood pool (spreading)
	_rect(img, 4, 11, 8, 2, blood_dk)
	_rect(img, 5, 11, 6, 1, blood)
	# Splatter
	_px(img, 2, 12, blood)
	_px(img, 13, 12, blood)
	_px(img, 8, 13, blood_dk)
	# Dropped sword
	_rect(img, 12, 5, 1, 5, Palette.STEEL_LT)
	_rect(img, 11, 9, 3, 1, Palette.GOLD)

static func _draw_bones(img: Image) -> void:
	var bone := Palette.BONE
	var shadow := Palette.BONE_DK
	# Skull
	_rect(img, 5, 2, 6, 4, bone)
	_rect(img, 5, 2, 1, 4, shadow)
	_rect(img, 10, 2, 1, 4, shadow)
	# Eye sockets
	_rect(img, 6, 3, 2, 2, Palette.VOID)
	_rect(img, 8, 3, 2, 2, Palette.VOID)
	# Jaw
	_rect(img, 6, 6, 4, 1, bone)
	# Crossed bones
	_line(img, 2, 9, 14, 13, bone)
	_line(img, 2, 13, 14, 9, bone)
	_line(img, 2, 10, 14, 14, shadow)
	# Small bone bits
	_px(img, 3, 7, bone); _px(img, 12, 7, bone)
	_px(img, 7, 10, shadow); _px(img, 8, 10, shadow)

static func _draw_door(img: Image) -> void:
	var wood := Palette.WOOD_DK
	var wood_lt := Palette.WOOD
	var shadow := Palette.VOID
	var gold := Palette.GOLD
	# Frame
	_rect(img, 0, 0, 16, 16, shadow)
	# Door
	_rect(img, 2, 1, 12, 14, wood)
	_rect(img, 2, 1, 12, 1, wood_lt)  # top highlight
	_rect(img, 2, 1, 1, 14, wood_lt)  # left highlight
	_rect(img, 13, 1, 1, 14, Palette.WOOD_DK)  # right shadow
	# Planks
	_rect(img, 5, 1, 1, 14, shadow)
	_rect(img, 9, 1, 1, 14, shadow)
	# Iron rivets
	for i in 3:
		_px(img, 3, 4 + i * 4, Palette.IRON)
		_px(img, 7, 4 + i * 4, Palette.IRON)
		_px(img, 11, 4 + i * 4, Palette.IRON)
	# Handle
	_rect(img, 11, 7, 2, 2, gold)
	_px(img, 11, 7, Palette.GOLD_LT)

static func _draw_stairs(img: Image) -> void:
	var stone := Palette.STONE
	var shadow := Palette.STONE_DK
	var high := Palette.STONE_LT
	# Steps (going down, 5 steps)
	for i in 5:
		var y := 1 + i * 2
		var inset := i
		# Step top
		_rect(img, inset, y, 16 - inset * 2, 1, high)
		# Step face
		_rect(img, inset, y + 1, 16 - inset * 2, 1, stone)
		# Step shadow
		if i < 4:
			_rect(img, inset, y + 2, 16 - inset * 2, 1, shadow)
	# Void at bottom
	_rect(img, 6, 11, 4, 4, Palette.VOID)
	# Subtle glow from below
	_px(img, 7, 11, Color(0.20, 0.15, 0.30, 0.8))
	_px(img, 8, 11, Color(0.20, 0.15, 0.30, 0.8))

static func _draw_bell(img: Image) -> void:
	var metal := Palette.GOLD
	var shadow := Palette.GOLD_LT
	var high := Color(1.00, 0.95, 0.60)
	var dark := Palette.WOOD_DK
	# Rope
	_rect(img, 7, 0, 2, 3, Palette.WOOD)
	_rect(img, 7, 0, 1, 3, Palette.WOOD_LT)
	# Bell top
	_rect(img, 7, 2, 2, 1, metal)
	# Bell body (trapezoid)
	_rect(img, 5, 3, 6, 1, metal)
	_rect(img, 4, 4, 8, 1, metal)
	_rect(img, 4, 5, 8, 4, metal)
	_rect(img, 3, 9, 10, 2, metal)
	# Highlight
	_rect(img, 4, 4, 1, 5, high)
	_rect(img, 5, 3, 4, 1, high)
	# Shadow
	_rect(img, 11, 4, 1, 5, shadow)
	_rect(img, 12, 9, 1, 2, shadow)
	# Bottom rim
	_rect(img, 3, 10, 10, 1, dark)
	# Clapper
	_rect(img, 7, 11, 2, 2, dark)
	_px(img, 7, 12, Palette.IRON)

static func _draw_map_table(img: Image) -> void:
	var wood := Palette.WOOD
	var shadow := Palette.WOOD_DK
	var high := Palette.WOOD_LT
	var parchment := Palette.BONE
	# Legs
	_rect(img, 2, 9, 2, 5, wood)
	_rect(img, 12, 9, 2, 5, wood)
	_rect(img, 2, 9, 1, 5, high)
	_rect(img, 13, 9, 1, 5, shadow)
	# Top surface
	_rect(img, 1, 5, 14, 4, wood)
	_rect(img, 1, 5, 14, 1, high)
	_rect(img, 1, 8, 14, 1, shadow)
	# Parchment map
	_rect(img, 3, 6, 10, 3, parchment)
	_rect(img, 3, 6, 10, 1, Color(0.95, 0.90, 0.78))
	# Map markings (dots = nodes, lines = path)
	_px(img, 5, 7, Palette.TEXT_RED)
	_px(img, 8, 7, Palette.TEXT_RED)
	_px(img, 11, 7, Palette.TEXT_GOLD)
	_line(img, 5, 7, 8, 7, Palette.WOOD_DK)
	_line(img, 8, 7, 11, 7, Palette.WOOD_DK)
	# Compass rose
	_px(img, 13, 7, Palette.TEXT_GOLD)

static func _draw_weapon_rack(img: Image) -> void:
	var wood := Palette.WOOD
	var shadow := Palette.WOOD_DK
	var high := Palette.WOOD_LT
	# Frame (top + bottom rails)
	_rect(img, 1, 3, 14, 1, wood)
	_rect(img, 1, 3, 14, 1, high)
	_rect(img, 1, 12, 14, 1, wood)
	_rect(img, 1, 13, 14, 1, shadow)
	# Side posts
	_rect(img, 1, 3, 1, 11, wood)
	_rect(img, 14, 3, 1, 11, shadow)
	# Back panel
	_rect(img, 2, 4, 12, 8, Palette.WOOD_DK)
	# Pegs
	_px(img, 4, 7, shadow); _px(img, 8, 7, shadow); _px(img, 12, 7, shadow)
	# Mini weapons on pegs
	# Sword
	_rect(img, 4, 5, 1, 2, Palette.STEEL_LT)
	_px(img, 3, 7, Palette.GOLD)
	# Staff
	_rect(img, 8, 5, 1, 2, Palette.WOOD)
	_px(img, 8, 4, Palette.GLOW_BLUE)
	# Helm
	_rect(img, 11, 5, 3, 2, Palette.STEEL)
	_rect(img, 11, 5, 3, 1, Palette.STEEL_LT)

static func _draw_shrine(img: Image) -> void:
	var stone := Palette.STONE_LT
	var shadow := Palette.STONE_DK
	var high := Color(0.42, 0.40, 0.50)
	var glow := Palette.GLOW_CYAN
	# Base
	_rect(img, 2, 12, 12, 3, stone)
	_rect(img, 2, 12, 12, 1, high)
	_rect(img, 2, 14, 12, 1, shadow)
	# Pillars
	_rect(img, 3, 5, 2, 8, stone)
	_rect(img, 11, 5, 2, 8, stone)
	_rect(img, 3, 5, 1, 8, high)
	_rect(img, 12, 5, 1, 8, shadow)
	# Roof (pointed)
	_px(img, 7, 2, stone); _px(img, 8, 2, stone)
	_rect(img, 6, 3, 4, 1, stone)
	_rect(img, 5, 4, 6, 1, stone)
	_rect(img, 5, 4, 6, 1, high)
	# Soul glow (center)
	_rect(img, 7, 6, 2, 4, glow)
	_rect(img, 6, 7, 4, 2, Color(0.55, 0.98, 0.92, 0.8))
	# Sparks rising
	_px(img, 5, 5, Color(0.55, 0.98, 0.92, 0.6))
	_px(img, 10, 5, Color(0.55, 0.98, 0.92, 0.6))
	_px(img, 7, 4, Color(0.70, 1.00, 0.95, 0.5))
	_px(img, 8, 4, Color(0.70, 1.00, 0.95, 0.5))

static func _draw_spark(img: Image) -> void:
	var yellow := Palette.FIRE_CORE
	var white := Color(1.0, 1.0, 0.90)
	# 4-pointed star
	_rect(img, 7, 0, 2, 16, yellow)
	_rect(img, 0, 7, 16, 2, yellow)
	# Center bright
	_rect(img, 6, 6, 4, 4, white)
	# Diagonal
	_line(img, 3, 3, 12, 12, yellow)
	_line(img, 3, 12, 12, 3, yellow)

static func _draw_cobweb(img: Image) -> void:
	var web := Color(0.70, 0.68, 0.72, 0.5)
	# Corner cobweb
	_line(img, 0, 0, 6, 6, web)
	_line(img, 0, 2, 4, 6, web)
	_line(img, 0, 4, 3, 6, web)
	_line(img, 2, 0, 6, 4, web)
	_line(img, 4, 0, 6, 2, web)
	# Connecting threads
	_line(img, 2, 2, 4, 4, web)
	_line(img, 3, 3, 5, 5, web)

static func _draw_chain(img: Image) -> void:
	var metal := Palette.IRON
	var high := Palette.STEEL_DK
	# Hanging chain (vertical)
	for i in 4:
		var y := i * 4
		# Link 1 (horizontal)
		_rect(img, 7, y, 2, 1, metal)
		_rect(img, 7, y, 1, 1, high)
		# Link 2 (vertical)
		_rect(img, 7, y + 1, 2, 2, metal)
		_rect(img, 7, y + 1, 1, 2, high)
		# Link 3 (horizontal)
		_rect(img, 7, y + 3, 2, 1, metal)

static func _draw_skull_pile(img: Image) -> void:
	var bone := Palette.BONE
	var shadow := Palette.BONE_DK
	# Bottom skull
	_rect(img, 3, 10, 6, 4, bone)
	_rect(img, 3, 10, 1, 4, shadow)
	_rect(img, 4, 11, 2, 2, Palette.VOID)
	_rect(img, 6, 11, 2, 2, Palette.VOID)
	# Top skull
	_rect(img, 8, 7, 6, 4, bone)
	_rect(img, 8, 7, 1, 4, shadow)
	_rect(img, 9, 8, 2, 2, Palette.VOID)
	_rect(img, 11, 8, 2, 2, Palette.VOID)
	# Small skull
	_rect(img, 5, 5, 4, 3, bone)
	_rect(img, 5, 5, 1, 3, shadow)
	_px(img, 6, 6, Palette.VOID); _px(img, 7, 6, Palette.VOID)
	# Bone bits
	_line(img, 1, 14, 4, 14, bone)
	_line(img, 12, 14, 15, 14, bone)

# === FALLBACK ===
static func _draw_default(img: Image) -> void:
	for x in 16:
		for y in 16:
			var c := Palette.TEXT_RED if (x + y) % 2 == 0 else Palette.VOID
			img.set_pixel(x, y, c)

# === HELPER: Weapon sprite with state tint ===
static func get_weapon_sprite(type: String, state: int) -> ImageTexture:
	var key := "w_%s_%d" % [type, state]
	if _cache.has(key):
		return _cache[key]
	var base := get_sprite(type)
	var img := base.get_image()
	# Apply state tint
	var tint: Color = Color.WHITE
	match state:
		Weapon.State.BLOODIED:  tint = Color(1.3, 0.6, 0.6, 1.0)
		Weapon.State.RUSTED:    tint = Color(1.3, 1.0, 0.5, 1.0)
		Weapon.State.HAUNTED:   tint = Color(0.7, 0.9, 1.3, 1.0)
		Weapon.State.CURSED:    tint = Color(1.3, 0.6, 1.4, 1.0)
		Weapon.State.SHATTERED: tint = Color(0.5, 0.5, 0.5, 1.0)
	if tint != Color.WHITE:
		for y in 16:
			for x in 16:
				var c := img.get_pixel(x, y)
				if c.a > 0:
					var nc := Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a)
					img.set_pixel(x, y, nc)
	# Add state-specific overlays
	match state:
		Weapon.State.BLOODIED:
			for i in 4:
				_px(img, 3 + i * 3, 4 + (i % 2) * 4, Palette.BLOOD)
		Weapon.State.RUSTED:
			for i in 5:
				_px(img, 2 + (i * 3) % 12, 3 + (i * 2) % 10, Palette.RUST)
		Weapon.State.HAUNTED:
			for i in 4:
				_px(img, 4 + i * 3, 2 + (i % 2) * 6, Color(0.6, 0.85, 1.0, 0.6))
		Weapon.State.CURSED:
			for i in 3:
				_px(img, 5 + i * 4, 4, Palette.GLOW_PURP)
				_px(img, 5 + i * 4, 8, Palette.GLOW_PURP)
		Weapon.State.SHATTERED:
			_line(img, 2, 4, 8, 8, Palette.VOID)
			_line(img, 8, 8, 14, 12, Palette.VOID)
			_line(img, 8, 8, 6, 14, Palette.VOID)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
