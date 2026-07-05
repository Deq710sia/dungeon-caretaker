class_name GameFont
extends RefCounted
## Helper to get the pixel font for draw_string calls.
## NEVER use ThemeDB.get_default_theme().default_font — it's a vector font.

static var _pixel_font: Font = null

static func get_font() -> Font:
	if _pixel_font == null:
		_pixel_font = load("res://assets/fonts/press_start_2p.ttf")
	return _pixel_font

## Draw string with the pixel font. Size should be 8 or 16 (native sizes for Press Start 2P).
static func draw_string(canvas: CanvasItem, pos: Vector2, text: String, size: int = 8, color: Color = Color.WHITE, align: int = HORIZONTAL_ALIGNMENT_LEFT, outline: bool = true) -> void:
	var font := get_font()
	if outline:
		canvas.draw_string(font, pos + Vector2(1, 1), text, align, -1, size, Color(0, 0, 0))
		canvas.draw_string(font, pos + Vector2(-1, 1), text, align, -1, size, Color(0, 0, 0))
		canvas.draw_string(font, pos + Vector2(1, -1), text, align, -1, size, Color(0, 0, 0))
		canvas.draw_string(font, pos + Vector2(-1, -1), text, align, -1, size, Color(0, 0, 0))
	canvas.draw_string(font, pos, text, align, -1, size, color)

## Draw string centered on a point
static func draw_string_centered(canvas: CanvasItem, center: Vector2, text: String, size: int = 8, color: Color = Color.WHITE, outline: bool = true) -> void:
	var font := get_font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
	draw_string(canvas, center - Vector2(w / 2, 0), text, size, color, HORIZONTAL_ALIGNMENT_LEFT, outline)
