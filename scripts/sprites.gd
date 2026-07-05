class_name Sprites
extends RefCounted
## Procedurally generates all pixel sprites at runtime.
## All sprites are 16x16 ImageTextures cached in a static dictionary.
## Replace with Kenney.nl CC0 packs in V1.1 — see README.

static var _cache: Dictionary = {}

static func get_sprite(name: String) -> ImageTexture:
	if _cache.has(name):
		return _cache[name]
	var img := _build(name)
	var tex := ImageTexture.create_from_image(img)
	tex.set_meta("name", name)
	_cache[name] = tex
	return tex

static func _build(name: String) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	# Fill with transparent
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
		"wall":        _draw_wall(img)
		"altar":       _draw_altar(img)
		"bench":       _draw_bench(img)
		"grindstone":  _draw_grindstone(img)
		"furnace":     _draw_furnace(img)
		"chest":       _draw_chest(img)
		"crate":       _draw_crate(img)
		_:             _draw_default(img)
	return img

# --- Pixel helpers ---
static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < 16 and y >= 0 and y < 16:
		img.set_pixel(x, y, c)

static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for i in range(x, x + w):
		for j in range(y, y + h):
			_px(img, i, j, c)

# --- Sprites ---
static func _draw_ghost(img: Image) -> void:
	# Wispy white-blue ghost with two dark eyes
	var body := Color(0.85, 0.85, 0.95, 0.92)
	var dark := Color(0.15, 0.10, 0.20, 1.0)
	# Top dome
	_rect(img, 4, 3, 8, 1, body)
	_rect(img, 3, 4, 10, 6, body)
	# Wavy bottom
	_px(img, 3, 10, body); _px(img, 4, 11, body); _px(img, 5, 10, body)
	_px(img, 6, 11, body); _px(img, 7, 10, body); _px(img, 8, 11, body)
	_px(img, 9, 10, body); _px(img, 10, 11, body); _px(img, 11, 10, body)
	_px(img, 12, 11, body)
	# Eyes
	_px(img, 5, 6, dark); _px(img, 6, 6, dark)
	_px(img, 9, 6, dark); _px(img, 10, 6, dark)

static func _draw_knight(img: Image) -> void:
	var armor := Color(0.55, 0.65, 0.85)
	var dark := Color(0.25, 0.30, 0.45)
	var skin := Color(0.95, 0.80, 0.65)
	# Body
	_rect(img, 4, 8, 8, 6, armor)
	# Helmet
	_rect(img, 5, 3, 6, 4, armor)
	_rect(img, 4, 4, 1, 3, armor)
	_rect(img, 11, 4, 1, 3, armor)
	# Visor slit
	_rect(img, 5, 5, 6, 1, dark)
	# Plume
	_px(img, 7, 2, Color(0.85, 0.30, 0.30))
	_px(img, 8, 2, Color(0.85, 0.30, 0.30))
	# Belt
	_rect(img, 4, 11, 8, 1, dark)

static func _draw_mage(img: Image) -> void:
	var robe := Color(0.50, 0.30, 0.70)
	var dark := Color(0.25, 0.15, 0.35)
	var skin := Color(0.95, 0.80, 0.65)
	# Hat (pointed)
	_px(img, 7, 1, robe)
	_px(img, 6, 2, robe); _px(img, 7, 2, robe); _px(img, 8, 2, robe)
	_rect(img, 5, 3, 6, 1, robe)
	# Face
	_rect(img, 5, 4, 6, 2, skin)
	_px(img, 6, 5, dark); _px(img, 9, 5, dark)  # eyes
	# Robe body
	_rect(img, 4, 6, 8, 8, robe)
	# Robe shading
	_rect(img, 4, 12, 8, 2, dark)
	# Star on robe
	_px(img, 7, 9, Color(0.95, 0.85, 0.30))
	_px(img, 6, 10, Color(0.95, 0.85, 0.30))
	_px(img, 8, 10, Color(0.95, 0.85, 0.30))
	_px(img, 7, 11, Color(0.95, 0.85, 0.30))

static func _draw_sword(img: Image) -> void:
	var blade := Color(0.80, 0.85, 0.90)
	var hilt := Color(0.55, 0.35, 0.20)
	var dark := Color(0.30, 0.30, 0.35)
	# Blade (vertical)
	_rect(img, 7, 1, 2, 9, blade)
	_px(img, 7, 0, blade); _px(img, 8, 0, blade)  # tip
	# Crossguard
	_rect(img, 5, 10, 6, 1, dark)
	# Grip
	_rect(img, 7, 11, 2, 3, hilt)
	# Pommel
	_px(img, 7, 14, hilt); _px(img, 8, 14, hilt)

static func _draw_staff(img: Image) -> void:
	var wood := Color(0.45, 0.30, 0.20)
	var orb := Color(0.50, 0.70, 0.95)
	var glow := Color(0.70, 0.85, 1.0, 0.8)
	# Stick
	_rect(img, 7, 4, 1, 11, wood)
	_px(img, 8, 4, wood)
	# Orb (top)
	_rect(img, 6, 1, 4, 3, orb)
	_px(img, 5, 2, glow); _px(img, 10, 2, glow)
	_px(img, 7, 0, glow); _px(img, 8, 0, glow)
	# Highlights
	_px(img, 6, 1, Color(0.95, 0.95, 1.0))

static func _draw_helm(img: Image) -> void:
	var metal := Color(0.75, 0.80, 0.85)
	var dark := Color(0.40, 0.45, 0.55)
	# Dome
	_rect(img, 4, 4, 8, 1, metal)
	_rect(img, 3, 5, 10, 4, metal)
	# Visor
	_rect(img, 4, 9, 8, 2, dark)
	_px(img, 5, 9, metal); _px(img, 10, 9, metal)  # eye slits glow
	# Chin
	_rect(img, 5, 11, 6, 1, metal)
	# Top spike
	_px(img, 7, 3, metal); _px(img, 8, 3, metal)
	_px(img, 7, 2, metal); _px(img, 8, 2, metal)

static func _draw_robe(img: Image) -> void:
	var cloth := Color(0.45, 0.35, 0.65)
	var dark := Color(0.25, 0.20, 0.40)
	# Trapezoid shape
	_rect(img, 5, 2, 6, 2, cloth)
	_rect(img, 4, 4, 8, 8, cloth)
	_rect(img, 3, 12, 10, 2, cloth)
	# Sleeves
	_rect(img, 2, 6, 2, 4, cloth)
	_rect(img, 12, 6, 2, 4, cloth)
	# Trim
	_rect(img, 3, 13, 10, 1, dark)
	_px(img, 7, 7, Color(0.95, 0.85, 0.30))  # button
	_px(img, 8, 7, Color(0.95, 0.85, 0.30))

static func _draw_slime(img: Image) -> void:
	var body := Color(0.50, 0.85, 0.50)
	var dark := Color(0.25, 0.55, 0.25)
	# Dome shape
	_rect(img, 4, 8, 8, 4, body)
	_rect(img, 5, 6, 6, 2, body)
	_rect(img, 6, 5, 4, 1, body)
	# Highlight
	_px(img, 5, 7, Color(0.80, 1.0, 0.80))
	_px(img, 6, 6, Color(0.80, 1.0, 0.80))
	# Eyes
	_px(img, 6, 9, dark); _px(img, 9, 9, dark)
	# Mouth
	_px(img, 7, 11, dark); _px(img, 8, 11, dark)
	# Bottom shadow
	_rect(img, 4, 12, 8, 1, dark)

static func _draw_skeleton(img: Image) -> void:
	var bone := Color(0.90, 0.88, 0.78)
	var dark := Color(0.15, 0.10, 0.10)
	# Skull
	_rect(img, 5, 2, 6, 5, bone)
	_px(img, 6, 4, dark); _px(img, 9, 4, dark)  # eyes
	_px(img, 7, 6, dark); _px(img, 8, 6, dark)  # nose
	# Jaw
	_rect(img, 6, 7, 4, 1, bone)
	# Ribs (cross pattern)
	_rect(img, 6, 9, 4, 4, bone)
	_px(img, 5, 9, bone); _px(img, 10, 9, bone)
	_px(img, 7, 10, dark); _px(img, 8, 10, dark)
	_px(img, 7, 11, dark); _px(img, 8, 11, dark)
	# Arms
	_px(img, 4, 10, bone); _px(img, 11, 10, bone)
	# Legs
	_rect(img, 6, 13, 1, 2, bone); _rect(img, 9, 13, 1, 2, bone)

static func _draw_bat(img: Image) -> void:
	var body := Color(0.30, 0.20, 0.40)
	var dark := Color(0.10, 0.05, 0.15)
	# Body
	_rect(img, 7, 7, 2, 4, body)
	# Head
	_rect(img, 7, 5, 2, 2, body)
	_px(img, 7, 6, Color(0.85, 0.30, 0.30))  # eye
	_px(img, 8, 6, Color(0.85, 0.30, 0.30))
	# Wings (spread)
	# Left wing
	_px(img, 6, 7, body); _px(img, 5, 6, body); _px(img, 4, 7, body)
	_px(img, 3, 8, body); _px(img, 2, 7, body); _px(img, 1, 8, body)
	_px(img, 0, 9, body); _px(img, 6, 9, body)
	# Right wing
	_px(img, 9, 7, body); _px(img, 10, 6, body); _px(img, 11, 7, body)
	_px(img, 12, 8, body); _px(img, 13, 7, body); _px(img, 14, 8, body)
	_px(img, 15, 9, body); _px(img, 9, 9, body)
	# Ears
	_px(img, 7, 4, body); _px(img, 8, 4, body)

static func _draw_floor(img: Image) -> void:
	# Tiled floor pattern (single 16x16 tile)
	var base := Color(0.18, 0.16, 0.22)
	var dark := Color(0.12, 0.10, 0.16)
	img.fill(base)
	# 4 8x8 tiles
	_rect(img, 0, 0, 8, 8, base)
	_rect(img, 8, 0, 8, 8, base)
	_rect(img, 0, 8, 8, 8, base)
	_rect(img, 8, 8, 8, 8, base)
	# Grout lines
	_rect(img, 0, 7, 16, 1, dark)
	_rect(img, 7, 0, 1, 16, dark)
	# Some flecks
	_px(img, 2, 3, dark); _px(img, 11, 5, dark)
	_px(img, 4, 12, dark); _px(img, 13, 11, dark)

static func _draw_wall(img: Image) -> void:
	# Stone wall pattern
	var stone := Color(0.30, 0.28, 0.34)
	var dark := Color(0.18, 0.16, 0.22)
	img.fill(stone)
	# Brick pattern
	_rect(img, 0, 0, 16, 1, dark)
	_rect(img, 0, 5, 16, 1, dark)
	_rect(img, 0, 10, 16, 1, dark)
	_rect(img, 0, 15, 16, 1, dark)
	# Vertical breaks (offset per row)
	_rect(img, 7, 0, 1, 5, dark)
	_rect(img, 3, 5, 1, 5, dark)
	_rect(img, 11, 5, 1, 5, dark)
	_rect(img, 7, 10, 1, 5, dark)
	# Highlight
	_px(img, 1, 1, Color(0.40, 0.38, 0.44))
	_px(img, 8, 1, Color(0.40, 0.38, 0.44))
	_px(img, 4, 6, Color(0.40, 0.38, 0.44))

static func _draw_altar(img: Image) -> void:
	# Stone altar with rune glow
	var stone := Color(0.40, 0.38, 0.45)
	var dark := Color(0.20, 0.18, 0.25)
	var glow := Color(0.55, 0.75, 0.95)
	# Top
	_rect(img, 2, 4, 12, 2, stone)
	# Body
	_rect(img, 3, 6, 10, 7, stone)
	# Base
	_rect(img, 2, 13, 12, 2, stone)
	# Shadow
	_rect(img, 3, 13, 10, 1, dark)
	# Rune glow on top
	_px(img, 7, 4, glow); _px(img, 8, 4, glow)
	_px(img, 6, 5, glow); _px(img, 9, 5, glow)
	# Pillars
	_px(img, 4, 6, dark); _px(img, 11, 6, dark)

static func _draw_bench(img: Image) -> void:
	# Polish bench: wooden surface
	var wood := Color(0.50, 0.32, 0.20)
	var dark := Color(0.30, 0.18, 0.12)
	# Top
	_rect(img, 1, 6, 14, 3, wood)
	# Legs
	_rect(img, 2, 9, 2, 5, wood)
	_rect(img, 12, 9, 2, 5, wood)
	# Shadow
	_rect(img, 1, 9, 14, 1, dark)
	# Wood grain
	_px(img, 3, 7, dark); _px(img, 7, 7, dark)
	_px(img, 11, 7, dark); _px(img, 5, 8, dark)

static func _draw_grindstone(img: Image) -> void:
	var stone := Color(0.55, 0.55, 0.58)
	var dark := Color(0.30, 0.30, 0.33)
	var wood := Color(0.45, 0.30, 0.20)
	# Wheel
	_rect(img, 3, 2, 10, 10, stone)
	# Center
	_rect(img, 7, 6, 2, 2, dark)
	# Inner shadow
	_px(img, 4, 3, dark); _px(img, 5, 3, dark)
	_px(img, 4, 4, dark)
	# Stand
	_rect(img, 7, 12, 2, 3, wood)
	_rect(img, 4, 14, 8, 1, wood)

static func _draw_furnace(img: Image) -> void:
	var stone := Color(0.40, 0.35, 0.32)
	var dark := Color(0.22, 0.18, 0.18)
	var fire := Color(0.95, 0.55, 0.20)
	var fire_bright := Color(1.0, 0.85, 0.40)
	# Body
	_rect(img, 2, 3, 12, 11, stone)
	# Opening
	_rect(img, 4, 6, 8, 6, dark)
	# Fire
	_rect(img, 5, 9, 6, 3, fire)
	_rect(img, 6, 10, 4, 2, fire_bright)
	_px(img, 7, 11, fire_bright); _px(img, 8, 11, fire_bright)
	# Chimney
	_rect(img, 6, 1, 4, 2, stone)
	_rect(img, 7, 0, 2, 1, dark)
	# Trim
	_rect(img, 2, 13, 12, 1, dark)

static func _draw_chest(img: Image) -> void:
	var wood := Color(0.55, 0.35, 0.20)
	var dark := Color(0.30, 0.18, 0.12)
	var gold := Color(0.95, 0.80, 0.30)
	# Lid
	_rect(img, 2, 4, 12, 3, wood)
	# Body
	_rect(img, 2, 7, 12, 6, wood)
	# Bands
	_rect(img, 2, 6, 12, 1, dark)
	_rect(img, 2, 12, 12, 1, dark)
	# Lock
	_rect(img, 7, 8, 2, 3, gold)
	# Trim
	_rect(img, 2, 4, 1, 9, dark)
	_rect(img, 13, 4, 1, 9, dark)

static func _draw_crate(img: Image) -> void:
	var wood := Color(0.65, 0.45, 0.25)
	var dark := Color(0.35, 0.22, 0.15)
	# Outer
	_rect(img, 1, 1, 14, 14, wood)
	# Border
	_rect(img, 1, 1, 14, 1, dark)
	_rect(img, 1, 14, 14, 1, dark)
	_rect(img, 1, 1, 1, 14, dark)
	_rect(img, 14, 1, 1, 14, dark)
	# X bracing
	for i in 14:
		_px(img, 1 + i, 1 + i, dark)
		_px(img, 14 - i, 1 + i, dark)

static func _draw_default(img: Image) -> void:
	# Magenta-black checkerboard (Godot missing-texture style)
	for x in 16:
		for y in 16:
			var c := Color(0.95, 0.10, 0.85) if (x + y) % 2 == 0 else Color(0.05, 0.05, 0.05)
			img.set_pixel(x, y, c)
