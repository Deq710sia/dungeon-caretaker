# Movement Redesign Proposal — v0.40 (2026-07-12)

A synthesis of: user's design direction (2-charge pulse that refreshes after phase cancel + dive), v30's "polished" feel analysis, and research into how top-down pixel games (HLD, Hades, Tunic, Mina, Celeste, CrossCode, Death's Door, Nier) achieve good movement feel.

This is a DESIGN DOC, not code. Read this before implementing.

---

## 1. Why v30 Felt Better (Diagnosis)

The user reported v30 feels "most polished" and "simplest." Reading v30's ghost_movement.gd vs game-nightly's, the key differences:

### v30's design (what felt good)
- **4 states but only 2 are "verbs":** FLOAT (walk) + PHASE (dash). DIVE and COAST are *consequences* of the phase cancel, not separate buttons.
- **DIVE is a one-shot burst with fixed decay** (DIVE_DECAY=3.0, DIVE_DURATION=0.4s). No momentum cost, no chain counter. Just "cancel phase → get burst → ride it out."
- **COAST is the landing pad** — low decel (0.08), short duration (0.6s base, extendable by pulse-timing). The chain naturally ends back in FLOAT.
- **Pulse is INPUT-TIMING, not a button.** You pulse by pressing a direction within 0.35s of releasing it. In FLOAT it gives +15% speed; in COAST it extends duration. It's a rhythm reward, not a resource spend.
- **No momentum resource.** Speed IS the momentum. There's no separate 0-2.0 meter to manage.
- **Phase cancel is the only skill move.** Cancel early = big burst (DIVE_MAX_MULT=2.5). Cancel late = small burst (DIVE_MIN_MULT=1.2). One gauge, one decision.

### Why game-nightly feels worse (despite being "cleaner" code)
- **Momentum meter adds cognitive load.** The player watches a number (0-2.0) instead of feeling speed. It's a UI element between the player and the verb.
- **Pulse as a button (SHIFT) feels disconnected.** In v30, pulse emerges from your movement rhythm. In game-nightly, it's a separate input you manage alongside phase. Two resources (momentum + shards) + two buttons (SHIFT + SPACE) = 4 things to track.
- **DIVE as a one-shot impulse (not a state) loses the "ride it out" feel.** v30's DIVE state lasts 0.4s with visible decay — you feel the burst fading. game-nightly's impulse just sets velocity and lets normal friction handle it — the burst vanishes into the friction curve.
- **COAST as a momentum tier (not a state) loses the visual identity.** v30's COAST has a distinct blue tint and low-friction feel. game-nightly's is_coasting is just a flag — visually identical to NORMAL.
- **Friction curve (continuous) is harder to read than discrete states.** The player can't tell when they've crossed the coasting threshold. v30's state transitions are explicit.

### The core insight
v30 works because it has **one resource (speed), one verb (phase), one skill move (cancel timing)**. game-nightly added a second resource (momentum meter) and a second verb (pulse button) — that's twice the cognitive load for less feel payoff.

---

## 2. The User's Proposed Design (Restated)

The user wants:
1. **Remove pulse as a standalone button.** It's a bad idea in its current form.
2. **Replace with 2 charges that refresh only after phase-cancel + dive.** The chain becomes: `phase → cancel → dive → pulse → pulse → phase`.
3. **Visualize as 2 tactile blue circle-segments around the ghost** that disappear with a pixel poof when used, refresh when the dive completes.
4. **Remove the momentum circle from the HUD.** Replace with a small "speed + momentum" number near the bottom, togglable in pause menu.
5. **Reduce phase's "continues your movement" behavior.** Phase should feel more like a committed dash, less like a speed carry.
6. **Keep the internal momentum multiplier** (or slightly nerf it) — it still drives state transitions, just isn't shown.
7. **Per-action drift tuning.** Each movement action (phase exit, dive exit, pulse exit, etc.) should have individually-tuned drift values based on its purpose, not a global friction curve.
8. **Fix WASD sluggishness.** Needs a way to cancel movement without reversing direction. Everything feels too slippery/delayed.

---

## 3. Research-Backed Design Choices

### 3.1 The 2-charge pulse pattern (user's core idea)

**Closest precedents:**
- **HLD chain dash:** each chained dash refreshes the ability to dash again, momentum grows. User's design = "chain dash where the link is a cancel+dive instead of a re-press."
- **CrossCode Infinite Dash:** shield-hold between dashes resets the dash counter. User's "phase-cancel + dive" = required intermediary action to refill charges.
- **Fighting game rekkas:** 3-stage specials where each stage must be input during the previous stage's window. User's chain (phase→cancel→dive→pulse→pulse→phase) is a rekka with a resource gate.

**Pitfalls the research flags:**
1. **HLD's "first-4-dashes problem":** different timing for first inputs vs later ones is universally hated. Make both pulses identical, or make the *first* more forgiving.
2. **Tunic's "no-cancel" trap:** if pulse has 0 charges and the player presses it, the input shouldn't vanish. Convert to a phase input (Hades simultaneous-press friendliness).
3. **Hades II over-buffer:** if the two pulses share one long buffer, the second pulse's buffer swallows the next phase input. Use 5-frame buffer per pulse (Celeste standard).
4. **HLD's too-strict window:** community says 5-6 frame chain window is too tight. For 60fps, 8-10 frames (133-166ms) is the sweet spot.

**Concrete design:**
- 2 pulse charges, refresh only on phase→cancel→dive completion (dive state ends → charges refill to 2)
- Pulse input buffer: 5 frames per pulse (Celeste standard)
- Pulse-to-pulse chain window: 10 frames between the two pulses
- After 2nd pulse: 6-frame window where phase can be input as cancel (Celeste "Dash Attack" pattern) — this is the link back into the loop
- Pulse with 0 charges: convert to phase input (no wasted inputs)
- Pulse momentum: preserve across cancel into phase (CrossCode Momentum pattern), grow slightly per pulse (HLD chain slide), cap at 2 pulses worth

### 3.2 Cancel without reversing direction

**Four standard solutions from research:**
- **A. Dodge Offset (Bayonetta/Nier):** hold a button to preserve state through the cancel. The cancel doesn't inherit movement intent, it inherits combo state.
- **B. Neutral Dodge (Hades/Nier):** directionless input defaults to backward/neutral, preserving facing.
- **C. Cancel-into-forward (CrossCode):** the cancel target always fires in current facing/momentum direction, never input direction.
- **D. Momentum carry + friction brake (Tunic/HLD):** no explicit cancel; release input and physics bleeds speed over 10-15 frames. Higher friction in COAST than FLOAT.

**Recommended combo: C + D.**
- DIVE always fires in current momentum/facing direction (never input direction) — CrossCode pattern
- COAST has higher friction than FLOAT, so releasing input in COAST stops you in 8-12 frames, while FLOAT takes 18-24 — Tunic/HLD pattern
- This gives "cancel without reversing" for free, no new button needed

### 3.3 Fixing sluggish/slippery WASD

**Research-identified causes + fixes:**

| Cause | Fix |
|-------|-----|
| Symmetric accel/decel | Asymmetric: 4-frame accel, 12-frame decel |
| No input buffer on direction changes | 5-frame buffer (Celeste standard) |
| Velocity not normalized for diagonals | Always `input_dir.normalized()` |
| No snap-on-stop | If input==ZERO and vel < 20% max, zero velocity |
| Animation locking movement | Cap animation transitions at 0.05s |
| No velocity carry across state transitions | Carry velocity 10 frames (Celeste liftboost) |
| Input polling in _process, movement in _physics_process | Both in _physics_process, 60Hz fixed |

**Concrete starting numbers (60 FPS, 480x270):**
- FLOAT accel: reach max in 4 frames (accel = max_speed / 0.066s)
- FLOAT decel: reach zero in 12 frames
- COAST accel: inherited (no new accel)
- COAST decel: reach zero in 8 frames (snappier than FLOAT — Solution D)
- Input buffer: 5 frames for all verbs
- Snap-stop threshold: 20% of max speed
- State-transition velocity carry: 10 frames of preserved momentum

### 3.4 Phase's "continues movement" reduction

The user wants phase to feel more like a committed dash, less like a speed carry.

**Current (game-nightly):** Phase holds current velocity when no input. If you phase at high speed, you keep that speed through the whole phase.

**Proposed:** Phase SETS velocity to `facing * phase_speed` on entry, then holds that velocity. Your pre-phase speed doesn't carry — phase is a fixed-speed dash. This matches HLD/Hades where dash is a fixed burst, not a speed multiplier.

**Exception:** if you phase from COAST (high momentum), preserve 50% of pre-phase velocity. This rewards the chain without making phase a free speed carry.

### 3.5 Per-action drift tuning

The user wants each exit point to have individually-tuned drift. Here's the matrix:

| Action | Drift behavior | Why |
|--------|---------------|-----|
| FLOAT → stop (release input) | Hard decel, 12 frames to zero | Precision — player wants to stop |
| PHASE → DIVE (manual cancel) | Burst in momentum direction, 0.4s decay | Skill reward — early cancel = big burst |
| PHASE → FLOAT (natural expiry) | Clean stop, 6 frames to zero | v0.36 bifurcation — clean exit, no drift |
| DIVE → COAST | Inherit dive velocity, 8-frame decel | Ride the burst — momentum preservation |
| COAST → FLOAT (timer/speed expiry) | Gradual, 15-frame decel | Soft landing — don't punish chain end |
| PULSE (in COAST) | Small directional nudge, extends coast 0.2s | Chain continuation — rhythm reward |
| PULSE (with charges, post-dive) | Strong burst in momentum direction | The new 2-charge pulse — chain link |
| Wall collision (high momentum) | Bleed 50% on clamped axis | PF lesson — mistakes aren't catastrophic |
| Wall collision (low momentum) | Full zero on clamped axis | v0.23 fix — no momentum buildup against walls |

---

## 4. Proposed State Machine (v0.40)

```
FLOAT ──[SPACE]──> PHASE ──[SPACE (cancel)]──> DIVE ──[timer]──> COAST ──[timer]──> FLOAT
                         └──[timer expiry]──> FLOAT (clean, v0.36)
                                                              │
                                                              ├──[SHIFT w/ charges]──> PULSE_BURST ──> COAST
                                                              ├──[SHIFT w/ charges]──> PULSE_BURST ──> COAST
                                                              └──[SPACE]──> PHASE (chain restart, charges refill on dive)
```

**States:** FLOAT, PHASE, DIVE, COAST (same as v30 — back to 4 states)
**Pulse is NOT a state** — it's a one-shot burst event with 2 charges, fires from COAST only, refreshes when DIVE completes.

**Why 4 states (not game-nightly's 2):**
- v30's 4 states gave each phase of the chain a distinct visual + feel identity
- game-nightly's 2-state model collapsed DIVE/COAST into NORMAL, losing that identity
- The user's proposed 2-charge pulse needs a clear "post-dive" state (COAST) to fire from — otherwise the charges have no anchor

**Why pulse is NOT a state:**
- It's a one-shot burst, not a mode you're in
- 2 charges means it fires twice then waits for refill
- The visual (2 circle segments) is a charge indicator, not a state indicator

---

## 5. Constants (proposed, starting values)

```gdscript
# Base movement
const BASE_SPEED: float = 55.0
const ACCEL: float = 833.0          # reach max in 4 frames (55 / 0.066s)
const FLOAT_DECEL: float = 0.18     # 12-frame stop (833 * 0.18 = 150 decel)
const COAST_DECEL: float = 0.12     # 8-frame stop (snappier than FLOAT)

# Phase
const PHASE_DURATION: float = 1.2   # was 1.5 — shorter, more committed
const PHASE_CD: float = 3.0         # was 4.0 — tighter chain
const PHASE_COST: int = 1
const PHASE_SPEED: float = 110.0    # FIXED speed (2x base), no carry from pre-phase
const PHASE_COAST_CARRY: float = 0.5 # if phasing from COAST, preserve 50% of pre-phase vel

# Dive (one-shot burst, decays)
const DIVE_MIN_MULT: float = 1.2    # cancel at 0s remaining
const DIVE_MAX_MULT: float = 2.5    # cancel at full duration
const DIVE_DURATION: float = 0.4
const DIVE_DECAY: float = 3.0

# Coast (ride the dive burst)
const COAST_BASE_DURATION: float = 0.6
const COAST_MIN_SPEED: float = 35.0

# Pulse (NEW — 2 charges, refresh on dive completion)
const PULSE_MAX_CHARGES: int = 2
const PULSE_BOOST: float = 80.0     # +80px/s burst in momentum direction
const PULSE_COAST_EXTEND: float = 0.2  # extends coast by 0.2s
const PULSE_BUFFER_FRAMES: int = 5  # 5-frame input buffer per pulse
const PULSE_CHAIN_WINDOW: float = 0.166  # 10 frames between the two pulses
const PULSE_PHASE_CANCEL_WINDOW: float = 0.1  # 6-frame window after 2nd pulse to cancel into phase

# Snap-stop
const SNAP_STOP_THRESHOLD: float = 0.2  # below 20% max speed + no input = zero velocity

# Input buffer (all verbs)
const INPUT_BUFFER_FRAMES: int = 5  # 5-frame buffer (Celeste standard)

# Wall collision
const WALL_BLEED_COASTING: float = 0.5  # bleed 50% when coasting
const WALL_BLEED_NORMAL: float = 0.0    # full zero when not coasting
```

---

## 6. Visual Design (per user)

- **2 pulse charges:** 2 blue circle-segments around the ghost (like 2 arcs of a ring, 90° each, opposite sides). Disappear with a 6-pixel blue poof when used. Reappear (fade in) when DIVE completes.
- **Momentum ring:** REMOVED from around the ghost. Replace with a small "SPD: 55  MOM: 1.2" text at bottom-right of screen, togglable in pause menu (off by default).
- **State tints (back from v30):**
  - FLOAT: default
  - PHASE: translucent blue (current)
  - DIVE: bright white-blue flash (0.4s, fades)
  - COAST: faint blue tint (riding momentum)
- **Phase cooldown ring:** keep (current behavior)

---

## 7. Implementation Plan

**This is a big change.** Do it in this order, parse-checking + playtesting after each step:

### Step 1: Restore v30's 4-state structure
- Port v30's state machine (FLOAT/PHASE/DIVE/COAST) but keep game-nightly's v0.36 bifurcation (natural expiry → clean FLOAT, manual cancel → DIVE)
- Keep game-nightly's telemetry hooks + wall bleed + profile system
- Remove the momentum meter as a driver — speed IS the momentum again
- Pulse button (SHIFT) does nothing yet

### Step 2: Implement 2-charge pulse
- Add `pulse_charges: int = 0` (starts at 0, must dive to earn)
- On DIVE completion (→ COAST): set `pulse_charges = PULSE_MAX_CHARGES`
- SHIFT press in COAST: if charges > 0, fire pulse burst, decrement charges
- SHIFT press with 0 charges: convert to phase input (no wasted input)
- 5-frame input buffer per pulse

### Step 3: Fix WASD feel
- Asymmetric accel/decel (4-frame accel, 12-frame decel)
- Snap-stop at 20% max speed
- 5-frame input buffer on direction changes
- Diagonal normalization (already done, verify)

### Step 4: Reduce phase speed carry
- Phase SETS velocity to `facing * PHASE_SPEED` on entry (no pre-phase carry)
- Exception: phasing from COAST preserves 50% of pre-phase velocity

### Step 5: Per-action drift tuning
- Apply the drift matrix from section 3.5
- Each state exit has its own decel value, not a global friction curve

### Step 6: Visual updates
- 2 charge segments around ghost
- Remove momentum ring
- Add togglable SPD/MOM text at bottom-right
- Restore v30's state tints (DIVE flash, COAST tint)

### Step 7: Update constitution
- New 4-state constitution rules (back to FLOAT/PHASE/DIVE/COAST)
- Add pulse charge rules (pulse_per_dive, pulse_charge_efficiency)
- Remove momentum_avg rule (no more momentum meter) — replace with speed_avg

---

## 8. Risks + Open Questions

1. **Is 4 states back-tracking on game-nightly's 2-state cleanup?** Yes, partially. But the user's 2-charge pulse design needs a clear "post-dive" state to anchor to. The 2-state model's continuous coast doesn't give pulse a home. Recommendation: go back to 4 states, but keep game-nightly's cleaner code structure (no chain_count, no coast-bypasses-cooldown bug).

2. **Does removing the momentum meter lose depth?** Maybe. The meter was a visible resource to manage. But the user explicitly wants it gone from the HUD (replaced with a number you can toggle). The depth moves from "manage the meter" to "manage the chain timing" — which is v30's design and the user says it felt better.

3. **Will the 2-charge pulse feel too restrictive?** The HLD research says strict windows are hated. Mitigation: 5-frame buffer per pulse, 10-frame chain window, and the 0-charge fallback (converts to phase input). If it still feels restrictive, loosen the windows.

4. **Is phase as fixed-speed dash too punishing?** Currently phase carries your speed, so phasing at high speed = very fast phase. Fixed-speed phase = always same speed. Mitigation: the COAST→PHASE carry (50%) preserves some of the reward for chaining.

5. **Should this go on game-nightly or a new branch?** game-nightly. It's a big enough change that main would be wrong, and game-nightly is already the experimental branch. Per AGENT.md: never merge game-nightly to main without user confirmation.

---

## 9. What I Need From You Before Implementing

1. **Confirm the 4-state return.** v30 had 4 states (FLOAT/PHASE/DIVE/COAST). game-nightly collapsed to 2 (NORMAL/PHASE). The 2-charge pulse needs a "post-dive" state. Go back to 4?

2. **Confirm the pulse charge model.** 2 charges, refresh on dive completion, fire from COAST only. Or: fire from anywhere post-dive? Or: refresh on phase-START, not dive-end?

3. **Confirm the phase speed change.** Phase as fixed-speed dash (no pre-phase carry) vs current (carries your speed). The user said "greatly reduce" — does "fixed speed" go too far?

4. **Confirm the momentum meter removal.** The internal momentum multiplier stays (drives state transitions), but the visible ring goes away, replaced by a togglable number. Yes?

5. **Confirm per-action drift.** The matrix in section 3.5 has specific decel values per transition. Approve those, or adjust?

Once these are confirmed, I'll implement in the 7 steps above, parse-checking + playtesting after each.
