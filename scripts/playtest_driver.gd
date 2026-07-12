extends Node
## PlaytestDriver — automated playtest harness for continuous testing.
## Reads commands from user://playtest_commands.txt, executes them,
## captures screenshots, logs game state, and runs vision checks.
##
## This file lives on the debug-tools branch ONLY. Do not merge to main.
##
## Commands:
##   start_game              — start new run, go to gate
##   advance                 — force-transition to next phase
##   set_phase <name>        — jump to a specific phase
##   equip_all               — auto-equip all party members
##   kill_party              — kill all party members (test wipe)
##   win_battle              — set last_battle_result to a win
##   move <dir> <sec>        — move ghost in direction for N seconds
##   interact                — force-call _handle_interact() on current phase
##   wait <sec>              — wait
##   screenshot <label>      — capture screenshot
##   log_state <context>     — write game state to log
##   done                    — quit

var commands: Array = []
var command_index: int = 0
var wait_timer: float = 0.0
var move_dir: Vector2 = Vector2.ZERO
var move_time: float = 0.0
var log_file: FileAccess = null
var screenshot_count: int = 0
var finished: bool = false
var executing: bool = false

func _ready() -> void:
	_load_commands()
	log_file = FileAccess.open("user://playtest_log.txt", FileAccess.WRITE)
	if log_file:
		log_file.store_line("=== PLAYTEST LOG START ===")
		log_file.store_line("Time: %s" % Time.get_datetime_string_from_system())
		log_file.store_line("")
	_write_state("init")

func _load_commands() -> void:
	var f := FileAccess.open("user://playtest_commands.txt", FileAccess.READ)
	if not f:
		push_error("No playtest_commands.txt found")
		return
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		commands.append(line)
	f.close()
	print("Loaded %d playtest commands" % commands.size())

func _process(delta: float) -> void:
	if finished:
		return
	if move_time > 0:
		move_time -= delta
		var dir_str := ""
		if move_dir.x < 0: dir_str = "move_left"
		elif move_dir.x > 0: dir_str = "move_right"
		elif move_dir.y < 0: dir_str = "move_up"
		elif move_dir.y > 0: dir_str = "move_down"
		if dir_str != "":
			Input.action_press(dir_str)
		if move_time <= 0:
			Input.action_release(dir_str)
			move_dir = Vector2.ZERO
		return
	if wait_timer > 0:
		wait_timer -= delta
		return
	if executing:
		return
	if command_index >= commands.size():
		return
	var cmd: String = commands[command_index]
	command_index += 1
	executing = true
	_execute(cmd)
	await get_tree().process_frame
	executing = false

func _execute(cmd: String) -> void:
	var parts := cmd.split(" ")
	var verb := parts[0]
	match verb:
		"start_game":
			GameState.start_new_run()
			GameState.set_phase("gate")
			_write_log("STARTED new run -> gate")
		"advance":
			_advance_phase()
		"set_phase":
			if parts.size() >= 2:
				GameState.set_phase(parts[1])
				_write_log("SET PHASE: %s" % parts[1])
		"equip_all":
			_auto_equip()
		"kill_party":
			for adv in GameState.party:
				adv.alive = false
				adv.hp = 0
			GameState.last_battle_result = {
				"won": false, "survivors": 0,
				"party_size": GameState.party.size(),
				"shards_earned": 10, "stage": GameState.stage,
				"wave": GameState.wave,
				"fallen_names": GameState.party.map(func(a): return a.get("name", "?")),
			}
			_write_log("KILLED PARTY")
		"win_battle":
			GameState.last_battle_result = {
				"won": true, "survivors": 2,
				"party_size": 2, "shards_earned": 88,
				"stage": GameState.stage, "wave": GameState.wave,
				"fallen_names": [],
			}
			_write_log("SET WIN BATTLE")
		"move":
			if parts.size() >= 3:
				var dir := parts[1]
				var sec := float(parts[2])
				match dir:
					"up": move_dir = Vector2.UP
					"down": move_dir = Vector2.DOWN
					"left": move_dir = Vector2.LEFT
					"right": move_dir = Vector2.RIGHT
				move_time = sec
		"interact":
			_force_interact()
		"wait":
			if parts.size() >= 2:
				wait_timer = float(parts[1])
		"screenshot":
			var label := parts[1] if parts.size() >= 2 else "shot"
			_capture_screenshot(label)
		"log_state":
			_write_state(parts[1] if parts.size() >= 2 else "manual")
		"done":
			_finish()
		_:
			_write_log("UNKNOWN COMMAND: %s" % cmd)

func _get_phase_node() -> Node:
	var main := get_tree().current_scene
	if main:
		for child in main.get_children():
			if child.name.begins_with("Phase_"):
				return child
	return null

func _force_interact() -> void:
	var phase := _get_phase_node()
	if phase == null:
		_write_log("INTERACT: no phase node found")
		return
	if phase.has_method("_handle_interact"):
		phase._handle_interact()
		_write_log("INTERACT: called _handle_interact()")
	elif phase.has_method("_open_gate"):
		phase._open_gate()
		_write_log("INTERACT: called _open_gate()")
	else:
		# Fallback: send input event
		Input.action_press("interact")
		await get_tree().process_frame
		Input.action_release("interact")
		_write_log("INTERACT: sent input action")

func _advance_phase() -> void:
	match GameState.current_phase:
		"menu":
			GameState.start_new_run()
			GameState.set_phase("gate")
		"gate":
			GameState.set_phase("salvage")
		"salvage":
			GameState.set_phase("workshop")
		"workshop":
			GameState.set_phase("upgrade")
		"upgrade":
			GameState.set_phase("planning")
		"planning":
			GameState.set_phase("battle")
		"battle":
			GameState.set_phase("results")
		"results":
			GameState.set_phase("gate")
		"aftermath":
			GameState.set_phase("gate")
		_:
			_write_log("No next phase for: %s" % GameState.current_phase)
			return
	_write_log("ADVANCED to: %s" % GameState.current_phase)

func _auto_equip() -> void:
	for adv in GameState.party:
		if not adv.get("alive", true):
			continue
		var cls: String = adv.get("class", "knight")
		var exp_w := "sword" if cls == "knight" else "staff"
		var exp_a := "helm" if cls == "knight" else "robe"
		for w in GameState.arsenal:
			if w.type == exp_w and not w.is_broken:
				adv.equipped_weapon = w
				w.wielder = adv.get("name", "")
				GameState.arsenal.erase(w)
				_write_log("EQUIP: %s -> %s" % [w.display_name, adv.name])
				break
		for w in GameState.arsenal:
			if w.type == exp_a and not w.is_broken:
				adv.equipped_armor = w
				w.wielder = adv.get("name", "")
				GameState.arsenal.erase(w)
				_write_log("EQUIP: %s -> %s" % [w.display_name, adv.name])
				break
	GameState.arsenal_changed.emit()

func _capture_screenshot(label: String) -> void:
	screenshot_count += 1
	var img := get_viewport().get_texture().get_image()
	if img:
		var path := "user://pt_%03d_%s.png" % [screenshot_count, label]
		img.save_png(path)
		_write_log("SCREENSHOT %d: %s" % [screenshot_count, label])

func _write_state(context: String) -> void:
	if not log_file:
		return
	log_file.store_line("--- STATE: %s ---" % context)
	log_file.store_line("  phase: %s | stage: %d wave: %d" % [GameState.current_phase, GameState.stage, GameState.wave])
	log_file.store_line("  shards: %d" % GameState.soul_shards)
	log_file.store_line("  party: %d (%d alive)" % [GameState.party.size(), GameState.living_party_count()])
	for i in min(GameState.party.size(), 4):
		var a: Dictionary = GameState.party[i]
		var wn := "none"
		var an := "none"
		if a.get("equipped_weapon") != null:
			wn = (a.equipped_weapon as Weapon).display_name + " [%.0f%%]" % (a.equipped_weapon.stat_multiplier() * 100)
		if a.get("equipped_armor") != null:
			an = (a.equipped_armor as Weapon).display_name
		log_file.store_line("    [%d] %s (%s) HP=%d/%d alive=%s weapon=%s armor=%s" % [i, a.get("name","?"), a.get("class","?"), a.get("hp",0), a.get("hp_max",0), a.get("alive",false), wn, an])
	log_file.store_line("  arsenal: %d" % GameState.arsenal.size())
	for i in min(GameState.arsenal.size(), 8):
		var w: Weapon = GameState.arsenal[i]
		log_file.store_line("    [%d] %s [%s/%s] dur=%d/%d broken=%s" % [i, w.display_name, w.state_name(), w.wear_name(), w.durability, w.durability_max, w.is_broken])
	var res: Dictionary = GameState.last_battle_result
	log_file.store_line("  last_battle: won=%s surv=%s fallen=%s" % [res.get("won", "N/A"), res.get("survivors", "N/A"), res.get("fallen_names", [])])
	if res.has("fallen_gear"):
		log_file.store_line("  fallen_gear: %d items" % res["fallen_gear"].size())
		for g in res["fallen_gear"]:
			log_file.store_line("    %s (%s) state=%s" % [g.get("name","?"), g.get("type","?"), g.get("state","?")])
	log_file.store_line("  run_log (last 5):")
	for i in range(max(0, GameState.run_log.size() - 5), GameState.run_log.size()):
		log_file.store_line("    %s" % GameState.run_log[i])
	log_file.store_line("")

func _write_log(msg: String) -> void:
	if log_file:
		log_file.store_line(msg)
	print("[PT] %s" % msg)

func _finish() -> void:
	finished = true
	_write_state("done")
	if log_file:
		log_file.store_line("=== PLAYTEST LOG END ===")
		log_file.close()
	get_tree().quit()
