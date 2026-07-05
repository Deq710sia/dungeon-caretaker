class_name Sprites
extends RefCounted
## V4 Sprites — palette-disciplined, 16x16 base, pixel-perfect.
## All colors from Palette. No vector primitives. No arbitrary scaling.

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
		"wall":        _draw_wall(img)
		"wall_mossy":  _draw_wall_mossy(img)
		"altar":       _draw_altar(img)
		"bench":       _draw_bench(img)
		"grindstone":  _draw_grindstone(img)
		"furnace":     _draw_furnace(img)
		"chest":       _draw_chest(img)
		"crate":       _draw_crate(img)
		"pit":         _draw_pit(img)
		"torch":       _draw_torch(img)
		"corpse":      _draw_corpse(img)
		"bones":       _draw_bones(img)
		"door":        _draw_door(img)
		"stairs":      _draw_stairs(img)
		"bell":        _draw_bell(img)
		"map_table":   _draw_map_table(img)
		"weapon_rack": _draw_weapon_rack(img)
		"spark":       _draw_spark(img)
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

# === CHARACTERS (16x16) ===
static func _draw_ghost(img: Image) -> void:
	var body := Palette.GHOST
	var dark := Palette.VOID
	# Dome
	_rect(img, 5, 2, 6, 1, body)
	_rect(img, 4, 3, 8, 5, body)
	_rect(img, 4, 8, 8, 3, body)
	# Wavy bottom
	_px(img, 4, 11, body); _px(img, 5, 12, body)
	_px(img, 6, 11, body); _px(img, 7, 12, body)
	_px(img, 8, 11, body); _px(img, 9, 12, body)
	_px(img, 10, 11, body); _px(img, 11, 12, body)
	# Eyes
	_rect(img, 6, 5, 2, 2, dark)
	_rect(img, 9, 5, 2, 2, dark)

static func _draw_knight(img: Image) -> void:
	var armor := Palette.STEEL
	var dark := Palette.STEEL_DK
	var lt := Palette.STEEL_LT
	var plume := Palette.BLOOD
	# Helmet
	_rect(img, 5, 2, 6, 4, armor)
	_rect(img, 5, 2, 6, 1, lt)
	# Visor
	_rect(img, 5, 5, 6, 1, dark)
	# Plume
	_px(img, 7, 0, plume); _px(img, 8, 0, plume)
	_px(img, 7, 1, plume); _px(img, 8, 1, plume)
	# Body
	_rect(img, 4, 7, 8, 6, armor)
	_rect(img, 4, 7, 8, 1, lt)
	_rect(img, 4, 12, 8, 1, dark)
	# Belt
	_rect(img, 4, 10, 8, 1, dark)
	# Legs
	_rect(img, 5, 13, 2, 2, dark)
	_rect(img, 9, 13, 2, 2, dark)

static func _draw_mage(img: Image) -> void:
	var robe := Palette.GLOW_PURP
	var dark := Palette.VOID
	var hat := Palette.GLOW_PURP
	var gold := Palette.GOLD
	# Hat
	_px(img, 7, 0, hat)
	_rect(img, 6, 1, 4, 1, hat)
	_rect(img, 5, 2, 6, 2, hat)
	# Face
	_rect(img, 5, 4, 6, 3, Palette.BONE)
	_px(img, 6, 5, dark); _px(img, 9, 5, dark)
	# Robe
	_rect(img, 4, 7, 8, 7, robe)
	_rect(img, 4, 7, 8, 1, Palette.GLOW_BLUE)
	# Star
	_px(img, 7, 9, gold); _px(img, 8, 9, gold)
	# Bottom
	_rect(img, 3, 13, 10, 1, dark)

static func _draw_sword(img: Image) -> void:
	var blade := Palette.STEEL_LT
	var blade_dk := Palette.STEEL_DK
	var hilt := Palette.WOOD
	var guard := Palette.GOLD
	# Blade
	_rect(img, 7, 0, 2, 8, blade)
	_rect(img, 7, 0, 1, 8, Palette.TEXT)
	_rect(img, 8, 0, 1, 8, blade_dk)
	_px(img, 7, 0, blade)
	# Guard
	_rect(img, 5, 8, 6, 1, guard)
	# Grip
	_rect(img, 7, 9, 2, 5, hilt)
	# Pommel
	_rect(img, 7, 14, 2, 1, guard)

static func _draw_staff(img: Image) -> void:
	var wood := Palette.WOOD
	var orb := Palette.GLOW_BLUE
	# Stick
	_rect(img, 7, 4, 1, 11, wood)
	_rect(img, 8, 4, 1, 11, Palette.WOOD_DK)
	# Orb
	_rect(img, 6, 1, 4, 3, orb)
	_px(img, 5, 2, orb); _px(img, 10, 2, orb)
	_px(img, 7, 0, Palette.FIRE_CORE)
	# Glow
	_px(img, 6, 2, Palette.TEXT)

static func _draw_helm(img: Image) -> void:
	var metal := Palette.STEEL
	var dark := Palette.STEEL_DK
	# Dome
	_rect(img, 5, 3, 6, 1, metal)
	_rect(img, 4, 4, 8, 4, metal)
	_rect(img, 4, 4, 8, 1, Palette.STEEL_LT)
	# Visor
	_rect(img, 5, 8, 6, 2, dark)
	_px(img, 6, 8, Palette.FIRE_CORE); _px(img, 9, 8, Palette.FIRE_CORE)
	# Spike
	_px(img, 7, 1, metal); _px(img, 8, 1, metal)
	_px(img, 7, 2, metal); _px(img, 8, 2, metal)
	# Gem
	_px(img, 7, 5, Palette.SLIME); _px(img, 8, 5, Palette.SLIME)

static func _draw_robe(img: Image) -> void:
	var cloth := Palette.GLOW_PURP
	var dark := Palette.VOID
	var gold := Palette.GOLD
	# Body
	_rect(img, 5, 2, 6, 2, cloth)
	_rect(img, 4, 4, 8, 6, cloth)
	_rect(img, 3, 10, 10, 4, cloth)
	_rect(img, 3, 13, 10, 1, dark)
	# Trim
	_rect(img, 3, 13, 10, 1, gold)
	# Buttons
	_px(img, 7, 6, gold); _px(img, 7, 9, gold)

static func _draw_slime(img: Image) -> void:
	var body := Palette.SLIME
	var dark := Palette.WOOD_DK
	# Dome
	_rect(img, 5, 6, 6, 2, body)
	_rect(img, 4, 8, 8, 4, body)
	_rect(img, 4, 12, 8, 1, Palette.WOOD_DK)
	# Eyes
	_px(img, 6, 9, dark); _px(img, 9, 9, dark)
	# Mouth
	_px(img, 7, 11, dark); _px(img, 8, 11, dark)

static func _draw_skeleton(img: Image) -> void:
	var bone := Palette.BONE
	var dark := Palette.VOID
	# Skull
	_rect(img, 5, 1, 6, 5, bone)
	_px(img, 6, 3, dark); _px(img, 9, 3, dark)
	_px(img, 7, 5, dark); _px(img, 8, 5, dark)
	# Jaw
	_rect(img, 6, 6, 4, 1, bone)
	# Body
	_rect(img, 7, 7, 2, 5, bone)
	# Ribs
	_px(img, 5, 9, bone); _px(img, 10, 9, bone)
	_px(img, 5, 11, bone); _px(img, 10, 11, bone)
	# Legs
	_rect(img, 6, 12, 1, 3, bone)
	_rect(img, 9, 12, 1, 3, bone)

static func _draw_bat(img: Image) -> void:
	var body := Palette.VOID
	var wing := Palette.GLOW_PURP
	# Body
	_rect(img, 7, 6, 2, 4, body)
	_rect(img, 7, 4, 2, 2, body)
	# Eyes
	_px(img, 7, 5, Palette.FIRE_CORE); _px(img, 8, 5, Palette.FIRE_CORE)
	# Wings
	_rect(img, 3, 7, 4, 2, wing)
	_rect(img, 9, 7, 4, 2, wing)
	_px(img, 2, 6, wing); _px(img, 13, 6, wing)
	_px(img, 1, 8, wing); _px(img, 14, 8, wing)

# === TILES (16x16) ===
static func _draw_floor(img: Image) -> void:
	img.fill(Palette.FLOOR)
	# Tile divisions (8x8 sub-tiles)
	_rect(img, 0, 7, 16, 1, Palette.GRIME)
	_rect(img, 7, 0, 1, 16, Palette.GRIME)
	# Flecks
	_px(img, 2, 2, Palette.FLOOR_DK)
	_px(img, 11, 4, Palette.FLOOR_DK)
	_px(img, 4, 10, Palette.FLOOR_DK)
	_px(img, 13, 12, Palette.FLOOR_DK)
	# Highlights
	_px(img, 1, 1, Palette.FLOOR_LT)
	_px(img, 9, 9, Palette.FLOOR_LT)

static func _draw_floor_crack(img: Image) -> void:
	_draw_floor(img)
	_line(img, 2, 3, 7, 8, Palette.VOID)
	_line(img, 7, 8, 12, 6, Palette.VOID)
	_line(img, 7, 8, 9, 13, Palette.VOID)

static func _draw_floor_blood(img: Image) -> void:
	_draw_floor(img)
	# Blood pool
	_rect(img, 4, 9, 6, 2, Palette.BLOOD)
	_px(img, 3, 10, Palette.BLOOD)
	_px(img, 10, 10, Palette.BLOOD)
	# Splatter
	_px(img, 2, 7, Palette.BLOOD)
	_px(img, 12, 8, Palette.BLOOD)
	_px(img, 6, 12, Palette.BLOOD)

static func _draw_wall(img: Image) -> void:
	img.fill(Palette.STONE)
	# Bricks
	_rect(img, 0, 0, 16, 1, Palette.STONE_DK)
	_rect(img, 0, 5, 16, 1, Palette.STONE_DK)
	_rect(img, 0, 10, 16, 1, Palette.STONE_DK)
	_rect(img, 0, 15, 16, 1, Palette.STONE_DK)
	# Vertical breaks
	_rect(img, 7, 0, 1, 5, Palette.STONE_DK)
	_rect(img, 3, 6, 1, 4, Palette.STONE_DK)
	_rect(img, 11, 6, 1, 4, Palette.STONE_DK)
	_rect(img, 7, 11, 1, 4, Palette.STONE_DK)
	# Highlights
	_px(img, 1, 1, Palette.STONE_LT)
	_px(img, 8, 1, Palette.STONE_LT)
	_px(img, 4, 7, Palette.STONE_LT)
	_px(img, 12, 7, Palette.STONE_LT)

static func _draw_wall_mossy(img: Image) -> void:
	_draw_wall(img)
	# Moss patches
	_rect(img, 2, 2, 3, 1, Palette.SLIME)
	_rect(img, 9, 7, 4, 1, Palette.SLIME)
	_rect(img, 4, 12, 3, 1, Palette.SLIME)
	_px(img, 3, 2, Palette.WOOD); _px(img, 10, 7, Palette.WOOD)

# === STATIONS (16x16) ===
static func _draw_altar(img: Image) -> void:
	var stone := Palette.STONE_LT
	var dark := Palette.STONE_DK
	var glow := Palette.GLOW_BLUE
	# Top
	_rect(img, 2, 5, 12, 1, stone)
	_rect(img, 2, 4, 12, 1, Palette.TEXT)
	# Body
	_rect(img, 3, 6, 10, 7, stone)
	_rect(img, 3, 6, 10, 1, Palette.STONE_LT)
	# Base
	_rect(img, 2, 13, 12, 1, dark)
	# Rune glow
	_px(img, 6, 5, glow); _px(img, 7, 5, glow)
	_px(img, 8, 5, glow); _px(img, 9, 5, glow)

static func _draw_bench(img: Image) -> void:
	var wood := Palette.WOOD
	var dark := Palette.WOOD_DK
	# Top
	_rect(img, 1, 6, 14, 2, wood)
	_rect(img, 1, 6, 14, 1, Palette.WOOD_LT)
	# Legs
	_rect(img, 2, 8, 2, 6, wood)
	_rect(img, 12, 8, 2, 6, wood)
	# Cross-brace
	_rect(img, 2, 12, 12, 1, dark)
	# Cloth
	_px(img, 6, 8, Palette.BONE); _px(img, 7, 8, Palette.BONE)
	_px(img, 8, 8, Palette.BONE); _px(img, 9, 8, Palette.BONE)

static func _draw_grindstone(img: Image) -> void:
	var stone := Palette.STEEL_DK
	var wood := Palette.WOOD
	# Wheel
	_rect(img, 4, 3, 8, 8, stone)
	_rect(img, 5, 4, 6, 6, Palette.STEEL)
	_rect(img, 6, 5, 4, 4, Palette.STEEL_LT)
	# Center
	_px(img, 7, 7, wood); _px(img, 8, 7, wood)
	# Stand
	_rect(img, 7, 11, 2, 3, wood)
	_rect(img, 4, 14, 8, 1, wood)

static func _draw_furnace(img: Image) -> void:
	var stone := Palette.STONE
	var dark := Palette.STONE_DK
	var fire := Palette.FIRE
	# Body
	_rect(img, 2, 3, 12, 12, stone)
	_rect(img, 2, 3, 12, 1, Palette.STONE_LT)
	# Opening
	_rect(img, 4, 6, 8, 6, Palette.VOID)
	# Fire
	_rect(img, 5, 9, 6, 3, Palette.FIRE_DK)
	_rect(img, 6, 10, 4, 2, fire)
	_rect(img, 7, 10, 2, 1, Palette.FIRE_CORE)
	# Chimney
	_rect(img, 6, 0, 4, 3, stone)
	_rect(img, 6, 0, 4, 1, Palette.STONE_LT)

static func _draw_chest(img: Image) -> void:
	var wood := Palette.WOOD
	var dark := Palette.WOOD_DK
	var gold := Palette.GOLD
	# Lid
	_rect(img, 3, 4, 10, 3, wood)
	_rect(img, 3, 4, 10, 1, Palette.WOOD_LT)
	# Body
	_rect(img, 3, 7, 10, 5, wood)
	_rect(img, 3, 11, 10, 1, dark)
	# Bands
	_rect(img, 3, 6, 10, 1, dark)
	_rect(img, 3, 10, 10, 1, dark)
	# Lock
	_rect(img, 7, 7, 2, 3, gold)

static func _draw_crate(img: Image) -> void:
	var wood := Palette.WOOD
	var dark := Palette.WOOD_DK
	_rect(img, 1, 1, 14, 14, wood)
	_rect(img, 1, 1, 14, 1, Palette.WOOD_LT)
	_rect(img, 1, 14, 14, 1, dark)
	# X brace
	_line(img, 1, 1, 14, 14, dark)
	_line(img, 1, 14, 14, 1, dark)

static func _draw_pit(img: Image) -> void:
	# Dark hole with edge
	_rect(img, 2, 2, 12, 12, Palette.VOID)
	_rect(img, 3, 3, 10, 10, Palette.DARK)
	# Edge highlights
	_rect(img, 2, 2, 12, 1, Palette.STONE_DK)
	_rect(img, 2, 13, 12, 1, Palette.STONE_DK)
	_rect(img, 2, 2, 1, 12, Palette.STONE_DK)
	_rect(img, 13, 2, 1, 12, Palette.STONE_DK)

static func _draw_torch(img: Image) -> void:
	var wood := Palette.WOOD
	var fire := Palette.FIRE
	# Handle
	_rect(img, 7, 8, 2, 7, wood)
	# Holder
	_rect(img, 6, 7, 4, 1, Palette.WOOD_DK)
	# Flame
	_rect(img, 7, 4, 2, 3, fire)
	_px(img, 7, 3, Palette.FIRE_CORE)
	_px(img, 8, 3, Palette.FIRE_CORE)
	_px(img, 6, 5, fire); _px(img, 9, 5, fire)
	# Glow
	_px(img, 5, 4, Palette.FIRE_DK); _px(img, 10, 4, Palette.FIRE_DK)

static func _draw_corpse(img: Image) -> void:
	var armor := Palette.STEEL_DK
	var blood := Palette.BLOOD
	# Body (lying down)
	_rect(img, 2, 8, 12, 4, armor)
	_rect(img, 2, 8, 12, 1, Palette.STEEL)
	# Helmet (off to side)
	_rect(img, 1, 6, 3, 3, armor)
	# Blood
	_rect(img, 5, 11, 6, 2, blood)
	_px(img, 3, 12, blood); _px(img, 13, 12, blood)
	# Sword (dropped)
	_rect(img, 13, 6, 1, 5, Palette.STEEL_LT)

static func _draw_bones(img: Image) -> void:
	var bone := Palette.BONE
	var dark := Palette.WOOD_DK
	# Skull
	_rect(img, 6, 2, 4, 3, bone)
	_px(img, 7, 3, dark); _px(img, 8, 3, dark)
	# Bones
	_rect(img, 2, 8, 6, 1, bone)
	_px(img, 2, 7, bone); _px(img, 7, 9, bone)
	_rect(img, 9, 10, 5, 1, bone)
	_px(img, 9, 9, bone); _px(img, 13, 11, bone)

static func _draw_door(img: Image) -> void:
	var wood := Palette.WOOD_DK
	var dark := Palette.VOID
	# Frame
	_rect(img, 1, 0, 14, 16, dark)
	# Door
	_rect(img, 2, 1, 12, 14, wood)
	_rect(img, 2, 1, 12, 1, Palette.WOOD)
	# Planks
	_rect(img, 6, 1, 1, 14, dark)
	_rect(img, 10, 1, 1, 14, dark)
	# Handle
	_px(img, 11, 8, Palette.GOLD); _px(img, 11, 9, Palette.GOLD)

static func _draw_stairs(img: Image) -> void:
	var stone := Palette.STONE
	var dark := Palette.STONE_DK
	# Steps (going down)
	for i in 5:
		var y := 2 + i * 2
		var inset := i
		_rect(img, inset, y, 16 - inset * 2, 2, stone if i % 2 == 0 else Palette.STONE_LT)
		_rect(img, inset, y + 1, 16 - inset * 2, 1, dark)
	# Void at bottom
	_rect(img, 6, 12, 4, 4, Palette.VOID)

static func _draw_bell(img: Image) -> void:
	var metal := Palette.GOLD
	var dark := Palette.WOOD_DK
	# Bell body
	_rect(img, 4, 5, 8, 6, metal)
	_rect(img, 4, 5, 8, 1, Palette.FIRE_CORE)
	_rect(img, 3, 11, 10, 1, dark)
	# Top
	_rect(img, 7, 3, 2, 2, metal)
	# Rope
	_rect(img, 7, 0, 2, 3, Palette.WOOD)
	# Clapper
	_px(img, 7, 12, dark); _px(img, 8, 12, dark)

static func _draw_map_table(img: Image) -> void:
	var wood := Palette.WOOD
	var dark := Palette.WOOD_DK
	var parchment := Palette.BONE
	# Legs
	_rect(img, 2, 8, 2, 6, wood)
	_rect(img, 12, 8, 2, 6, wood)
	# Top
	_rect(img, 1, 4, 14, 4, wood)
	_rect(img, 1, 4, 14, 1, Palette.WOOD_LT)
	# Map (parchment)
	_rect(img, 3, 5, 10, 3, parchment)
	# Map markings (dots = nodes)
	_px(img, 5, 6, Palette.TEXT_RED)
	_px(img, 8, 6, Palette.TEXT_RED)
	_px(img, 11, 6, Palette.TEXT_GOLD)
	# Path
	_line(img, 5, 6, 8, 6, Palette.WOOD_DK)
	_line(img, 8, 6, 11, 6, Palette.WOOD_DK)

static func _draw_weapon_rack(img: Image) -> void:
	var wood := Palette.WOOD
	var dark := Palette.WOOD_DK
	# Frame
	_rect(img, 1, 2, 14, 1, wood)
	_rect(img, 1, 13, 14, 1, wood)
	_rect(img, 1, 2, 1, 12, wood)
	_rect(img, 14, 2, 1, 12, wood)
	# Back
	_rect(img, 2, 3, 12, 10, Palette.WOOD_DK)
	# Pegs
	_px(img, 4, 7, dark); _px(img, 8, 7, dark); _px(img, 12, 7, dark)
	# Mini weapons on pegs
	_rect(img, 4, 4, 1, 3, Palette.STEEL_LT)  # sword
	_rect(img, 7, 4, 1, 3, Palette.WOOD)  # staff top
	_px(img, 7, 3, Palette.GLOW_BLUE)
	_rect(img, 12, 4, 3, 1, Palette.STEEL)  # helm

static func _draw_spark(img: Image) -> void:
	var yellow := Palette.FIRE_CORE
	# 4-pointed star
	_rect(img, 7, 0, 2, 16, yellow)
	_rect(img, 0, 7, 16, 2, yellow)
	# Center bright
	_rect(img, 6, 6, 4, 4, Palette.TEXT)
	# Diagonal
	_line(img, 3, 3, 12, 12, yellow)
	_line(img, 3, 12, 12, 3, yellow)

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
