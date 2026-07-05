extends Node2D
## Phase: battle V3 — SPECTATOR phase.
## Camera follows the party as they auto-walk through the dungeon.
## Weapons VISIBLY degrade during the fight (4 wear states with art changes).
## Player watches — can use ghost ability (key 1) to support, but can't fix weapons mid-fight.
## This is the "judgement phase" that reads the player's crafting.

const TILE: int = 32
const CORRIDOR_W: int = 14
const CORRIDOR_H: int = 50
const VIEW_W: int = 640
const VIEW_H: int = 360

var party_units: Array = []
var enemies: Array = []
var camera_y: float = 0.0
var cam: Camera2D
var battle_over: bool = false
var battle_won: bool = false
var elapsed: float = 0.0
var ghost_ability_cd: float = 0.0
var ghost_ability_active: float = 0.0
var damage_numbers: Array = []
var particles: Array = []
var continue_btn: Button
var log_label: Label
var wave_progress: float = 0.0
var hit_stop: float = 0.0  # freeze frames on big hits

const GHOST_ABILITY_CD: float = 20.0
const GHOST_ABILITY_DURATION: float = 4.0

func _ready() -> void:
        cam = Camera2D.new()
        cam.position = Vector2(CORRIDOR_W * TILE / 2, 0)
        cam.enabled = true
        cam.position_smoothing_enabled = true
        cam.position_smoothing_speed = 5.0
        add_child(cam)
        _spawn_party_units()
        _spawn_enemies()
        _build_hud()

func _spawn_party_units() -> void:
        party_units.clear()
        for i in GameState.party.size():
                var adv: Dictionary = GameState.party[i]
                if not adv.get("alive", true):
                        continue
                var hp := int(adv.get("hp", 100))
                var atk := int(adv.get("atk", 18))
                var def_ := int(adv.get("def", 12))
                # Apply weapon stats
                if adv.get("equipped_weapon") != null:
                        var w: Weapon = adv.equipped_weapon
                        var mult: float = w.stat_multiplier()
                        atk = int(atk * (0.7 + mult * 0.5))
                if adv.get("equipped_armor") != null:
                        var a: Weapon = adv.equipped_armor
                        var mult: float = a.stat_multiplier()
                        def_ = int(def_ * (0.7 + mult * 0.5))
                var iq_mult: float = 1.0 + float(GameState.meta_upgrades["adventurer_training"]) * 0.05
                atk = int(atk * iq_mult)
                party_units.append({
                        "pos": Vector2(CORRIDOR_W * TILE / 2 + (i - 1) * 32, (CORRIDOR_H - 3) * TILE),
                        "hp": hp,
                        "hp_max": hp,
                        "atk": atk,
                        "def": def_,
                        "sprite": "knight" if adv["class"] == "knight" else "mage",
                        "adv": adv,
                        "atk_cd": 1.5,
                        "alive": true,
                        "walk_anim": 0.0,
                        "flash": 0.0,
                })

func _spawn_enemies() -> void:
        enemies.clear()
        var count: int = GameState.get_enemy_count()
        for i in count:
                var x := (2 + (i * 5) % (CORRIDOR_W - 4)) * TILE + TILE / 2
                var y := (3 + i * 5) * TILE
                var sprite_name := "slime"
                match i % 3:
                        0: sprite_name = "slime"
                        1: sprite_name = "skeleton"
                        2: sprite_name = "bat"
                enemies.append({
                        "pos": Vector2(x, y),
                        "hp": GameState.get_enemy_hp(),
                        "hp_max": GameState.get_enemy_hp(),
                        "atk": GameState.get_enemy_atk(),
                        "def": 4,
                        "sprite": sprite_name,
                        "atk_cd": 2.0,
                        "alive": true,
                        "walk_anim": randf() * TAU,
                })

func _build_hud() -> void:
        var panel := Panel.new()
        panel.position = Vector2(0, 0)
        panel.size = Vector2(VIEW_W, 28)
        add_child(panel)
        var lbl := Label.new()
        lbl.text = "Stage %d Wave %d — BATTLE  [1] Haunt Enemy" % [GameState.stage, GameState.wave]
        lbl.add_theme_font_size_override("font_size", 10)
        lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
        lbl.position = Vector2(8, 6)
        lbl.size = Vector2(VIEW_W, 16)
        panel.add_child(lbl)
        continue_btn = Button.new()
        continue_btn.text = "Continue >"
        continue_btn.add_theme_font_size_override("font_size", 12)
        continue_btn.position = Vector2(VIEW_W / 2 - 60, VIEW_H / 2 + 40)
        continue_btn.size = Vector2(120, 28)
        continue_btn.visible = false
        continue_btn.pressed.connect(_on_continue)
        add_child(continue_btn)
        log_label = Label.new()
        log_label.text = "The party descends..."
        log_label.add_theme_font_size_override("font_size", 9)
        log_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
        log_label.position = Vector2(8, VIEW_H - 18)
        log_label.size = Vector2(VIEW_W, 14)
        add_child(log_label)

func _process(delta: float) -> void:
        if battle_over:
                return
        if hit_stop > 0:
                hit_stop -= delta
                return
        elapsed += delta
        ghost_ability_cd = max(0, ghost_ability_cd - delta)
        ghost_ability_active = max(0, ghost_ability_active - delta)
        # Party AI
        for u in party_units:
                if u.alive:
                        u.walk_anim += delta * 8
                        u.flash = max(0, u.flash - delta * 4)
                        var nearest: Dictionary = {}
                        var nearest_dist: float = 9999
                        for e in enemies:
                                if e.alive:
                                        var d: float = u.pos.distance_to(e.pos)
                                        if d < nearest_dist:
                                                nearest_dist = d
                                                nearest = e
                        if not nearest.is_empty():
                                if nearest_dist > 36:
                                        var dir: Vector2 = (nearest.pos - u.pos).normalized()
                                        u.pos += dir * 35 * delta
                                else:
                                        u.atk_cd -= delta
                                        if u.atk_cd <= 0:
                                                u.atk_cd = 1.5
                                                _attack_enemy(u, nearest)
                        else:
                                if u.pos.y > TILE * 3:
                                        u.pos.y -= 30 * delta
        # Enemy AI
        for e in enemies:
                if not e.alive:
                        continue
                e.walk_anim += delta * 5
                var nearest: Dictionary = {}
                var nearest_dist: float = 9999
                for u in party_units:
                        if u.alive:
                                var d: float = e.pos.distance_to(u.pos)
                                if d < nearest_dist:
                                        nearest_dist = d
                                        nearest = u
                if not nearest.is_empty():
                        if nearest_dist > 30:
                                var spd := 20.0
                                if ghost_ability_active > 0:
                                        spd = 8.0
                                var dir: Vector2 = (nearest.pos - e.pos).normalized()
                                e.pos += dir * spd * delta
                        else:
                                e.atk_cd -= delta
                                if ghost_ability_active > 0:
                                        e.atk_cd -= delta * 0.5
                                if e.atk_cd <= 0:
                                        e.atk_cd = 2.5
                                        _attack_party(e, nearest)
        # Camera
        var front_y: float = CORRIDOR_H * TILE
        for u in party_units:
                if u.alive and u.pos.y < front_y:
                        front_y = u.pos.y
        camera_y = lerp(camera_y, front_y, 1.0 - exp(-delta * 5.0))
        cam.position = Vector2(CORRIDOR_W * TILE / 2, camera_y)
        cam.offset = Vector2(0, -40)
        wave_progress = 1.0 - clampf(front_y / (CORRIDOR_H * TILE), 0, 1)
        # Win/lose
        var party_alive := false
        for u in party_units:
                if u.alive:
                        party_alive = true
                        break
        var enemies_alive := false
        for e in enemies:
                if e.alive:
                        enemies_alive = true
                        break
        if not enemies_alive:
                battle_over = true
                battle_won = true
                _end_battle()
        elif not party_alive:
                battle_over = true
                battle_won = false
                _end_battle()
        for p in particles:
                p.pos += p.vel * delta
                p.life -= delta
        particles = particles.filter(func(p): return p.life > 0)
        for d in damage_numbers:
                d.life -= delta
                d.pos.y -= 25 * delta
        damage_numbers = damage_numbers.filter(func(d): return d.life > 0)
        queue_redraw()

func _attack_enemy(unit: Dictionary, enemy: Dictionary) -> void:
        var dmg: int = max(1, int(unit.atk * (0.8 + randf() * 0.4) - enemy.def))
        enemy.hp -= dmg
        damage_numbers.append({"pos": enemy.pos + Vector2(0, -20), "text": str(dmg), "color": Color(0.95, 0.85, 0.40), "life": 0.8, "max_life": 0.8})
        for i in 4:
                particles.append({
                        "pos": enemy.pos,
                        "vel": Vector2(randf_range(-50, 50), randf_range(-50, 50)),
                        "color": Color(0.95, 0.40, 0.40),
                        "life": 0.3,
                        "max_life": 0.3,
                })
        # Weapon durability damage
        var adv: Dictionary = unit.adv
        if adv.get("equipped_weapon") != null:
                var w: Weapon = adv.equipped_weapon
                w.take_durability_damage(6, "combat hit")
                # Check for break
                var announced: bool = w.history.has("break_announced")
                if w.is_broken and not announced:
                        w.history.append("break_announced")
                        hit_stop = 0.4  # dramatic freeze
                        # Shatter particles
                        for i in 12:
                                particles.append({
                                        "pos": unit.pos,
                                        "vel": Vector2(randf_range(-80, 80), randf_range(-80, 80)),
                                        "color": Color(0.75, 0.75, 0.78),
                                        "life": 0.8,
                                        "max_life": 0.8,
                                })
                        log_label.text = "%s's %s SHATTERED!" % [adv.name, w.display_name]
        if enemy.hp <= 0:
                enemy.alive = false
                enemy.hp = 0
                # Record kill on weapon
                if adv.get("equipped_weapon") != null:
                        adv.equipped_weapon.record_kill(enemy.sprite)
                for i in 10:
                        particles.append({
                                "pos": enemy.pos,
                                "vel": Vector2(randf_range(-60, 60), randf_range(-60, 60)),
                                "color": Color(0.65, 0.65, 0.65),
                                "life": 0.6,
                                "max_life": 0.6,
                        })

func _attack_party(enemy: Dictionary, unit: Dictionary) -> void:
        var dmg: int = max(1, int(enemy.atk * (0.8 + randf() * 0.4) - unit.def))
        unit.hp -= dmg
        unit.flash = 1.0
        damage_numbers.append({"pos": unit.pos + Vector2(0, -20), "text": str(dmg), "color": Color(0.95, 0.40, 0.40), "life": 0.8, "max_life": 0.8})
        for i in 3:
                particles.append({
                        "pos": unit.pos,
                        "vel": Vector2(randf_range(-40, 40), randf_range(-40, 40)),
                        "color": Color(0.85, 0.30, 0.30),
                        "life": 0.3,
                        "max_life": 0.3,
                })
        # Armor durability damage
        var adv: Dictionary = unit.adv
        if adv.get("equipped_armor") != null:
                var a: Weapon = adv.equipped_armor
                a.take_durability_damage(4, "armor hit")
        if unit.hp <= 0:
                unit.alive = false
                unit.hp = 0
                unit.adv.alive = false
                hit_stop = 0.3
                for i in 12:
                        particles.append({
                                "pos": unit.pos,
                                "vel": Vector2(randf_range(-60, 60), randf_range(-60, 60)),
                                "color": Color(0.55, 0.10, 0.10),
                                "life": 0.8,
                                "max_life": 0.8,
                        })
                log_label.text = "%s has fallen!" % adv.name

func _end_battle() -> void:
        # Apply combat damage to weapons (state changes for dead owners)
        for adv in GameState.party:
                var equipped_w: Variant = adv.get("equipped_weapon")
                var equipped_a: Variant = adv.get("equipped_armor")
                var owner_died: bool = not adv.get("alive", true)
                if equipped_w != null:
                        equipped_w.apply_combat_damage(owner_died)
                        GameState.add_weapon(equipped_w)
                if equipped_a != null:
                        equipped_a.apply_combat_damage(owner_died)
                        GameState.add_weapon(equipped_a)
        for adv in GameState.party:
                adv.erase("equipped_weapon")
                adv.erase("equipped_armor")
        var survivors := 0
        for adv in GameState.party:
                if adv.get("alive", false):
                        survivors += 1
        GameState.last_battle_result = {
                "won": battle_won,
                "survivors": survivors,
                "party_size": GameState.party.size(),
                "shards_earned": 0,
                "stage": GameState.stage,
                "wave": GameState.wave,
        }
        var shards := 0
        if battle_won:
                shards += 30 + GameState.stage * 5 + GameState.wave * 3
                shards += survivors * 25
                GameState.run_log.append("Stage %d Wave %d — Victory! %d survivors." % [GameState.stage, GameState.wave, survivors])
        else:
                shards += 10 + GameState.stage
                shards += (GameState.party.size() - survivors) * 8
                GameState.run_log.append("Stage %d Wave %d — Party wiped." % [GameState.stage, GameState.wave])
        GameState.last_battle_result.shards_earned = shards
        GameState.add_shards(shards)
        continue_btn.visible = true
        log_label.text = "Battle %s! +%d shards." % ["WON" if battle_won else "LOST", shards]

func _draw() -> void:
        var cam_top := int((camera_y - VIEW_H / 2) / TILE) - 1
        var cam_bot := int((camera_y + VIEW_H / 2) / TILE) + 1
        cam_top = max(0, cam_top)
        cam_bot = min(CORRIDOR_H - 1, cam_bot)
        for y in range(cam_top, cam_bot + 1):
                for x in CORRIDOR_W:
                        var p := Vector2(x * TILE, y * TILE)
                        if (x + y) % 7 == 0 and y > 5:
                                draw_texture(Sprites.get_sprite("floor_cracked"), p)
                        elif (x + y) % 11 == 0 and y > 8:
                                draw_texture(Sprites.get_sprite("floor_blood"), p)
                        else:
                                draw_texture(Sprites.get_sprite("floor"), p)
        for y in range(cam_top, cam_bot + 1):
                draw_texture(Sprites.get_sprite("wall"), Vector2(-TILE, y * TILE))
                draw_texture(Sprites.get_sprite("wall_mossy"), Vector2(CORRIDOR_W * TILE, y * TILE))
                if y % 4 == 0:
                        draw_texture_rect(Sprites.get_sprite("torch"), Rect2(-TILE - 16, y * TILE + 8, 32, 32), false)
                        draw_texture_rect(Sprites.get_sprite("torch"), Rect2(CORRIDOR_W * TILE, y * TILE + 8, 32, 32), false)
        # Exit
        draw_texture_rect(Sprites.get_sprite("door"), Rect2((CORRIDOR_W * TILE / 2) - 20, -TILE - 20, 40, 40), false)
        draw_string(ThemeDB.get_default_theme().default_font, Vector2(CORRIDOR_W * TILE / 2 - 30, -TILE - 28), "EXIT", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.55, 0.95, 0.75))
        # Enemies
        for e in enemies:
                if e.alive:
                        var tex := Sprites.get_sprite(e.sprite)
                        var bob := sin(e.walk_anim) * 2
                        var ep: Vector2 = e.pos + Vector2(0, bob)
                        draw_rect(Rect2(ep.x - 10, e.pos.y + 12, 20, 4), Color(0, 0, 0, 0.3), true)
                        draw_texture_rect(tex, Rect2(ep.x - 20, ep.y - 20, 40, 40), false)
                        var pct: float = float(e.hp) / float(e.hp_max)
                        draw_rect(Rect2(ep.x - 16, ep.y - 26, 32, 3), Color(0.20, 0.20, 0.20), true)
                        draw_rect(Rect2(ep.x - 16, ep.y - 26, 32 * pct, 3), Color(0.95, 0.40, 0.40), true)
        # Party
        for u in party_units:
                if u.alive:
                        var tex := Sprites.get_sprite(u.sprite)
                        var bob := sin(u.walk_anim) * 2
                        var up: Vector2 = u.pos + Vector2(0, bob)
                        draw_rect(Rect2(up.x - 10, u.pos.y + 12, 20, 4), Color(0, 0, 0, 0.3), true)
                        # Flash red when hit
                        if u.flash > 0:
                                draw_rect(Rect2(up.x - 20, up.y - 20, 40, 40), Color(1, 0.3, 0.3, u.flash * 0.5), true)
                        draw_texture_rect(tex, Rect2(up.x - 20, up.y - 20, 40, 40), false)
                        # HP bar
                        var pct: float = float(u.hp) / float(u.hp_max)
                        draw_rect(Rect2(up.x - 16, up.y - 26, 32, 3), Color(0.20, 0.20, 0.20), true)
                        var c: Color = Color(0.55, 0.95, 0.55) if pct > 0.5 else (Color(0.95, 0.85, 0.30) if pct > 0.25 else Color(0.95, 0.40, 0.40))
                        draw_rect(Rect2(up.x - 16, up.y - 26, 32 * pct, 3), c, true)
                        # Show equipped weapon (with wear state color)
                        var adv: Dictionary = u.adv
                        if adv.get("equipped_weapon") != null:
                                var w: Weapon = adv.equipped_weapon
                                var wt := Sprites.get_weapon_sprite(w.type, w.state)
                                draw_texture_rect(wt, Rect2(up.x + 14, up.y - 8, 20, 20), false)
                                # Wear indicator (colored dot)
                                draw_circle(up + Vector2(24, -16), 3, w.wear_color())
                                # Durability bar
                                var dpct: float = w.durability_pct()
                                draw_rect(Rect2(up.x + 12, up.y - 22, 24, 2), Color(0.20, 0.20, 0.20), true)
                                draw_rect(Rect2(up.x + 12, up.y - 22, 24 * dpct, 2), w.wear_color(), true)
        # Particles
        for p in particles:
                var alpha: float = p.life / p.max_life
                var c: Color = p.color
                c.a = alpha
                draw_circle(p.pos, 4 * alpha, c)
        # Damage numbers
        for d in damage_numbers:
                var alpha: float = d.life / d.max_life
                var c: Color = d.color
                c.a = alpha
                draw_string(ThemeDB.get_default_theme().default_font, d.pos, d.text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, c)
        # Ghost ability HUD
        var hud_pos := cam.get_screen_center_position() - Vector2(VIEW_W / 2, VIEW_H / 2)
        var cd_pct: float = 1.0 - (ghost_ability_cd / GHOST_ABILITY_CD) if ghost_ability_cd > 0 else 1.0
        var cd_c := Color(0.55, 0.95, 0.55) if ghost_ability_cd <= 0 else Color(0.55, 0.55, 0.65)
        draw_rect(Rect2(hud_pos + Vector2(8, 300), Vector2(60, 10)), Color(0.20, 0.20, 0.20), true)
        draw_rect(Rect2(hud_pos + Vector2(8, 300), Vector2(60 * cd_pct, 10)), cd_c, true)
        draw_string(ThemeDB.get_default_theme().default_font, hud_pos + Vector2(8, 295), "[1] Haunt", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, cd_c)
        if ghost_ability_active > 0:
                draw_string(ThemeDB.get_default_theme().default_font, hud_pos + Vector2(VIEW_W / 2 - 50, 295), "HAUNTING!", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.55, 0.75, 0.95))
        # Progress bar
        draw_rect(Rect2(hud_pos + Vector2(VIEW_W - 14, 34), Vector2(6, VIEW_H - 60)), Color(0.20, 0.20, 0.25), true)
        draw_rect(Rect2(hud_pos + Vector2(VIEW_W - 14, 34 + (VIEW_H - 60) * (1 - wave_progress)), Vector2(6, (VIEW_H - 60) * wave_progress)), Color(0.55, 0.95, 0.55), true)

func _input(event: InputEvent) -> void:
        if battle_over:
                return
        if event is InputEventKey and event.pressed and event.keycode == KEY_1:
                if ghost_ability_cd <= 0:
                        ghost_ability_cd = GHOST_ABILITY_CD
                        ghost_ability_active = GHOST_ABILITY_DURATION
                        log_label.text = "Ghost haunts — enemies slow!"

func _on_continue() -> void:
        GameState.set_phase("results")
