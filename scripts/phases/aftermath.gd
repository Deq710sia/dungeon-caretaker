extends Node2D
## Phase: aftermath — a short beat between battle and salvage.
##
## Shows what was left behind after the last wave: the fallen (if any), laid
## out where the corridor still smells of it, before the ghost heads out to
## collect what's left of their gear. This is what makes the loop that
## follows (salvage -> workshop -> planning) feel earned rather than
## automatic — you see WHY there's gear to collect and armor to repair.

const ROOM_W: int = 320
const ROOM_H: int = 180

var fallen_names: Array = []
var continue_btn: Button
var hud_layer: CanvasLayer

func _ready() -> void:
	var res: Dictionary = GameState.last_battle_result
	fallen_names = res.get("fallen_names", [])
	_build_hud()

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	continue_btn = Button.new()
	continue_btn.text = "Continue >"
	continue_btn.add_theme_font_size_override("font_size", 8)
	continue_btn.position = Vector2(ROOM_W / 2 - 60, ROOM_H - 22)
	continue_btn.size = Vector2(120, 16)
	continue_btn.pressed.connect(_on_continue)
	hud_layer.add_child(continue_btn)

func _draw() -> void:
	# Dim, torch-lit corridor floor as a backdrop.
	for y in range(20, ROOM_H - 8, 16):
		for x in range(0, ROOM_W, 16):
			var hash := (x * 7 + y * 13) % 31
			if hash < 6:
				draw_texture(Sprites.get_sprite("floor_blood"), Vector2(x, y))
			else:
				draw_texture(Sprites.get_sprite("floor"), Vector2(x, y))
	draw_rect(Rect2(0, 20, ROOM_W, ROOM_H - 28), Color(0, 0, 0, 0.35), true)

	if fallen_names.is_empty():
		GameFont.draw_string_centered(self, Vector2(ROOM_W / 2, 30), "S%d W%d — AFTERMATH" % [GameState.last_battle_result.get("stage", GameState.stage), GameState.last_battle_result.get("wave", GameState.wave)], 8, Palette.TEXT_GOLD)
		GameFont.draw_string_centered(self, Vector2(ROOM_W / 2, ROOM_H / 2 - 6), "The party returns, weary but whole.", 8, Palette.TEXT)
		GameFont.draw_string_centered(self, Vector2(ROOM_W / 2, ROOM_H / 2 + 10), "Their gear still needs tending before the next wave.", 7, Palette.TEXT_DIM)
	else:
		GameFont.draw_string_centered(self, Vector2(ROOM_W / 2, 30), "S%d W%d — THE FALLEN" % [GameState.last_battle_result.get("stage", GameState.stage), GameState.last_battle_result.get("wave", GameState.wave)], 8, Palette.TEXT_RED)
		var start_y: float = 55.0
		var spacing: float = 90.0
		var start_x: float = ROOM_W / 2.0 - (fallen_names.size() - 1) * spacing / 2.0
		for i in fallen_names.size():
			var fname: String = fallen_names[i]
			var pos := Vector2(start_x + i * spacing, start_y)
			# A downed body: sprite drawn on its side, in shadow, with a
			# small pool of blood beneath it instead of a walking pose.
			draw_rect(Rect2(pos.x - 10, pos.y + 4, 20, 5), Color(0.4, 0.02, 0.02, 0.5), true)
			var tex := Sprites.get_sprite("knight" if i % 2 == 0 else "mage")
			draw_texture_rect(tex, Rect2(pos.x - 9, pos.y - 4, 18, 10), false, Color(0.5, 0.45, 0.5, 1.0))
			GameFont.draw_string_centered(self, pos + Vector2(0, 20), fname, 7, Palette.TEXT_DIM)
			GameFont.draw_string_centered(self, pos + Vector2(0, 30), "fell here", 7, Palette.TEXT_DIM)
		if GameState.last_battle_result.get("retreated", false):
			GameFont.draw_string_centered(self, Vector2(ROOM_W / 2, ROOM_H / 2 + 24), "The rest retreated, carrying what they could.", 7, Palette.TEXT)
		else:
			GameFont.draw_string_centered(self, Vector2(ROOM_W / 2, ROOM_H / 2 + 24), "The dungeon takes its due.", 7, Palette.TEXT)

func _on_continue() -> void:
	GameState.set_phase("gate")
