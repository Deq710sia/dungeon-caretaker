class_name GhostMovement
extends RefCounted
## Shared movement + phase verb logic for the ghost. Each walkable phase
## (salvage, workshop, planning, gate) owns a GhostMovement instance and
## calls its update() in _physics_process/_process. This normalizes the
## movement values across all phases — no more duplicated speed/accel/friction
## constants that drift out of sync.
##
## The phase provides: current position, bounds, and whether input is allowed
## (e.g. salvage blocks input during QTE, planning blocks during map view).
## GhostMovement handles: velocity, acceleration, friction, facing, bob,
## squash, footsteps, trail, and the phase verb (activate/cancel/bank).

# --- Movement constants (single source of truth) ---
const SPEED: float = 55.0
const ACCEL: float = 220.0
const DECEL_MULT: float = 0.6  # decel is 60% of accel (coasts on release)
const PHASE_SPEED_MULT: float = 2.0  # speed multiplier while phasing

# --- Phase verb constants ---
const PHASE_DURATION: float = 1.5
const PHASE_CD: float = 4.0
const PHASE_COST: int = 1
const PHASE_BANK_MAX: float = 3.0
const MOMENTUM_BOOST_MULT: float = 2.0  # velocity burst on manual cancel

# --- State ---
var pos: Vector2
var vel: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.DOWN
var bob: float = 0.0
var squash: float = 1.0

# --- Phase verb state ---
var phase_active: float = 0.0
var phase_cd: float = 0.0
var phase_bank: float = 0.0  # banked time from early cancel — reduces NEXT cooldown
var _footstep_timer: float = 0.0
var _last_input_dir: Vector2 = Vector2.ZERO  # for momentum boost on cancel

## Called every physics/idle tick by the owning phase.
## `input_dir` is the normalized direction from held keys (or Vector2.ZERO
## if no input / input blocked). `delta` is the frame time.
## Returns the new velocity (also stored in `vel`).
func update(input_dir: Vector2, delta: float) -> void:
	# Phase verb timers
	phase_cd = max(0, phase_cd - delta)
	if phase_active > 0:
		phase_active = max(0, phase_active - delta)
		if phase_active == 0:
			Juice.trail_phasing = false
			SFX.play("phase_out", 1.0, -3.0)
	# Velocity-driven bob: 3Hz idle → 9Hz top speed
	var speed_pct: float = vel.length() / SPEED
	bob += delta * (3.0 + speed_pct * 6.0)
	squash = lerp(squash, 1.0, 1.0 - exp(-delta * 8.0))
	# Movement — full accel when input present (fast direction changes),
	# 60% decel when no input (coasts slightly on release).
	var target_speed: float = SPEED * (PHASE_SPEED_MULT if phase_active > 0 else 1.0)
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		facing = input_dir
		_last_input_dir = input_dir
		vel = vel.move_toward(input_dir * target_speed, ACCEL * delta)
	else:
		vel = vel.move_toward(Vector2.ZERO, ACCEL * DECEL_MULT * delta)
	pos += vel * delta
	# Footstep whoosh — interval scales with speed
	_footstep_timer += delta
	if speed_pct > 0.25 and _footstep_timer > 0.30 / maxf(0.4, speed_pct):
		_footstep_timer = 0.0
		SFX.play("footstep", 0.85 + randf() * 0.25, -8.0, 0.04)
	# Ghost trail
	Juice.trail_sample(pos)

## Try to activate or cancel the phase verb. Call this when the player
## presses the phase key. Returns true if the verb state changed.
func try_activate_phase() -> bool:
	if phase_active > 0:
		# Manual cancel — bank remaining time (reduces next cooldown) and
		# apply a momentum boost in the current facing direction.
		var remaining := phase_active
		phase_bank = minf(PHASE_BANK_MAX, phase_bank + remaining)
		phase_active = 0.0
		Juice.trail_phasing = false
		SFX.play("phase_out", 1.0, -3.0)
		# Momentum boost — burst in last input direction
		if _last_input_dir != Vector2.ZERO:
			vel = _last_input_dir * SPEED * MOMENTUM_BOOST_MULT
			Juice.spawn_particles(pos, 6, Palette.GLOW_BLUE, 30.0, 0.4)
		return true
	if phase_cd > 0:
		return false
	if GameState.soul_shards < PHASE_COST:
		SFX.play("deny")
		return false
	GameState.soul_shards -= PHASE_COST
	GameState.shards_changed.emit(GameState.soul_shards)
	# Banked time reduces the cooldown (not adds to duration). The meter
	# you didn't spend is refunded as a shorter cooldown next time.
	phase_active = PHASE_DURATION
	phase_cd = max(0.0, PHASE_CD - phase_bank)
	phase_bank = 0.0
	Juice.trail_phasing = true
	Juice.add_trauma(0.15)
	Juice.spawn_particles(pos, 8, Palette.GLOW_BLUE, 35.0, 0.5)
	SFX.play("phase_in", 1.0, -2.0)
	return true

## Returns true if currently phasing (for draw logic).
func is_phasing() -> bool:
	return phase_active > 0

## Returns the phase cooldown progress 0-1 (for HUD/draw).
func cooldown_pct() -> float:
	if phase_cd <= 0:
		return 1.0
	return 1.0 - (phase_cd / PHASE_CD)

## Reset all state (called on phase enter by the owning phase).
func reset(p_pos: Vector2) -> void:
	pos = p_pos
	vel = Vector2.ZERO
	facing = Vector2.DOWN
	bob = 0.0
	squash = 1.0
	phase_active = 0.0
	phase_cd = 0.0
	phase_bank = 0.0
	_footstep_timer = 0.0
	_last_input_dir = Vector2.ZERO

## Draws the ghost sprite with trail, phase-verb visual, and cooldown ring.
## Call this from the owning phase's _draw(). The `is_underground` param
## selects between the normal phase visual (semi-transparent blue) and the
## salvage "underground" visual (very transparent + dark border ring that
## reads as sinking below the floor).
##
## This replaces ~15 lines of duplicated draw code that was copy-pasted
## across salvage, workshop, and planning. Now any new walkable phase just
## calls `move.draw_ghost(self)` — no copy-paste, no drift.
static func draw_ghost(canvas: CanvasItem, mv: GhostMovement, is_underground: bool = false) -> void:
	var bob_val := int(sin(mv.bob) * 1.5)
	var gx := int(mv.pos.x)
	var gy := int(mv.pos.y)
	# Shadow
	canvas.draw_rect(Rect2(gx - 5, gy + 6, 10, 2), Color(0, 0, 0, 0.3), true)
	var ghost_tex := Sprites.get_sprite("ghost")
	var sw := int(16.0 / maxf(0.1, mv.squash))
	var sh := int(16 * mv.squash)
	# Trail (drawn before the sprite so the current sprite sits on top)
	Juice.trail_draw(canvas, ghost_tex, 16)
	# Phase verb visual
	var ghost_mod := Color(1, 1, 1, 1)
	if mv.is_phasing():
		var phase_pct := mv.phase_active / PHASE_DURATION
		if is_underground:
			# Salvage: very transparent + deep blue (reads as sinking below floor)
			ghost_mod = Color(0.35, 0.55, 0.85, 0.3 + 0.15 * phase_pct)
		else:
			# Workshop/planning: semi-transparent blue
			ghost_mod = Color(0.55, 0.75, 0.95, 0.5 + 0.15 * phase_pct)
	canvas.draw_texture_rect(ghost_tex, Rect2(gx - sw / 2, gy - sh / 2 + bob_val, sw, sh), false, ghost_mod)
	# Underground border ring (salvage only — suggests the floor is covering the ghost)
	if is_underground and mv.is_phasing():
		canvas.draw_arc(Vector2(gx, gy + bob_val), 10, 0, TAU, 16, Color(0.1, 0.15, 0.3, 0.5), 2)
	# Cooldown ring (shown when on cooldown, not while active)
	if mv.phase_cd > 0 and not mv.is_phasing():
		var cd_pct: float = mv.cooldown_pct()
		canvas.draw_arc(Vector2(gx, gy), 12.0, -PI / 2, -PI / 2 + TAU * cd_pct, 16, Palette.TEXT_DIM, 1.5)
