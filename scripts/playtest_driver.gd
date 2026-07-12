extends Node
## PlaytestDriver — automated playtest harness for the Design Lab.
##
## This file lives on the tools-management branch ONLY. On main it is
## gitignored (per v0.33) — to run a playtest, drop this file into
## scripts/ on a main checkout and add PlaytestDriver to project.godot
## autoloads locally (do not commit that change to main).
##
## === LAYER 1: AUTOMATION (unchanged from v0.34) ===
## Reads commands from user://playtest_commands.txt, executes them,
## captures screenshots, logs game state. Existing command API:
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
##
## === LAYER 2: TELEMETRY (new in Design Lab v1) ===## Arms/disarms the Telemetry autoload so game code emits structured
## events to user://telemetry_<label>.jsonl. Pair with the Python
## analyzer in tools/design_lab/ to produce metrics + reports.
##   arm_telemetry <label>   — start recording events to telemetry_<label>.jsonl
##   disarm_telemetry        — stop recording (flush + close file)
##   finish_run <label>      — disarms telemetry + writes summary + done
##
## === LAYER 3: SCENARIO HELPERS (new in Design Lab v1) ===
## Canned input sequences for reproducible playtests. Each runs a fixed
## pattern of moves/interacts sized to the scenario.
##   run_movement_scenario <name>  — name in: empty_room, hazard_course, chain_practice
##   run_salvage_scenario <name>   — name in: main_only, deeper_commit, mixed
##
## === LAYER 4: DEBUG PRIMITIVES (new in Design Lab v1) ===
##   set_shards <n>          — set soul_shards to n (test phase economy)
##   force_phase_cancel      — simulate SPACE press during active phase (test DIVE)
##   press_pulse             — simulate SHIFT tap (test pulse)
##   press_phase             — simulate SPACE press (activate or cancel phase)

var commands: Array = []
var command_index: int = 0
var wait_timer: float = 0.0
var move_dir: Vector2 = Vector2.ZERO
var move_time: float = 0.0
var log_file: FileAccess = null
var screenshot_count: int = 0
var finished: bool = false
var executing: bool = false
var telemetry_label: String = ""

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
		# === LAYER 1: existing automation commands (unchanged) ===
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
		# === LAYER 2: telemetry commands (new) ===
		"arm_telemetry":
			if parts.size() >= 2:
				telemetry_label = parts[1]
				Telemetry.arm(telemetry_label)
				_write_log("TELEMETRY ARMED: %s" % telemetry_label)
		"disarm_telemetry":
			Telemetry.disarm()
			_write_log("TELEMETRY DISARMED: %s" % telemetry_label)
		"finish_run":
			if parts.size() >= 2:
				telemetry_label = parts[1]
			if not telemetry_label.is_empty():
				Telemetry.disarm()
				_write_log("TELEMETRY DISARMED: %s" % telemetry_label)
			_write_state("finish_run")
			_finish()
		# === LAYER 3: scenario helpers (new) ===
		"run_movement_scenario":
			if parts.size() >= 2:
				_run_movement_scenario(parts[1])
		"run_salvage_scenario":
			if parts.size() >= 2:
				_run_salvage_scenario(parts[1])
		# === LAYER 4: debug primitives (new) ===
		"set_shards":
			if parts.size() >= 2:
				GameState.soul_shards = int(parts[1])
				GameState.shards_changed.emit(GameState.soul_shards)
				_write_log("SET SHARDS: %d" % GameState.soul_shards)
		"force_phase_cancel":
			_force_phase_input()
			_write_log("FORCED PHASE INPUT (SPACE)")
		"press_pulse":
			_pulse_input()
			_write_log("PRESSED PULSE (SHIFT)")
		"press_phase":
			_force_phase_input()
			_write_log("PRESSED PHASE (SPACE)")
		_:
			_write_log("UNKNOWN COMMAND: %s" % cmd)

# === Scenario runners ===

func _run_movement_scenario(name: String) -> void:
	# Inject canned movement commands into the queue at the current position.
	# These run as if the user typed them — they go through the same
	# move/wait/interact pipeline.
	var scenario: Array = []
	match name:
		"empty_room":
			# Drift around in a loose circle in the workshop or planning phase.
			scenario = ["move right 1.5", "wait 0.2", "move down 1.5", "wait 0.2",
						"move left 1.5", "wait 0.2", "move up 1.5", "wait 0.2",
						"press_phase", "wait 0.3", "force_phase_cancel", "wait 0.5",
						"press_pulse", "wait 0.3", "move right 2.0", "wait 0.5"]
		"hazard_course":
			# Salvage: walk straight down through the main corridor.
			scenario = ["move down 4.0", "wait 0.3", "move down 4.0", "wait 0.3",
						"move down 4.0", "wait 0.5"]
		"chain_practice":
			# Try the optimal chain: phase -> cancel -> dive -> coast -> pulse.
			scenario = ["move down 1.0", "wait 0.2",
						"press_phase", "wait 0.4", "force_phase_cancel", "wait 0.6",
						"press_pulse", "wait 0.3",
						"press_phase", "wait 0.4", "force_phase_cancel", "wait 0.6",
						"press_pulse", "wait 0.3"]
		_:
			_write_log("UNKNOWN SCENARIO: %s" % name)
			return
	# Insert the scenario commands right after the current command.
	for i in scenario.size():
		commands.insert(command_index + i, scenario[i])
	_write_log("QUEUED MOVEMENT SCENARIO: %s (%d commands)" % [name, scenario.size()])

func _run_salvage_scenario(name: String) -> void:
	var scenario: Array = []
	match name:
		"main_only":
			# Walk down the main corridor to the exit at the fork. No deeper commit.
			scenario = ["move down 6.0", "wait 0.3", "move down 4.0", "wait 0.5",
						"interact", "wait 0.3", "move down 4.0", "wait 0.5"]
		"deeper_commit":
			# Walk past the fork into the deeper section. Triggers crossroads_committed event.
			scenario = ["move down 6.0", "wait 0.3", "move down 6.0", "wait 0.3",
						"move down 6.0", "wait 0.3", "move down 6.0", "wait 0.5"]
		"mixed":
			# Walk down a bit, interact with corpses, then either commit deeper or exit.
			scenario = ["move down 3.0", "wait 0.3", "interact", "wait 0.3",
						"move down 3.0", "wait 0.3", "interact", "wait 0.3",
						"move down 4.0", "wait 0.5"]
		_:
			_write_log("UNKNOWN SCENARIO: %s" % name)
			return
	for i in scenario.size():
		commands.insert(command_index + i, scenario[i])
	_write_log("QUEUED SALVAGE SCENARIO: %s (%d commands)" % [name, scenario.size()])

# === Input injection helpers ===

func _force_phase_input() -> void:
	# Simulate a SPACE press — triggers phase activation OR cancel depending on state.
	Input.action_press("phase")
	await get_tree().process_frame
	Input.action_release("phase")

func _pulse_input() -> void:
	# Simulate a SHIFT tap.
	Input.action_press("pulse")
	await get_tree().process_frame
	Input.action_release("pulse")

# === Existing helpers (unchanged) ===

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
