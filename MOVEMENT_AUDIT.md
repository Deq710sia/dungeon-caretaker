# Movement System Audit — game-nightly (2026-07-12)

A thorough audit of the entire movement system looking for feel problems, conflicting values, and friction points. Done by reading `ghost_movement.gd` end-to-end + how each phase consumes it.

Each finding has: **Problem**, **Numbers**, **Why it feels bad**, **Suggested fix**, **Risk**.

---

## Finding 1: Reversal penalty is too harsh (85%保留 on reversals)

**Location:** `_apply_movement()` line 328-329, `_update_phase()` line 312-313

**Numbers:**
```gdscript
if vel.length() > 10.0 and vel.normalized().dot(input_dir) < 0.0:
    vel = input_dir * vel.length() * 0.85   # 85% speed kept on reversal
```

**Problem:** When the player reverses direction (e.g. was moving right, now presses left), velocity is reflected at 85% of current speed. That sounds gentle, but combined with the `move_toward(input_dir * target_speed, ACCEL * delta)` on the next line, the effective penalty is much worse — the reflected velocity is now pointing the right way but the accel has to fight the friction curve to get back to target speed.

**Why it feels bad:** The player taps the opposite direction to correct course, and instead of a crisp pivot they get a slow drift-pivot. This is the #1 "slippery" complaint in momentum games. PF's lesson: reversals should COST something but not feel like hitting a wall.

**Suggested fix:** Lower the multiplier to 0.6 (keep 60% on reversal) AND skip the friction-against-itself problem by directly setting target_speed when reversing:
```gdscript
if vel.length() > 10.0 and vel.normalized().dot(input_dir) < 0.0:
    vel = input_dir * vel.length() * 0.6   # sharper pivot, less drift
```

**Risk:** LOW — only affects reversal moments, not steady-state movement.

---

## Finding 2: Momentum dead zone between 0.3 and 0.8 speed_pct

**Location:** `_update_momentum()` line 284-285

**Numbers:**
```gdscript
const MOMENTUM_CURVE_FLOOR: float = 0.3   # speed_pct below this -> momentum target 0
const MOMENTUM_CURVE_CEIL: float = 0.8    # speed_pct above this -> momentum target MAX
```

**Problem:** Between 30% and 80% of max speed, momentum target is a linear interpolation. Below 30%, momentum target is 0 (decays). Above 80%, target is MAX (builds). This means:
- Walking at 50% speed → momentum slowly drifts toward 50% of MAX
- Walking at 25% speed → momentum decays to 0
- Walking at 85% speed → momentum builds to MAX

**Why it feels bad:** The player has to commit to near-top-speed just to build momentum. Any hesitation (slowing to 25% to navigate a corner) kills momentum entirely. This is the "momentum rewards staying fast, but the game's tasks reward stopping precisely" tension from MEMORY_CONTEXT. The dead zone is too wide.

**Suggested fix:** Narrow the dead zone. Lower the floor to 0.15, raise the ceil to 0.6:
```gdscript
const MOMENTUM_CURVE_FLOOR: float = 0.15  # was 0.3 — momentum builds at lower speeds
const MOMENTUM_CURVE_CEIL: float = 0.6    # was 0.8 — full momentum at 60% speed, not 80%
```

**Risk:** MEDIUM — makes momentum easier to build, which could make the system feel less rewarding to master. Compensate by lowering MOMENTUM_RISE rate (next finding).

---

## Finding 3: Momentum rises too fast (MOMENTUM_RISE = 1.5)

**Location:** `_update_momentum()` line 287

**Numbers:**
```gdscript
const MOMENTUM_RISE: float = 1.5          # chases UP toward target quickly
const MOMENTUM_FALL: float = 0.6          # ...but lingers on the way down ("memory")
```

**Problem:** Rise rate 1.5 means momentum reaches ~95% of target in ~2 seconds. Fall rate 0.6 means it takes ~5 seconds to decay to 5%. The asymmetry is intentional (PF "memory" lesson), but the rise is so fast that there's no skill in building momentum — you just hold a direction for 2s.

**Why it feels bad:** Momentum feels automatic, not earned. The player doesn't feel like they're "building speed" — it just happens. PF's momentum was meaningful BECAUSE it took effort to build.

**Suggested fix:** Lower rise rate to 0.9 (slower build = more skill), keep fall at 0.6:
```gdscript
const MOMENTUM_RISE: float = 0.9          # was 1.5 — slower build = more skill
const MOMENTUM_FALL: float = 0.6          # unchanged
```

**Risk:** MEDIUM — slower build could feel sluggish if not paired with the dead-zone fix above. The two should be tuned together.

---

## Finding 4: Pulse cost equal to pulse gain (net 0.1, not 0.1 — actually net +0.1 but feels bad)

**Location:** `_fire_pulse()` line 128

**Numbers:**
```gdscript
const MOMENTUM_PULSE_GAIN: float = 0.4    # added by pulse
const MOMENTUM_PULSE_COST: float = 0.3    # required to fire pulse
# net: +0.1 momentum per pulse
# BUT: pulse also ADDS velocity: vel += boost_dir * (BASE_SPEED * 0.8) = +44 px/s
```

**Problem:** Pulse costs 0.3 momentum and adds 0.4 — net +0.1. That's a tiny gain. The velocity boost is +44px/s (BASE_SPEED * 0.8). At base speed 55px/s, that's an 80% instant speed boost. BUT — the velocity boost bleeds off through friction at FRICTION_LOW (0.25) when coasting, which means it decays to half in ~2.7s. So the "feelable" part of pulse lasts ~1s.

**Why it feels bad:** The pulse feels good for ~1 second, then the speed bleeds off and you're back where you started. The net momentum gain (+0.1) is too small to compound into a meaningful speed bonus. Players learn that pulse is a momentary burst, not a chain-builder.

**Suggested fix:** Increase net momentum gain to +0.2 (lower cost to 0.2, keep gain at 0.4):
```gdscript
const MOMENTUM_PULSE_GAIN: float = 0.4    # unchanged
const MOMENTUM_PULSE_COST: float = 0.2    # was 0.3 — net +0.2 per pulse
```
This was already suggested in TOOLS_ITERATION_LOG entry 002 but never applied to game-nightly (only to the reverted main v0.38).

**Risk:** LOW — pulse becomes more rewarding, which is the intended direction.

---

## Finding 5: Phase cooldown too long (4.0s base)

**Location:** `_start_phase()` line 295

**Numbers:**
```gdscript
const PHASE_CD: float = 4.0               # base cooldown
# discounted_cd (from coasting): 2.0s
# phase_bank reduces further: max(0, base_cd - phase_bank)
```

**Problem:** After a phase, the player waits 4 seconds before they can phase again. In a 30-second salvage run, that's only 7-8 phases max. The phase verb is the ghost's identity — 4s cooldown makes it feel rare and precious, but also makes the chain (phase → cancel → impulse → coast → pulse → phase) impossible to sustain.

**Why it feels bad:** The optimal chain requires phasing every ~2s (after coast + pulse). At 4s cooldown, the chain breaks. Players fall back to single phases with no follow-up, which feels less expressive.

**Suggested fix:** Lower base cooldown to 3.0s, keep coasting discount at 0.5x (so 1.5s from coast):
```gdscript
const PHASE_CD: float = 3.0               # was 4.0 — tighter chain loop
```

**Risk:** MEDIUM — phase becomes more spammy. May need to compensate by raising PHASE_COST to 2 shards, or adding a soft cap via momentum cost.

---

## Finding 6: No input buffering on phase/pulse

**Location:** `update_pulse()` line 114, `try_activate_phase()` called from phases

**Problem:** Pulse uses manual edge detection (`_pulse_was_pressed`). Phase uses `Input.is_action_just_pressed("phase")` in each phase script. Neither has input buffering — if the player presses SHIFT 50ms before they have enough momentum, the pulse is denied and the input is lost. They have to press again.

**Why it feels bad:** In fast play, players press buttons slightly early. Without buffering, those inputs vanish. The game feels unresponsive — "I pressed pulse, why didn't it fire?"

**Suggested fix:** Add a 100ms input buffer for both verbs:
```gdscript
var _pulse_buffer: float = 0.0   # >0 means pulse was pressed within last 100ms
var _phase_buffer: float = 0.0   # >0 means phase was pressed within last 100ms

# In update_pulse():
if pulse_just_pressed:
    _pulse_buffer = 0.1
_pulse_buffer = max(0, _pulse_buffer - delta)
# Try to fire if buffer is active AND momentum is sufficient
if _pulse_buffer > 0 and momentum >= MOMENTUM_PULSE_COST:
    _fire_pulse()
    _pulse_buffer = 0.0
```

**Risk:** LOW — standard fighting-game technique. Players who mash will get slightly more pulses, but that's fine.

---

## Finding 7: Camera smoothing fights against phase speed

**Location:** salvage.gd line 364-371

**Numbers:**
```gdscript
var cam_smooth: float = lerp(8.0, 13.0, move.momentum_pct())
# At momentum 0: cam_smooth=8 (slow follow)
# At momentum MAX: cam_smooth=13 (faster follow)
```

**Problem:** During phase, the ghost moves at 2x speed (PHASE_SPEED_MULT=2.0) plus momentum bonus. At max momentum, that's ~165px/s. The camera follows at smoothing rate 13, which means the camera lerp factor is `1 - exp(-delta * 13)` ≈ 0.21 per frame at 60fps. The camera catches up to half the distance in ~3 frames (50ms), which sounds fast but creates visible lag during phase.

**Why it feels bad:** During phase, the ghost outruns the camera. The ghost is near the screen edge for the duration of the phase, which feels disorienting. The "speed-based micro-shake" mentioned in the comment doesn't actually exist in the code (no shake implementation found).

**Suggested fix:** Snap camera during phase (no smoothing) or use a much higher smoothing rate:
```gdscript
var cam_smooth: float = lerp(8.0, 13.0, move.momentum_pct())
if move.is_phasing():
    cam_smooth = 25.0  # snap during phase — ghost shouldn't outrun camera
```

**Risk:** LOW — only affects phase moments.

---

## Finding 8: Weapon weight penalty applies even when not carrying

**Location:** `get_speed()` line 168-170

**Numbers:**
```gdscript
var weight_penalty: float = carry_count * WEAPON_WEIGHT_MULT  # 0.12 per weapon
weight_penalty *= lerp(1.0, COAST_WEIGHT_REDUCTION, momentum / MOMENTUM_MAX)
# carry_count=0: weight_penalty=0 (no penalty)
# carry_count=1: weight_penalty=0.12 * lerp(1.0, 0.5, momentum/MAX)
#   At momentum 0: 0.12 (12% speed reduction)
#   At momentum MAX: 0.06 (6% speed reduction)
```

**Problem:** This is actually fine when carry_count=0. But the `lerp(1.0, 0.5, momentum/MAX)` means the weight penalty halves at max momentum. Combined with the +50% speed bonus from momentum, the net effect of carrying a weapon at max momentum is: `(1 - 0.06) * (1 + 0.5) = 1.41x speed` vs `1.5x speed unburdened`. That's a 6% penalty at max momentum, 12% at zero momentum.

**Why it feels bad:** This isn't actually a feel problem — it's a design clarity problem. The player has no way to see WHY they're slow. There's no HUD indicator for weapon weight. They just feel "sluggish" and don't know why.

**Suggested fix:** Add a small "carrying" indicator in the HUD when carry_count > 0, showing the weight penalty. Or: reduce the penalty to 0.08 per weapon (was 0.12) so it's less noticeable.

**Risk:** LOW.

---

## Finding 9: Footstep sound threshold too high (0.25 speed_pct)

**Location:** `update()` line 273

**Numbers:**
```gdscript
if speed_pct > 0.25 and _footstep_timer > 0.30 / maxf(0.4, speed_pct):
    _footstep_timer = 0.0
    SFX.play("footstep", ...)
# At speed_pct 0.25: footsteps every 0.30/0.4 = 0.75s
# At speed_pct 1.0: footsteps every 0.30s
# At speed_pct 1.5 (phase): footsteps every 0.20s
```

**Problem:** Footsteps only play above 25% speed. Below that, the ghost is silent. This means slow maneuvering (positioning for a QTE, lining up with a corpse) has no audio feedback. The ghost feels "dead" at low speeds.

**Why it feels bad:** Audio is a huge part of "feel." Silent slow movement reads as "the game is paused" or "my input isn't registering."

**Suggested fix:** Lower threshold to 0.05 (almost always play footsteps when moving), and add a "hover" hum for stationary ghost:
```gdscript
if speed_pct > 0.05 and _footstep_timer > 0.30 / maxf(0.4, speed_pct):
    # ... play footstep
```

**Risk:** LOW — more audio feedback is almost always better for feel.

---

## Finding 10: Phase doesn't preserve momentum on natural expiry

**Location:** `_end_phase_natural()` line 367-376

**Numbers:**
```gdscript
func _end_phase_natural() -> void:
    state = State.NORMAL
    Juice.trail_phasing = false
    SFX.play("phase_out", 0.8, -6.0)
    # ... no momentum change
```

**Problem:** This is actually correct per the v0.36 design — natural expiry doesn't cost momentum. But during phase, `_update_momentum()` returns early (line 282-283: `if state == State.PHASE: return`). So momentum is FROZEN during phase. When phase ends naturally, momentum is whatever it was when phase started — which could be 0 if the player phased from a standstill.

**Why it feels bad:** The player phases from a standstill, moves fast during phase (2x speed), then phase ends and... momentum is still 0. The ghost immediately decelerates to base speed. The "fast" feeling of phase doesn't carry over.

**Suggested fix:** On natural expiry, set momentum to at least the coasting threshold (0.4 * MAX = 0.8) if it was lower:
```gdscript
func _end_phase_natural() -> void:
    state = State.NORMAL
    # Preserve some momentum from the phase speed — phase should feel like
    # it "launched" you, not that you teleported back to walking.
    var min_momentum: float = MOMENTUM_MAX * COASTING_THRESHOLD  # 0.8
    if momentum < min_momentum:
        momentum = min_momentum
    Juice.trail_phasing = false
    # ...
```

**Risk:** MEDIUM — this is a design call. The v0.36 bifurcation was specifically to make natural expiry "clean" (no boost). Adding momentum preservation blurs that line. Alternative: only preserve momentum if the player was moving during phase (vel.length > some threshold).

---

## Finding 11: gate.gd uses hand-copied movement (inconsistent feel)

**Location:** gate.gd line 85-91

**Numbers:**
```gdscript
# gate.gd: BASE_SPEED=55, ACCEL=300, DECEL_MULT=0.5 (hardcoded)
ghost_vel = ghost_vel.move_toward(input_dir * 55.0, 300.0 * delta)
# vs GhostMovement: BASE_SPEED=55, ACCEL=300, friction=lerp(0.5, 0.25, momentum/MAX)
```

**Problem:** gate.gd doesn't use GhostMovement at all — it has its own movement code with hardcoded constants. No momentum, no friction curve, no phase, no pulse. The gate phase feels completely different from every other phase.

**Why it feels bad:** The player enters the gate, and suddenly the ghost handles differently. No momentum build-up, no coasting, no phase verb. It's jarring.

**Suggested fix:** Refactor gate.gd to use GhostMovement (per AGENT.md gotcha #17, this is a known issue). This is a bigger change — deferred to a separate task.

**Risk:** MEDIUM — gate.gd is simple enough that the refactor is straightforward, but it's a separate task.

---

## Finding 12: No coyote time on phase cancel

**Location:** `try_activate_phase()` line 380-386

**Problem:** Phase cancel (pressing SPACE during phase) fires the impulse immediately. There's no grace period. If the player presses SPACE just AFTER phase expires naturally (within 100ms), the input is interpreted as "start a new phase" — which costs a shard and triggers cooldown. The player wanted to cancel, not start fresh.

**Why it feels bad:** The player's intent was "end phase with a boost." The game interprets it as "start a new phase." That's a 1-shard mistake that feels unfair.

**Suggested fix:** Add a 100ms "cancel grace" — if SPACE is pressed within 100ms after phase ended, fire the impulse anyway (no new phase activation):
```gdscript
var _phase_just_ended: float = 0.0  # >0 means phase ended within last 100ms

# In _end_phase_natural():
_phase_just_ended = 0.1

# In try_activate_phase():
if _phase_just_ended > 0:
    # Grace period — treat as cancel, not new activation
    _end_phase(0.0)  # minimal impulse
    _phase_just_ended = 0.0
    return true
```

**Risk:** MEDIUM — blurs the v0.36 bifurcation. May not be wanted.

---

## Finding 13: QTE input overrides movement input (dead zones during QTE)

**Location:** salvage.gd line 349

**Numbers:**
```gdscript
if active_qte.is_empty():
    if Input.is_action_pressed("move_left"):  input_dir.x -= 1
    # ... movement input only registered when no QTE active
```

**Problem:** When a QTE is active, movement input is ignored entirely. The ghost is frozen. This is intentional (player should focus on QTE), but the transition is instant — no fade, no easing. The ghost snaps from "moving" to "frozen."

**Why it feels bad:** The snap is jarring. A short deceleration (0.1s) before the freeze would feel much better.

**Suggested fix:** When a QTE starts, decelerate the ghost over 0.1s instead of snapping:
```gdscript
# In _start_qte():
# Don't zero velocity — let it decay through normal friction
# (just stop accepting input, which is already the case)
```

**Risk:** LOW — the ghost already decelerates when input_dir is zero. The fix is just... don't manually zero velocity on QTE start. Check if that's happening.

---

## Summary: Priority-ordered fix list

| # | Finding | Risk | Feel impact | Suggested action |
|---|---------|------|-------------|------------------|
| 6 | No input buffering on phase/pulse | LOW | HIGH | Add 100ms buffer — standard technique, big feel win |
| 1 | Reversal penalty too harsh (0.85) | LOW | HIGH | Lower to 0.6 — crisper pivots |
| 4 | Pulse net gain too small (+0.1) | LOW | HIGH | Lower cost 0.3→0.2 (net +0.2) |
| 7 | Camera lags during phase | LOW | HIGH | Snap camera during phase (smoothing 25) |
| 9 | Footstep threshold too high (0.25) | LOW | MEDIUM | Lower to 0.05 — always audio feedback |
| 2 | Momentum dead zone too wide (0.3-0.8) | MEDIUM | HIGH | Narrow to 0.15-0.6 — momentum builds at lower speeds |
| 3 | Momentum rises too fast (1.5) | MEDIUM | MEDIUM | Lower to 0.9 — slower build = more skill |
| 5 | Phase cooldown too long (4.0s) | MEDIUM | HIGH | Lower to 3.0s — tighter chain loop |
| 10 | Phase doesn't preserve momentum on natural expiry | MEDIUM | MEDIUM | Set min momentum to coasting threshold |
| 8 | Weapon weight penalty unclear | LOW | LOW | Add HUD indicator OR reduce penalty |
| 12 | No coyote time on phase cancel | MEDIUM | MEDIUM | 100ms cancel grace |
| 13 | QTE input freeze is instant | LOW | LOW | Let velocity decay naturally |
| 11 | gate.gd hand-copied movement | MEDIUM | MEDIUM | Refactor to use GhostMovement (separate task) |

## Recommended iteration order

**Batch 1 (low risk, high impact):** Findings 6, 1, 4, 7, 9
- Input buffering, reversal penalty, pulse cost, camera snap, footstep threshold
- All LOW risk, all HIGH feel impact
- Playtest after this batch — should be measurably better

**Batch 2 (medium risk, high impact):** Findings 2, 3, 5
- Momentum dead zone, rise rate, phase cooldown
- These interact — tune together, not separately
- Playtest after this batch — check if chain length increases

**Batch 3 (design calls):** Findings 10, 12
- Phase momentum preservation, coyote time on cancel
- These blur the v0.36 bifurcation — user signoff needed
- Playtest after this batch — check if it still feels like "intentional cancel vs clean expiry"

**Batch 4 (separate tasks):** Findings 8, 11, 13
- HUD indicator, gate.gd refactor, QTE freeze
- Lower priority, do later
