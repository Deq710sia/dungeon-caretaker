class_name GhostMovement
extends RefCounted
## Shared movement + phase verb logic for the ghost. State-based movement
## system inspired by Phantom Forces movement tech — momentum is player-
## generated through state transitions and timing, not granted by buttons.
##
## Movement states:
##   FLOAT  — normal walking. Pulse-timing inputs gives small speed boost.
##   PHASE  — incorporeal dash (2x speed, costs shard, bypasses hazards).
##   DIVE   — momentum burst on phase cancel. Boost scales with remaining
##            phase energy. Cancel early = big burst. Cancel late = small.
##   COAST  — carrying converted momentum. Low deceleration. Pulse-timing
##            extends coast duration instead of just adding speed.
##            Weapon weight is halved during coast (riding momentum, not
##            generating it).
##
## The skill chain:
##   1. Build speed (pulse-timing in FLOAT)
##   2. Phase (2x speed, committed direction)
##   3. Cancel phase early (DIVE — big momentum burst)
##   4. Pulse-time inputs during COAST to extend the momentum
##   5. Phase again to restart the chain
##
## Each step is a skill check. Mistime the cancel = weak boost. Stop
## pulsing during coast = lose speed. The player builds speed through
## terrain + timing, not through a button that gives speed.

enum State { FLOAT, PHASE, DIVE, COAST }

# --- Movement constants ---
const BASE_SPEED: float = 55.0
const ACCEL: float = 220.0
const DECEL_MULT: float = 0.3       # FLOAT decel (30% of accel)
const COAST_DECEL_MULT: float = 0.08 # COAST decel (8% — barely slows)
const PHASE_SPEED_MULT: float = 2.0
const WEAPON_WEIGHT_MULT: float = 0.12
const COAST_WEIGHT_REDUCTION: float = 0.5  # weapon weight halved during coast

# Pulse timing (momentum carrying) — works in FLOAT and COAST
const PULSE_WINDOW: float = 0.35
const PULSE_BOOST: float = 1.15       # FLOAT: 15% boost
const COAST_PULSE_EXTEND: float = 0.2 # COAST: each pulse extends coast by 0.2s
const PULSE_BOOST_DECAY: float = 2.5

# Phase verb constants
const PHASE_DURATION: float = 1.5
const PHASE_CD: float = 4.0
const PHASE_COST: int = 1
const PHASE_BANK_MAX: float = 3.0

# DIVE — momentum burst on phase cancel
const DIVE_MIN_MULT: float = 1.2     # minimum burst mult (cancel at 0s remaining)
const DIVE_MAX_MULT: float = 2.5     # maximum burst mult (cancel at full duration)
const DIVE_DURATION: float = 0.4     # how long the dive burst lasts
const DIVE_DECAY: float = 3.0        # how fast dive mult decays to 1.0

# COAST — carrying converted momentum
const COAST_MIN_SPEED: float = 40.0  # below this, coast ends (back to FLOAT)
const COAST_BASE_DURATION: float = 0.6  # base coast time after a dive

# --- State ---
var state: int = State.FLOAT
var pos: Vector2
var vel: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.DOWN
var bob: float = 0.0
var squash: float = 1.0
var carry_count: int = 0

# --- Phase verb state ---
var phase_active: float = 0.0
var phase_cd: float = 0.0
var phase_bank: float = 0.0

# --- Internal timers ---
var _footstep_timer: float = 0.0
var _last_input_dir: Vector2 = Vector2.ZERO
var _prev_input_dir: Vector2 = Vector2.ZERO
var _no_input_timer: float = 0.0
var _pulse_mult: float = 1.0
var _pulse_flash: float = 0.0
var _dive_mult: float = 1.0
var _dive_timer: float = 0.0
var _coast_timer: float = 0.0
# Double-click pulse detection
var _last_click_time: float = 0.0
const DOUBLE_CLICK_WINDOW: float = 0.3  # seconds between clicks to count as double

## Called by the owning phase when a mouse click happens. If it's a double-
## click AND the ghost is moving (WASD held), fire a pulse in the current
## movement direction. This moves the pulse off WASD-tapping (which was
## jarring and conflicted with normal movement) and onto a deliberate
## input: hold a direction + double-click = pulse.
func handle_click(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_click_time < DOUBLE_CLICK_WINDOW:
		# Double-click! Fire a pulse if we're moving.
		_fire_pulse()
	_last_click_time = now

## Fire a pulse in the current velocity direction (or facing if no velocity).
## Works in both FLOAT and COAST states.
func _fire_pulse() -> void:
	if vel.length() < 5.0 and _last_input_dir == Vector2.ZERO:
		return  # need to be moving
	var boost_dir: Vector2 = vel.normalized() if vel.length() > 1.0 else facing
	vel = boost_dir * get_speed() * PULSE_BOOST
	_pulse_mult = PULSE_BOOST
	_pulse_flash = 1.0
	Juice.spawn_particles(pos, 5, Palette.GLOW_BLUE, 25.0, 0.2)
	SFX.play("blip", 1.3, -6.0, 0.02)
	# In coast state, also extend duration
	if state == State.COAST:
		_coast_timer += COAST_PULSE_EXTEND

## Effective speed — includes Fleet Shade upgrade and weapon weight.
## During COAST, weapon weight is halved (riding momentum, not generating it).
func get_speed() -> float:
	var mult: float = 1.0 + float(GameState.meta_upgrades.get("fleet_shade", 0)) * 0.15
	var weight_penalty: float = carry_count * WEAPON_WEIGHT_MULT
	if state == State.COAST:
		weight_penalty *= COAST_WEIGHT_REDUCTION
	return BASE_SPEED * mult * (1.0 - weight_penalty)

## Returns true if currently phasing (for draw logic + hazard bypass).
func is_phasing() -> bool:
	return state == State.PHASE

## Returns the phase cooldown progress 0-1 (for HUD/draw).
func cooldown_pct() -> float:
	if phase_cd <= 0:
		return 1.0
	return 1.0 - (phase_cd / PHASE_CD)

## Returns true if in COAST state (for visual feedback — trail tint, etc.)
func is_coasting() -> bool:
	return state == State.COAST

## Main update — called every physics/idle tick by the owning phase.
func update(input_dir: Vector2, delta: float) -> void:
	# Phase verb timers
	phase_cd = max(0, phase_cd - delta)
	if phase_active > 0:
		phase_active = max(0, phase_active - delta)
		if phase_active == 0:
			# Phase ended naturally (timer expired) — transition to FLOAT
			# with a small dive (less than a manual cancel)
			_enter_dive(0.2)  # 20% of max dive — natural phase end gives a tiny boost
	# State-specific update
	match state:
		State.PHASE:  _update_phase(input_dir, delta)
		State.DIVE:   _update_dive(input_dir, delta)
		State.COAST:  _update_coast(input_dir, delta)
		_:            _update_float(input_dir, delta)
	_prev_input_dir = input_dir
	# Shared: footstep + trail
	var speed_pct: float = vel.length() / get_speed()
	_footstep_timer += delta
	if speed_pct > 0.25 and _footstep_timer > 0.30 / maxf(0.4, speed_pct):
		_footstep_timer = 0.0
		SFX.play("footstep", 0.85 + randf() * 0.25, -8.0, 0.04)
	Juice.trail_sample(pos)

# --- FLOAT: normal walking ---
func _update_float(input_dir: Vector2, delta: float) -> void:
	state = State.FLOAT
	# Bob + squash
	var speed_pct: float = vel.length() / get_speed()
	bob += delta * (3.0 + speed_pct * 6.0)
	squash = lerp(squash, 1.0, 1.0 - exp(-delta * 8.0))
	# Movement — pulse is now handled by handle_click() + _fire_pulse()
	var target_speed: float = get_speed() * _pulse_mult
	_apply_movement(input_dir, target_speed, ACCEL, ACCEL * DECEL_MULT, delta)
	# Decay pulse mult + flash
	_pulse_mult = lerp(_pulse_mult, 1.0, 1.0 - exp(-delta * PULSE_BOOST_DECAY))
	_pulse_flash = max(0, _pulse_flash - delta * 4.0)

# --- PHASE: incorporeal dash ---
func _update_phase(input_dir: Vector2, delta: float) -> void:
	# Bob faster during phase (spectral energy)
	var speed_pct: float = vel.length() / get_speed()
	bob += delta * (6.0 + speed_pct * 8.0)
	squash = lerp(squash, 1.0, 1.0 - exp(-delta * 8.0))
	# Movement — phase is 2x speed, committed to facing direction
	var target_speed: float = get_speed() * PHASE_SPEED_MULT
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		facing = input_dir
		_last_input_dir = input_dir
		vel = vel.move_toward(input_dir * target_speed, ACCEL * delta)
	else:
		# During phase, keep moving in facing direction even without input
		vel = vel.move_toward(facing * target_speed, ACCEL * delta)
	pos += vel * delta

# --- DIVE: momentum burst on phase cancel ---
func _update_dive(input_dir: Vector2, delta: float) -> void:
	_dive_timer -= delta
	# Dive mult decays from peak to 1.0
	_dive_mult = lerp(_dive_mult, 1.0, 1.0 - exp(-delta * DIVE_DECAY))
	# Bob is fast during dive (burst energy)
	var speed_pct: float = vel.length() / get_speed()
	bob += delta * (8.0 + speed_pct * 6.0)
	squash = lerp(squash, 1.0, 1.0 - exp(-delta * 10.0))
	# Movement — dive uses the dive_mult as a speed multiplier
	var target_speed: float = get_speed() * _dive_mult
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		facing = input_dir
		_last_input_dir = input_dir
		# During dive, steer toward input but maintain burst speed.
		# Reflect on direction change so the dive doesn't stall.
		if vel.length() > 10.0 and vel.normalized().dot(input_dir) < 0.0:
			vel = input_dir * vel.length() * 0.8
		vel = vel.move_toward(input_dir * target_speed, ACCEL * 1.5 * delta)
	else:
		# No input — keep going in current direction (burst momentum)
		vel = vel.move_toward(facing * target_speed, ACCEL * 0.5 * delta)
	pos += vel * delta
	# When dive mult decays enough, transition to COAST
	if _dive_timer <= 0 or _dive_mult < 1.1:
		_enter_coast()

# --- COAST: carrying converted momentum ---
func _update_coast(input_dir: Vector2, delta: float) -> void:
	_coast_timer -= delta
	# Bob is smooth during coast (gliding)
	var speed_pct: float = vel.length() / get_speed()
	bob += delta * (4.0 + speed_pct * 5.0)
	squash = lerp(squash, 1.0, 1.0 - exp(-delta * 6.0))
	# Movement — very low deceleration (riding momentum)
	var target_speed: float = get_speed() * _pulse_mult
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		facing = input_dir
		_last_input_dir = input_dir
		# Reflect on direction change so coast doesn't stall
		if vel.length() > 10.0 and vel.normalized().dot(input_dir) < 0.0:
			vel = input_dir * vel.length() * 0.75
		vel = vel.move_toward(input_dir * target_speed, ACCEL * 0.8 * delta)
	else:
		vel = vel.move_toward(Vector2.ZERO, ACCEL * COAST_DECEL_MULT * delta)
	pos += vel * delta
	# Decay pulse mult + flash (pulse extension handled by _fire_pulse)
	_pulse_mult = lerp(_pulse_mult, 1.0, 1.0 - exp(-delta * PULSE_BOOST_DECAY))
	_pulse_flash = max(0, _pulse_flash - delta * 4.0)
	# Coast ends when: timer expires, speed drops too low, or phase starts
	if _coast_timer <= 0 or vel.length() < COAST_MIN_SPEED:
		state = State.FLOAT

# --- Shared movement application ---
func _apply_movement(input_dir: Vector2, target_speed: float, accel: float, decel: float, delta: float) -> void:
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		facing = input_dir
		_last_input_dir = input_dir
		# Direction change check: if the new input is >90° from current
		# velocity, don't gradually decelerate-to-zero-then-accelerate
		# (that's the "slowdown on direction change" the player felt).
		# Instead, REFLECT the velocity — keep the speed, flip the direction.
		# This is how fast-paced games handle direction changes: you keep
		# your momentum, you just redirect it. The accel then smooths the
		# remaining difference.
		if vel.length() > 10.0:
			var vel_dir: Vector2 = vel.normalized()
			var dot: float = vel_dir.dot(input_dir)
			if dot < 0.0:
				# Opposite direction — reflect velocity to new direction
				# at current speed (minus a small penalty so it's not free)
				var current_speed: float = vel.length()
				vel = input_dir * current_speed * 0.85  # 85% speed retained on reverse
		vel = vel.move_toward(input_dir * target_speed, accel * delta)
	else:
		vel = vel.move_toward(Vector2.ZERO, decel * delta)
	pos += vel * delta

# --- State transitions ---

## Enter DIVE state from phase cancel. The dive mult scales with remaining
## phase energy — cancel early = big burst, cancel late = small burst.
func _enter_dive(energy_pct: float) -> void:
	state = State.DIVE
	# energy_pct: 0.0 = no energy left, 1.0 = full energy
	# Map to dive mult: DIVE_MIN_MULT at 0 energy, DIVE_MAX_MULT at full
	_dive_mult = lerpf(DIVE_MIN_MULT, DIVE_MAX_MULT, energy_pct)
	_dive_timer = DIVE_DURATION
	# Burst velocity in facing direction
	if _last_input_dir != Vector2.ZERO:
		vel = _last_input_dir * get_speed() * _dive_mult
	else:
		vel = facing * get_speed() * _dive_mult
	Juice.trail_phasing = false
	SFX.play("phase_out", 1.0, -3.0)
	Juice.spawn_particles(pos, 6, Palette.GLOW_BLUE, 30.0, 0.4)
	squash = 0.7  # compress on dive entry (stretches out as it decays)

## Enter COAST state from dive.
func _enter_coast() -> void:
	state = State.COAST
	_coast_timer = COAST_BASE_DURATION
	# Carry current velocity into coast (don't reset)
	_dive_mult = 1.0

## Try to activate or cancel the phase verb.
func try_activate_phase() -> bool:
	if state == State.PHASE:
		# Manual cancel — convert remaining phase energy into a DIVE.
		# The more time was left, the bigger the burst (zingus principle:
		# you're converting stored energy into raw momentum).
		var remaining_pct: float = phase_active / PHASE_DURATION
		phase_bank = minf(PHASE_BANK_MAX, phase_bank + phase_active)
		phase_active = 0.0
		_enter_dive(remaining_pct)
		return true
	if state == State.COAST:
		# Can phase out of coast — converts coast momentum into phase
		# (keeps the chain going)
		_start_phase()
		return true
	if phase_cd > 0:
		return false
	if GameState.soul_shards < PHASE_COST:
		SFX.play("deny")
		return false
	_start_phase()
	return true

func _start_phase() -> void:
	GameState.soul_shards -= PHASE_COST
	GameState.shards_changed.emit(GameState.soul_shards)
	phase_active = PHASE_DURATION
	phase_cd = max(0.0, PHASE_CD - phase_bank)
	phase_bank = 0.0
	state = State.PHASE
	Juice.trail_phasing = true
	Juice.add_trauma(0.15)
	Juice.spawn_particles(pos, 8, Palette.GLOW_BLUE, 35.0, 0.5)
	SFX.play("phase_in", 1.0, -2.0)

## Reset all state (called on phase enter by the owning phase).
func reset(p_pos: Vector2) -> void:
	pos = p_pos
	vel = Vector2.ZERO
	facing = Vector2.DOWN
	bob = 0.0
	squash = 1.0
	state = State.FLOAT
	phase_active = 0.0
	phase_cd = 0.0
	phase_bank = 0.0
	_footstep_timer = 0.0
	_last_input_dir = Vector2.ZERO
	_prev_input_dir = Vector2.ZERO
	_no_input_timer = 0.0
	_pulse_mult = 1.0
	_pulse_flash = 0.0
	_dive_mult = 1.0
	_dive_timer = 0.0
	_coast_timer = 0.0

## Draws the ghost sprite with trail, phase visual, and cooldown ring.
static func draw_ghost(canvas: CanvasItem, mv: GhostMovement, is_underground: bool = false) -> void:
	var bob_val := int(sin(mv.bob) * 1.5)
	var gx := int(mv.pos.x)
	var gy := int(mv.pos.y)
	# Shadow
	canvas.draw_rect(Rect2(gx - 5, gy + 6, 10, 2), Color(0, 0, 0, 0.3), true)
	var ghost_tex := Sprites.get_sprite("ghost")
	var sw := int(16.0 / maxf(0.1, mv.squash))
	var sh := int(16 * mv.squash)
	# Trail
	Juice.trail_draw(canvas, ghost_tex, 16)
	# Visual modulate based on state
	var ghost_mod := Color(1, 1, 1, 1)
	if mv.state == State.PHASE:
		var phase_pct := mv.phase_active / PHASE_DURATION
		if is_underground:
			ghost_mod = Color(0.35, 0.55, 0.85, 0.3 + 0.15 * phase_pct)
		else:
			ghost_mod = Color(0.55, 0.75, 0.95, 0.5 + 0.15 * phase_pct)
	elif mv.state == State.DIVE:
		# Dive: bright white-blue flash that fades
		ghost_mod = Color(0.8, 0.9, 1.0, 0.8)
	elif mv.state == State.COAST:
		# Coast: faint blue tint (riding spectral momentum)
		ghost_mod = Color(0.7, 0.8, 1.0, 0.85)
	canvas.draw_texture_rect(ghost_tex, Rect2(gx - sw / 2, gy - sh / 2 + bob_val, sw, sh), false, ghost_mod)
	# Pulse flash — brief white-blue glow ring when a pulse fires
	if mv._pulse_flash > 0:
		var flash_alpha: float = mv._pulse_flash * 0.6
		canvas.draw_arc(Vector2(gx, gy + bob_val), 9, 0, TAU, 12, Color(0.8, 0.9, 1.0, flash_alpha), 2)
		canvas.draw_arc(Vector2(gx, gy + bob_val), 14, 0, TAU, 12, Color(0.6, 0.8, 1.0, flash_alpha * 0.5), 1)
	# Underground border ring (salvage only)
	if is_underground and mv.state == State.PHASE:
		canvas.draw_arc(Vector2(gx, gy + bob_val), 10, 0, TAU, 16, Color(0.1, 0.15, 0.3, 0.5), 2)
	# Cooldown ring
	if mv.phase_cd > 0 and mv.state != State.PHASE:
		var cd_pct: float = mv.cooldown_pct()
		canvas.draw_arc(Vector2(gx, gy), 12.0, -PI / 2, -PI / 2 + TAU * cd_pct, 16, Palette.TEXT_DIM, 1.5)
