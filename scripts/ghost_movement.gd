class_name GhostMovement
extends RefCounted
## Movement + phase verb logic for the ghost.
##
## v2 — momentum/friction rewrite. FLOAT/DIVE/COAST used to be four separate
## branches, each with its own decel constant, timer, and exit condition,
## plus a chain_count counter bolted on to stop DIVE from being spammed for
## free speed. This version keeps momentum as the one tunable resource and
## makes everything else a continuous function of it instead of a mode:
##
##   - Friction now scales smoothly with momentum (high momentum = low
##     friction). That WAS the entire reason COAST existed as a state.
##   - Canceling PHASE early (or letting it expire) converts remaining phase
##     energy into a one-time velocity impulse. That WAS DIVE — it doesn't
##     need its own timer or decay curve, because ordinary friction (above)
##     already governs how a burst of speed bleeds off.
##   - Momentum itself now chases a target derived from how fast you're
##     actually moving, on a curve — not a flat build/decay rate with a dead
##     zone between two hardcoded thresholds.
##
## Two states left: NORMAL and PHASE. PHASE stays a real state because it
## changes actual rules (collision, momentum freezes, velocity holds with no
## input) — not just a momentum tier.
##
## Also fixed in passing: try_activate_phase() used to let a coasting ghost
## start a new phase for free — no cooldown check, no shard check, straight
## bypass (see "Chain: phase from coast" in the old code). That's almost
## certainly why chain_count had to exist: it was the only thing stopping
## infinite free phase-chaining. This version still gives a coasting ghost a
## cooldown discount, but it goes through the same cost/cooldown gate as any
## other phase activation, so there's nothing left for a chain counter to
## guard against.
##
## Unchanged: momentum as the resource, Phase as a shard-costed dash that
## holds velocity on no input, Pulse as a tap-fired momentum spend for an
## instant directional burst.

enum State { NORMAL, PHASE }

# --- Base movement ---
const BASE_SPEED: float = 55.0
const ACCEL: float = 300.0
const WEAPON_WEIGHT_MULT: float = 0.12
const COAST_WEIGHT_REDUCTION: float = 0.5   # now eases in continuously with momentum

# --- Friction: continuous function of momentum (was FLOAT vs COAST decel) ---
const FRICTION_HIGH: float = 0.5    # friction at momentum = 0 (was DECEL_MULT)
const FRICTION_LOW: float = 0.25    # friction at momentum = MAX (was COAST_DECEL_MULT)

# --- Momentum: smooth pursuit of a target, not build/decay rates + dead zone ---
const MOMENTUM_MAX: float = 2.0
const MOMENTUM_RISE: float = 1.5          # chases UP toward target quickly
const MOMENTUM_FALL: float = 0.6          # ...but lingers on the way down ("memory")
const MOMENTUM_CURVE_FLOOR: float = 0.3   # speed_pct below this -> momentum target 0
const MOMENTUM_CURVE_CEIL: float = 0.8    # speed_pct above this -> momentum target MAX
const MOMENTUM_SPEED_BONUS: float = 0.5   # max +50% speed at full momentum
const MOMENTUM_PHASE_BONUS: float = 0.3   # phase gets +30% speed at full momentum
const MOMENTUM_DIVE_BONUS: float = 0.5    # phase-end impulse gets +0.5 mult per momentum point
const MOMENTUM_DIVE_COST: float = 0.3     # spent whenever phase ends
const MOMENTUM_PULSE_GAIN: float = 0.4    # added by pulse
const MOMENTUM_PULSE_COST: float = 0.3    # required to fire pulse
const COASTING_THRESHOLD: float = 0.4     # fraction of MOMENTUM_MAX that counts as "coasting"

# --- Pulse (unchanged mechanically — tap-fire momentum spend) ---
const PULSE_BOOST_MULT: float = 1.5
const PULSE_BOOST_DECAY: float = 3.0

# --- Phase verb (unchanged) ---
const PHASE_DURATION: float = 1.5
const PHASE_CD: float = 4.0
const PHASE_COST: int = 1
const PHASE_BANK_MAX: float = 3.0
const PHASE_SPEED_MULT: float = 2.0

# --- Phase-end impulse (was DIVE, a whole state; now a one-shot event) ---
const DIVE_MIN_MULT: float = 1.2
const DIVE_MAX_MULT: float = 2.5

# --- State ---
var state: int = State.NORMAL
var pos: Vector2
var vel: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.DOWN
var bob: float = 0.0
var squash: float = 1.0
var carry_count: int = 0

# --- Momentum (the core compoundable value) ---
var momentum: float = 0.0

# --- Phase verb state ---
var phase_active: float = 0.0
var phase_cd: float = 0.0
var phase_bank: float = 0.0
var _last_phase_cd: float = 0.0  # for accurate cooldown_pct (fixes bank bug)

# --- Internal timers ---
var _footstep_timer: float = 0.0
var _last_input_dir: Vector2 = Vector2.ZERO
var _pulse_was_pressed: bool = false  # manual edge detection for pulse
var _pulse_mult: float = 1.0          # active burst multiplier (decays to 1.0)
var _pulse_flash: float = 0.0         # brief flash ring on pulse

## Called every tick by the owning phase. Handles pulse tap + burst decay.
## Should be called BEFORE update().
func update_pulse(delta: float) -> void:
	_pulse_mult = lerp(_pulse_mult, 1.0, 1.0 - exp(-delta * PULSE_BOOST_DECAY))
	_pulse_flash = max(0, _pulse_flash - delta * 4.0)
	# Pulse: TAP to fire (manual edge detection — more reliable than Input.is_action_just_pressed)
	var pulse_now: bool = Input.is_action_pressed("pulse")
	var pulse_just_pressed: bool = pulse_now and not _pulse_was_pressed
	_pulse_was_pressed = pulse_now
	if pulse_just_pressed:
		_fire_pulse()

## Fire an instant pulse burst. Costs momentum, adds momentum back net.
func _fire_pulse() -> void:
	if momentum < MOMENTUM_PULSE_COST:
		SFX.play("deny", 0.8, -6.0)
		return
	momentum = clampf(momentum - MOMENTUM_PULSE_COST + MOMENTUM_PULSE_GAIN, 0.0, MOMENTUM_MAX)
	var boost_dir: Vector2 = vel.normalized() if vel.length() > 1.0 else facing
	if boost_dir == Vector2.ZERO:
		boost_dir = facing
	vel = boost_dir * get_speed() * PULSE_BOOST_MULT
	_pulse_mult = PULSE_BOOST_MULT
	_pulse_flash = 0.8
	SFX.play("pulse_release", 0.9 + 0.1 * momentum / MOMENTUM_MAX, -4.0, 0.02)
	Juice.spawn_particles(pos, 6, Palette.GLOW_BLUE, 25.0, 0.3)
	Juice.add_trauma(0.05)
	squash = 0.7  # compress on pulse

## Returns momentum 0-1 (for HUD).
func momentum_pct() -> float:
	return momentum / MOMENTUM_MAX

## Returns true if pulse can fire (enough momentum).
func pulse_ready() -> bool:
	return momentum >= MOMENTUM_PULSE_COST

## True once momentum is high enough that friction is meaningfully low.
## Replaces the old discrete COAST state for external callers (camera feel,
## HUD, phase cooldown discount) — same job, continuous underneath.
func is_coasting() -> bool:
	return state == State.NORMAL and momentum > MOMENTUM_MAX * COASTING_THRESHOLD

## Effective speed — includes Fleet Shade, weapon weight, momentum bonus.
## Weight penalty eases off as momentum rises (was: halved only during COAST).
func get_speed() -> float:
	var mult: float = 1.0 + float(GameState.meta_upgrades.get("fleet_shade", 0)) * 0.15
	var weight_penalty: float = carry_count * WEAPON_WEIGHT_MULT
	weight_penalty *= lerp(1.0, COAST_WEIGHT_REDUCTION, momentum / MOMENTUM_MAX)
	var speed: float = BASE_SPEED * mult * (1.0 - weight_penalty)
	speed *= 1.0 + (momentum / MOMENTUM_MAX) * MOMENTUM_SPEED_BONUS
	return speed

## Returns true if currently phasing.
func is_phasing() -> bool:
	return state == State.PHASE

## Returns the phase cooldown progress 0-1 (for HUD/draw).
func cooldown_pct() -> float:
	if phase_cd <= 0:
		return 1.0
	var cd_max: float = _last_phase_cd if _last_phase_cd > 0 else PHASE_CD
	return 1.0 - (phase_cd / cd_max)

## Main update — called every tick by the owning phase.
func update(input_dir: Vector2, delta: float) -> void:
	# Phase verb timers
	phase_cd = max(0, phase_cd - delta)
	if phase_active > 0:
		phase_active = max(0, phase_active - delta)
		if phase_active == 0:
			_end_phase(0.2)
	# State-specific update — just two branches now
	if state == State.PHASE:
		_update_phase(input_dir, delta)
	else:
		_update_normal(input_dir, delta)
	# Momentum update (after movement, so speed_pct is accurate)
	_update_momentum(delta)
	# Shared: footstep + trail
	var speed_pct: float = vel.length() / get_speed()
	_footstep_timer += delta
	if speed_pct > 0.25 and _footstep_timer > 0.30 / maxf(0.4, speed_pct):
		_footstep_timer = 0.0
		SFX.play("footstep", 0.85 + randf() * 0.25, -8.0, 0.04)
	Juice.trail_sample(pos)

## Momentum chases a target derived from how fast you're actually moving —
## a smooth curve, no build/decay dead zone. Rises quickly, falls slowly
## (momentum "has memory" instead of evaporating the instant you slow down).
func _update_momentum(delta: float) -> void:
	if state == State.PHASE:
		return  # frozen during phase — phase protects momentum, doesn't spend it
	var speed_pct: float = clampf(vel.length() / get_speed(), 0.0, 1.5)
	var curve: float = clampf((speed_pct - MOMENTUM_CURVE_FLOOR) / (MOMENTUM_CURVE_CEIL - MOMENTUM_CURVE_FLOOR), 0.0, 1.0)
	var target: float = curve * MOMENTUM_MAX
	var rate: float = MOMENTUM_RISE if target > momentum else MOMENTUM_FALL
	momentum = lerp(momentum, target, 1.0 - exp(-delta * rate))

## NORMAL: everything that isn't phasing. Was FLOAT/DIVE/COAST — now one
## branch where friction itself scales with momentum, so "coasting" is just
## what high momentum looks like, not a separate mode with its own timer.
func _update_normal(input_dir: Vector2, delta: float) -> void:
	state = State.NORMAL
	var speed_pct: float = vel.length() / get_speed()
	bob += delta * (3.0 + speed_pct * 6.0)
	squash = lerp(squash, 1.0, 1.0 - exp(-delta * 12.0))
	var target_speed: float = get_speed() * _pulse_mult
	var friction: float = lerp(FRICTION_HIGH, FRICTION_LOW, momentum / MOMENTUM_MAX)
	_apply_movement(input_dir, target_speed, ACCEL, ACCEL * friction, delta)

## PHASE: incorporeal dash (holds current velocity when no input).
func _update_phase(input_dir: Vector2, delta: float) -> void:
	var speed_pct: float = vel.length() / get_speed()
	bob += delta * (6.0 + speed_pct * 8.0)
	squash = lerp(squash, 1.0, 1.0 - exp(-delta * 12.0))
	var target_speed: float = get_speed() * PHASE_SPEED_MULT * (1.0 + (momentum / MOMENTUM_MAX) * MOMENTUM_PHASE_BONUS)
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		facing = input_dir
		_last_input_dir = input_dir
		if vel.length() > 10.0 and vel.normalized().dot(input_dir) < 0.0:
			vel = input_dir * vel.length() * 0.85
		vel = vel.move_toward(input_dir * target_speed, ACCEL * delta)
	else:
		# Hold current velocity when no input — phase is a committed dash,
		# not steering. (This is the one piece of the old system that was
		# already right; unchanged from v0.17.)
		pass
	pos += vel * delta

# --- Shared movement application (unchanged) ---
func _apply_movement(input_dir: Vector2, target_speed: float, accel: float, decel: float, delta: float) -> void:
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		facing = input_dir
		_last_input_dir = input_dir
		if vel.length() > 10.0 and vel.normalized().dot(input_dir) < 0.0:
			vel = input_dir * vel.length() * 0.85
		vel = vel.move_toward(input_dir * target_speed, accel * delta)
	else:
		vel = vel.move_toward(Vector2.ZERO, decel * delta)
	pos += vel * delta

## Phase ends — cancelled early or timer ran out. Remaining energy becomes a
## ONE-TIME velocity impulse. This is DIVE's entire replacement: no state,
## no timer, no separate decay curve. The impulse just IS the new velocity,
## and it bleeds off through the same momentum-driven friction as everything
## else in NORMAL — a fast exit naturally coasts, then naturally settles.
func _end_phase(energy_pct: float) -> void:
	state = State.NORMAL
	var base_mult: float = lerpf(DIVE_MIN_MULT, DIVE_MAX_MULT, energy_pct)
	var momentum_bonus: float = (momentum / MOMENTUM_MAX) * MOMENTUM_DIVE_BONUS
	var impulse_mult: float = base_mult + momentum_bonus
	momentum = clampf(momentum - MOMENTUM_DIVE_COST, 0.0, MOMENTUM_MAX)
	var burst_dir: Vector2 = vel.normalized() if vel.length() > 1.0 else (_last_input_dir if _last_input_dir != Vector2.ZERO else facing)
	vel = burst_dir * get_speed() * impulse_mult
	Juice.trail_phasing = false
	SFX.play("phase_out", 1.0, -3.0)
	Juice.spawn_particles(pos, 6, Palette.GLOW_BLUE, 30.0, 0.4)
	squash = 0.7

## Try to activate or cancel the phase verb.
func try_activate_phase() -> bool:
	if state == State.PHASE:
		# Manual cancel — convert remaining phase energy into an impulse
		var remaining_pct: float = phase_active / PHASE_DURATION
		phase_bank = minf(PHASE_BANK_MAX, phase_bank + phase_active)
		phase_active = 0.0
		_end_phase(remaining_pct)
		return true
	# NOTE: the old code let a coasting ghost skip this cooldown/cost check
	# entirely ("Chain: phase from coast"). That was almost certainly a bug,
	# not a feature — it's the reason chain_count had to exist. Fixed here:
	# coasting still gets a cheaper phase (below), but never a free one.
	if phase_cd > 0:
		return false
	if GameState.soul_shards < PHASE_COST:
		SFX.play("deny")
		return false
	_start_phase(is_coasting())
	return true

func _start_phase(discounted_cd: bool = false) -> void:
	GameState.soul_shards -= PHASE_COST
	GameState.shards_changed.emit(GameState.soul_shards)
	phase_active = PHASE_DURATION
	# Cooldown: full normally, halved if you were carrying momentum into it,
	# reduced further by any banked energy from an early cancel.
	var base_cd: float = PHASE_CD
	if discounted_cd:
		base_cd *= 0.5
	var final_cd: float = maxf(0.0, base_cd - phase_bank)
	_last_phase_cd = final_cd
	phase_cd = final_cd
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
	state = State.NORMAL
	momentum = 0.0
	phase_active = 0.0
	phase_cd = 0.0
	phase_bank = 0.0
	_last_phase_cd = 0.0
	_footstep_timer = 0.0
	_last_input_dir = Vector2.ZERO
	_pulse_mult = 1.0
	_pulse_flash = 0.0
	_pulse_was_pressed = false

## Draws the ghost sprite with trail, phase visual, momentum ring.
static func draw_ghost(canvas: CanvasItem, mv: GhostMovement, is_underground: bool = false) -> void:
	var bob_val := int(sin(mv.bob) * 1.5)
	var gx := int(mv.pos.x)
	var gy := int(mv.pos.y)
	canvas.draw_rect(Rect2(gx - 5, gy + 6, 10, 2), Color(0, 0, 0, 0.3), true)
	var ghost_tex := Sprites.get_sprite("ghost")
	var sw := int(16.0 / maxf(0.1, mv.squash))
	var sh := int(16 * mv.squash)
	Juice.trail_draw(canvas, ghost_tex, 16)
	var ghost_mod := Color(1, 1, 1, 1)
	if mv.state == State.PHASE:
		var phase_pct := mv.phase_active / PHASE_DURATION
		if is_underground:
			ghost_mod = Color(0.35, 0.55, 0.85, 0.3 + 0.15 * phase_pct)
		else:
			ghost_mod = Color(0.55, 0.75, 0.95, 0.5 + 0.15 * phase_pct)
	else:
		# Was a DIVE/COAST color switch — now a continuous tint by momentum,
		# since "carrying momentum" isn't a discrete mode anymore.
		var mom_pct: float = mv.momentum / MOMENTUM_MAX
		ghost_mod = Color(1, 1, 1, 1).lerp(Color(0.75, 0.85, 1.0, 0.85), mom_pct)
	canvas.draw_texture_rect(ghost_tex, Rect2(gx - sw / 2, gy - sh / 2 + bob_val, sw, sh), false, ghost_mod)
	# Momentum ring — fills clockwise, color shifts blue->gold as momentum grows
	if mv.momentum > 0.05:
		var mom_pct: float = mv.momentum / MOMENTUM_MAX
		var mom_color: Color = Color(0.5, 0.7, 1.0).lerp(Color(1.0, 0.85, 0.3), mom_pct)
		canvas.draw_arc(Vector2(gx, gy + bob_val), 14, 0, TAU, 24, Color(1, 1, 1, 0.1), 1)
		canvas.draw_arc(Vector2(gx, gy + bob_val), 14, -PI / 2, -PI / 2 + TAU * mom_pct, 24, mom_color, 2)
	# Pulse burst flash — expanding ring on pulse
	if mv._pulse_flash > 0:
		var flash_alpha: float = mv._pulse_flash * 0.7
		var flash_radius: float = 9 + (1.0 - mv._pulse_flash) * 12
		canvas.draw_arc(Vector2(gx, gy + bob_val), flash_radius, 0, TAU, 16, Color(0.8, 0.9, 1.0, flash_alpha), 2)
		canvas.draw_arc(Vector2(gx, gy + bob_val), flash_radius + 5, 0, TAU, 16, Color(0.6, 0.8, 1.0, flash_alpha * 0.5), 1)
	# Underground border ring (salvage only)
	if is_underground and mv.state == State.PHASE:
		canvas.draw_arc(Vector2(gx, gy + bob_val), 10, 0, TAU, 16, Color(0.1, 0.15, 0.3, 0.5), 2)
	# Cooldown ring (uses accurate _last_phase_cd)
	if mv.phase_cd > 0 and mv.state != State.PHASE:
		var cd_pct: float = mv.cooldown_pct()
		canvas.draw_arc(Vector2(gx, gy), 12.0, -PI / 2, -PI / 2 + TAU * cd_pct, 16, Palette.TEXT_DIM, 1.5)
