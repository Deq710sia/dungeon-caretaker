class_name GhostMovement
extends RefCounted
## Shared movement + phase verb logic for the ghost. State-based movement
## system with a compoundable MOMENTUM value — momentum builds with speed,
## gets spent by dive, added by pulse, and modifies speed multiplicatively.
## Different states interact with momentum differently, so the player
## compounds momentum across states rather than just preserving velocity.
##
## Movement states:
##   FLOAT  — normal walking. Build momentum by moving fast. Tap SHIFT to
##            pulse (spends momentum for an instant burst, resets chain).
##   PHASE  — incorporeal dash (2x speed + momentum bonus, costs shard).
##            Holds current velocity when no input (doesn't push toward facing).
##            Natural expiry (timer runs out) returns to FLOAT cleanly (v0.36).
##            Tap SPACE during phase to cancel early → DIVE (intentional burst).
##   DIVE   — momentum burst on phase CANCEL (manual only, not natural expiry).
##            Boost scales with remaining phase energy AND current momentum.
##            Chain degradation reduces boost 10% per consecutive phase (min 50%).
##   COAST  — carrying momentum. Low deceleration. Pulse during coast
##            extends duration AND adds momentum. Weapon weight halved.
##
## Momentum (the core system):
##   - Builds when moving fast (speed_pct > 0.7): +0.5/s
##   - Decays when slow: -0.3/s
##   - Spent by DIVE: -0.3 per dive
##   - Added by PULSE: +0.4 per pulse (costs 0.3 to fire, net +0.1)
##   - Modifies speed: up to +50% at full momentum
##   - Preserved across states (compounds), resets when FLOAT for 0.5s
##
## Pulse verb (v0.17+): TAP SHIFT for instant burst.
##   - No charge, no cooldown, no slowdown
##   - Costs 0.3 momentum (must have >= 0.3)
##   - Gives instant 1.5x burst + 0.4 momentum gain (net +0.1)
##   - Resets chain_count to 0 (creative chain continuation)
##   - During COAST: also extends coast duration
##
## Chain system (v0.17+):
##   - chain_count increments on each phase
##   - Each chain step: dive boost reduced 10% (min 50% of normal)
##   - Chain resets when FLOAT for 0.5s, OR when pulse fires
##   - Optimal loop: phase → cancel → dive → coast → pulse (reset) → phase → ...
##   - Without pulse, chain degrades — rewards creative continuation
##
## The skill chain:
##   1. Build momentum (move fast in FLOAT)
##   2. Phase (2x speed + momentum bonus)
##   3. Cancel phase early (DIVE — big momentum burst, but chain degrades)
##   4. COAST carries momentum (low decel)
##   5. Pulse to reset chain + extend coast (+momentum)
##   6. Phase again at full power (chain reset by pulse)

enum State { FLOAT, PHASE, DIVE, COAST }

# --- Movement constants ---
const BASE_SPEED: float = 55.0
const ACCEL: float = 300.0          # was 220 — snappier response, less delay
const DECEL_MULT: float = 0.5       # was 0.3 — faster FLOAT stop (less drift)
const COAST_DECEL_MULT: float = 0.25 # was 0.08 — much faster COAST stop
const PHASE_SPEED_MULT: float = 2.0
const WEAPON_WEIGHT_MULT: float = 0.12
const COAST_WEIGHT_REDUCTION: float = 0.5

# --- Momentum system (v0.17 core) ---
const MOMENTUM_MAX: float = 2.0
const MOMENTUM_BUILD_RATE: float = 0.5    # +0.5/s when moving fast
const MOMENTUM_DECAY_RATE: float = 0.3    # -0.3/s when slow
const MOMENTUM_DIVE_COST: float = 0.3     # spent on dive
const MOMENTUM_PULSE_GAIN: float = 0.4    # added by pulse
const MOMENTUM_PULSE_COST: float = 0.3    # required to fire pulse
const MOMENTUM_SPEED_BONUS: float = 0.5   # max +50% speed at full momentum
const MOMENTUM_PHASE_BONUS: float = 0.3   # phase gets +30% speed at full momentum
const MOMENTUM_DIVE_BONUS: float = 0.5    # dive gets +0.5 mult per momentum point
const MOMENTUM_FAST_THRESHOLD: float = 0.7 # speed_pct above this builds momentum

# --- Pulse verb (v0.17 — tap, not charge) ---
const PULSE_BOOST_MULT: float = 1.5       # instant burst multiplier
const PULSE_BURST_DUR: float = 0.25       # burst duration
const PULSE_BOOST_DECAY: float = 3.0      # how fast burst decays
const COAST_PULSE_EXTEND: float = 0.4     # COAST: pulse extends coast by 0.4s

# --- Phase verb constants ---
const PHASE_DURATION: float = 1.5
const PHASE_CD: float = 4.0
const PHASE_COST: int = 1
const PHASE_BANK_MAX: float = 3.0

# --- DIVE — momentum burst on phase cancel ---
const DIVE_MIN_MULT: float = 1.2
const DIVE_MAX_MULT: float = 2.5
const DIVE_DURATION: float = 0.4
const DIVE_DECAY: float = 3.0
const DIVE_CHAIN_DEGRADE: float = 0.1     # 10% less per chain step
const DIVE_CHAIN_MIN: float = 0.5         # min 50% of normal boost

# --- COAST ---
const COAST_MIN_SPEED: float = 50.0       # was 40 — ends coast sooner
const COAST_BASE_DURATION: float = 0.6

# --- Chain system ---
const CHAIN_RESET_TIME: float = 0.5       # FLOAT for 0.5s resets chain

# --- State ---
var state: int = State.FLOAT
var pos: Vector2
var vel: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.DOWN
var bob: float = 0.0
var squash: float = 1.0
var carry_count: int = 0

# --- Momentum (the core compoundable value) ---
var momentum: float = 0.0

# --- Chain system ---
var chain_count: int = 0
var _chain_reset_timer: float = 0.0

# --- Phase verb state ---
var phase_active: float = 0.0
var phase_cd: float = 0.0
var phase_bank: float = 0.0
var _last_phase_cd: float = 0.0  # for accurate cooldown_pct (fixes bank bug)

# --- Internal timers ---
var _footstep_timer: float = 0.0
var _last_input_dir: Vector2 = Vector2.ZERO
var _prev_input_dir: Vector2 = Vector2.ZERO
var _pulse_was_pressed: bool = false  # manual edge detection for pulse
var _pulse_mult: float = 1.0       # active burst multiplier (decays to 1.0)
var _pulse_flash: float = 0.0      # brief flash ring on pulse
var _dive_mult: float = 1.0
var _dive_timer: float = 0.0
var _coast_timer: float = 0.0
var _coast_input_hold: float = 0.0

## Called every tick by the owning phase. Handles pulse tap, momentum
## updates, burst decay. Should be called BEFORE update().
func update_pulse(delta: float) -> void:
        # Decay burst multiplier
        _pulse_mult = lerp(_pulse_mult, 1.0, 1.0 - exp(-delta * PULSE_BOOST_DECAY))
        _pulse_flash = max(0, _pulse_flash - delta * 4.0)
        # Pulse: TAP to fire (manual edge detection — more reliable than Input.is_action_just_pressed)
        var pulse_now: bool = Input.is_action_pressed("pulse")
        var pulse_just_pressed: bool = pulse_now and not _pulse_was_pressed
        _pulse_was_pressed = pulse_now
        if pulse_just_pressed:
                _fire_pulse()
        # Momentum update (state-specific, called from update())
        # Chain reset timer (counts up while in FLOAT)
        if state == State.FLOAT:
                _chain_reset_timer += delta
                if _chain_reset_timer >= CHAIN_RESET_TIME and chain_count > 0:
                        chain_count = 0
                        _pulse_flash = 0.3  # subtle visual on chain reset
        else:
                _chain_reset_timer = 0.0

## Fire an instant pulse burst. Costs momentum, adds momentum, resets chain.
## ADDS to current velocity (not sets) — so you always feel it, even at top speed.
func _fire_pulse() -> void:
        if momentum < MOMENTUM_PULSE_COST:
                SFX.play("deny", 0.8, -6.0)
                return
        # Spend momentum cost, then add net gain
        momentum = clampf(momentum - MOMENTUM_PULSE_COST + MOMENTUM_PULSE_GAIN, 0.0, MOMENTUM_MAX)
        # ADD a fixed velocity boost on top of current speed — always feelable
        var boost_dir: Vector2 = vel.normalized() if vel.length() > 1.0 else facing
        if boost_dir == Vector2.ZERO:
                boost_dir = facing
        # Fixed boost: BASE_SPEED * 0.8 added ON TOP of current velocity
        # This means at low speed you get +44 px/s (huge), at high speed you still
        # get +44 px/s on top of whatever you had (still feelable)
        var boost_amount: float = BASE_SPEED * 0.8
        vel += boost_dir * boost_amount
        _pulse_mult = PULSE_BOOST_MULT
        _pulse_flash = 0.8
        # Reset chain (creative continuation reward)
        chain_count = 0
        # Visual + audio
        SFX.play("pulse_release", 0.9 + 0.1 * momentum / MOMENTUM_MAX, -4.0, 0.02)
        Juice.spawn_particles(pos, 6, Palette.GLOW_BLUE, 25.0, 0.3)
        Juice.add_trauma(0.05)
        # During COAST, extend duration
        if state == State.COAST:
                _coast_timer += COAST_PULSE_EXTEND
        squash = 0.7  # compress on pulse

## Returns momentum 0-1 (for HUD).
func momentum_pct() -> float:
        return momentum / MOMENTUM_MAX

## Returns chain count (for HUD).
func get_chain_count() -> int:
        return chain_count

## Returns true if pulse can fire (enough momentum).
func pulse_ready() -> bool:
        return momentum >= MOMENTUM_PULSE_COST

## Effective speed — includes Fleet Shade, weapon weight, momentum bonus,
## and phase momentum bonus. During COAST, weapon weight is halved.
func get_speed() -> float:
        var mult: float = 1.0 + float(GameState.meta_upgrades.get("fleet_shade", 0)) * 0.15
        var weight_penalty: float = carry_count * WEAPON_WEIGHT_MULT
        if state == State.COAST:
                weight_penalty *= COAST_WEIGHT_REDUCTION
        var speed: float = BASE_SPEED * mult * (1.0 - weight_penalty)
        # Momentum speed bonus (up to +50%)
        speed *= 1.0 + (momentum / MOMENTUM_MAX) * MOMENTUM_SPEED_BONUS
        return speed

## Returns true if currently phasing.
func is_phasing() -> bool:
        return state == State.PHASE

## Returns the phase cooldown progress 0-1 (for HUD/draw).
## Uses _last_phase_cd for accurate percentage (fixes bank/halve bug).
func cooldown_pct() -> float:
        if phase_cd <= 0:
                return 1.0
        var cd_max: float = _last_phase_cd if _last_phase_cd > 0 else PHASE_CD
        return 1.0 - (phase_cd / cd_max)

## Returns true if in COAST state.
func is_coasting() -> bool:
        return state == State.COAST

## Main update — called every tick by the owning phase.
func update(input_dir: Vector2, delta: float) -> void:
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
        # Momentum update (after movement, so speed_pct is accurate)
        _update_momentum(delta)
        _prev_input_dir = input_dir
        # Shared: footstep + trail
        var speed_pct: float = vel.length() / get_speed()
        _footstep_timer += delta
        if speed_pct > 0.25 and _footstep_timer > 0.30 / maxf(0.4, speed_pct):
                _footstep_timer = 0.0
                SFX.play("footstep", 0.85 + randf() * 0.25, -8.0, 0.04)
        Juice.trail_sample(pos)

# --- Momentum update (the core compoundable system) ---
func _update_momentum(delta: float) -> void:
        var speed_pct: float = vel.length() / get_speed()
        if speed_pct > MOMENTUM_FAST_THRESHOLD:
                # Building momentum (moving fast)
                momentum = clampf(momentum + MOMENTUM_BUILD_RATE * delta, 0.0, MOMENTUM_MAX)
        elif state == State.FLOAT and speed_pct < 0.3:
                # Decaying momentum (slow/stopped in FLOAT)
                momentum = clampf(momentum - MOMENTUM_DECAY_RATE * delta, 0.0, MOMENTUM_MAX)
        # PHASE: momentum frozen (locked at current value)
        # DIVE: momentum frozen (spent on entry, not during)
        # COAST: momentum slowly decays (riding, not building)
        if state == State.COAST:
                momentum = clampf(momentum - MOMENTUM_DECAY_RATE * 0.5 * delta, 0.0, MOMENTUM_MAX)

# --- FLOAT: normal walking ---
func _update_float(input_dir: Vector2, delta: float) -> void:
        state = State.FLOAT
        var speed_pct: float = vel.length() / get_speed()
        bob += delta * (3.0 + speed_pct * 6.0)
        squash = lerp(squash, 1.0, 1.0 - exp(-delta * 12.0))  # was 8 — faster recovery
        var target_speed: float = get_speed() * _pulse_mult
        _apply_movement(input_dir, target_speed, ACCEL, ACCEL * DECEL_MULT, delta)

# --- PHASE: incorporeal dash (holds current velocity when no input) ---
func _update_phase(input_dir: Vector2, delta: float) -> void:
        var speed_pct: float = vel.length() / get_speed()
        bob += delta * (6.0 + speed_pct * 8.0)
        squash = lerp(squash, 1.0, 1.0 - exp(-delta * 12.0))
        # Phase speed includes momentum bonus
        var target_speed: float = get_speed() * PHASE_SPEED_MULT * (1.0 + (momentum / MOMENTUM_MAX) * MOMENTUM_PHASE_BONUS)
        if input_dir != Vector2.ZERO:
                input_dir = input_dir.normalized()
                facing = input_dir
                _last_input_dir = input_dir
                # Direction reflect on reversals
                if vel.length() > 10.0 and vel.normalized().dot(input_dir) < 0.0:
                        vel = input_dir * vel.length() * 0.85
                vel = vel.move_toward(input_dir * target_speed, ACCEL * delta)
        else:
                # FIX: hold current velocity when no input (was: push toward facing)
                # Phase is a dash — you keep going at whatever speed/direction you had.
                # This feels like "committed dash" not "stuck flying in last direction."
                pass  # vel stays as-is
        pos += vel * delta

# --- DIVE: momentum burst on phase cancel ---
func _update_dive(input_dir: Vector2, delta: float) -> void:
        _dive_timer -= delta
        _dive_mult = lerp(_dive_mult, 1.0, 1.0 - exp(-delta * DIVE_DECAY))
        var speed_pct: float = vel.length() / get_speed()
        bob += delta * (8.0 + speed_pct * 6.0)
        squash = lerp(squash, 1.0, 1.0 - exp(-delta * 15.0))  # was 10 — faster
        var target_speed: float = get_speed() * _dive_mult
        if input_dir != Vector2.ZERO:
                input_dir = input_dir.normalized()
                facing = input_dir
                _last_input_dir = input_dir
                if vel.length() > 10.0 and vel.normalized().dot(input_dir) < 0.0:
                        vel = input_dir * vel.length() * 0.80
                vel = vel.move_toward(input_dir * target_speed, ACCEL * 1.5 * delta)
        else:
                # FIX: hold current velocity (was: push toward facing)
                pass
        pos += vel * delta
        if _dive_timer <= 0 or _dive_mult < 1.1:
                _enter_coast()

# --- COAST: carrying momentum ---
func _update_coast(input_dir: Vector2, delta: float) -> void:
        _coast_timer -= delta
        # Track steering input (>45° off current vel for >0.25s cancels coast)
        if input_dir != Vector2.ZERO:
                var vel_dir: Vector2 = vel.normalized() if vel.length() > 1.0 else facing
                if input_dir.normalized().dot(vel_dir) < 0.7:
                        _coast_input_hold += delta
                else:
                        _coast_input_hold = 0.0
        else:
                _coast_input_hold = 0.0
        var speed_pct: float = vel.length() / get_speed()
        bob += delta * (4.0 + speed_pct * 5.0)
        squash = lerp(squash, 1.0, 1.0 - exp(-delta * 8.0))
        var target_speed: float = get_speed() * _pulse_mult
        if input_dir != Vector2.ZERO:
                input_dir = input_dir.normalized()
                facing = input_dir
                _last_input_dir = input_dir
                if vel.length() > 10.0 and vel.normalized().dot(input_dir) < 0.0:
                        vel = input_dir * vel.length() * 0.70
                vel = vel.move_toward(input_dir * target_speed, ACCEL * 0.8 * delta)
        else:
                vel = vel.move_toward(Vector2.ZERO, ACCEL * COAST_DECEL_MULT * delta)
        pos += vel * delta
        if _coast_timer <= 0 or vel.length() < COAST_MIN_SPEED or _coast_input_hold > 0.25:
                state = State.FLOAT

# --- Shared movement application ---
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

# --- State transitions ---

## Natural phase expiry — clean return to FLOAT (v0.36 fix).
## Previously, letting phase timer run out forced _enter_dive(0.2), which
## locked the player into ~1s of DIVE+COAST with reduced control after
## using their hazard tool. That felt bad: the player didn't choose to dive,
## they were just caught off-guard by phase ending.
##
## Now: natural expiry just releases the ghost back to normal walking.
## The skill expression is choosing WHEN to cancel phase:
##   - Tap SPACE during phase = intentional DIVE (full boost from remaining energy)
##   - Let phase expire        = clean FLOAT exit (no boost, no control loss)
##
## No forced burst, no momentum spend, no chain degradation. Trail returns
## to normal density. Soft phase_out SFX gives audio cue without the dive's
## heavier hit.
func _end_phase_natural() -> void:
        state = State.FLOAT
        Juice.trail_phasing = false
        SFX.play("phase_out", 0.8, -6.0)  # softer than dive's phase_out (1.0, -3.0)

## Enter DIVE state from phase cancel. Boost scales with remaining phase
## energy AND current momentum. Chain degradation reduces boost 10% per step.
func _enter_dive(energy_pct: float) -> void:
        state = State.DIVE
        # Chain degradation: each consecutive phase reduces dive boost
        var chain_mult: float = maxf(DIVE_CHAIN_MIN, 1.0 - chain_count * DIVE_CHAIN_DEGRADE)
        # Base dive mult from remaining phase energy
        var base_dive: float = lerpf(DIVE_MIN_MULT, DIVE_MAX_MULT, energy_pct)
        # Momentum adds to dive mult (compoundable!)
        var momentum_bonus: float = (momentum / MOMENTUM_MAX) * MOMENTUM_DIVE_BONUS
        _dive_mult = (base_dive + momentum_bonus) * chain_mult
        _dive_timer = DIVE_DURATION
        # Spend momentum on dive
        momentum = clampf(momentum - MOMENTUM_DIVE_COST, 0.0, MOMENTUM_MAX)
        # Burst velocity in current direction
        var burst_dir: Vector2 = vel.normalized() if vel.length() > 1.0 else (_last_input_dir if _last_input_dir != Vector2.ZERO else facing)
        vel = burst_dir * get_speed() * _dive_mult
        Juice.trail_phasing = false
        SFX.play("phase_out", 1.0, -3.0)
        Juice.spawn_particles(pos, 6, Palette.GLOW_BLUE, 30.0, 0.4)
        squash = 0.7

## Enter COAST state from dive.
func _enter_coast() -> void:
        state = State.COAST
        _coast_timer = COAST_BASE_DURATION
        _dive_mult = 1.0

## Try to activate or cancel the phase verb.
func try_activate_phase() -> bool:
        if state == State.PHASE:
                # Manual cancel — convert remaining phase energy into a DIVE
                var remaining_pct: float = phase_active / PHASE_DURATION
                phase_bank = minf(PHASE_BANK_MAX, phase_bank + phase_active)
                phase_active = 0.0
                _enter_dive(remaining_pct)
                return true
        if state == State.COAST:
                # Chain: phase from coast (halved cd)
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
        # Increment chain count (degradation tracker)
        chain_count += 1
        # Cooldown: full from FLOAT, halved from COAST, reduced by bank
        var base_cd: float = PHASE_CD
        if from_coast:
                base_cd *= 0.5
        var final_cd: float = maxf(0.0, base_cd - phase_bank)
        _last_phase_cd = final_cd  # store for accurate cooldown_pct
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
        state = State.FLOAT
        momentum = 0.0
        chain_count = 0
        _chain_reset_timer = 0.0
        phase_active = 0.0
        phase_cd = 0.0
        phase_bank = 0.0
        _last_phase_cd = 0.0
        _footstep_timer = 0.0
        _last_input_dir = Vector2.ZERO
        _prev_input_dir = Vector2.ZERO
        _pulse_mult = 1.0
        _pulse_flash = 0.0
        _pulse_was_pressed = false
        _dive_mult = 1.0
        _dive_timer = 0.0
        _coast_timer = 0.0
        _coast_input_hold = 0.0

## Draws the ghost sprite with trail, phase visual, momentum ring, chain indicator.
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
        elif mv.state == State.DIVE:
                ghost_mod = Color(0.8, 0.9, 1.0, 0.8)
        elif mv.state == State.COAST:
                ghost_mod = Color(0.7, 0.8, 1.0, 0.85)
        canvas.draw_texture_rect(ghost_tex, Rect2(gx - sw / 2, gy - sh / 2 + bob_val, sw, sh), false, ghost_mod)
        # Momentum ring — fills clockwise, color shifts blue→gold as momentum grows
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
        # Chain count indicator — small dots above ghost (1 dot per chain step, max 5)
        if mv.chain_count > 0:
                var dots: int = minf(mv.chain_count, 5)
                for i in dots:
                        var dot_x: float = gx - (dots - 1) * 2 + i * 4
                        var dot_color: Color = Color(1.0, 0.7, 0.3, 0.8) if i < 3 else Color(1.0, 0.4, 0.3, 0.8)
                        canvas.draw_circle(Vector2(dot_x, gy - 12 + bob_val), 1, dot_color)
        # Underground border ring (salvage only)
        if is_underground and mv.state == State.PHASE:
                canvas.draw_arc(Vector2(gx, gy + bob_val), 10, 0, TAU, 16, Color(0.1, 0.15, 0.3, 0.5), 2)
        # Cooldown ring (uses accurate _last_phase_cd)
        if mv.phase_cd > 0 and mv.state != State.PHASE:
                var cd_pct: float = mv.cooldown_pct()
                canvas.draw_arc(Vector2(gx, gy), 12.0, -PI / 2, -PI / 2 + TAU * cd_pct, 16, Palette.TEXT_DIM, 1.5)
