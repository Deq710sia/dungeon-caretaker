class_name GhostMovement
extends RefCounted
## v0.40 — 3-state movement redesign.
##
## States: FLOAT, PHASE, DIVE. No COAST (it caused the slippery feel).
##
## Design (per MOVEMENT_REDESIGN_PROPOSAL.md + user signoff):
##   - Speed IS the momentum. No separate 0-2.0 meter driving everything.
##     An internal momentum value still exists for state transition bonuses,
##     but it's not the primary resource — velocity is.
##   - Phase is momentum-influenced (not fixed, not full carry). Phase speed
##     = PHASE_SPEED * (1 + momentum_bonus). Pre-phase velocity is partially
##     preserved (50% if diving from high momentum).
##   - Pulse is a 2-charge one-shot burst, NOT a state. Charges refresh when
##     DIVE completes. Fires from FLOAT post-dive. The chain:
##       FLOAT → PHASE → DIVE → FLOAT (2 charges) → pulse → pulse → PHASE
##   - Per-action drift matrix: each state exit has its own decel value,
##     not a global friction curve. See DRIFT_* constants.
##   - v0.36 bifurcation preserved: natural phase expiry → clean FLOAT exit
##     (no dive), manual cancel → DIVE.
##
## WASD feel fixes (per research):
##   - Asymmetric accel/decel: 4-frame accel, 12-frame FLOAT decel
##   - 5-frame input buffer on pulse + phase
##   - Snap-stop: if no input + vel < 20% max, zero velocity
##   - Reversal penalty: 0.6 (keep 60% speed on reversal) — crisper pivots

enum State { FLOAT, PHASE, DIVE, COAST }

# --- Base movement ---
const BASE_SPEED: float = 55.0
const ACCEL: float = 833.0              # reach max in 4 frames (55 / 0.066s)
const WEAPON_WEIGHT_MULT: float = 0.12

# --- Per-action drift matrix (each exit has its own decel) ---
# All values are multipliers of ACCEL. Lower = more drift, higher = more stop.
const DRIFT_FLOAT_DECEL: float = 0.18       # 12-frame stop (release input in FLOAT)
const DRIFT_PHASE_NATURAL: float = 0.5      # 4-frame stop (phase expired → FLOAT, clean)
const DRIFT_DIVE_DECAY: float = 3.0         # dive mult decays to 1.0 over ~0.4s
const DRIFT_DIVE_TO_FLOAT: float = 0.25     # 8-frame stop (dive ends → COAST, ride the burst)
const DRIFT_PULSE_TO_FLOAT: float = 0.20    # 10-frame stop (pulse burst fades)
const DRIFT_WALL_HIGH_MOMENTUM: float = 0.5 # bleed 50% on clamped axis (coasting-equivalent)
const DRIFT_WALL_LOW_MOMENTUM: float = 0.0  # full zero (prevents momentum buildup against walls)

# --- COAST (v30-style: bounded 0.6s glide after DIVE, low decel, inherits dive vel) ---
const COAST_DECEL_MULT: float = 0.08    # barely slows (8% of accel) — riding momentum
const COAST_MIN_SPEED: float = 35.0     # below this, coast ends (back to FLOAT)
const COAST_BASE_DURATION: float = 0.6  # base coast time after a dive
const COAST_WEIGHT_REDUCTION: float = 0.5  # weapon weight halved during coast

# --- Snap-stop ---
const SNAP_STOP_THRESHOLD: float = 0.2  # below 20% max speed + no input = zero velocity

# --- Reversal ---
const REVERSAL_KEEP: float = 0.6  # keep 60% speed on direction reversal (was 0.85)

# --- Momentum (internal — drives state bonuses, not the primary resource) ---
const MOMENTUM_MAX: float = 2.0
const MOMENTUM_RISE: float = 0.9          # v0.39: was 1.5 — slower build = more skill
const MOMENTUM_FALL: float = 0.6          # lingers on the way down ("memory")
const MOMENTUM_CURVE_FLOOR: float = 0.15  # v0.39: was 0.3 — builds at lower speeds
const MOMENTUM_CURVE_CEIL: float = 0.6    # v0.39: was 0.8 — full momentum at 60% speed
const MOMENTUM_SPEED_BONUS: float = 0.4   # max +40% speed at full momentum (was 0.5 — slightly nerfed per user)
const MOMENTUM_PHASE_BONUS: float = 0.3   # phase gets +30% speed at full momentum
const MOMENTUM_DIVE_BONUS: float = 0.5    # dive impulse gets +0.5 mult per momentum point
const MOMENTUM_DIVE_COST: float = 0.3     # spent on manual cancel (dive)

# --- Phase ---
const PHASE_DURATION: float = 1.2     # was 1.5 — shorter, more committed
const PHASE_CD: float = 3.0           # was 4.0 — tighter chain
const PHASE_COST: int = 1
const PHASE_BANK_MAX: float = 3.0
const PHASE_SPEED: float = 110.0      # base phase speed (2x BASE_SPEED)
const PHASE_COAST_CARRY: float = 0.5  # if phasing from high momentum, preserve 50% of pre-phase vel

# --- Dive (one-shot burst on phase cancel) ---
const DIVE_MIN_MULT: float = 1.2      # cancel at 0s remaining
const DIVE_MAX_MULT: float = 2.5      # cancel at full duration
const DIVE_DURATION: float = 0.4

# --- Pulse (NEW — 2 charges, refresh on dive completion) ---
const PULSE_MAX_CHARGES: int = 2
const PULSE_BOOST: float = 80.0          # +80px/s burst in momentum direction
const PULSE_COAST_EXTEND: float = 0.0    # no COAST to extend — kept for compat
const PULSE_BOOST_DECAY: float = 3.0     # how fast pulse mult decays
const PULSE_BUFFER: float = 0.083        # 5-frame input buffer (5/60s)
const PULSE_CHAIN_WINDOW: float = 0.166  # 10-frame window between the two pulses
const PULSE_PHASE_CANCEL_WINDOW: float = 0.1  # 6-frame window after 2nd pulse to cancel into phase

# --- Input buffer (phase) ---
const PHASE_BUFFER: float = 0.083    # 5-frame input buffer for phase

# --- State ---
var state: int = State.FLOAT
var pos: Vector2
var vel: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.DOWN
var bob: float = 0.0
var squash: float = 1.0
var carry_count: int = 0

# --- Momentum (internal — drives state bonuses) ---
var momentum: float = 0.0

# --- Phase verb state ---
var phase_active: float = 0.0
var phase_cd: float = 0.0
var phase_bank: float = 0.0
var _last_phase_cd: float = 0.0

# --- Pulse charges (NEW) ---
var pulse_charges: int = 0           # starts at 0, must dive to earn
var _pulse_mult: float = 1.0         # active burst multiplier (decays to 1.0)
var _pulse_flash: float = 0.0        # brief flash ring on pulse
var _pulse_buffer: float = 0.0       # input buffer for pulse
var _last_pulse_time: float = -1.0   # for chain window tracking
var _pulse_count_in_chain: int = 0   # 0, 1, or 2 — tracks which pulse in the chain

# --- Dive state ---
var _dive_mult: float = 1.0
var _dive_timer: float = 0.0
var _coast_timer: float = 0.0  # v0.41: COAST state timer (bounded 0.6s glide)

# --- Internal timers ---
var _footstep_timer: float = 0.0
var _last_input_dir: Vector2 = Vector2.ZERO
var _pulse_was_pressed: bool = false  # manual edge detection for pulse
var _phase_buffer: float = 0.0        # input buffer for phase
var _telemetry_tick_accum: float = 0.0  # 10Hz tick accumulator

## Called every tick by the owning phase. Handles pulse tap + burst decay.
## Should be called BEFORE update().
func update_pulse(delta: float) -> void:
        _pulse_mult = lerp(_pulse_mult, 1.0, 1.0 - exp(-delta * PULSE_BOOST_DECAY))
        _pulse_flash = max(0, _pulse_flash - delta * 4.0)
        # Input buffer — if pulse was pressed within last 5 frames, try to fire.
        _pulse_buffer = max(0, _pulse_buffer - delta)
        # Pulse: TAP to fire (manual edge detection)
        var pulse_now: bool = Input.is_action_pressed("pulse")
        var pulse_just_pressed: bool = pulse_now and not _pulse_was_pressed
        _pulse_was_pressed = pulse_now
        if pulse_just_pressed:
                _pulse_buffer = PULSE_BUFFER
        # Try to fire if buffer is active
        if _pulse_buffer > 0:
                if _try_fire_pulse():
                        _pulse_buffer = 0.0

## Try to fire a pulse. Returns true if fired.
## v0.42: Pulse fires from ANY state (FLOAT, DIVE, COAST) — interrupts them.
## Charges refresh on phase END (so you can pulse the instant phase ends).
## The player chooses: cancel dive/coast momentum into pulse immediately, or
## ride it longer and pulse later. Most pulses still happen after dive/coast
## (that's the intended use — continue the greater dive momentum), but the
## freedom to do it earlier is there for spatial situations.
## With 0 charges, converts to a phase input (no wasted input — Hades pattern).
func _try_fire_pulse() -> bool:
        if state == State.PHASE:
                # Can't pulse during phase — phase is the dash, pulse is a chain link
                return false
        if pulse_charges <= 0:
                # No charges — convert to phase input (no wasted input)
                _phase_buffer = PHASE_BUFFER
                return false
        # Check chain window (must be within PULSE_CHAIN_WINDOW of last pulse)
        var now: float = Time.get_ticks_msec() / 1000.0
        if _pulse_count_in_chain > 0 and _last_pulse_time > 0:
                if now - _last_pulse_time > PULSE_CHAIN_WINDOW:
                        # Chain broken — reset count
                        _pulse_count_in_chain = 0
        # v0.42: If pulsing from DIVE or COAST, interrupt that state (go to FLOAT first,
        # so the pulse burst is clean and not fighting dive/coast movement logic).
        if state == State.DIVE or state == State.COAST:
                state = State.FLOAT
                _dive_mult = 1.0
                _coast_timer = 0.0
        # Fire the pulse
        pulse_charges -= 1
        _pulse_count_in_chain += 1
        _last_pulse_time = now
        # Burst in momentum direction
        var boost_dir: Vector2 = vel.normalized() if vel.length() > 1.0 else facing
        if boost_dir == Vector2.ZERO:
                boost_dir = facing
        vel += boost_dir * PULSE_BOOST
        _pulse_mult = 1.5  # brief speed mult
        _pulse_flash = 0.8
        SFX.play("pulse_release", 0.9 + 0.1 * momentum / MOMENTUM_MAX, -4.0, 0.02)
        Juice.spawn_particles(pos, 6, Palette.GLOW_BLUE, 25.0, 0.3)
        Juice.add_trauma(0.05)
        squash = 0.7  # compress on pulse
        Telemetry.emit({
                "type": "pulse_fired",
                "momentum": momentum,
                "state": state_name(state),
                "charges_remaining": pulse_charges,
                "pulse_count_in_chain": _pulse_count_in_chain,
                "pos": [pos.x, pos.y],
        })
        return true

## Returns the number of pulse charges available (for HUD/draw).
func get_pulse_charges() -> int:
        return pulse_charges

## Returns momentum 0-1 (for HUD — togglable number, not ring).
func momentum_pct() -> float:
        return momentum / MOMENTUM_MAX

## Returns true if pulse can fire (has charges + in FLOAT state).
func pulse_ready() -> bool:
        return state == State.FLOAT and pulse_charges > 0

## Returns true if currently phasing.
func is_phasing() -> bool:
        return state == State.PHASE

## Returns the state name as a string (for telemetry + debug).
static func state_name(s: int) -> String:
        match s:
                State.FLOAT: return "FLOAT"
                State.PHASE: return "PHASE"
                State.DIVE:  return "DIVE"
                State.COAST: return "COAST"
                _:           return "?"

## Returns the phase cooldown progress 0-1 (for HUD/draw).
func cooldown_pct() -> float:
        if phase_cd <= 0:
                return 1.0
        var cd_max: float = _last_phase_cd if _last_phase_cd > 0 else PHASE_CD
        return 1.0 - (phase_cd / cd_max)

## Wall collision velocity bleed — call from phase scripts when clamping pos.
## Per-action drift: high momentum = bleed 50%, low momentum = full zero.
func bleed_wall_velocity(axis: String) -> void:
        var bleed: float = DRIFT_WALL_HIGH_MOMENTUM if momentum > MOMENTUM_MAX * 0.3 else DRIFT_WALL_LOW_MOMENTUM
        if bleed == 0.0:
                if axis == "x":
                        vel.x = 0.0
                else:
                        vel.y = 0.0
        else:
                if axis == "x":
                        vel.x *= (1.0 - bleed)
                else:
                        vel.y *= (1.0 - bleed)

## Effective speed — includes Fleet Shade, weapon weight, momentum bonus.
## During COAST, weapon weight is halved (riding momentum, not generating it).
func get_speed() -> float:
        var mult: float = 1.0 + float(GameState.meta_upgrades.get("fleet_shade", 0)) * 0.15
        var weight_penalty: float = carry_count * WEAPON_WEIGHT_MULT
        if state == State.COAST:
                weight_penalty *= COAST_WEIGHT_REDUCTION
        var speed: float = BASE_SPEED * mult * (1.0 - weight_penalty)
        speed *= 1.0 + (momentum / MOMENTUM_MAX) * MOMENTUM_SPEED_BONUS
        return speed

## Main update — called every tick by the owning phase.
func update(input_dir: Vector2, delta: float) -> void:
        var prev_state: int = state
        # Phase verb timers
        phase_cd = max(0, phase_cd - delta)
        if phase_active > 0:
                phase_active = max(0, phase_active - delta)
                if phase_active == 0:
                        _end_phase_natural()
        # State-specific update
        match state:
                State.PHASE:  _update_phase(input_dir, delta)
                State.DIVE:   _update_dive(input_dir, delta)
                State.COAST:  _update_coast(input_dir, delta)
                _:            _update_float(input_dir, delta)
        # Telemetry: state change
        if state != prev_state:
                Telemetry.emit({
                        "type": "state_change",
                        "from": state_name(prev_state),
                        "to": state_name(state),
                        "pos": [pos.x, pos.y],
                        "vel": [vel.x, vel.y],
                        "momentum": momentum,
                })
        # Momentum update (after movement, so speed_pct is accurate)
        _update_momentum(delta)
        # Telemetry: 10Hz tick snapshot
        _telemetry_tick_accum += delta
        if _telemetry_tick_accum >= 0.1:
                _telemetry_tick_accum = 0.0
                Telemetry.emit_tick({
                        "state": state_name(state),
                        "pos": [pos.x, pos.y],
                        "vel": [vel.x, vel.y],
                        "speed_pct": vel.length() / get_speed() if get_speed() > 0 else 0.0,
                        "momentum": momentum,
                        "pulse_charges": pulse_charges,
                        "input": [input_dir.x, input_dir.y],
                        "phase_active": phase_active,
                        "phase_cd": phase_cd,
                })
        # Shared: footstep + trail
        var speed_pct: float = vel.length() / get_speed() if get_speed() > 0 else 0.0
        _footstep_timer += delta
        if speed_pct > 0.05 and _footstep_timer > 0.30 / maxf(0.4, speed_pct):
                _footstep_timer = 0.0
                SFX.play("footstep", 0.85 + randf() * 0.25, -8.0, 0.04)
        Juice.trail_sample(pos)

## Momentum chases a target derived from how fast you're actually moving.
## Frozen during PHASE + DIVE (those states protect momentum).
## During COAST, momentum slowly decays (riding, not building).
func _update_momentum(delta: float) -> void:
        if state == State.PHASE or state == State.DIVE:
                return  # frozen
        if state == State.COAST:
                # Slow decay during coast — momentum lingers but doesn't build
                momentum = lerp(momentum, 0.0, 1.0 - exp(-delta * MOMENTUM_FALL * 0.5))
                return
        var speed_pct: float = clampf(vel.length() / get_speed(), 0.0, 1.5)
        var curve: float = clampf((speed_pct - MOMENTUM_CURVE_FLOOR) / (MOMENTUM_CURVE_CEIL - MOMENTUM_CURVE_FLOOR), 0.0, 1.0)
        var target: float = curve * MOMENTUM_MAX
        var rate: float = MOMENTUM_RISE if target > momentum else MOMENTUM_FALL
        momentum = lerp(momentum, target, 1.0 - exp(-delta * rate))

# --- FLOAT: normal walking ---
func _update_float(input_dir: Vector2, delta: float) -> void:
        state = State.FLOAT
        var speed_pct: float = vel.length() / get_speed() if get_speed() > 0 else 0.0
        bob += delta * (3.0 + speed_pct * 6.0)
        squash = lerp(squash, 1.0, 1.0 - exp(-delta * 12.0))
        var target_speed: float = get_speed() * _pulse_mult
        # Snap-stop: if no input + vel < 20% max, zero velocity (kills slippery feel)
        if input_dir == Vector2.ZERO and vel.length() < get_speed() * SNAP_STOP_THRESHOLD:
                vel = Vector2.ZERO
        _apply_movement(input_dir, target_speed, ACCEL, ACCEL * DRIFT_FLOAT_DECEL, delta)

# --- PHASE: incorporeal dash (momentum-influenced, not full carry) ---
func _update_phase(input_dir: Vector2, delta: float) -> void:
        var speed_pct: float = vel.length() / get_speed() if get_speed() > 0 else 0.0
        bob += delta * (6.0 + speed_pct * 8.0)
        squash = lerp(squash, 1.0, 1.0 - exp(-delta * 12.0))
        # Phase speed = PHASE_SPEED * (1 + momentum bonus)
        var target_speed: float = PHASE_SPEED * (1.0 + (momentum / MOMENTUM_MAX) * MOMENTUM_PHASE_BONUS)
        if input_dir != Vector2.ZERO:
                input_dir = input_dir.normalized()
                facing = input_dir
                _last_input_dir = input_dir
                if vel.length() > 10.0 and vel.normalized().dot(input_dir) < 0.0:
                        vel = input_dir * vel.length() * REVERSAL_KEEP
                vel = vel.move_toward(input_dir * target_speed, ACCEL * delta)
        else:
                # Hold current velocity when no input — phase is a committed dash
                pass
        pos += vel * delta

# --- DIVE: momentum burst on phase cancel (one-shot, decays) ---
func _update_dive(input_dir: Vector2, delta: float) -> void:
        _dive_timer -= delta
        _dive_mult = lerp(_dive_mult, 1.0, 1.0 - exp(-delta * DRIFT_DIVE_DECAY))
        var speed_pct: float = vel.length() / get_speed() if get_speed() > 0 else 0.0
        bob += delta * (8.0 + speed_pct * 6.0)
        squash = lerp(squash, 1.0, 1.0 - exp(-delta * 15.0))
        # Dive uses the dive_mult as a speed multiplier
        var target_speed: float = get_speed() * _dive_mult
        if input_dir != Vector2.ZERO:
                input_dir = input_dir.normalized()
                facing = input_dir
                _last_input_dir = input_dir
                if vel.length() > 10.0 and vel.normalized().dot(input_dir) < 0.0:
                        vel = input_dir * vel.length() * REVERSAL_KEEP
                # DIVE always fires in current momentum direction (CrossCode pattern —
                # cancel without reversing). Input steers but doesn't reverse.
                vel = vel.move_toward(input_dir * target_speed, ACCEL * 1.5 * delta)
        else:
                # No input — keep going in current direction (ride the burst)
                pass
        pos += vel * delta
        # When dive mult decays enough, transition to COAST (v30-style: ride the burst)
        if _dive_timer <= 0 or _dive_mult < 1.1:
                _enter_coast()

# --- COAST: carrying converted momentum (v30-style bounded glide) ---
## COAST is a 0.6s bounded glide state entered from DIVE. It inherits the
## dive's velocity and barely decelerates (COAST_DECEL_MULT=0.08). The player
## can steer but can't exceed base speed. When COAST ends (timer or speed too
## low), the 2 pulse charges refresh and the ghost returns to FLOAT.
## This is the "ride the burst" landing pad — gives the chain a satisfying tail.
func _update_coast(input_dir: Vector2, delta: float) -> void:
        _coast_timer -= delta
        # Bob is smooth during coast (gliding)
        var speed_pct: float = vel.length() / get_speed() if get_speed() > 0 else 0.0
        bob += delta * (4.0 + speed_pct * 5.0)
        squash = lerp(squash, 1.0, 1.0 - exp(-delta * 6.0))
        # Movement — very low deceleration (riding momentum)
        var target_speed: float = get_speed()
        if input_dir != Vector2.ZERO:
                input_dir = input_dir.normalized()
                facing = input_dir
                _last_input_dir = input_dir
                # Can steer during coast but can't exceed base speed
                vel = vel.move_toward(input_dir * target_speed, ACCEL * 0.8 * delta)
        else:
                # No input — barely decelerate (coasting)
                vel = vel.move_toward(Vector2.ZERO, ACCEL * COAST_DECEL_MULT * delta)
        pos += vel * delta
        # Coast ends when: timer expires, speed drops too low
        if _coast_timer <= 0 or vel.length() < COAST_MIN_SPEED:
                _end_coast()

# --- Shared movement application ---
func _apply_movement(input_dir: Vector2, target_speed: float, accel: float, decel: float, delta: float) -> void:
        if input_dir != Vector2.ZERO:
                input_dir = input_dir.normalized()
                facing = input_dir
                _last_input_dir = input_dir
                if vel.length() > 10.0 and vel.normalized().dot(input_dir) < 0.0:
                        # v0.39: lowered reversal penalty 0.85 -> 0.6 for crisper pivots
                        vel = input_dir * vel.length() * REVERSAL_KEEP
                vel = vel.move_toward(input_dir * target_speed, accel * delta)
        else:
                vel = vel.move_toward(Vector2.ZERO, decel * delta)
        pos += vel * delta

# --- State transitions ---

## Phase ends — cancelled early (MANUAL). Fires the DIVE impulse.
## v0.42: Pulse charges refresh HERE (not on COAST exit) — so the player can
## pulse the instant phase ends, interrupting the dive if they choose.
## v0.36 bifurcation: manual cancel → DIVE, natural expiry → clean FLOAT.
func _end_phase(energy_pct: float) -> void:
        state = State.DIVE
        # Dive mult scales with remaining phase energy + momentum bonus
        var base_mult: float = lerpf(DIVE_MIN_MULT, DIVE_MAX_MULT, energy_pct)
        var momentum_bonus: float = (momentum / MOMENTUM_MAX) * MOMENTUM_DIVE_BONUS
        _dive_mult = base_mult + momentum_bonus
        _dive_timer = DIVE_DURATION
        # Spend momentum on dive
        var momentum_before: float = momentum
        momentum = clampf(momentum - MOMENTUM_DIVE_COST, 0.0, MOMENTUM_MAX)
        # Burst velocity in current momentum direction (CrossCode pattern —
        # cancel without reversing. Dive fires in vel/facing dir, never input dir.)
        var burst_dir: Vector2 = vel.normalized() if vel.length() > 1.0 else (_last_input_dir if _last_input_dir != Vector2.ZERO else facing)
        vel = burst_dir * get_speed() * _dive_mult
        Juice.trail_phasing = false
        SFX.play("phase_out", 1.0, -3.0)
        Juice.spawn_particles(pos, 6, Palette.GLOW_BLUE, 30.0, 0.4)
        squash = 0.7
        # v0.42: Refresh pulse charges on phase end — player can pulse immediately,
        # interrupting the dive, OR ride the dive/coast and pulse later.
        var charges_before: int = pulse_charges
        pulse_charges = PULSE_MAX_CHARGES
        _pulse_count_in_chain = 0
        _last_pulse_time = -1.0
        Telemetry.emit({
                "type": "dive_entered",
                "energy_pct": energy_pct,
                "momentum_before": momentum_before,
                "momentum_after": momentum,
                "dive_mult": _dive_mult,
                "pos": [pos.x, pos.y],
        })
        Telemetry.emit({
                "type": "dive_completed",
                "charges_before": charges_before,
                "charges_after": pulse_charges,
                "pos": [pos.x, pos.y],
                "momentum": momentum,
        })

## Natural phase expiry — clean return to FLOAT (v0.36 fix).
## No impulse, no momentum cost. Soft phase_out SFX.
## v0.42: Pulse charges refresh HERE too (so natural expiry also enables pulse).
func _end_phase_natural() -> void:
        state = State.FLOAT
        Juice.trail_phasing = false
        SFX.play("phase_out", 0.8, -6.0)
        # v0.42: Refresh pulse charges on natural phase expiry too
        var charges_before: int = pulse_charges
        pulse_charges = PULSE_MAX_CHARGES
        _pulse_count_in_chain = 0
        _last_pulse_time = -1.0
        Telemetry.emit({
                "type": "phase_expired_natural",
                "pos": [pos.x, pos.y],
                "vel": [vel.x, vel.y],
                "momentum": momentum,
        })
        Telemetry.emit({
                "type": "dive_completed",
                "charges_before": charges_before,
                "charges_after": pulse_charges,
                "pos": [pos.x, pos.y],
                "momentum": momentum,
        })

## Dive ends — transition to COAST (v30-style: ride the burst before FLOAT).
## Pulse charges refresh when COAST ends (not here).
func _end_dive() -> void:
        _enter_coast()

## Enter COAST state from dive. Inherits dive velocity (no reset).
func _enter_coast() -> void:
        state = State.COAST
        _coast_timer = COAST_BASE_DURATION
        _dive_mult = 1.0
        Telemetry.emit({
                "type": "coast_entered",
                "momentum": momentum,
                "pos": [pos.x, pos.y],
        })

## COAST ends — transition to FLOAT.
## v0.42: Pulse charges no longer refresh here (they refresh on phase end now).
func _end_coast() -> void:
        state = State.FLOAT

## Try to activate or cancel the phase verb.
func try_activate_phase() -> bool:
        # Input buffer check
        if _phase_buffer > 0:
                _phase_buffer = 0.0
        if state == State.PHASE:
                # Manual cancel — convert remaining phase energy into a DIVE impulse
                var remaining_pct: float = phase_active / PHASE_DURATION
                phase_bank = minf(PHASE_BANK_MAX, phase_bank + phase_active)
                phase_active = 0.0
                _end_phase(remaining_pct)
                return true
        if phase_cd > 0:
                return false
        if GameState.soul_shards < PHASE_COST:
                SFX.play("deny")
                return false
        _start_phase(false)
        return true

func _start_phase(from_high_momentum: bool = false) -> void:
        GameState.soul_shards -= PHASE_COST
        GameState.shards_changed.emit(GameState.soul_shards)
        phase_active = PHASE_DURATION
        # Cooldown: full normally, reduced by banked energy
        var base_cd: float = PHASE_CD
        var final_cd: float = maxf(0.0, base_cd - phase_bank)
        _last_phase_cd = final_cd
        phase_cd = final_cd
        phase_bank = 0.0
        state = State.PHASE
        Juice.trail_phasing = true
        Juice.add_trauma(0.15)
        Juice.spawn_particles(pos, 8, Palette.GLOW_BLUE, 35.0, 0.5)
        SFX.play("phase_in", 1.0, -2.0)
        # Momentum-influenced phase: if entering from high momentum, preserve 50% of velocity.
        # Otherwise phase is a committed dash at PHASE_SPEED.
        if from_high_momentum and vel.length() > get_speed() * 0.5:
                # Preserve 50% of pre-phase velocity (rewards chaining)
                vel = vel * PHASE_COAST_CARRY + facing * PHASE_SPEED * 0.5
        # Else: phase SETS velocity to facing * PHASE_SPEED (committed dash)
        else:
                vel = facing * PHASE_SPEED
        Telemetry.emit({
                "type": "phase_activated",
                "from_high_momentum": from_high_momentum,
                "momentum": momentum,
                "pos": [pos.x, pos.y],
                "shards_remaining": GameState.soul_shards,
        })

## Reset all state (called on phase enter by the owning phase).
func reset(p_pos: Vector2) -> void:
        pos = p_pos
        vel = Vector2.ZERO
        facing = Vector2.DOWN
        bob = 0.0
        squash = 1.0
        state = State.FLOAT
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
        _phase_buffer = 0.0
        _pulse_buffer = 0.0
        _telemetry_tick_accum = 0.0
        pulse_charges = 0  # start with 0 — must dive to earn
        _pulse_count_in_chain = 0
        _last_pulse_time = -1.0
        _dive_mult = 1.0
        _dive_timer = 0.0
        _coast_timer = 0.0

## Draws the ghost sprite with trail, phase visual, pulse charge indicators.
## v0.40: momentum ring REMOVED. Pulse charges shown as 2 blue arc segments.
static func draw_ghost(canvas: CanvasItem, mv: GhostMovement, is_underground: bool = false) -> void:
        var bob_val := int(sin(mv.bob) * 1.5)
        var gx := int(mv.pos.x)
        var gy := int(mv.pos.y)
        # Shadow
        canvas.draw_rect(Rect2(gx - 5, gy + 6, 10, 2), Color(0, 0, 0, 0.3), true)
        var ghost_tex := Sprites.get_sprite("ghost")
        var sw := int(16.0 / maxf(0.1, mv.squash))
        var sh := int(16 * mv.squash)
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
                # DIVE: bright white-blue flash that fades
                ghost_mod = Color(0.8, 0.9, 1.0, 0.8)
        elif mv.state == State.COAST:
                # COAST: faint blue tint (riding spectral momentum) — v30-style
                ghost_mod = Color(0.7, 0.8, 1.0, 0.85)
        canvas.draw_texture_rect(ghost_tex, Rect2(gx - sw / 2, gy - sh / 2 + bob_val, sw, sh), false, ghost_mod)
        # Pulse charge indicators — 2 blue arc segments around the ghost
        # (only show when charges > 0, in FLOAT state)
        if mv.state == State.FLOAT and mv.pulse_charges > 0:
                var charge_color: Color = Palette.GLOW_BLUE
                var radius: float = 14.0
                # Draw 2 arcs (each 60°), on left and right sides
                for i in mv.pulse_charges:
                        var angle_offset: float = -PI / 2 + (i - 0.5) * PI  # i=0: left, i=1: right
                        canvas.draw_arc(Vector2(gx, gy + bob_val), radius,
                                angle_offset - PI / 6, angle_offset + PI / 6,
                                8, charge_color, 2)
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
