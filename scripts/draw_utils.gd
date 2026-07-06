class_name DrawUtils
extends RefCounted
## Shared drawing utilities. Eliminates duplicated glow/helper draw code
## across phase scripts. Call these as static methods:
##   DrawUtils.draw_glow(canvas, pos, radius, color)
##   DrawUtils.draw_radial_glow(canvas, pos, radii, color, alpha_mult)

## Concentric-circle glow with alpha falloff. Used for torches, furnace,
## altar, exit glows. Replaces _draw_glow (was duplicated in battle + workshop)
## and the 4 near-identical _draw_*_glow variants in salvage.
static func draw_glow(canvas: CanvasItem, pos: Vector2, radius: int, color: Color) -> void:
	var center := Vector2(int(pos.x), int(pos.y))
	for r in [radius, int(radius * 0.6), int(radius * 0.3)]:
		var c := color
		c.a = c.a * (1.0 - float(r) / float(radius)) * 0.8
		canvas.draw_circle(center, r, c)

## Parameterized radial glow — takes an array of radii and an alpha multiplier.
## Replaces salvage's _draw_torch_glow / _draw_fire_glow / _draw_gear_glow /
## _draw_exit_glow (all the same pattern with different params).
static func draw_radial_glow(canvas: CanvasItem, pos: Vector2, radii: Array, color: Color, alpha_mult: float = 0.8) -> void:
	var center := Vector2(int(pos.x), int(pos.y))
	var max_r: int = radii[0]
	for r in radii:
		var c := color
		c.a = c.a * (1.0 - float(r) / float(max_r)) * alpha_mult
		canvas.draw_circle(center, r, c)
