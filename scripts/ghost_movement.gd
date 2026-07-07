class_name GhostMovement
extends RefCounted
## Shared movement + phase verb logic for the ghost. State-based movement
## system inspired by Phantom Forces movement tech — momentum is player-
## generated through state transitions and timing, not granted by buttons.
##
## Movement states:
##   FLOAT  — normal walking. Hold SHIFT to charge a pulse burst.
##   PHASE  — incorporeal dash (2x speed, costs shard, bypasses hazards).
##   DIVE   — momentum burst on phase cancel. Boost scales with remaining
##            phase energy. Cancel early = big burst. Cancel late = small.
##   COAST  — carrying converted momentum. Low deceleration. A pulse
##            during coast extends its duration (ride the momentum longer).
##            Weapon weight is halved during coast (riding momentum, not
##            generating it).
##
## Pulse verb (v0.14+): HOLD SHIFT to charge, RELEASE to burst.
##   - Min charge (0-0.2s held):  1.4x boost, 0.3s duration
##   - Med charge (0.2-0.5s):     1.7x boost, 0.4s duration
##   - Max charge (0.5s+):        2.2x boost, 0.6s duration + screen shake
##   - Cooldown: 1.2s after release (prevents spam, rewards timing)
##   - Tradeoff: ghost slows to 70% speed WHILE charging
## The skill chain:
##   1. Build speed (charge pulse in FLOAT)
##   2. Phase (2x speed, committed direction)
##   3. Cancel phase early (DIVE — big momentum burst)
##   4. Pulse during COAST to extend the momentum
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

# Pulse verb (v0.14+): charge-and-release on SHIFT
const PULSE_CHARGE_MAX: float = 1.0   # full charge takes 1.0s
const PULSE_CD: float = 1.2           # cooldown after release
const PULSE_CHARGE_SPEED_MULT: float = 0.7  # ghost slows to 70% while charging
# Charge thresholds: [min_charge_time, boost_mult, burst_duration, particles, trauma]
const PULSE_MIN: Array = [0.0, 1.4, 0.3, 4, 0.05]
const PULSE_MED: Array = [0.2, 1.7, 0.4, 7, 0.10]
const PULSE_MAX: Array = [0.5, 2.2, 0.6, 12, 0.20]
const COAST_PULSE_EXTEND: float = 0.4 # COAST: pulse extends coast by 0.4s
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
var _pulse_mult: float = 1.0       # active burst multiplier (decays to 1.0)
var _pulse_flash: float = 0.0      # brief flash ring on release
var _pulse_charging: bool = false  # true while SHIFT held
var _pulse_charge_t: float = 0.0   # 0-1, how long SHIFT has been held (clamped to PULSE_CHARGE_MAX)
var _pulse_charge_level: int = 0   # 0=idle, 1=min, 2=med, 3=max (for visual + sound)
var _pulse_burst_t: float = 0.0    # remaining burst duration (0 = no burst)
var _pulse_cd_t: float = 0.0       # cooldown remaining
var _dive_mult: float = 1.0
var _dive_timer: float = 0.0
var _coast_timer: float = 0.0
var _coast_input_hold: float = 0.0  # how long input has been held during coast

## Called every tick by the owning phase. Handles SHIFT charge/release,
## burst decay, and cooldown. Should be called BEFORE update() so the
## burst multiplier is applied to this tick's movement.
func update_pulse(delta: float) -> void:
	# Decay burst + cooldown timers
	if _pulse_burst_t > 0:
		_pulse_burst_t = max(0, _pulse_burst_t - delta)
		if _pulse_burst_t == 0:
			_pulse_mult = 1.0  # burst ended
	if _pulse_cd_t > 0:
		_pulse_cd_t = max(0, _pulse_cd_t - delta)
	_pulse_flash = max(0, _pulse_flash - delta * 4.0)
	# Decay pulse_mult toward 1.0 (smooth ramp-down after burst peak)
	_pulse_mult = lerp(_pulse_mult, 1.0, 1.0 - exp(-delta * PULSE_BOOST_DECAY))
	# Charge handling
	if Input.is_action_pressed("pulse") and _pulse_cd_t == 0 and state != State.PHASE and state != State.DIVE:
		if not _pulse_charging:
			_pulse_charging = true
			_pulse_charge_t = 0.0
			SFX.play("pulse_charge", 1.0, -8.0, 0.0)
		_pulse_charge_t = min(PULSE_CHARGE_MAX, _pulse_charge_t + delta)
		# Update charge level for visual feedback
		if _pulse_charge_t >= PULSE_MAX[0]:
			_pulse_charge_level = 3
		elif _pulse_charge_t >= PULSE_MED[0]:
			_pulse_charge_level = 2
		else:
			_pulse_charge_level = 1
	elif _pulse_charging:
		# SHIFT released — fire the burst
		_release_pulse()
	elif not Input.is_action_pressed("pulse"):
		_pulse_charging = false
		_pulse_charge_t = 0.0
		_pulse_charge_level = 0

## Release the charged pulse. Boost scales with charge level.
func _release_pulse() -> void:
	_pulse_charging = false
	var level: int = _pulse_charge_level
	if level == 0:
		level = 1  # minimum
	var cfg: Array
	match level:
		3: cfg = PULSE_MAX
		2: cfg = PULSE_MED
		_: cfg = PULSE_MIN
	var boost_mult: float = cfg[1]
	var burst_dur: float = cfg[2]
	var particles: int = cfg[3]
	var trauma: float = cfg[4]
	# Apply burst in current movement direction (or facing if no velocity)
	var boost_dir: Vector2 = vel.normalized() if vel.length() > 1.0 else facing
	if boost_dir == Vector2.ZERO:
		boost_dir = facing
	vel = boost_dir * get_speed() * boost_mult
	_pulse_mult = boost_mult
	_pulse_burst_t = burst_dur
	_pulse_flash = 0.8
	_pulse_cd_t = PULSE_CD
	_pulse_charge_t = 0.0
	_pulse_charge_level = 0  # reset so HUD/draw doesn't show stale charge
	# Visual + audio feedback scales with charge level
	var pitch: float = 0.85 + 0.15 * level  # higher charge = higher pitch
	SFX.play("pulse_release", pitch, -4.0, 0.02)
	Juice.spawn_particles(pos, particles, Palette.GLOW_BLUE, 25.0 + 10.0 * level, 0.4)
	Juice.add_trauma(trauma)
	# In coast state, also extend duration (chain reward)
	if state == State.COAST:
		_coast_timer += COAST_PULSE_EXTEND
	# Squash on release (compresses, stretches out as burst decays)
	squash = 0.6

## Returns the current charge level 0-3 for HUD/draw (0 = not charging).
func pulse_charge_level() -> int:
	return _pulse_charge_level if _pulse_charging else 0

## Returns charge progress 0-1 (for HUD charge ring fill).
func pulse_charge_pct() -> float:
	if not _pulse_charging:
		return 0.0
	return _pulse_charge_t / PULSE_CHARGE_MAX

## Returns true if pulse is on cooldown (for HUD).
func pulse_on_cooldown() -> bool:
	return _pulse_cd_t > 0

## Returns cooldown progress 0-1 (1 = ready).
func pulse_cooldown_pct() -> float:
	if _pulse_cd_t <= 0:
		return 1.0
	return 1.0 - (_pulse_cd_t / PULSE_CD)

## Effective speed — includes Fleet Shade upgrade, weapon weight, and
## pulse charge slowdown. During COAST, weapon weight is halved (riding
## momentum, not generating it). While charging a pulse, speed is reduced
## to PULSE_CHARGE_SPEED_MULT (tradeoff: charge = anticipation, not free).
func get_speed() -> float:
	var mult: float = 1.0 + float(GameState.meta_upgrades.get("fleet_shade", 0)) * 0.15
	var weight_penalty: float = carry_count * WEAPON_WEIGHT_MULT
	if state == State.COAST:
		weight_penalty *= COAST_WEIGHT_REDUCTION
	var speed: float = BASE_SPEED * mult * (1.0 - weight_penalty)
	if _pulse_charging:
		speed *= PULSE_CHARGE_SPEED_MULT
	return speed

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
	# Movement — pulse burst multiplier applied via _pulse_mult (set by update_pulse)
	var target_speed: float = get_speed() * _pulse_mult
	_apply_movement(input_dir, target_speed, ACCEL, ACCEL * DECEL_MULT, delta)
	# Pulse mult + flash decay handled by update_pulse() (called by owning phase)

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
		# Direction reflect — keep speed, flip direction. Phase is fast and
		# committed; reflect lets you curve through a turn without stalling.
		if vel.length() > 10.0 and vel.normalized().dot(input_dir) < 0.0:
			vel = input_dir * vel.length() * 0.85
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
		# Direction reflect — dive is a burst, you can curve it but it
		# keeps the burst momentum. 0.80 retain (slight loss on redirect).
		if vel.length() > 10.0 and vel.normalized().dot(input_dir) < 0.0:
			vel = input_dir * vel.length() * 0.80
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
	# Track input hold for coast cancel — but ONLY count input that steers
	# away from current velocity (>45° off). Holding the dive direction
	# keeps you in coast (so you can chain phase); pushing a different
	# direction for >0.25s cancels coast (player wants to regain control).
	if input_dir != Vector2.ZERO:
		var vel_dir: Vector2 = vel.normalized() if vel.length() > 1.0 else facing
		if input_dir.normalized().dot(vel_dir) < 0.7:  # >45° off current direction
			_coast_input_hold += delta
		else:
			_coast_input_hold = 0.0
	else:
		_coast_input_hold = 0.0
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
		# Direction reflect — keep speed, flip direction. Coast is lighter
		# (0.70 retain) so steering out of coast feels deliberate.
		if vel.length() > 10.0 and vel.normalized().dot(input_dir) < 0.0:
			vel = input_dir * vel.length() * 0.70
		vel = vel.move_toward(input_dir * target_speed, ACCEL * 0.8 * delta)
	else:
		vel = vel.move_toward(Vector2.ZERO, ACCEL * COAST_DECEL_MULT * delta)
	pos += vel * delta
	# Pulse mult + flash decay handled by update_pulse() (called by owning phase)
	# Coast ends when: timer expires, speed drops too low, or steering input
	# is held firmly. Steering = pushing a direction >45° off current vel
	# for >0.25s. Holding the dive direction does NOT cancel (so the chain
	# phase→dive→coast→phase stays possible).
	if _coast_timer <= 0 or vel.length() < COAST_MIN_SPEED or _coast_input_hold > 0.25:
		state = State.FLOAT

# --- Shared movement application ---
## Direction reflect on reversals: when the new input is >90° from current
## velocity, snap velocity to the new direction at 85% of current speed.
## This eliminates the "slowdown on direction change" that move_toward
## causes (it has to decelerate to zero before accelerating the other way).
## 85% retain = you keep most of your momentum, just redirected. The 15%
## loss prevents reversal-spam from being free. For partial turns (<90°),
## move_toward handles it smoothly — no reflect needed.
func _apply_movement(input_dir: Vector2, target_speed: float, accel: float, decel: float, delta: float) -> void:
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		facing = input_dir
		_last_input_dir = input_dir
		# Direction reflect on reversals only (dot < 0 means >90° turn)
		if vel.length() > 10.0 and vel.normalized().dot(input_dir) < 0.0:
			vel = input_dir * vel.length() * 0.85
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
		var remaining_pct: float = phase_active / PHASE_DURATION
		phase_bank = minf(PHASE_BANK_MAX, phase_bank + phase_active)
		phase_active = 0.0
		_enter_dive(remaining_pct)
		return true
	if state == State.COAST:
		# Can phase out of coast — the chain continues. Coast momentum
		# converts into phase (the whole point of the chain system).
		# Cooldown is HALVED when phasing from coast (reward for chaining).
		_start_phase(true)
		return true
	if phase_cd > 0:
		return false
	if GameState.soul_shards < PHASE_COST:
		SFX.play("deny")
		return false
	_start_phase(false)
	return true

func _start_phase(from_coast: bool = false) -> void:
	GameState.soul_shards -= PHASE_COST
	GameState.shards_changed.emit(GameState.soul_shards)
	phase_active = PHASE_DURATION
	# Cooldown: full from FLOAT, halved from COAST (chain reward),
	# further reduced by banked time.
	var base_cd: float = PHASE_CD
	if from_coast:
		base_cd *= 0.5  # coasting into phase = half cooldown
	phase_cd = max(0.0, base_cd - phase_bank)
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
	_pulse_charging = false
	_pulse_charge_t = 0.0
	_pulse_charge_level = 0
	_pulse_burst_t = 0.0
	_pulse_cd_t = 0.0
	_dive_mult = 1.0
	_dive_timer = 0.0
	_coast_timer = 0.0
	_coast_input_hold = 0.0

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
	# Pulse charge ring — fills clockwise while SHIFT held, color shifts
	# white -> cyan -> blue -> purple as charge level grows
	if mv._pulse_charging:
		var charge_pct: float = mv.pulse_charge_pct()
		var level: int = mv._pulse_charge_level
		var charge_color: Color
		match level:
			3: charge_color = Color(0.7, 0.5, 1.0, 0.9)  # purple (max)
			2: charge_color = Color(0.5, 0.7, 1.0, 0.9)  # blue (med)
			_: charge_color = Color(0.7, 0.9, 1.0, 0.9)  # cyan (min)
		# Background ring (dim)
		canvas.draw_arc(Vector2(gx, gy + bob_val), 14, 0, TAU, 24, Color(1, 1, 1, 0.15), 1)
		# Charge fill (clockwise from top)
		canvas.draw_arc(Vector2(gx, gy + bob_val), 14, -PI / 2, -PI / 2 + TAU * charge_pct, 24, charge_color, 2)
		# Inner pulse dot (pulses while charging)
		var pulse_dot: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.015)
		canvas.draw_circle(Vector2(gx, gy + bob_val), 2, Color(charge_color.r, charge_color.g, charge_color.b, pulse_dot * 0.6))
	# Pulse burst flash — expanding ring on release, fades quickly
	if mv._pulse_flash > 0:
		var flash_alpha: float = mv._pulse_flash * 0.7
		var flash_radius: float = 9 + (1.0 - mv._pulse_flash) * 12
		canvas.draw_arc(Vector2(gx, gy + bob_val), flash_radius, 0, TAU, 16, Color(0.8, 0.9, 1.0, flash_alpha), 2)
		canvas.draw_arc(Vector2(gx, gy + bob_val), flash_radius + 5, 0, TAU, 16, Color(0.6, 0.8, 1.0, flash_alpha * 0.5), 1)
	# Pulse cooldown ring (when on cooldown and not charging)
	if mv._pulse_cd_t > 0 and not mv._pulse_charging:
		var cd_pct: float = mv.pulse_cooldown_pct()
		canvas.draw_arc(Vector2(gx, gy + bob_val), 14, -PI / 2, -PI / 2 + TAU * cd_pct, 16, Palette.TEXT_DIM, 1)
	# Underground border ring (salvage only)
	if is_underground and mv.state == State.PHASE:
		canvas.draw_arc(Vector2(gx, gy + bob_val), 10, 0, TAU, 16, Color(0.1, 0.15, 0.3, 0.5), 2)
	# Cooldown ring
	if mv.phase_cd > 0 and mv.state != State.PHASE:
		var cd_pct: float = mv.cooldown_pct()
		canvas.draw_arc(Vector2(gx, gy), 12.0, -PI / 2, -PI / 2 + TAU * cd_pct, 16, Palette.TEXT_DIM, 1.5)
