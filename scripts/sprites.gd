class_name Sprites
extends RefCounted
## Procedurally generates all pixel sprites at runtime.
## V2: Larger 32x32 base sprites with more detail + state-tinted weapon renders.
## All sprites cached in a static dictionary.

# Sprite size constants
const SIZE_16: int = 16
const SIZE_32: int = 32

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
	# Default to 32x32 for richer detail; legacy 16x16 still supported via "_16" suffix
	var size: int = SIZE_32
	var base_name := name
	if name.ends_with("_16"):
		size = SIZE_16
		base_name = name.substr(0, name.length() - 3)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match base_name:
		"ghost":       _draw_ghost(img, size)
		"knight":      _draw_knight(img, size)
		"mage":        _draw_mage(img, size)
		"sword":       _draw_sword(img, size)
		"staff":       _draw_staff(img, size)
		"helm":        _draw_helm(img, size)
		"robe":        _draw_robe(img, size)
		"slime":       _draw_slime(img, size)
		"skeleton":    _draw_skeleton(img, size)
		"bat":         _draw_bat(img, size)
		"floor":       _draw_floor(img, size)
		"floor_cracked": _draw_floor_cracked(img, size)
		"floor_blood": _draw_floor_blood(img, size)
		"wall":        _draw_wall(img, size)
		"wall_mossy":  _draw_wall_mossy(img, size)
		"altar":       _draw_altar(img, size)
		"bench":       _draw_bench(img, size)
		"grindstone":  _draw_grindstone(img, size)
		"furnace":     _draw_furnace(img, size)
		"chest":       _draw_chest(img, size)
		"crate":       _draw_crate(img, size)
		"pit":         _draw_pit(img, size)
		"torch":       _draw_torch(img, size)
		"corpse":      _draw_corpse(img, size)
		"bone_pile":   _draw_bone_pile(img, size)
		"door":        _draw_door(img, size)
		"stairs_down": _draw_stairs_down(img, size)
		"heart":       _draw_heart(img, size)
		"shard":       _draw_shard(img, size)
		"spark":       _draw_spark(img, size)
		"smoke":       _draw_smoke(img, size)
		"flag":        _draw_flag(img, size)
		_:             _draw_default(img, size)
	return img

# === PIXEL HELPERS ===
static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, c)

static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for i in range(x, x + w):
		for j in range(y, y + h):
			_px(img, i, j, c)

static func _circle(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y <= r * r:
				_px(img, cx + x, cy + y, c)

static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx: int = abs(x1 - x0)
	var dy: int = abs(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx - dy
	while true:
		_px(img, x0, y0, c)
		if x0 == x1 and y0 == y1:
			break
		var e2: int = 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy

# === CHARACTERS (32x32) ===
static func _draw_ghost(img: Image, s: int) -> void:
	var body := Color(0.85, 0.88, 0.95, 0.85)
	var body_dim := Color(0.65, 0.68, 0.80, 0.65)
	var dark := Color(0.10, 0.05, 0.18, 1.0)
	var cheek := Color(0.85, 0.65, 0.85, 0.6)
	# Top dome
	_circle(img, s/2, s/2 - 2, 9, body)
	# Body wavy bottom
	for x in range(s/2 - 9, s/2 + 10):
		for y in range(s/2 + 5, s/2 + 12):
			# Wave pattern
			var wave := sin((x - s/2) * 0.7) * 2
			if y < s/2 + 12 + wave:
				_px(img, x, y, body)
	# Outer dim halo
	_circle(img, s/2, s/2 - 2, 11, body_dim)
	_circle(img, s/2, s/2 - 2, 9, body)
	# Wavy bottom (3 bumps)
	_rect(img, s/2 - 9, s/2 + 6, 18, 4, body)
	_px(img, s/2 - 9, s/2 + 10, body); _px(img, s/2 - 8, s/2 + 11, body)
	_px(img, s/2 - 7, s/2 + 10, body); _px(img, s/2 - 6, s/2 + 11, body)
	_px(img, s/2 - 5, s/2 + 10, body); _px(img, s/2 - 4, s/2 + 11, body)
	_px(img, s/2 - 3, s/2 + 10, body); _px(img, s/2 - 2, s/2 + 11, body)
	_px(img, s/2 - 1, s/2 + 10, body); _px(img, s/2, s/2 + 11, body)
	_px(img, s/2 + 1, s/2 + 10, body); _px(img, s/2 + 2, s/2 + 11, body)
	_px(img, s/2 + 3, s/2 + 10, body); _px(img, s/2 + 4, s/2 + 11, body)
	_px(img, s/2 + 5, s/2 + 10, body); _px(img, s/2 + 6, s/2 + 11, body)
	_px(img, s/2 + 7, s/2 + 10, body); _px(img, s/2 + 8, s/2 + 11, body)
	# Eyes (large, expressive)
	_rect(img, s/2 - 6, s/2 - 4, 4, 5, dark)
	_rect(img, s/2 + 2, s/2 - 4, 4, 5, dark)
	# Eye highlights
	_px(img, s/2 - 5, s/2 - 3, Color(1, 1, 1, 0.9))
	_px(img, s/2 + 3, s/2 - 3, Color(1, 1, 1, 0.9))
	# Cheeks (rosy)
	_px(img, s/2 - 7, s/2 + 1, cheek); _px(img, s/2 - 8, s/2 + 1, cheek)
	_px(img, s/2 + 6, s/2 + 1, cheek); _px(img, s/2 + 7, s/2 + 1, cheek)
	# Mouth (small O)
	_rect(img, s/2 - 1, s/2 + 3, 2, 2, dark)

static func _draw_knight(img: Image, s: int) -> void:
	var armor := Color(0.55, 0.65, 0.85)
	var armor_dark := Color(0.30, 0.38, 0.55)
	var armor_light := Color(0.75, 0.82, 0.95)
	var plume := Color(0.85, 0.30, 0.30)
	var dark := Color(0.15, 0.15, 0.20)
	# Body (armor)
	_rect(img, s/2 - 7, s/2 + 2, 14, 12, armor)
	# Armor shading
	_rect(img, s/2 - 7, s/2 + 2, 14, 2, armor_light)
	_rect(img, s/2 - 7, s/2 + 12, 14, 2, armor_dark)
	# Belt
	_rect(img, s/2 - 7, s/2 + 8, 14, 2, dark)
	_px(img, s/2 - 1, s/2 + 8, Color(0.95, 0.85, 0.30))  # buckle
	_px(img, s/2, s/2 + 8, Color(0.95, 0.85, 0.30))
	# Helmet
	_rect(img, s/2 - 5, s/2 - 8, 10, 8, armor)
	_rect(img, s/2 - 5, s/2 - 8, 10, 2, armor_light)
	_rect(img, s/2 - 5, s/2 - 2, 10, 2, armor_dark)
	# Visor slit
	_rect(img, s/2 - 4, s/2 - 3, 8, 1, dark)
	# Plume
	_rect(img, s/2 - 1, s/2 - 12, 2, 4, plume)
	_px(img, s/2 - 2, s/2 - 11, plume)
	_px(img, s/2 + 1, s/2 - 11, plume)
	# Shoulder pads
	_rect(img, s/2 - 9, s/2 + 2, 2, 4, armor)
	_rect(img, s/2 + 7, s/2 + 2, 2, 4, armor)
	# Legs
	_rect(img, s/2 - 5, s/2 + 14, 4, 4, armor_dark)
	_rect(img, s/2 + 1, s/2 + 14, 4, 4, armor_dark)
	# Shield (left side)
	_rect(img, s/2 - 12, s/2 + 4, 3, 8, armor_light)
	_px(img, s/2 - 11, s/2 + 7, plume)  # shield emblem

static func _draw_mage(img: Image, s: int) -> void:
	var robe := Color(0.50, 0.30, 0.70)
	var robe_dark := Color(0.30, 0.18, 0.45)
	var robe_light := Color(0.65, 0.45, 0.85)
	var skin := Color(0.95, 0.80, 0.65)
	var hat := Color(0.40, 0.22, 0.60)
	var dark := Color(0.15, 0.10, 0.20)
	var gold := Color(0.95, 0.85, 0.30)
	# Hat (pointed)
	_px(img, s/2, s/2 - 14, hat)
	_rect(img, s/2 - 1, s/2 - 13, 2, 1, hat)
	_rect(img, s/2 - 2, s/2 - 12, 4, 1, hat)
	_rect(img, s/2 - 3, s/2 - 11, 6, 1, hat)
	_rect(img, s/2 - 4, s/2 - 10, 8, 1, hat)
	_rect(img, s/2 - 5, s/2 - 9, 10, 1, hat)
	_rect(img, s/2 - 6, s/2 - 8, 12, 1, hat)
	# Hat star
	_px(img, s/2 - 1, s/2 - 7, gold); _px(img, s/2, s/2 - 7, gold)
	_px(img, s/2 - 2, s/2 - 6, gold); _px(img, s/2 + 1, s/2 - 6, gold)
	_px(img, s/2 - 1, s/2 - 5, gold); _px(img, s/2, s/2 - 5, gold)
	# Face
	_rect(img, s/2 - 5, s/2 - 7, 10, 5, skin)
	_rect(img, s/2 - 5, s/2 - 7, 10, 1, robe_dark)  # hat brim
	_px(img, s/2 - 3, s/2 - 5, dark); _px(img, s/2 + 2, s/2 - 5, dark)  # eyes
	# Beard
	_rect(img, s/2 - 3, s/2 - 2, 6, 2, Color(0.85, 0.80, 0.70))
	# Robe body
	_rect(img, s/2 - 7, s/2 + 2, 14, 14, robe)
	# Robe shading
	_rect(img, s/2 - 7, s/2 + 2, 14, 2, robe_light)
	_rect(img, s/2 - 7, s/2 + 14, 14, 2, robe_dark)
	# Robe sash
	_rect(img, s/2 - 7, s/2 + 8, 14, 1, gold)
	# Star on robe
	_px(img, s/2 - 1, s/2 + 5, gold); _px(img, s/2, s/2 + 5, gold)
	_px(img, s/2 - 2, s/2 + 6, gold); _px(img, s/2 + 1, s/2 + 6, gold)
	_px(img, s/2 - 1, s/2 + 7, gold); _px(img, s/2, s/2 + 7, gold)
	# Sleeve (with hand visible)
	_rect(img, s/2 - 10, s/2 + 6, 3, 5, robe)
	_px(img, s/2 - 9, s/2 + 11, skin)
	_rect(img, s/2 + 7, s/2 + 6, 3, 5, robe)
	_px(img, s/2 + 8, s/2 + 11, skin)
	# Bottom flare
	_rect(img, s/2 - 9, s/2 + 14, 18, 2, robe_dark)

# === WEAPONS (32x32, drawn LARGE for minigame visibility) ===
static func _draw_sword(img: Image, s: int) -> void:
	var blade := Color(0.80, 0.85, 0.92)
	var blade_light := Color(0.95, 0.97, 1.0)
	var blade_dark := Color(0.50, 0.55, 0.65)
	var hilt := Color(0.55, 0.35, 0.20)
	var hilt_dark := Color(0.30, 0.18, 0.12)
	var guard := Color(0.75, 0.65, 0.25)
	var gem := Color(0.85, 0.30, 0.40)
	# Blade (vertical, top half)
	_rect(img, s/2 - 1, 2, 3, 14, blade)
	# Blade highlight
	_rect(img, s/2 - 1, 2, 1, 14, blade_light)
	# Blade dark edge
	_rect(img, s/2 + 1, 2, 1, 14, blade_dark)
	# Blade tip
	_px(img, s/2, 1, blade_light)
	_px(img, s/2 - 1, 2, blade_light)
	_px(img, s/2 + 1, 2, blade_light)
	# Crossguard
	_rect(img, s/2 - 5, 16, 11, 2, guard)
	_rect(img, s/2 - 5, 18, 11, 1, hilt_dark)
	# Gem in guard center
	_px(img, s/2 - 1, 16, gem); _px(img, s/2, 16, gem)
	_px(img, s/2 - 1, 17, Color(1.0, 0.6, 0.7)); _px(img, s/2, 17, Color(1.0, 0.6, 0.7))
	# Grip
	_rect(img, s/2 - 1, 19, 3, 8, hilt)
	# Grip wrap (cross pattern)
	for i in 4:
		_px(img, s/2 - 1, 19 + i * 2, hilt_dark)
		_px(img, s/2 + 1, 20 + i * 2, hilt_dark)
	# Pommel
	_circle(img, s/2, 28, 2, guard)
	_px(img, s/2 - 1, 27, blade_light)

static func _draw_staff(img: Image, s: int) -> void:
	var wood := Color(0.45, 0.28, 0.18)
	var wood_dark := Color(0.25, 0.15, 0.10)
	var wood_light := Color(0.60, 0.40, 0.25)
	var orb := Color(0.45, 0.70, 0.95)
	var orb_bright := Color(0.85, 0.95, 1.0)
	var orb_glow := Color(0.55, 0.80, 1.0, 0.5)
	var gold := Color(0.85, 0.70, 0.25)
	# Stick (vertical)
	_rect(img, s/2, 8, 2, 22, wood)
	# Wood grain
	_px(img, s/2, 10, wood_dark)
	_px(img, s/2, 14, wood_dark)
	_px(img, s/2, 18, wood_dark)
	_px(img, s/2 + 1, 22, wood_dark)
	# Wood highlight
	_px(img, s/2, 12, wood_light)
	_px(img, s/2, 20, wood_light)
	# Orb holder (claws)
	_px(img, s/2 - 2, 6, gold); _px(img, s/2 + 3, 6, gold)
	_px(img, s/2 - 2, 7, gold); _px(img, s/2 + 3, 7, gold)
	_rect(img, s/2 - 1, 5, 4, 1, gold)
	# Orb (top)
	_circle(img, s/2 + 1, 4, 4, orb)
	# Orb highlight
	_circle(img, s/2 - 1, 2, 2, orb_bright)
	# Glow
	_px(img, s/2 - 3, 4, orb_glow); _px(img, s/2 + 5, 4, orb_glow)
	_px(img, s/2 + 1, 0, orb_glow); _px(img, s/2 + 1, 9, orb_glow)
	# Sparkle
	_px(img, s/2 - 2, 1, Color(1, 1, 1, 0.9))

static func _draw_helm(img: Image, s: int) -> void:
	var metal := Color(0.78, 0.82, 0.88)
	var metal_light := Color(0.95, 0.97, 1.0)
	var metal_dark := Color(0.45, 0.50, 0.60)
	var dark := Color(0.15, 0.15, 0.20)
	var gold := Color(0.85, 0.70, 0.25)
	var gem := Color(0.30, 0.80, 0.50)
	# Top spike
	_rect(img, s/2 - 1, 1, 2, 3, metal)
	# Dome
	_circle(img, s/2, s/2 - 4, 8, metal)
	_rect(img, s/2 - 8, s/2 - 4, 16, 8, metal)
	# Highlight
	_circle(img, s/2 - 3, s/2 - 7, 3, metal_light)
	# Bottom rim
	_rect(img, s/2 - 9, s/2 + 3, 18, 2, metal_dark)
	# Visor (eye slit)
	_rect(img, s/2 - 6, s/2 - 2, 12, 2, dark)
	# Eye glow
	_px(img, s/2 - 5, s/2 - 2, Color(0.95, 0.40, 0.40))
	_px(img, s/2 + 4, s/2 - 2, Color(0.95, 0.40, 0.40))
	# Nose guard
	_rect(img, s/2 - 1, s/2 - 1, 2, 4, metal_dark)
	# Side rivets
	_px(img, s/2 - 7, s/2 + 1, gold); _px(img, s/2 + 6, s/2 + 1, gold)
	# Gem on forehead
	_px(img, s/2 - 1, s/2 - 6, gem); _px(img, s/2, s/2 - 6, gem)
	_px(img, s/2 - 1, s/2 - 5, Color(0.50, 0.95, 0.70))
	_px(img, s/2, s/2 - 5, Color(0.50, 0.95, 0.70))
	# Cheek plates
	_rect(img, s/2 - 9, s/2 - 1, 2, 5, metal_dark)
	_rect(img, s/2 + 7, s/2 - 1, 2, 5, metal_dark)

static func _draw_robe(img: Image, s: int) -> void:
	var cloth := Color(0.45, 0.32, 0.65)
	var cloth_dark := Color(0.25, 0.18, 0.40)
	var cloth_light := Color(0.60, 0.45, 0.80)
	var gold := Color(0.95, 0.85, 0.30)
	var trim := Color(0.85, 0.65, 0.25)
	# Trapezoid body
	_rect(img, s/2 - 5, 4, 10, 4, cloth)
	_rect(img, s/2 - 7, 8, 14, 8, cloth)
	_rect(img, s/2 - 9, 16, 18, 6, cloth)
	_rect(img, s/2 - 11, 22, 22, 4, cloth_dark)
	# Highlight (left side)
	_rect(img, s/2 - 5, 4, 3, 4, cloth_light)
	_rect(img, s/2 - 7, 8, 3, 8, cloth_light)
	_rect(img, s/2 - 9, 16, 3, 6, cloth_light)
	# Sleeves
	_rect(img, 4, 10, 4, 8, cloth)
	_rect(img, s - 8, 10, 4, 8, cloth)
	_rect(img, 4, 17, 4, 2, cloth_dark)
	_rect(img, s - 8, 17, 4, 2, cloth_dark)
	# Trim (gold along edges)
	_rect(img, s/2 - 11, 22, 22, 1, gold)
	_rect(img, s/2 - 5, 4, 10, 1, gold)
	# Center buttons
	_px(img, s/2, 10, gold); _px(img, s/2, 14, gold); _px(img, s/2, 18, gold)
	# Collar (V shape)
	_line(img, s/2 - 2, 4, s/2, 9, trim)
	_line(img, s/2 + 1, 4, s/2, 9, trim)
	# Bottom hem
	_rect(img, s/2 - 11, 25, 22, 1, gold)

# === ENEMIES (32x32) ===
static func _draw_slime(img: Image, s: int) -> void:
	var body := Color(0.50, 0.85, 0.50)
	var body_dark := Color(0.30, 0.55, 0.30)
	var body_light := Color(0.70, 1.0, 0.70)
	var dark := Color(0.10, 0.20, 0.10)
	# Dome body
	_rect(img, s/2 - 10, s/2 + 2, 20, 10, body)
	_rect(img, s/2 - 8, s/2 - 4, 16, 6, body)
	_rect(img, s/2 - 5, s/2 - 8, 10, 4, body)
	# Top highlight
	_rect(img, s/2 - 7, s/2 - 6, 4, 3, body_light)
	_px(img, s/2 - 6, s/2 - 5, Color(1, 1, 1, 0.8))
	# Bottom shadow
	_rect(img, s/2 - 10, s/2 + 10, 20, 2, body_dark)
	# Eyes (big, expressive)
	_rect(img, s/2 - 6, s/2 - 1, 3, 4, dark)
	_rect(img, s/2 + 3, s/2 - 1, 3, 4, dark)
	_px(img, s/2 - 5, s/2, Color(1, 1, 1)); _px(img, s/2 + 4, s/2, Color(1, 1, 1))
	# Mouth (smile)
	_rect(img, s/2 - 3, s/2 + 5, 6, 1, dark)
	_px(img, s/2 - 4, s/2 + 4, dark); _px(img, s/2 + 3, s/2 + 4, dark)
	# Drips
	_px(img, s/2 - 9, s/2 + 12, body); _px(img, s/2 + 8, s/2 + 12, body)

static func _draw_skeleton(img: Image, s: int) -> void:
	var bone := Color(0.92, 0.88, 0.75)
	var bone_dark := Color(0.65, 0.58, 0.45)
	var dark := Color(0.10, 0.08, 0.10)
	var eye := Color(0.95, 0.30, 0.30)
	# Skull
	_rect(img, s/2 - 6, s/2 - 12, 12, 10, bone)
	_rect(img, s/2 - 6, s/2 - 12, 12, 2, bone_dark)
	# Forehead shadow
	_rect(img, s/2 - 6, s/2 - 10, 12, 1, bone_dark)
	# Eye sockets (deep)
	_rect(img, s/2 - 4, s/2 - 8, 3, 3, dark)
	_rect(img, s/2 + 1, s/2 - 8, 3, 3, dark)
	# Eye glow
	_px(img, s/2 - 3, s/2 - 7, eye); _px(img, s/2 + 2, s/2 - 7, eye)
	# Nose
	_rect(img, s/2 - 1, s/2 - 5, 2, 2, dark)
	# Teeth (vertical lines)
	for i in 5:
		_px(img, s/2 - 4 + i * 2, s/2 - 3, dark)
		_px(img, s/2 - 4 + i * 2, s/2 - 2, dark)
	_rect(img, s/2 - 5, s/2 - 4, 10, 1, bone_dark)
	# Spine
	_rect(img, s/2 - 1, s/2 - 2, 2, 8, bone)
	# Ribs (3 pairs)
	for i in 3:
		_rect(img, s/2 - 6, s/2 + i * 2, 5, 1, bone)
		_rect(img, s/2 + 1, s/2 + i * 2, 5, 1, bone)
		_px(img, s/2 - 6, s/2 + i * 2, bone_dark)
		_px(img, s/2 + 5, s/2 + i * 2, bone_dark)
	# Arms
	_rect(img, s/2 - 10, s/2, 4, 1, bone)
	_rect(img, s/2 - 11, s/2 + 1, 2, 4, bone)
	_rect(img, s/2 + 7, s/2, 4, 1, bone)
	_rect(img, s/2 + 10, s/2 + 1, 2, 4, bone)
	# Pelvis
	_rect(img, s/2 - 4, s/2 + 6, 8, 2, bone)
	# Legs
	_rect(img, s/2 - 4, s/2 + 8, 2, 8, bone)
	_rect(img, s/2 + 2, s/2 + 8, 2, 8, bone)
	_px(img, s/2 - 4, s/2 + 15, bone_dark)
	_px(img, s/2 + 2, s/2 + 15, bone_dark)

static func _draw_bat(img: Image, s: int) -> void:
	var body := Color(0.30, 0.18, 0.40)
	var body_dark := Color(0.15, 0.08, 0.20)
	var wing := Color(0.40, 0.25, 0.50)
	var wing_dark := Color(0.20, 0.12, 0.30)
	var eye := Color(0.95, 0.30, 0.30)
	# Body (center)
	_rect(img, s/2 - 2, s/2 - 4, 4, 10, body)
	_rect(img, s/2 - 2, s/2 - 4, 4, 2, body_dark)
	# Head
	_rect(img, s/2 - 3, s/2 - 8, 6, 4, body)
	# Ears
	_px(img, s/2 - 3, s/2 - 10, body)
	_px(img, s/2 - 2, s/2 - 11, body)
	_px(img, s/2 + 2, s/2 - 10, body)
	_px(img, s/2 + 3, s/2 - 11, body)
	# Eyes
	_px(img, s/2 - 2, s/2 - 6, eye)
	_px(img, s/2 + 1, s/2 - 6, eye)
	# Fangs
	_px(img, s/2 - 1, s/2 - 3, Color(1, 1, 1))
	_px(img, s/2, s/2 - 3, Color(1, 1, 1))
	# Left wing (spread)
	_rect(img, 2, s/2 - 2, 8, 4, wing)
	_px(img, 1, s/2 - 1, wing); _px(img, 1, s/2 + 2, wing)
	# Wing finger lines
	_line(img, 2, s/2 - 1, 9, s/2 - 2, wing_dark)
	_line(img, 2, s/2 + 1, 9, s/2 + 1, wing_dark)
	_line(img, 2, s/2 + 3, 9, s/2 + 3, wing_dark)
	# Right wing
	_rect(img, s - 10, s/2 - 2, 8, 4, wing)
	_px(img, s - 2, s/2 - 1, wing); _px(img, s - 2, s/2 + 2, wing)
	_line(img, s - 9, s/2 - 2, s - 2, s/2 - 1, wing_dark)
	_line(img, s - 9, s/2 + 1, s - 2, s/2 + 1, wing_dark)
	_line(img, s - 9, s/2 + 3, s - 2, s/2 + 3, wing_dark)
	# Feet
	_px(img, s/2 - 2, s/2 + 6, body_dark)
	_px(img, s/2 + 1, s/2 + 6, body_dark)

# === TILES (32x32) ===
static func _draw_floor(img: Image, s: int) -> void:
	var base := Color(0.18, 0.16, 0.22)
	var dark := Color(0.12, 0.10, 0.16)
	var light := Color(0.22, 0.20, 0.28)
	img.fill(base)
	# 4 large tiles (16x16 each)
	for ty in 2:
		for tx in 2:
			var ox := tx * 16
			var oy := ty * 16
			# Tile base
			_rect(img, ox, oy, 16, 16, base)
			# Random flecks
			for i in 6:
				_px(img, ox + (i * 7 + tx * 3) % 14, oy + (i * 5 + ty * 2) % 14, dark)
			# Highlight corner
			_px(img, ox + 2, oy + 2, light)
			_px(img, ox + 3, oy + 2, light)
	# Grout lines (cross in center)
	_rect(img, 0, 15, 32, 2, dark)
	_rect(img, 15, 0, 2, 32, dark)

static func _draw_floor_cracked(img: Image, s: int) -> void:
	_draw_floor(img, s)
	var dark := Color(0.05, 0.04, 0.07)
	# Crack from top-left to bottom-right
	_line(img, 4, 6, 10, 12, dark)
	_line(img, 10, 12, 18, 14, dark)
	_line(img, 18, 14, 24, 22, dark)
	_line(img, 24, 22, 28, 26, dark)
	# Branch
	_line(img, 18, 14, 20, 22, dark)

static func _draw_floor_blood(img: Image, s: int) -> void:
	_draw_floor(img, s)
	var blood := Color(0.55, 0.10, 0.10)
	var blood_dark := Color(0.35, 0.05, 0.05)
	# Blood pool
	_circle(img, 10, 20, 5, blood_dark)
	_circle(img, 10, 20, 4, blood)
	# Splatter
	_px(img, 4, 14, blood); _px(img, 18, 22, blood)
	_px(img, 22, 16, blood); _px(img, 6, 26, blood)
	_px(img, 16, 8, blood_dark); _px(img, 24, 26, blood_dark)

static func _draw_wall(img: Image, s: int) -> void:
	var stone := Color(0.30, 0.28, 0.34)
	var stone_dark := Color(0.18, 0.16, 0.22)
	var stone_light := Color(0.40, 0.38, 0.44)
	img.fill(stone)
	# Brick pattern: 3 rows of 2 bricks each
	# Row 1 (top)
	_rect(img, 0, 0, 32, 1, stone_dark)
	_rect(img, 0, 10, 32, 1, stone_dark)
	_rect(img, 0, 21, 32, 1, stone_dark)
	_rect(img, 0, 31, 32, 1, stone_dark)
	# Vertical breaks (offset)
	_rect(img, 15, 0, 1, 10, stone_dark)
	_rect(img, 8, 11, 1, 10, stone_dark)
	_rect(img, 23, 11, 1, 10, stone_dark)
	_rect(img, 15, 22, 1, 10, stone_dark)
	# Highlights
	_rect(img, 1, 1, 4, 1, stone_light)
	_rect(img, 17, 1, 4, 1, stone_light)
	_rect(img, 1, 12, 4, 1, stone_light)
	_rect(img, 9, 12, 4, 1, stone_light)
	_rect(img, 24, 12, 4, 1, stone_light)
	_rect(img, 1, 23, 4, 1, stone_light)
	_rect(img, 17, 23, 4, 1, stone_light)

static func _draw_wall_mossy(img: Image, s: int) -> void:
	_draw_wall(img, s)
	var moss := Color(0.30, 0.55, 0.25)
	var moss_light := Color(0.45, 0.70, 0.35)
	# Moss patches
	_rect(img, 2, 3, 5, 2, moss)
	_px(img, 3, 2, moss_light); _px(img, 5, 5, moss_light)
	_rect(img, 18, 14, 6, 2, moss)
	_px(img, 19, 13, moss_light); _px(img, 22, 16, moss_light)
	_rect(img, 4, 25, 7, 2, moss)
	_px(img, 6, 24, moss_light); _px(img, 9, 27, moss_light)
	_rect(img, 20, 26, 5, 2, moss)

# === STATIONS (32x32) ===
static func _draw_altar(img: Image, s: int) -> void:
	var stone := Color(0.40, 0.38, 0.45)
	var stone_dark := Color(0.22, 0.20, 0.28)
	var stone_light := Color(0.55, 0.52, 0.60)
	var glow := Color(0.55, 0.75, 0.95, 0.9)
	var glow_bright := Color(0.85, 0.95, 1.0, 0.8)
	# Top slab
	_rect(img, 2, 6, 28, 4, stone)
	_rect(img, 2, 6, 28, 1, stone_light)
	# Body
	_rect(img, 4, 10, 24, 14, stone)
	# Base
	_rect(img, 2, 24, 28, 4, stone_dark)
	_rect(img, 2, 27, 28, 1, Color(0.10, 0.08, 0.12))
	# Pillars at corners
	_rect(img, 4, 10, 2, 14, stone_dark)
	_rect(img, 26, 10, 2, 14, stone_dark)
	# Rune glow on top
	_rect(img, s/2 - 4, 7, 8, 2, glow)
	_rect(img, s/2 - 2, 6, 4, 3, glow_bright)
	# Mystical sparks rising
	_px(img, s/2 - 5, 4, glow_bright)
	_px(img, s/2 + 4, 3, glow_bright)
	_px(img, s/2, 2, glow_bright)

static func _draw_bench(img: Image, s: int) -> void:
	var wood := Color(0.50, 0.32, 0.20)
	var wood_dark := Color(0.30, 0.18, 0.12)
	var wood_light := Color(0.65, 0.45, 0.28)
	var metal := Color(0.75, 0.78, 0.82)
	# Top surface
	_rect(img, 2, 10, 28, 6, wood)
	# Wood grain on top
	_line(img, 4, 12, 28, 12, wood_dark)
	_line(img, 4, 14, 28, 14, wood_dark)
	# Top highlight
	_rect(img, 2, 10, 28, 1, wood_light)
	# Legs
	_rect(img, 4, 16, 3, 12, wood)
	_rect(img, 25, 16, 3, 12, wood)
	# Leg shadows
	_rect(img, 4, 26, 3, 2, wood_dark)
	_rect(img, 25, 26, 3, 2, wood_dark)
	# Cross-brace
	_rect(img, 4, 22, 24, 2, wood_dark)
	# Metal corner brackets
	_rect(img, 2, 10, 2, 2, metal)
	_rect(img, 28, 10, 2, 2, metal)
	# Polish cloth (hanging)
	_rect(img, 12, 14, 6, 4, Color(0.85, 0.75, 0.50))
	_px(img, 13, 17, Color(0.55, 0.45, 0.25))

static func _draw_grindstone(img: Image, s: int) -> void:
	var stone := Color(0.55, 0.55, 0.58)
	var stone_dark := Color(0.30, 0.30, 0.33)
	var stone_light := Color(0.75, 0.75, 0.78)
	var wood := Color(0.45, 0.30, 0.20)
	var wood_dark := Color(0.25, 0.15, 0.12)
	# Wheel (large)
	_circle(img, s/2, s/2 - 4, 11, stone)
	_circle(img, s/2, s/2 - 4, 9, stone_light)
	_circle(img, s/2, s/2 - 4, 7, stone)
	# Center hub
	_circle(img, s/2, s/2 - 4, 3, wood)
	_px(img, s/2, s/2 - 4, wood_dark)
	# Spokes
	for i in 6:
		var a := i * (PI / 3.0)
		var x1 := int(s/2 + cos(a) * 3)
		var y1 := int(s/2 - 4 + sin(a) * 3)
		var x2 := int(s/2 + cos(a) * 9)
		var y2 := int(s/2 - 4 + sin(a) * 9)
		_line(img, x1, y1, x2, y2, stone_dark)
	# Stand
	_rect(img, s/2 - 1, s/2 + 6, 2, 8, wood)
	_rect(img, s/2 - 6, s/2 + 13, 12, 3, wood)
	_rect(img, s/2 - 6, s/2 + 15, 12, 1, wood_dark)
	# Sparks
	_px(img, s/2 + 10, s/2 - 8, Color(1.0, 0.85, 0.30))
	_px(img, s/2 + 11, s/2 - 6, Color(1.0, 0.85, 0.30))
	_px(img, s/2 - 11, s/2 - 8, Color(1.0, 0.85, 0.30))

static func _draw_furnace(img: Image, s: int) -> void:
	var stone := Color(0.40, 0.35, 0.32)
	var stone_dark := Color(0.22, 0.18, 0.18)
	var stone_light := Color(0.55, 0.50, 0.45)
	var fire := Color(0.95, 0.55, 0.20)
	var fire_bright := Color(1.0, 0.85, 0.40)
	var fire_dark := Color(0.85, 0.30, 0.10)
	# Body
	_rect(img, 2, 4, 28, 24, stone)
	# Top edge highlight
	_rect(img, 2, 4, 28, 1, stone_light)
	# Brick lines
	_rect(img, 2, 12, 28, 1, stone_dark)
	_rect(img, 2, 20, 28, 1, stone_dark)
	# Vertical breaks
	_px(img, 10, 5, stone_dark); _px(img, 22, 5, stone_dark)
	_px(img, 6, 13, stone_dark); _px(img, 16, 13, stone_dark); _px(img, 26, 13, stone_dark)
	# Opening (arched)
	_rect(img, 6, 12, 20, 12, Color(0.05, 0.03, 0.03))
	# Arch top
	for x in 20:
		var y_off := int(sqrt(max(0, 100 - (x - 10) * (x - 10))) * 0.3)
		_rect(img, 6 + x, 12 - y_off, 1, 2, stone_dark)
	# Fire inside
	_rect(img, 8, 18, 16, 6, fire_dark)
	_rect(img, 9, 19, 14, 4, fire)
	_rect(img, 10, 20, 12, 2, fire_bright)
	# Flames licking up
	_px(img, 12, 16, fire); _px(img, 14, 14, fire_bright)
	_px(img, 16, 15, fire); _px(img, 18, 13, fire_bright)
	_px(img, 20, 16, fire); _px(img, 22, 14, fire_bright)
	# Chimney top
	_rect(img, 10, 0, 12, 4, stone)
	_rect(img, 10, 0, 12, 1, stone_light)
	_rect(img, 11, 1, 10, 1, stone_dark)
	# Smoke
	_px(img, 14, -1 if s > 16 else 0, Color(0.50, 0.45, 0.45, 0.6))
	_px(img, 16, -2 if s > 16 else 0, Color(0.60, 0.55, 0.55, 0.5))

static func _draw_chest(img: Image, s: int) -> void:
	var wood := Color(0.55, 0.35, 0.20)
	var wood_dark := Color(0.30, 0.18, 0.12)
	var wood_light := Color(0.70, 0.50, 0.30)
	var gold := Color(0.95, 0.80, 0.30)
	var gold_dark := Color(0.65, 0.50, 0.15)
	# Lid (curved top)
	for x in 24:
		var h := int(sqrt(max(0, 144 - (x - 12) * (x - 12))) * 0.5)
		_rect(img, 4 + x, 12 - h, 1, h, wood)
	# Lid bottom edge
	_rect(img, 4, 12, 24, 1, wood_dark)
	# Body
	_rect(img, 4, 12, 24, 14, wood)
	# Body shadow
	_rect(img, 4, 24, 24, 2, wood_dark)
	# Wood grain
	_line(img, 6, 18, 26, 18, wood_dark)
	# Iron bands
	_rect(img, 4, 11, 24, 2, wood_dark)
	_rect(img, 4, 22, 24, 2, wood_dark)
	# Vertical bands
	_rect(img, 9, 12, 2, 14, wood_dark)
	_rect(img, 21, 12, 2, 14, wood_dark)
	# Lock plate
	_rect(img, s/2 - 2, 14, 4, 6, gold)
	_rect(img, s/2 - 2, 14, 4, 1, gold_dark)
	# Keyhole
	_rect(img, s/2 - 1, 16, 2, 2, Color(0, 0, 0))
	# Corner studs
	_px(img, 5, 13, gold); _px(img, 26, 13, gold)
	_px(img, 5, 24, gold); _px(img, 26, 24, gold)

static func _draw_crate(img: Image, s: int) -> void:
	var wood := Color(0.65, 0.45, 0.25)
	var wood_dark := Color(0.35, 0.22, 0.15)
	var wood_light := Color(0.80, 0.60, 0.35)
	# Outer
	_rect(img, 2, 2, 28, 28, wood)
	# Highlight (top + left)
	_rect(img, 2, 2, 28, 1, wood_light)
	_rect(img, 2, 2, 1, 28, wood_light)
	# Shadow (bottom + right)
	_rect(img, 2, 29, 28, 1, wood_dark)
	_rect(img, 29, 2, 1, 28, wood_dark)
	# X bracing
	_line(img, 2, 2, 29, 29, wood_dark)
	_line(img, 2, 29, 29, 2, wood_dark)
	_line(img, 3, 3, 28, 28, wood_light)
	# Corner reinforcements
	_rect(img, 2, 2, 3, 3, wood_dark)
	_rect(img, 27, 2, 3, 3, wood_dark)
	_rect(img, 2, 27, 3, 3, wood_dark)
	_rect(img, 27, 27, 3, 3, wood_dark)

static func _draw_pit(img: Image, s: int) -> void:
	# Salvage pit: dark hole with stuff in it
	var stone := Color(0.25, 0.20, 0.18)
	var stone_dark := Color(0.10, 0.08, 0.06)
	var gold := Color(0.85, 0.70, 0.25)
	var bone := Color(0.80, 0.75, 0.60)
	# Outer ring
	_circle(img, s/2, s/2, 13, stone)
	# Inner dark
	_circle(img, s/2, s/2, 10, stone_dark)
	# Treasure glints
	_px(img, s/2 - 4, s/2 - 2, gold)
	_px(img, s/2 + 3, s/2 + 1, gold)
	_px(img, s/2 - 1, s/2 + 4, gold)
	_px(img, s/2 + 5, s/2 - 4, gold)
	# Bone bits
	_px(img, s/2 - 6, s/2 + 3, bone)
	_px(img, s/2 - 5, s/2 + 4, bone)
	_px(img, s/2 + 4, s/2 - 6, bone)
	_px(img, s/2 + 5, s/2 - 5, bone)
	# Edge highlights
	_px(img, s/2 - 10, s/2 - 8, Color(0.40, 0.32, 0.28))
	_px(img, s/2 + 9, s/2 - 9, Color(0.40, 0.32, 0.28))
	_px(img, s/2 - 9, s/2 + 9, Color(0.15, 0.12, 0.10))

static func _draw_torch(img: Image, s: int) -> void:
	var wood := Color(0.45, 0.28, 0.18)
	var wood_dark := Color(0.25, 0.15, 0.10)
	var fire := Color(0.95, 0.55, 0.20)
	var fire_bright := Color(1.0, 0.85, 0.40)
	var fire_red := Color(0.95, 0.30, 0.10)
	# Handle
	_rect(img, s/2 - 1, 14, 2, 16, wood)
	_rect(img, s/2 - 1, 14, 1, 16, wood_dark)
	# Holder (wrapped)
	_rect(img, s/2 - 2, 10, 4, 4, wood_dark)
	# Flame body
	_circle(img, s/2, 7, 4, fire)
	# Flame shape (tapered top)
	_px(img, s/2, 1, fire_bright)
	_px(img, s/2 - 1, 2, fire_bright); _px(img, s/2, 2, fire_bright); _px(img, s/2 + 1, 2, fire_bright)
	_px(img, s/2 - 2, 3, fire); _px(img, s/2 - 1, 3, fire_bright); _px(img, s/2, 3, fire_bright); _px(img, s/2 + 1, 3, fire_bright); _px(img, s/2 + 2, 3, fire)
	# Inner bright
	_circle(img, s/2, 8, 2, fire_bright)
	# Outer red glow
	_px(img, s/2 - 4, 7, fire_red); _px(img, s/2 + 4, 7, fire_red)
	_px(img, s/2, 11, fire_red)

static func _draw_corpse(img: Image, s: int) -> void:
	# Dead adventurer (knight fallen)
	var armor := Color(0.40, 0.45, 0.55)
	var armor_dark := Color(0.20, 0.25, 0.35)
	var blood := Color(0.45, 0.08, 0.08)
	var blood_dark := Color(0.30, 0.05, 0.05)
	# Body (lying horizontal)
	_rect(img, 4, s/2, 24, 8, armor)
	_rect(img, 4, s/2, 24, 2, armor_dark)
	# Helmet (off to side)
	_rect(img, 2, s/2 - 4, 6, 6, armor)
	_rect(img, 2, s/2 - 4, 6, 1, armor_dark)
	# Blood pool
	_circle(img, s/2, s/2 + 6, 8, blood_dark)
	_circle(img, s/2, s/2 + 6, 6, blood)
	# Splatter
	_px(img, s/2 - 10, s/2 + 4, blood)
	_px(img, s/2 + 10, s/2 + 4, blood)
	_px(img, s/2 - 6, s/2 + 12, blood)
	_px(img, s/2 + 8, s/2 + 12, blood)
	# Sword (dropped beside)
	_rect(img, s - 6, s/2 + 4, 2, 8, Color(0.75, 0.80, 0.85))

static func _draw_bone_pile(img: Image, s: int) -> void:
	var bone := Color(0.85, 0.80, 0.65)
	var bone_dark := Color(0.55, 0.50, 0.40)
	# Pile of bones (random arrangement)
	# Large bone 1 (horizontal)
	_rect(img, 4, s/2 + 2, 14, 2, bone)
	_circle(img, 4, s/2 + 3, 2, bone)
	_circle(img, 18, s/2 + 3, 2, bone)
	# Large bone 2 (diagonal)
	_line(img, 10, s/2 - 4, 22, s/2 + 4, bone)
	_circle(img, 10, s/2 - 4, 2, bone)
	_circle(img, 22, s/2 + 4, 2, bone)
	# Skull
	_rect(img, s/2 - 3, 6, 6, 5, bone)
	_rect(img, s/2 - 3, 6, 6, 1, bone_dark)
	_px(img, s/2 - 2, 8, Color(0.10, 0.08, 0.05))
	_px(img, s/2 + 1, 8, Color(0.10, 0.08, 0.05))
	# Small bone bits
	_rect(img, 22, 4, 4, 1, bone)
	_rect(img, 6, 14, 4, 1, bone)
	_px(img, 24, 12, bone); _px(img, 26, 14, bone)
	# Shadows
	_rect(img, 4, s/2 + 5, 14, 1, bone_dark)
	_rect(img, 8, s/2 + 8, 6, 1, bone_dark)

static func _draw_door(img: Image, s: int) -> void:
	var wood := Color(0.40, 0.25, 0.15)
	var wood_dark := Color(0.20, 0.12, 0.08)
	var wood_light := Color(0.55, 0.35, 0.20)
	var metal := Color(0.70, 0.70, 0.72)
	# Frame
	_rect(img, 2, 2, 28, 28, wood_dark)
	# Door
	_rect(img, 5, 4, 22, 24, wood)
	# Wood planks (2 vertical)
	_rect(img, 5, 4, 1, 24, wood_dark)
	_rect(img, 15, 4, 1, 24, wood_dark)
	_rect(img, 26, 4, 1, 24, wood_dark)
	# Highlights
	_rect(img, 5, 4, 22, 1, wood_light)
	_rect(img, 5, 4, 1, 24, wood_light)
	# Iron rivets
	for i in 3:
		_px(img, 8, 8 + i * 8, metal)
		_px(img, 12, 8 + i * 8, metal)
		_px(img, 18, 8 + i * 8, metal)
		_px(img, 22, 8 + i * 8, metal)
	# Handle
	_circle(img, 22, s/2, 2, metal)
	_px(img, 22, s/2, Color(0.30, 0.30, 0.32))

static func _draw_stairs_down(img: Image, s: int) -> void:
	var stone := Color(0.30, 0.28, 0.32)
	var stone_dark := Color(0.18, 0.16, 0.22)
	var stone_darker := Color(0.10, 0.08, 0.14)
	# Steps (going down)
	for i in 5:
		var y := 4 + i * 5
		var inset := i * 2
		var col := stone_dark if i % 2 == 0 else stone
		_rect(img, inset, y, 32 - inset * 2, 4, col)
		# Top highlight
		_rect(img, inset, y, 32 - inset * 2, 1, stone)
		# Bottom shadow
		_rect(img, inset, y + 3, 32 - inset * 2, 1, stone_darker)
	# Black void at bottom
	_rect(img, 10, 24, 12, 4, stone_darker)
	# Subtle glow from below
	_px(img, 14, 25, Color(0.30, 0.20, 0.40))
	_px(img, 17, 25, Color(0.30, 0.20, 0.40))

# === UI SPRITES (32x32) ===
static func _draw_heart(img: Image, s: int) -> void:
	var red := Color(0.85, 0.20, 0.25)
	var red_dark := Color(0.55, 0.10, 0.15)
	var red_light := Color(1.0, 0.50, 0.55)
	# Heart shape
	_circle(img, s/2 - 4, s/2 - 2, 5, red)
	_circle(img, s/2 + 4, s/2 - 2, 5, red)
	# Bottom triangle
	for i in 8:
		_rect(img, s/2 - 7 + i, s/2 + 2 + i, 14 - i * 2, 1, red)
	# Highlight
	_circle(img, s/2 - 5, s/2 - 4, 2, red_light)
	# Outline (dark)
	_px(img, s/2 - 8, s/2 - 1, red_dark)
	_px(img, s/2 + 8, s/2 - 1, red_dark)

static func _draw_shard(img: Image, s: int) -> void:
	# Soul shard: glowing crystal
	var blue := Color(0.45, 0.75, 0.95)
	var blue_dark := Color(0.20, 0.45, 0.70)
	var blue_light := Color(0.80, 0.95, 1.0)
	var glow := Color(0.55, 0.85, 1.0, 0.5)
	# Outer glow
	_circle(img, s/2, s/2, 10, glow)
	# Crystal shape (diamond)
	for i in 8:
		var w: int = 8 - abs(i - 4) * 2
		_rect(img, s/2 - w, s/2 - 4 + i, w * 2, 1, blue)
	# Dark edges
	_line(img, s/2, 4, s/2 - 8, s/2, blue_dark)
	_line(img, s/2, 4, s/2 + 8, s/2, blue_dark)
	_line(img, s/2 - 8, s/2, s/2, s - 4, blue_dark)
	_line(img, s/2 + 8, s/2, s/2, s - 4, blue_dark)
	# Highlight
	_px(img, s/2 - 2, s/2 - 2, blue_light)
	_px(img, s/2 - 3, s/2 - 1, blue_light)
	_px(img, s/2 - 2, s/2, blue_light)

static func _draw_spark(img: Image, s: int) -> void:
	# 4-pointed star spark
	var yellow := Color(1.0, 0.95, 0.40)
	var white := Color(1.0, 1.0, 1.0)
	# Horizontal
	_rect(img, s/2 - 12, s/2 - 1, 24, 2, yellow)
	# Vertical
	_rect(img, s/2 - 1, s/2 - 12, 2, 24, yellow)
	# Center bright
	_rect(img, s/2 - 3, s/2 - 3, 6, 6, white)
	# Diagonal sparks
	_line(img, s/2 - 8, s/2 - 8, s/2 + 8, s/2 + 8, yellow)
	_line(img, s/2 - 8, s/2 + 8, s/2 + 8, s/2 - 8, yellow)

static func _draw_smoke(img: Image, s: int) -> void:
	var gray := Color(0.55, 0.50, 0.50, 0.7)
	var gray_dark := Color(0.35, 0.32, 0.32, 0.6)
	var gray_light := Color(0.75, 0.70, 0.70, 0.5)
	# Puffy cloud shape
	_circle(img, s/2 - 4, s/2, 5, gray)
	_circle(img, s/2 + 4, s/2, 5, gray)
	_circle(img, s/2, s/2 - 3, 6, gray)
	_circle(img, s/2, s/2 + 3, 5, gray)
	# Highlights
	_circle(img, s/2 - 5, s/2 - 4, 2, gray_light)
	_circle(img, s/2 + 3, s/2 - 5, 2, gray_light)
	# Dark spots
	_px(img, s/2 - 6, s/2 + 3, gray_dark)
	_px(img, s/2 + 5, s/2 + 4, gray_dark)

static func _draw_flag(img: Image, s: int) -> void:
	# Stage cleared flag
	var pole := Color(0.45, 0.30, 0.18)
	var pole_dark := Color(0.25, 0.15, 0.10)
	var flag_c := Color(0.85, 0.25, 0.25)
	var flag_dark := Color(0.55, 0.15, 0.15)
	var gold := Color(0.95, 0.85, 0.30)
	# Pole
	_rect(img, 6, 2, 2, 28, pole)
	_rect(img, 6, 2, 1, 28, pole_dark)
	# Pole top
	_circle(img, 7, 2, 2, gold)
	# Flag (wavy)
	for i in 12:
		var wave := int(sin(i * 0.5) * 2)
		_rect(img, 8 + i, 6 + wave, 1, 10, flag_c)
		_rect(img, 8 + i, 6 + wave, 1, 1, flag_dark)
	# Flag bottom edge
	for i in 12:
		var wave := int(sin(i * 0.5) * 2)
		_px(img, 8 + i, 16 + wave, flag_dark)
	# Flag emblem (skull-ish)
	_rect(img, 12, 9, 4, 4, Color(0.10, 0.05, 0.05))
	_px(img, 12, 10, flag_c); _px(img, 15, 10, flag_c)

# === FALLBACK ===
static func _draw_default(img: Image, s: int) -> void:
	# Magenta-black checkerboard
	for x in s:
		for y in s:
			var c := Color(0.95, 0.10, 0.85) if (x + y) % 2 == 0 else Color(0.05, 0.05, 0.05)
			img.set_pixel(x, y, c)

# === HELPER: Render a weapon with state tint overlay ===
# Returns a new ImageTexture for a weapon in a specific state.
static func get_weapon_sprite(type: String, state: int) -> ImageTexture:
	var key := "weapon_%s_%d" % [type, state]
	if _cache.has(key):
		return _cache[key]
	var base := get_sprite(type)
	var img := base.get_image()
	# Apply state tint
	var tint: Color = Color.WHITE
	match state:
		Weapon.State.BLOODIED:  tint = Color(1.2, 0.6, 0.6, 1.0)  # redden
		Weapon.State.RUSTED:    tint = Color(1.3, 1.0, 0.5, 1.0)  # orange-brown
		Weapon.State.HAUNTED:   tint = Color(0.7, 0.9, 1.3, 1.0)  # icy
		Weapon.State.CURSED:    tint = Color(1.3, 0.6, 1.4, 1.0)  # purple
		Weapon.State.SHATTERED: tint = Color(0.5, 0.5, 0.5, 1.0)  # gray
	# Multiply tint onto the image
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0:
				var nc := Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a)
				img.set_pixel(x, y, nc)
	# Add state-specific overlays
	match state:
		Weapon.State.BLOODIED:
			# Add blood drips
			for i in 5:
				var bx := 8 + i * 4
				var by := 4 + (i % 3) * 3
				_px(img, bx, by, Color(0.55, 0.05, 0.05, 1.0))
				_px(img, bx, by + 1, Color(0.35, 0.03, 0.03, 1.0))
		Weapon.State.RUSTED:
			# Add rust spots
			for i in 8:
				var rx := 4 + (i * 5) % 24
				var ry := 4 + (i * 3) % 24
				_px(img, rx, ry, Color(0.55, 0.30, 0.10, 1.0))
				_px(img, rx + 1, ry, Color(0.40, 0.20, 0.05, 1.0))
		Weapon.State.HAUNTED:
			# Add ghostly wisps
			for i in 6:
				var wx := 6 + (i * 4) % 20
				var wy := 2 + (i * 5) % 26
				_px(img, wx, wy, Color(0.60, 0.85, 1.0, 0.6))
		Weapon.State.CURSED:
			# Add dark runes
			for i in 5:
				var cx := 6 + i * 5
				var cy := 6 + (i % 3) * 8
				_px(img, cx, cy, Color(0.20, 0.05, 0.30, 1.0))
				_px(img, cx + 1, cy, Color(0.40, 0.10, 0.50, 1.0))
				_px(img, cx, cy + 1, Color(0.40, 0.10, 0.50, 1.0))
		Weapon.State.SHATTERED:
			# Add crack lines
			_line(img, 4, 8, 16, 14, Color(0.05, 0.05, 0.05, 1.0))
			_line(img, 16, 14, 24, 22, Color(0.05, 0.05, 0.05, 1.0))
			_line(img, 16, 14, 12, 24, Color(0.05, 0.05, 0.05, 1.0))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
