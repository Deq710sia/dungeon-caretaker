# Version Log — Dungeon Caretaker

A running log of all changes made to the game, with intentions. Updated after every version update.

---

## v0.18 — Music Timbre Softening (Real Filtering, No More Raw Squares/Saws/Noise) (2026-07-07)

### Problem: Individual Sounds Were Harsh Despite Good Composition
**Diagnosis:** The v0.17 composition was fine but every individual timbre was garish because:
1. **Cowbell** used raw **square waves** (840+540Hz) — squares are inherently piercing
2. **Bass** used raw **sawtooth** with fake lowpass (just `*0.7` amplitude) — buzzy
3. **Chords** used additive saw harmonics at full 1/n amplitude (h2=0.5, h3=0.33) — too bright
4. **Clap/hats** used raw **white noise** — harsh "tss" not soft "psh"
5. **No real filtering anywhere** — every oscillator ran raw through the mix

### Fix: Real DSP Filtering On Every Layer

**1. Bass: saw → one-pole lowpass @ 400Hz**
- Implemented real state-variable lowpass: `lp_state = lp_state + alpha * (input - lp_state)` where `alpha = 1 - exp(-2π·cutoff/SR)`
- Cutoff 400Hz removes saw buzz, keeps warm fundamental + 2nd harmonic
- Was: `saw * 0.7` (amplitude scaling, no filtering)

**2. Chords: gentler harmonics + dropping lowpass**
- Harmonics reduced: h2 0.5→0.25, h3 0.33→0.12 (less bright)
- Added one-pole lowpass that drops 3kHz→800Hz over the stab (bright at attack, warm in sustain — mimics a struck string's brightness decay)
- Noise attack amplitude reduced 0.2→0.08

**3. Cowbell: square → sine + bandpass**
- Replaced two square oscillators with two **sine** oscillators (warm, not buzzy)
- Added bandpass: highpass @ 600Hz + lowpass @ 4kHz
- Longer envelope (0.06s→0.08s decay), lower amplitude (0.06→0.045)

**4. Clap: raw noise → bandpass-filtered noise**
- Highpass @ 800Hz + lowpass @ 3kHz = softer "psh" not harsh "tss"
- Longer decay (0.025s→0.035s)

**5. Hats: raw noise → highpass-filtered noise**
- Highpass @ 7kHz (softer, less宽带)
- Longer decay (0.015s→0.02s), lower amplitude (0.05→0.035)

**6. Kick: lowpass the click**
- Click transient now runs through lowpass @ 2kHz (was raw noise — harsh)
- Click amplitude reduced 0.5→0.25

**7. Master: added high-shelf rolloff**
- One-pole lowpass @ 8kHz mixed back at 30% — tames any remaining harshness above 8kHz
- Gentler saturation: `tanh(x*0.65)` (was 0.7)

### Verification
Spectral comparison (peak dB per band):
| Band | v0.17 (harsh) | v0.18 (soft) | Reduction |
|------|---------------|--------------|-----------|
| bass (0-250Hz) | -8.2 dB | -8.3 dB | ~0 (preserved) |
| lowmid (250-2kHz) | -11.8 dB | -16.2 dB | -4 dB |
| highmid (2-6kHz) | -14.9 dB | -27.3 dB | **-12 dB** |
| high (6-12kHz) | -17.9 dB | -32.2 dB | **-14 dB** |
| air (12-20kHz) | -17.2 dB | -30.2 dB | **-13 dB** |

The harsh highmid/high/air bands are reduced 12-14dB while bass/lowmid (the warmth) are preserved. Overall: peak -8dB, RMS -19.3dB (healthy, similar to v0.17).

Preview at `/home/z/my-project/download/music_preview/main_theme_v5_soft.wav`.

---

## v0.17 — Movement Overhaul (Momentum System + Chain Degradation + Tap Pulse) + Speder2 Music (2026-07-07)

### Movement: Complete Redesign Based on Game Design Analysis

**9 user-reported issues, all fixed:**

**1. Phase no longer pushes toward facing when no input**
- Before: `vel.move_toward(facing * target_speed)` — you kept flying in the last-pressed direction
- After: phase HOLDS current velocity when no input (no accel, no decel). Feels like "committed dash" not "stuck flying."

**2. Reduced drift (momentum was too long)**
- FLOAT decel: 0.3 → 0.5 (faster stop)
- COAST decel: 0.08 → 0.25 (3.1s stop → 0.9s stop)
- COAST_MIN_SPEED: 40 → 50 (coast ends sooner)
- ACCEL: 220 → 300 (snappier response, less delay)

**3. Momentum is now a compoundable VALUE, not just preserved velocity**
- New `momentum` float (0.0 to 2.0) that:
  - Builds when moving fast (speed_pct > 0.7): +0.5/s
  - Decays when slow in FLOAT: -0.3/s
  - Spent by DIVE: -0.3 per dive
  - Added by PULSE: +0.4 (net +0.1 after 0.3 cost)
  - Modifies speed: up to +50% at full momentum
  - Preserved across states (compounds), resets when FLOAT for 0.5s
- Phase gets +30% speed at full momentum
- Dive gets +0.5 mult per momentum point (compoundable!)

**4. Pulse is now a TAP (no charge, no cooldown, no slowdown)**
- Before: HOLD SHIFT 0.2-0.5s to charge, 70% slowdown while charging, 1.2s cooldown
- After: TAP SHIFT for instant 1.5x burst. No charge, no cooldown, no slowdown.
- Costs 0.3 momentum (must have >= 0.3 to fire). Adds 0.4 momentum (net +0.1).
- Manual edge detection (`_pulse_was_pressed`) instead of `Input.is_action_just_pressed` (more reliable)
- No more cognitive conflict between holding SHIFT and hitting SPACE

**5. Chain degradation prevents spam**
- New `chain_count` increments on each phase
- Each chain step: dive boost reduced 10% (min 50% of normal)
- Chain resets when FLOAT for 0.5s, OR when pulse fires
- Without pulse, chain degrades: dive1=2.32, dive2=2.04 (verified)

**6. Chaining has clear value (momentum compounds)**
- Chaining preserves momentum (doesn't reset across PHASE→DIVE→COAST)
- Each chain step at full momentum gives bigger dive bursts
- Pulse resets chain degradation (creative continuation)

**7. Chain limit via degradation + pulse reset**
- Max chain effectiveness at chain_count=0 (full boost)
- Degrades to 50% by chain_count=5
- Pulse is the "refresh" — resets chain_count to 0

**8. Delay feeling eliminated**
- Removed charge anticipation (0.2-0.5s delay)
- Removed 70% slowdown while charging
- Faster ACCEL (220→300) for snappier response
- Faster squash recovery (8→12, 10→15)
- Phase holds velocity (no pushing toward facing = no feeling of being dragged)

**9. Cooldown/bank interaction fixed**
- Before: `cooldown_pct()` divided by `PHASE_CD` (4.0) even when actual cd was 2.0 (halved) → ring filled too slowly
- After: stores `_last_phase_cd` on phase start, uses that for accurate percentage
- Verified: cooldown_pct returns 0.0 right after a coast-phase (cd=0.5, last_cd=0.5)

### New Visual Feedback
- **Momentum ring**: fills clockwise around ghost, color shifts blue→gold as momentum grows
- **Chain dots**: small dots above ghost (1 per chain step, max 5), color shifts gold→red as chain grows
- Removed: charge ring (no more charge), charge color shift, cooldown ring for pulse (no cooldown)

### Music: Speder2-Style Game-Electronica (NOT Jazz, NOT Lo-Fi)

**Research:** Speder2 is a Japanese game-electronica composer (NOT lo-fi). Their sound = modal color-chord rotation over a house beat with chiptune textures. Full research at `/home/z/my-project/download/MUSIC_RESEARCH_REPORT.md`.

**Complete rewrite with speder2 techniques:**

**Chord progression** (2-beat rate, modal color rotation — NOT functional ii-V-I):
- Section A (Gm): Cm6 - BbM7(9) - Cm6 - G7#5#9 - Cm7(9) - BbM7(9) - Cm7(9) - Dm7(9)/Daug7
- Section B (Fm→Bb→Gm): DbM7(9) - DbmM7 - Cm7(11) - Faug7 - Bbm7(9) - Bbm7(11) - EbM7(9) - Dm7b5 - G7#5#9 - Cm6 - BbM7(9) - Cm7(9) - G7#5#9 - Cm6 - BbM7(9) - Cm6

**Speder2 chord palette used:** m7(9), M7(9), m6, mM7, aug7, 7alt(+5+9), m7b5, m7(11) — all from the "微妙なコードの雰囲気" video.

**8 layers** (speder2 production techniques):
1. **Kick**: four-on-the-floor, sine drop 80→40Hz (808-style)
2. **Clap**: noise burst on 2&4, bandpass ~2kHz
3. **Hats**: off-beat 8th notes, short noise
4. **Cowbell**: beats 3&4 (kaiwai-kyoku signature), square ~840Hz+540Hz
5. **Bass**: sustained saw, root notes, 2-beat chord rate, lowpass
6. **Chords**: saw stabs (additive harmonics), rootless drop voicings, 2-beat rate
7. **Arpeggio**: high-register sine counter-line, 8th notes, fills melodic gaps
8. **Lead**: sparse synth lead (saw + vibrato), enters off-beat, stepwise motion

**Specs:** 128 BPM, 4/4, 16 bars, 30s loop. Reverb (one-comb feedback delay). Gentle master (tanh*0.7).

**Verified:** 30.0s loop, peak -7.5dB, RMS -19.9dB. Preview at `/home/z/my-project/download/music_preview/main_theme_v4_speder2.wav`.

### Verification
- 8 movement unit tests pass (temp TestRunner, removed pre-commit):
  - Phase holds velocity when no input
  - Momentum builds with speed (0.94 after 2s running)
  - Momentum spent on dive (0.94 → 0.67)
  - Pulse is instant tap (mult=1.48)
  - Pulse resets chain count
  - Chain degrades dive boost (dive1=2.32, dive2=2.04)
  - Cooldown percentage uses actual cd (not PHASE_CD constant)
  - Phase chain still works (FLOAT→PHASE→DIVE→COAST→PHASE)

---

## v0.16 — Jazzy Theme v3 (SNES-informed synthesis, fixed voicings, reverb, melody) (2026-07-07)

### Problem: v0.15 Sounded Bad Despite Correct Harmony
**Diagnosis (via research report):** The chord choices and 3-layer concept (walking bass + comp + ride) were musically correct jazz. The problem was entirely **timbre + envelopes + one voicing bug + no reverb**:
1. Comp stabs were **pure sine waves** → soft organ, not piano/guitar comp
2. Ride was **white noise with 40ms decay** → "tss tss", no metallic ping (a real ride rings 1-3s)
3. Walking bass was a **triangle wave** → weak, flutey, no pluck transient
4. **D7#5#9 voicing was wrong** — the #9 (F) was missing, 3rd and #5 were doubled
5. **No reverb/echo** — SNES has hardware echo; jazz needs a room. Dry PCM sounds dead
6. Walking bass **jumped octaves between bars** and was **pushed on beats 2&4** (should be even; hi-hat carries 2&4)
7. Mix was **over-compressed** by `tanh(x*1.2)*0.9`
8. **4 bars / 8.7s loop** was too short — gets grating fast

### Fixes Applied (all from the research report)

**1. Comp stabs: sine → SAW (additive harmonics) + noise attack + exp decay**
- Each voice now sums fundamental + 2nd harmonic (1/2 amp) + 3rd harmonic (1/3 amp) → sawtooth-ish, much richer than pure sine
- 3ms noise attack transient at the start (hammer/pick)
- Exp decay (τ=80ms) with NO sustain phase — piano/guitar stabs die, they don't sustain

**2. Ride: white noise 40ms → 6 inharmonic square oscillators + 0.5s decay**
- 6 square oscillators at non-harmonic ratios (1.0, 1.34, 1.56, 1.78, 2.0, 2.4 × 2.2kHz base) — TR-808 cymbal technique. Non-harmonic = metallic
- Bandpass noise layered for the wash
- 1.5ms stick click at the very start
- τ=0.5s decay (was 0.04s — 10x too short). Now rings ~1.5s like a real ride
- Spang-a-lang pattern preserved (1, &2, 3, &4 with 66% swing)
- Hi-hat chick on beats 2 & 4 (40ms, tight)

**3. Walking bass: triangle → sine + harmonics + pluck + humanized**
- Sine fundamental + 2nd harmonic at -12dB + 3rd at -18dB (woody body, not buzzy)
- 2ms pluck transient (bright noise) at each note onset
- Humanized timing: +6-10ms random delay per note (laid-back, never ahead)
- Removed the beats 2&4 amp boost (bass should be even; hi-hat carries 2&4)
- Fixed bass walks to stay in one octave (D2-D3) — no more octave jumps between bars

**4. D7#5#9 voicing FIXED**
- Before: `[F#3, Bb3, C4, F#4, Bb4]` = 3, #5, b7, 3, #5 — #9 (F) missing, 3rd and #5 doubled
- After: `[F#3, C4, F4, A#4]` = 3, b7, #9, #5 — rootless, #9 voiced ABOVE the 3rd (correct jazz voicing)
- Same audit applied to all chords: all now rootless (bass plays root), drop-2 voicings

**5. Reverb: one-comb feedback delay (SNES-style)**
- 90ms delay, 45% feedback, one-pole lowpass in feedback path (kills harshness)
- 25% dry send, 35% wet into master
- Transforms "dead dry" → "in a room"

**6. Extended 4 bars → 8 bars (A + B sections)**
- A section (bars 1-4): Am9 → D7#5#9 → Gmaj9 → Fm6 (ii-V-I-vi in G + bVI color)
- B section (bars 5-8): Cmaj7 → Fmaj7 → Bm7b5 → E7#5#9 (turn-around back to Am9)
- Loop is now 17.45s (was 8.7s) — much less repetitive

**7. Varied comp rhythm per bar**
- Each bar now uses a different subset of stab positions: `[1,&2,3,&4]`, `[1,3,&4]`, `[1,&2,3]`, `[&2,3,&4]` (Basie-style drop of beat 1)
- No more mechanical same-rhythm-every-bar

**8. Added melody motif layer (Toby Fox lesson)**
- Recurring 4-note motif per bar, derived from chord's upper extensions
- Placed on syncopated 1, &2, 3, &4 pattern
- Sine + subtle 2nd harmonic + 5Hz vibrato for life
- Motif transforms across chords (Toby Fox leitmotif technique)

**9. Gentler master**
- Replaced `tanh(x*1.2)*0.9` with `tanh(x*0.7)` — preserves dynamics, only saturates when needed
- Master volume raised from -14dB to -10dB to compensate

### Verification
- Renders to 17.45s WAV at /home/z/my-project/download/music_preview/main_theme_v3.wav
- Peak: -6.4dB (no clipping), RMS: -18.8dB (more dynamic range than v0.15's -14.7dB — reverb + gentler master preserved dynamics)
- 8 distinct bars verified via per-bar RMS sampling
- B section (bars 5-8) slightly louder than A section (Cmaj7/Fmaj7 are brighter chords)
- Spectral content now balanced across bass/lowmid/highmid/high (v0.15 had huge 110Hz peak from over-loud bass)

### Research basis
All fixes based on `/home/z/my-project/download/MUSIC_RESEARCH_REPORT.md` — research into SNES SPC700/BRR specs, Toby Fox's FL Studio + soundfont process, jazz voicing theory (rootless ii-V-I, drop-2), walking bass construction (chord tones on 1&3, chromatic approach on 4), jazz ride spang-a-lang pattern, cymbal synthesis (TR-808 inharmonic oscillators), and why pure sine/triangle/noise layers sound bad.

---

## v0.15 — Jazzy Main Theme (Speder2 Chords + Walking Bass + Comp) (2026-07-07)

### Replaced Ambient Pad with Jazzy Rhythmic Loop
**Problem:** The v0.14 main theme was an ambient Am-F-G-Em pad with a slow arpeggio — too slow, too ambient, not bouncy or rhythmic. User wanted jazzy, bouncy, rhythmic, using speder2's actual chord types.

**Changed:** Completely rewrote `scripts/autoload/music.gd` to be a jazzy 4-bar loop using speder2's actual chord types from the "Subtle Chord Atmosphere" analysis:

**Chord progression** (ii-V-I-vi jazz feel in A minor):
| Bar | Chord | Speder2 Type | Mood | Notes |
|-----|-------|--------------|------|-------|
| 1 | Am9 | m7(9) | cold, crystal hardness | A C E G B |
| 2 | D7#5#9 | 7alt(+5+9) | high-impact emptiness | D F# A# C E#(F) |
| 3 | Gmaj9 | M7(9) | warm, fluffy cushion | G B D F# A |
| 4 | Fm6 | m6 | anxious, transparent | F Ab C D |

The D7#5#9 (altered dominant) creates maximum jazz tension that resolves to Gmaj9, then Fm6 (with its tritone Ab-D) provides an anxious turn-around back to Am9.

**Three rhythmic layers** (bouncy + jazzy):
1. **Walking bass** — triangle wave, quarter notes (4 per bar), walks chord tones + chromatic approach to next chord root. Back-beat (beats 2, 4) 15% louder for bouncy feel. Example walk for Am9: A2→C3→E3→Eb3 (chromatic approach to D, the next root).
2. **Comp stabs** — sine chord on syncopated 1-&2-3-&4 pattern with **66% swing** (long-short 8th notes). Speder2 drop voicings + amplitude scaling (9th at -8dB, altered #5/#9 at -12 to -15dB). 180ms stabs with ADSR.
3. **Ride cymbal** — filtered noise on each beat + softer "bell" on swung &2 and &4 (jazz ride pattern). Plus soft back-beat ticks on beats 2 and 4.

**Speder2 techniques applied** (from the video analysis):
- **Drop voicings:** root in octave 2, 5th in octave 3, chord tones spread across octaves 4-5 (no half-steps in same octave — prevents intermodulation distortion)
- **Amplitude scaling:** higher-tension notes (9ths, altered tones) get lower amplitude. Example: Am9 comp amps = [0.20, 0.22, 0.18, 0.10, 0.06] — the 9th (B4) is quietest at 0.06
- **Micro-pitch drift:** ±0.2% per voice (speder2's value, prevents static phase cancellation)
- **ADSR envelopes** per layer (8ms bass attack, 3ms comp attack, fast noise decay for ride)

**Tempo & structure:**
- 110 BPM (bouncy, not slow)
- 4/4 time, 4 beats per bar
- Beat duration: 0.5454s
- Bar duration: 2.1818s
- Loop duration: 8.727s (4 bars)

**Master processing:** tanh soft-clipper on the summed output to prevent clipping from layer sum.

### Verification
- Renders to 8.73s WAV at /home/z/my-project/download/music_preview/main_theme_jazzy.wav
- Peak: -6.5dB (no clipping), RMS: -14.7dB (healthy background level)
- Rhythmic structure verified via per-beat RMS sampling: clear back-beat emphasis at beats 2 and 4 of each bar (RMS peaks ~1-2dB louder on beats 2/4 vs beats 1/3)
- Spectrogram shows distinct bass-note onsets every 0.5454s (quarter notes) + comp stab transients on the swung off-beats

---

## v0.14 — Pulse v2 (Charge-and-Release) + Procedural Main Theme (2026-07-07)

### Pulse Redesign: Double-Click → Hold-to-Charge
**Problem:** The v0.10.4 double-click pulse was confusing and unclear. The boost was only 15% (1.15x), the sound was a high-pitched 880Hz square-wave blip (same as the UI tick), and there was no "hold" mechanic — players couldn't tell what was happening or how to use it.

**Changed:** Replaced the double-click pulse with a **hold-to-charge** system bound to **SHIFT**:

| Charge Level | Hold Time | Boost | Duration | Particles | Trauma |
|-------------|-----------|-------|----------|-----------|--------|
| Min | 0-0.2s | 1.4x | 0.3s | 4 | 0.05 |
| Med | 0.2-0.5s | 1.7x | 0.4s | 7 | 0.10 |
| Max | 0.5s+ | 2.2x | 0.6s | 12 | 0.20 |

- **Cooldown:** 1.2s after release (prevents spam, rewards timing)
- **Tradeoff:** Ghost slows to 70% speed WHILE charging (anticipation, not free)
- **Visual feedback:** Charge ring around ghost fills clockwise; color shifts cyan → blue → purple as charge grows. On release, expanding flash ring + particle burst scales with charge level. Cooldown ring when on CD.
- **Sound:** New `pulse_charge` (low triangle drone 110→165Hz, 1s build) and `pulse_release` (maj9 chord burst at A3 220Hz — lower-pitched than blip, with speder2 drop voicing + 9th shimmer). Release pitch rises with charge level.

**Clearer game design:** The charge ring + color shift + slowdown while charging makes it obvious what's happening. The 3 distinct charge levels (with visual + audio scaling) make the mechanic readable. The SHIFT binding is the canonical "boost" key in FPS games.

### Procedural Main Theme (Music Autoload)
**Added:** A new `Music` autoload (`scripts/autoload/music.gd`) that generates a 12-second looped AudioStreamWAV at startup using speder2 chord-timbre techniques.

**Chord progression:** Am - F - G - Em (i - VI - VII - v in A minor) — melancholy with tension, fits the ghost-bound-to-dungeon theme.

**Structure:** 80 BPM, 4 beats per chord, 4 chords = 16 beats = 12 seconds. Three layers baked into one loop:
1. **Pad:** Sustained chord with speder2 drop voicing (root in octave 2, chord tones in octaves 4-5) + min9/maj9 extension at -12dB. 50ms attack, 500ms release, 1.5Hz LFO amplitude modulation for "breathing" pad.
2. **Bass:** Root note plucked (triangle wave) on beat 1 of each chord. 5ms attack, 0.6s exponential decay.
3. **Arpeggio:** 8th notes cycling through chord tones (sine wave, very quiet at 0.07 amplitude). 3ms attack, 0.15s decay.

**Speder2 techniques applied:**
- Drop voicings: root in octave 2 (82-110Hz), chord tones spread across octaves 3-5
- Amplitude scaling: 9th extension at 0.06 amplitude (vs root at 0.18-0.30)
- Micro-pitch drift: ±0.12-0.14% detuning per voice (prevents static phase cancellation)
- Slow attack: 50ms on pad chords (ambient, not plucked)

**Wider procedural soundtrack techniques used:**
- **Layered composition:** Pad/bass/arp baked into one stream (simpler than runtime mixing, fewer voices)
- **Loop-forward mode:** `AudioStreamWAV.LOOP_FORWARD` with loop_begin=0, loop_end=sample_count
- **Continuous playback:** Music starts at `_ready()` and loops forever at -14dB on the Music bus
- **Chord progression choice:** i - VI - VII - v is a classic emotional progression (used in many indie roguelikes) — melancholy but not hopeless, with the v (Em) creating unresolved tension that makes the loop feel natural

### Input Changes
- **Added:** `pulse` input action bound to **Shift** (keycode 4194325)
- **Removed:** Double-click pulse detection (`handle_click`, `_fire_pulse`, `_last_click_time`, `DOUBLE_CLICK_WINDOW`)

### Phase Updates
- All walkable phases (salvage, workshop, planning) now call `move.update_pulse(delta)` before `move.update(input_dir, delta)`
- Removed `move.handle_click(event)` calls and empty `_input` functions
- Updated hint texts: "DblClick:pulse" → "SHIFT:hold pulse" (salvage), "SHIFT:pulse" added to workshop + planning hints

### Verification
24 unit tests pass (temp TestRunner autoload, removed pre-commit):
- Min/med/max charge each give correct boost (1.4x/1.7x/2.2x)
- Cooldown blocks re-charging
- Ghost slows to 70% while charging
- Phase chain still works (FLOAT→PHASE→DIVE→COAST→PHASE, halved cd)
- Music autoload plays 12.0s loop with LOOP_FORWARD mode

All 17 SFX + main theme rendered to `/home/z/my-project/download/` for ear-test:
- `sfx_preview/*.wav` — 15 original + 2 new (pulse_charge, pulse_release)
- `music_preview/main_theme.wav` — 12.0s, 44.1kHz mono, ~1MB

---

## v0.13 — SFX Distinction Overhaul (2026-07-07)

### Problem: Speder2 Chord-Timbre Made Everything Sound the Same
**Diagnosis:** The v0.11 speder2 chord-timbre SFX overhaul was a good idea (warm sines instead of harsh squares) but went too far — it converted EVERY SFX (including percussive impacts, UI ticks, error tones, mechanical sounds) into warm sine chords. Result: blip, chime, coin, bell, recruit, repair all became "sine chords in 440-1000Hz range" and shatter/deny/death all became "descending sine arpeggios". They literally sounded the same.

### Fix: Distinct Waveform + Frequency Range Per Sound
**Changed:** Kept speder2 chord-timbre for **musical/positive/spectral** sounds (chime, bell, coin, recruit, phase_in, phase_out) but gave **percussive/UI/mechanical** sounds (blip, thud, hit, shatter, deny, death, repair) their own distinctive waveforms AND frequency ranges so each is identifiable by ear:

| Sound | Waveform | Freq Range | Duration | Character |
|-------|----------|-----------|----------|-----------|
| blip | **Square** | 880Hz | 0.08s | NES UI tick (was sine+5th chord) |
| chime | Sine chord (maj9) | 880-1319Hz | 0.5s | Bright sustained chord (brightened from 440-659) |
| thud | **Triangle** + noise | 80-50Hz | 0.18s | Sub-bass impact (was 110-82Hz, now lower) |
| hit | **Saw** + noise | 220-110Hz | 0.14s | Buzzy mid impact (was sine+harmonic) |
| shatter | Sine arp + **noise** | 2093-880Hz | 0.35s | Glassy break (noise restored, was pure arpeggio) |
| coin | Sine glissando | 988→1319Hz | 0.12s | Quick pickup blip (was 4-note chord, now shorter bend) |
| select | Sine | 1200Hz | 0.05s | Tiny tick (unchanged) |
| deny | **Square** | 165→110Hz | 0.2s | Buzzy error (was pure sine — too gentle) |
| bell | Sine + **inharmonic** partials | 523-2197Hz | 0.8s | Metallic ring (was harmonic chord — sounded like organ) |
| death | **Triangle** + sub-bass + noise | 220-55Hz | 0.6s | Heavy dramatic (was sine arpeggio — too melodic) |
| repair | **Saw taps + noise** (4x) | 880Hz | 0.32s | Mechanical hammer (was sine chord — sounded like recruit) |
| recruit | Sine glissando | 523→784Hz | 0.4s | Friendly bend (was 2-step, now continuous) |
| footstep | Sine + noise | 180-120Hz | 0.08s | Soft step (unchanged) |
| phase_in | Sine chord (m6) | 880→220Hz | 0.25s | Spectral descent (unchanged — speder2 showcase) |
| phase_out | Sine chord (mM7) | 330→660Hz | 0.20s | Spectral ascent (unchanged — speder2 showcase) |

### Verification
All 15 SFX rendered to `/home/z/my-project/download/sfx_preview/*.wav` for ear-test verification. Amplitudes are appropriately varied: death (-8dB, loudest) → thud (-8dB) → hit (-10dB) → footstep (-20dB, quietest). Each sound occupies a distinct register or uses a distinct waveform so they're identifiable by ear.

### Principle
Warm sine chords work for **musical** sounds (success cues, spectral effects, welcoming tones) where you want warmth and sustain. But **percussive/UI/mechanical** sounds need sharp transients, distinctive waveforms (square/saw/triangle), and noise components to read as "impact", "tick", "error", or "mechanical work". The speder2 approach removed those distinctions. This patch restores them while keeping the chord-timbre character where it belongs.

---

## v0.12 — Snappy Reflect + Coast Cancel Fix (2026-07-07)

### Movement Feel: Hard Reflect Restored (v0.11 Blend Was Too Soft)
**Changed:** Replaced v0.11's progressive velocity blend (`lerp` with `exp(-delta*12.0)*0.6` factor) with the v0.10.5 hard reflect on direction changes >90°. The blend was too soft — at 60fps the per-frame blend factor was only ~10.9%, so a full 180° reversal took ~0.4s to actually start moving the other way. The hard reflect snaps velocity to the new direction at 85% of current speed (FLOAT/PHASE), 80% (DIVE), 70% (COAST — lighter so steering out feels deliberate). The 15-30% loss prevents reversal-spam from being free. Partial turns (<90°) still use `move_toward` for smoothness. Reflect is now also applied to PHASE state (v0.10.5 was missing PHASE direction-change handling entirely).

### Chain System Fixed (Coast Cancel Was Too Aggressive)
**Changed:** The v0.10.5 coast-cancel threshold (`_coast_input_hold > 0.15` on ANY held direction) was kicking the player out of COAST before they could chain phase. By the time they wanted to chain phase→dive→coast→phase, they were already in FLOAT, and the chain halving never fired. Fixed: coast cancel now only triggers on STEERING input — a direction >45° off current velocity, held >0.25s. Holding the dive direction (the natural chain input) keeps you in COAST so the chain stays possible. Threshold raised from 0.15s to 0.25s for more grace.

### Chain Halving + Bank Intact
**Kept:** v0.11's chain cooldown halving (PHASE_CD * 0.5 when phasing from COAST) and phase_bank reduction are preserved and verified working. Unit-tested: FLOAT→PHASE cd=4.0s, COAST→PHASE cd=0.5s (2.0 halved + 1.5 bank). Three consecutive chain cycles verified end-to-end.

### SFX + Camera Untouched
**Kept:** All v0.11 speder2 chord-timbre SFX work and v0.10.5 camera feel changes (look-ahead 8px, speed micro-shake, smoothing rates) are preserved — only `ghost_movement.gd` was modified.

---

## v0.11 — Momentum Blend, Chain Fix, SFX Overhaul (2026-07-07)

### Momentum Blend Replaces Hard Reflect
**Changed:** Direction changes now use a progressive velocity blend (lerp) instead of the hard 85% reflect that felt too aggressive. The blend rate is `exp(-delta * 12.0) * 0.6` — fast but not instant. Keeps ~60% of speed through a reversal, then accel handles the rest. No harsh snap, no floaty drift. Applied to ALL 4 states (FLOAT, PHASE, DIVE, COAST — PHASE was previously missing direction-change handling entirely).

### Chain System Fixed
**Changed:** Phasing from COAST now halves the cooldown (PHASE_CD * 0.5). Previously, the cooldown blocked the chain after the first cycle — phase→dive→coast→phase was impossible because `_start_phase()` set the full 4s cooldown. Now coasting into phase = 2s cooldown, and banked time reduces it further. The chain is: phase → cancel → dive → coast → phase (half cd) → cancel → dive → coast → phase (half cd) → ... Each cycle costs a shard but the cooldown no longer blocks it.

### SFX Overhaul — Softer, More Melodic
**Changed:** Replaced all harsh square-wave + noise SFX with sine/triangle waves and harmonic overtones, following NES/GBA retro sound design principles:

- **thud**: Square wave → triangle wave (110→82Hz). NES used triangle for soft percussion.
- **hit**: Square + 50% noise → sine + 2nd harmonic (220→110Hz). Harmonic adds warmth.
- **shatter**: High-freq sine + 70% noise → descending sine arpeggio (C7→G6→E6→A5). Crystalline, not piercing.
- **deny**: Square wave at 140Hz → sine wave descending (165→110Hz). Gentle "no" not buzzy error.
- **death**: Sine + 30% noise → descending sine arpeggio (A4→F4→D4→A3). Fading spirit, not crash.

Key principle: square waves and white noise are inherently harsh. Sine waves are pure and warm. Triangle waves are soft (used for NES percussion). Harmonic overtones (2x, 3x frequency) add richness without harshness. Arpeggios create melodic interest that single sustained notes can't.

---

## v0.10.5 — Camera Feel, Coast Cancel, Reverse QTE, Pulse Subtlety, Exit Fix (2026-07-07)

### Camera Feel
**Changed:** Look-ahead reduced from 24px to 8px (camera was ahead of movement, making player feel slow). Added speed-based micro-shake — screen vibrates slightly above base speed for "false sense of speed" (racing game technique). Smoothing rates increased: FLOAT 6→8, COAST 9→11, DIVE 12→14.

### Coast Cancelable
**Changed:** Holding any direction for >0.15s exits coast back to FLOAT. No more awkward slidy feeling — just hold a direction to regain control. Quick taps still work for pulse-extends.

### Reverse QTE Shortened
**Changed:** 2.5s → 1.5s. Still tense, less tedious.

### Damage/Death SFX Adjusted
**Changed:** Replaced layered "hit"+"shatter" (grating) with "thud" + low "deny". Death uses "death" + deep "deny". (Further improved in v0.11.)

### Pulse Feedback Made Subtle
**Changed:** Particles 5→3, flash 1.0→0.6, SFX pitch 1.3→1.0, volume -6→-10dB. Still noticeable but not distracting.

### Exit Trigger Fixed
**Changed:** Radius 12→8px (less accidental triggering). Added green particles + chime SFX on exit touch. Transition delay 0.5s→0.2s (snappier).

---

## v0.10.4 — Direction Change Reflect + Pulse on Double-Click (2026-07-07)

### Direction Change Reflect (later replaced by blend in v0.11)
**Changed:** Velocity reflection on direction changes >90°. When pressing opposite direction, velocity instantly flipped at 75-85% of current speed. Eliminated the "slowdown on direction change" caused by move_toward having to decelerate to zero first.

### Pulse Moved to Double-Click
**Changed:** Pulse trigger moved from WASD-tap (jarring, conflicted with normal movement) to WASD + double left-click. handle_click() on GhostMovement detects double-clicks within 0.3s window.

### Salvage Camera X-Axis Smoothing
**Changed:** X axis now smoothed (was instant — caused jarring left/right snaps). Both axes use lerpf with exp smoothing. Smoothing scales with movement state.

---

## v0.10.3 — Pulse Instant Velocity Surge + Feedback (2026-07-07)

### Pulse Was Invisible — Now Instant Surge
**Changed:** Pulse only raised TARGET speed by 15% — unfeelable. Fixed: pulse now sets velocity DIRECTLY to boosted speed (instant surge). Added blue particle burst, "blip" SFX, white-blue glow ring around ghost.

---

## v0.10.2 — State-Based Movement System (Phantom Forces Inspired) (2026-07-07)

### 4-State Momentum System
**Changed:** Replaced flat movement with FLOAT → PHASE → DIVE → COAST state machine. DIVE = momentum burst on phase cancel (scales with remaining energy). COAST = low deceleration, pulse-extends duration. Weapon weight halved during coast.

---

## v0.10.1 — Momentum Carrying + Sidestep Removed (2026-07-07)

### Sidestep Removed
**Changed:** Sidestep was jarring — fired on every direction tap, conflicted with normal movement. Removed entirely.

### Momentum Carrying Added
**Changed:** Release a direction, re-press within 0.35s for 15% speed boost. (Later replaced by state-based system + double-click pulse.)

---

## v0.10 — Micro-Rewards: Weapon Weight, Sidestep, Pickup Feedback (2026-07-07)

### Weapon Weight System
**Changed:** Each carried weapon reduces speed by 12%. Tradeoff: grab everything (slow) or be selective (fast).

### Sidestep (later removed)
**Changed:** Tap direction key for 0.2s micro-burst at 2x speed. Separate 1.5s cooldown from phase verb. (Removed in v0.10.1 — too jarring.)

### Salvage Pickup Micro-Reward
**Changed:** Bigger squash, longer slowmo, more particles, upward blue burst. Sets carry_count = 1 for immediate weight penalty.

---

## v0.10 — Priority 2 Complete: Push-Your-Luck, Corpse Identity, 4th QTE (2026-07-07)

## v0.10 — Priority 2 Complete: Push-Your-Luck, Corpse Identity, 4th QTE (2026-07-07)

### Push-Your-Luck Salvage
**Changed:** The main exit is now at the corridor MIDPOINT, not the end. Past the exit is a "deeper" section with bonus corpses that have better gear (30% chance of legendary/cursed names). The player can leave at the exit (guaranteed floor) or push deeper for more reward (ceiling). The exit now shows "DEEPER ↓ (N)" indicating how many special corpses are in the deeper section.

**Intention:** This is the "exceed expectations" curve from the design philosophy. The floor (reach exit) is always achievable. The ceiling (collect everything) costs real risk — more hazards, more ghost HP, less time. The player decides how hard to push. The marginal cost rises (more hazards deeper) faster than the reward (limited corpses), so it's always a live decision.

### Corpse Identity
**Changed:** Corpses now have visual identity:
- **YOUR fallen** (actual party gear): blue soul-glow + name + death cause text
- **Bonus corpses** (random NPCs): gold glow + name only
- **Deeper corpses**: purple glow + name + "DEEPER - special" tag

**Intention:** The design plan called for "your fallen have a blue soul-glow, random corpses don't." The visual difference is immediate — the player knows which corpses carry their actual gear (with preserved history/kill logs) vs. which are random fill. The purple glow on deeper corpses signals "this is the push-your-luck reward."

### 4th QTE Type: Debris (Reverse QTE)
**Changed:** New "debris" hazard type with a reverse QTE — "DON'T MOVE!" The player must NOT press any key for 3 seconds. Pressing any movement/interact/space key = instant failure (you flinched into the debris). Succeeding by doing nothing is the "Dumb Ways to Die" comedy beat. Added to dungeon gen hazard rotation (pit, fire, spikes, debris).

**Intention:** The design plan called for "Falling debris: Do nothing (don't click the glowing bell — reverse QTE)." This is the 4th and final QTE type. Each hazard now has a distinct minigame: timing (pit), spam (fire), pattern (spikes), reverse (debris). The reverse QTE is the comedy one — failure is entertaining because you PANICKED.

### Phase Verb Bypass Updated
**Changed:** Phase verb now bypasses fire and spikes but NOT pits or debris. You can phase through fire and spikes (incorporeal), but pits still make you fall and debris still hits you even when phasing (the floor is still there, the rocks are still physical).

**Intention:** Gives the phase verb tactical depth — it's not a universal "skip all hazards" button. Some hazards require QTE skill regardless of phasing.

---

## v0.9 — Feedback Fixes: Shrine, Fleet Shade, Interact Bug, Movement, Corpses (2026-07-07)

### Shrine Shard Cost Now Updates
**Changed:** Planning phase now connects `GameState.shards_changed` signal. The shard HUD was never updating after recruit — the signal was missing. Now the shard count updates immediately when you recruit.

### Fleet Shade Upgrade Wired
**Changed:** `GhostMovement.SPEED` was a `const` — the Fleet Shade upgrade (+15% ghost speed per level) had NO effect. Changed to `get_speed()` which reads `GameState.meta_upgrades["fleet_shade"]` per-frame. Upgrades take effect immediately after purchase.

### Interact Bug Fixed (Phase Verb Breaking Planning)
**Changed:** `interact_pressed = false` was placed AFTER the `Juice.is_hit_stopped()` early return. If hit_stop was active (which happens during `_assign_weapon` and `_try_recruit`), the interact guard got stuck as `true` and blocked ALL further interactions for the rest of the phase. Fixed: moved the reset to the TOP of `_process`/`_physics_process` in planning, workshop, and salvage — before any early returns.

### Movement Sticking Reduced
**Changed:** `GhostMovement.DECEL_MULT` lowered from 0.6 to 0.3 (30% of accel). Direction changes are now much more responsive — the ghost barely slows when you switch directions. Gate phase also updated to match (was using 300 accel / 0.6 decel, now 220 accel / 0.3 decel).

### Salvage Corpses at Death Positions
**Changed:** Battle now records `unit.death_pos` (pixel position) when a party member dies. This is passed through `fallen_gear` as `death_tile` (tile coords). Salvage uses this to place corpses at the actual death location — the player finds their gear where they fell, not scattered randomly. Falls back to spread layout if no death_tile (first run / simulation).

### Weapon Color After Reforge Fixed
**Changed:** `repair_curve()` nearly-broken penalty increased from 0.7 to 0.4. A perfect forge pass from BROKEN now gives ~24% durability (DAMAGED/orange) instead of ~42% (WORN/yellow). Shattered weapons require multiple forge visits to fully restore — graduated repair actually graduates now.

### Battle Phase Verb Clarity
**Changed:** HUD text changed from "PHASING!" to "PHASING — enemies slowed!" so the player understands what the verb does in battle. The effect (60% enemy speed reduction + 50% slower enemy attacks) was always coded but the feedback didn't explain it.

### Gate Movement Unified
**Changed:** Gate phase movement constants updated to match GhostMovement (220 accel, 0.3 decel mult, 55 speed). Was using old values (300 accel, 0.6 decel) that felt different from every other phase.

---

## v0.8.1 — Code Audit Fixes + Repair Minigame Bug (2026-07-07)

### Critical: Repair Minigames Now Display the Weapon
**Changed:** All 4 repair minigames (oil_grindstone, polish_bench, exorcise_altar, reforge_furnace) had `p.ghost.carrying` which referenced the old `ghost` dict that was removed when workshop migrated to `var carrying`. The weapon was always `null` during minigames — the centerpiece art was invisible. Fixed: `p.ghost.carrying` → `p.carrying` in all 4 files.

**Intention:** This was the highest-impact bug found in the audit. The minigames functioned (quality was applied on completion) but the weapon art — the whole point of the minigame visual — was missing.

### Trail Reverted to Working Version
**Changed:** Reverted `juice.gd trail_draw` back to `draw_texture_rect` with alpha 0.6/0.4 (the version the user confirmed was working). A previous attempt to switch to colored rects and raise the alpha broke the trail visibility. Added a comment explaining that the playtest harness's software renderer (llvmpipe) doesn't show the trail, but it IS visible on real hardware.

**Intention:** The trail was working before. Don't fix what isn't broken. The playtest harness limitation (software GL) is documented so future audits don't try to "fix" the trail again.

### Dead Code Removed
**Changed:**
- `weapon.gd`: Removed `survive_wave()` (never called) and `state_color()` (never called)
- `dungeon_gen.gd`: Removed `to_dict()` and `from_dict()` (never used — dungeon gen isn't saved to disk)
- `game_state.gd`: Removed dead `_used_names` meta-storage block in `_random_name` (the actual filtering uses `_recently_used_names` directly)
- `planning.gd`: Removed unreachable map-view close branch (the `interact_pressed` guard made it dead code)

### Redundant Checks Fixed
**Changed:**
- `game_state.gd can_recruit()`: Was calling `living_party_count()` twice. Now caches the result.
- `planning.gd`: Removed redundant `Juice.hit_stop()` double-calls in `_try_recruit` and `_ring_bell` (hit_stop uses `max()`, so calling twice with the same value is a no-op).
- `salvage.gd`: Cached `c.get("weapon", null)` in the corpse draw code (was calling it 4× per corpse per frame in an unreadable one-liner).

### Deep Dive Results
**Checked:** Scanned all 23 scripts for:
- Type inference crashes (`var := dict.access` pattern) — none found
- Cross-script duplication — identified `_draw_glow` (identical in battle + workshop) and ghost-draw block (duplicated in 3 phases) as refactor candidates for future
- Obsolete patterns — all `ghost` dict references migrated to `move`/`carrying` (except the 4 repair minigames, now fixed)
- Efficiency issues — per-frame allocations in `filter()` lambdas noted but low-priority

**Playtest verified:** Full loop (gate → salvage → workshop → upgrade → planning → battle → results) runs without crashes in headless mode. All 18 screenshots captured in visual mode.

---

## v0.8 — DungeonGen Script + Crash Fixes + Warning Cleanup (2026-07-07)

### Extracted DungeonGen Into Its Own Script
**Changed:** New `scripts/dungeon_gen.gd` — a dedicated `DungeonGen` class that handles ALL dungeon randomness: corridor length, width segments (wide/narrow zones), hazard placement, and noise seeds for floor detail. `GameState.get_dungeon_gen()` now returns a `DungeonGen` instance instead of a Dictionary. Salvage and battle both read from the same `DungeonGen` object.

**Intention:** Generation was spread across `GameState._generate_dungeon()` (a 60-line inline function) and the phase scripts. The user correctly identified that generation should be its own script — it's a distinct concern with its own data and logic. `DungeonGen` encapsulates all randomness so it can be tested, tuned, and extended independently. Other scripts just ask it for data (`gen.corridor_h`, `gen.get_width_bounds_at_y(tile_y)`, `gen.get_floor_noise(x, y)`) without knowing how the generation works.

### Fixed Crash: salvage.gd:403 Type Inference
**Changed:** `var qte_type := hazard.type` failed with "Cannot infer the type of 'qte_type' variable" because `hazard` is an untyped Dictionary, so `.type` returns `Variant`. Fixed by typing explicitly: `var qte_type: String = hazard.get("type", "pit")`.

**Intention:** This is the same crash pattern that hit `weapon.gd:169` — Godot 4's `:=` can't infer types from Dictionary value access. This is a recurring issue with the untyped Dictionaries used throughout the codebase.

### Fixed Crash: salvage.gd:753 Type Inference
**Changed:** `var time_pct := active_qte.timer / active_qte.max_timer` failed because both values are `Variant` from the Dictionary. Fixed by casting: `var time_pct: float = float(active_qte.timer) / float(active_qte.max_timer)`.

### Fixed All Integer Division Warnings
**Changed:** Replaced integer divisions with float divisions where the decimal part was being discarded:
- `game_state.gd`: `int(stage / 2)` → `int(stage / 2.0)`, `int(wave / 2)` → `int(wave / 2.0)`
- `juice.gd`: `sz / 2` → `sz / 2.0`
- `sfx.gd`: `n/2` → `n / 2` (explicit, with warning suppressed by float context)

### Fixed Unused Parameter Warning
**Changed:** `_random_name(seed_i: int)` → `_random_name(_seed_i: int)`. The parameter was never used (names are randomized via shuffle, not seed).

### Fixed Shadowed Variable Warning
**Changed:** `sfx.gd play(name: String)` → `play(p_name: String)`. The parameter `name` was shadowing `Node.name` (the base class property). Renamed to `p_name` and updated all references.

### Fixed Unused Variable
**Changed:** Removed unused `var t := float(i) / SR` in `sfx.gd _phase_in()` — the variable was declared but never used (the frequency calculation uses `float(i) / n` directly).

### Deep Dive: No Other Type Inference Crashes Found
**Checked:** Scanned all scripts for `var := dict.access` patterns (the recurring crash pattern). All remaining `:=` inferences are from typed properties (`move.pos`, `gear.state`) or function returns (`_noise.get_noise_2d()`, `Sprites.get_sprite()`), which are safe. No other Dictionary-access type inference issues found.

---

## v0.7.1 — Battle Uses Full Dungeon Generation (2026-07-07)

### Battle Matches Salvage Generation
**Changed:** Battle now reads the FULL dungeon generation from `GameState.get_dungeon_gen()` — not just `corridor_h` but also `narrow_zones` and `noise_seed`. Previously battle only read the corridor length but ignored the narrow zones, so the battle corridor was a uniform 18-tile-wide tube while salvage had narrow chokepoints. Now both phases render the same physical space:
- Floor detail uses the same `FastNoiseLite` seed (same moss/crack/blood patterns)
- Walls respect narrow zones (narrow zones have walls at the narrow bounds, wide zones at 0 and CORRIDOR_W)
- Enemy spawn positions respect narrow zones (spawn within the walkable width at their y-level)
- Party spawn position respects narrow zones at the bottom of the corridor

**Intention:** The player runs through the SAME dungeon in battle and salvage. If salvage has a narrow chokepoint at y=30, battle has the same narrow chokepoint at y=30. This makes the dungeon feel like a real place, not two separate layouts. The direction is opposite (party fights up, ghost salvages down) but the physical space is identical.

### Crash Fix (v0.7 hotfix)
**Changed:** Fixed `weapon.gd:169` crash — `var enemy := enemies[...]` failed type inference on an untyped array. Fixed by typing as `Array[String]` and `var enemy: String`. Also fixed shadowed variable warning (`roll_affliction(type)` → `roll_affliction(p_type)`).

---

## v0.7 — Salvage Overhaul + Movement Normalization + Phase Bank Fix (2026-07-07)

### Phase Bank Fix
**Changed:** Banked phase time now reduces NEXT COOLDOWN (was: added to next duration). The meter you didn't spend is refunded as a shorter cooldown. So: activate phase (1.5s dur, 4s cd) → cancel at 0.8s remaining → bank 0.8s → next activation has 1.5s dur but only 3.2s cd. Momentum boost on manual cancel increased to 2.0x speed (was 1.8x).

**Intention:** The old "bank adds to duration" felt unrewarding because the cooldown was still full. Reducing the cooldown makes early-canceling feel like a real tactical choice — cancel early, get your next phase sooner. The boost was too subtle; 2.0x is more noticeable.

### Shared GhostMovement Script
**Changed:** New `scripts/ghost_movement.gd` — single source of truth for movement constants (speed 55, accel 220, decel 60% of accel), phase verb logic (activate/cancel/bank/momentum boost), footstep SFX, and ghost trail. Salvage, workshop, and planning now each own a `GhostMovement` instance and call `move.update(input_dir, delta)` + `move.try_activate_phase()`. Battle uses its own inline phase logic (no ghost movement in battle).

**Intention:** Movement values were duplicated across 4 phase scripts with slight drift (gate used 300 accel, others used 220). Now all phases use identical movement feel. Adding a new walkable phase just means `move = GhostMovement.new()` instead of copying 50 lines of movement code.

### Phase Visual: "Underground" Effect
**Changed:** While phasing, the ghost is now MUCH more transparent (alpha 0.3-0.45, was 0.5-0.65) with a deeper blue tint (0.35, 0.55, 0.85). A dark blue semi-transparent ring is drawn around the ghost, suggesting the floor is covering it — reads as "sinking below the ground" rather than just "turning blue."

**Intention:** The phase verb is described as going "underground" (incorporeal). The old visual was just a blue tint — didn't read as underground. The low alpha + dark ring makes the ghost look like it's phasing below the floor surface.

### Salvage: Noise-Based Floor Detail
**Changed:** Floor detail tiles (moss, cracks, blood) now use `FastNoiseLite` (cellular noise) instead of a hash function (`(x*7 + y*13) % 31`). The noise seed is part of the dungeon generation, so it's consistent within a stage but different per stage.

**Intention:** The hash-based tiling was too regular — you could see the pattern repeat. Noise gives organic, non-repeating variation that reads as natural dungeon wear.

### Salvage: Hazards Activate on TOUCH
**Changed:** Hazards now auto-trigger their QTE when the ghost overlaps them (distance < 14px). Previously hazards only triggered on E/SPACE press, meaning you could walk right past them. Phase verb still bypasses fire/spikes (not pits). Hazard proximity indicator only shows when within 20px (was 30px) — harder to see.

**Intention:** Hazards were trivially avoidable — you could just walk past without interacting. Touch-activation makes them real obstacles. The reduced indicator range means you have to actually watch where you're going.

### Salvage: Narrower Corridor + Width Segments
**Changed:** The corridor now has 2-3 "narrow zones" at random y-levels per generation. Wide zones use the full 18-tile width; narrow zones are 8-12 tiles wide with their own walls. The ghost is clamped to the narrow width when inside a narrow zone. Diagonal transitions between wide and narrow are drawn as wall textures.

**Intention:** The old corridor was uniformly wide, making it too easy to dodge hazards. Narrow zones create chokepoints where hazards are harder to avoid. The varied widths make the corridor feel like a real dungeon with different passage sizes.

### Salvage: Generation Persists Per Stage
**Changed:** Dungeon generation (corridor length, narrow zones, hazard positions, noise seed) is now stored in `GameState.dungeon_gen` and persists for the entire stage. Battle and salvage both read the same generation. It's regenerated when the stage changes (new stage = new dungeon). Cleared on new run.

**Intention:** Previously salvage regenerated the corridor every visit, so the layout you saw in battle didn't match salvage. Now the dungeon is a real place — you run through the same corridors in battle and salvage. The first-run predecessor graves use the same generation, establishing continuity.

### Salvage: Corridor Length Clamped to Weapon Count
**Changed:** Corridor length = `clamp(20 + weapon_count * 6 + rand(0-7), 20, 80)`. More weapons to salvage = longer corridor. Random variance of ±7 tiles so it's not the same length every time.

**Intention:** Previously the corridor was always 60 tiles regardless of how many weapons there were. Now the length scales with content — more corpses to collect means a longer walk, but with random variance so it doesn't feel mechanical.

### Salvage: 3 QTE Types
**Changed:** Each hazard type now has a distinct QTE minigame:
- **Pit** → Timing bar (hit the green zone on a sweeping bar) — the original QTE
- **Fire** → Spam (mash SPACE to fill a progress meter before time runs out)
- **Spikes** → Pattern (press a sequence of 4 WASD keys in order, shown on screen)

**Intention:** Was just the timing bar for every hazard. Three different QTE types give variety — each hazard feels different to disarm. The pattern QTE is the hardest (requires memory + execution), spam is the easiest (just mash), timing is the middle ground.

### Salvage: Timer
**Changed:** 45-second timer displayed in the HUD. At 0, forced exit to workshop (same as ghost HP reaching 0).

**Intention:** Salvage had no time pressure — you could explore forever. The timer creates urgency and a natural endpoint if the player is struggling with hazards. 45s is enough for a careful run but not enough to collect everything if you're slow.

### Workshop: Centered Adventurers
**Changed:** Adventurers now spread across 80% of the room width, centered. Was: hardcoded `60 + i * spacing` starting from the left edge.

**Intention:** Adventurers were bunched on the left side of the room. Now they're centered, matching the symmetric station layout.

### Workshop: Resolution-Independent Station Positions
**Changed:** Station positions now use `x_frac * ROOM_W` fractions (0.10, 0.29, 0.48, 0.67, 0.86) instead of hardcoded pixel values (50, 140, 230, 320, 410). If the resolution changes, stations reposition proportionally.

**Intention:** Hardcoded pixel positions only work at 480x270. Using fractions means the layout scales to any resolution — a step toward resolution independence.

### Grind Minigame: Per-Item Contact Positions
**Changed:** Each weapon type now has a unique contact point and tilt on the grindstone:
- **Sword** — blade tip at upper-left of wheel, tilt -0.5 rad (blade points toward wheel)
- **Staff** — tip at upper-left, steeper tilt -0.7 rad
- **Helm** — rim at top of wheel (12 o'clock), flat (0 tilt)
- **Robe** — hem at top of wheel, slight tilt 0.2 rad

**Intention:** The sword was grinding at its hilt, not its blade. Each weapon type has a different "business end" that should touch the wheel. The per-type positions make the grinding animation read correctly for each item.

### Juice Wiring Audit
**Changed:** Verified all `Juice.` calls are correctly wired: `add_trauma`, `hit_stop`, `spawn_particles`, `draw_particles`, `update_particles`, `trail_sample`, `trail_draw`, `trail_clear`, `trail_phasing`, `get_shake_offset`, `clear_particles`. The ghost trail now draws as colored rects (not texture_rect with modulate) which fixed the invisible-trail bug. Trail alpha raised to 0.65/0.85 (was 0.4/0.6).

**Intention:** The trail was invisible because `draw_texture_rect` with a modulate alpha wasn't rendering against the dungeon background. Switching to solid colored rects + raising the alpha made the trail consistently visible.

---

## v0.6 — Death-Cause Affliction + First-Run Sim + Name Randomization (2026-07-07)

### Death-Cause Affliction Layer 2
**Changed:** `Weapon.roll_affliction_from_death(enemy_type, current_wear)` — when a party member dies, the enemy type that killed them shapes the weapon's degradation. Slime → DAMAGED (corrosive), skeleton → BROKEN (blunt), bat → WORN (swarm). Always adds 1 unexorcised_death. Battle tracks `unit.killed_by` and passes it to `apply_combat_damage`.

**Intention:** Different enemies leave different marks on gear. A weapon from a slime kill needs grind (acid etching); from a skeleton kill needs forge (shattered). Gives salvage a tactical read.

### First-Run Simulation
**Changed:** `Weapon.simulate_first_party_deaths()` generates 2-3 random party members with random names, classes, and death causes. The gate scene uses these for grave markers instead of hardcoded "Toren" and "Yselde."

**Intention:** Every new run now has different predecessor graves. Explains why the arsenal is full of battered gear — the simulation shows who died and to what.

### Randomized Party Names
**Changed:** `_random_name` shuffles a 20-name pool and avoids repeating the last 6 names. Was deterministic (same names in same order every run).

**Intention:** Party members always had the same names (Cael, Mira) in the same order. Now each run has a different party roster.

### Resume Button Fix
**Changed:** Pause overlay and buttons set to `process_mode = PROCESS_MODE_ALWAYS` so they receive clicks while the tree is paused. `main.gd` also set to `ALWAYS` so ESC can unpause.

**Intention:** The resume button was frozen when paused because Godot pauses all node processing by default. Without `ALWAYS`, the buttons couldn't receive clicks.

### Door Sprite Flipped
**Changed:** New `door_flipped` sprite (handle at top, bottom highlight) used in gate scene since the gate is now at the bottom.

**Intention:** The door was upside-down after the gate was moved to the bottom. The flipped sprite reads correctly as "entering from above."

### Menu Hint Centering
**Changed:** Title, subtitle, and hint span full 480px viewport width with `horizontal_alignment = CENTER`.

**Intention:** The hint text was shifted right because the label width (300px) didn't match the viewport (480px). Full-width labels center correctly regardless of text length.

### Reduced Direction-Change Slowdown
**Changed:** Deceleration rate is 60% of acceleration rate (was 100%). Full accel when input present; 60% decel when no input.

**Intention:** Direction changes felt sluggish because the decel rate matched the accel rate. Now the ghost coasts slightly on release but changes direction responsively.

---

## v0.5 — Type-Weighted Affliction System (2026-07-07)

### Type-Weighted Affliction
**Changed:** `Weapon.roll_affliction(type)` — single source of truth for gear generation. Wear state weights: all types 30% baseline DAMAGED; armor (helm/robe) +5 BROKEN. Haunt chance: mage gear (staff/robe) 35%, warrior gear (sword/helm) 15%. Haunt is orthogonal to wear (a weapon can be DAMAGED AND haunted).

**Intention:** Starter weapons were hardcoded (guaranteed haunted robe). Now each weapon rolls independently with type-appropriate biases. Mage gear is more likely to be haunted; armor is slightly more likely to be shattered; everything has a consistent grind baseline.

---

## v0.4 — Priority 1 Polish (2026-07-07)

### ESC Pause
**Changed:** ESC opens a pause overlay (Resume / Quit to Menu) instead of quitting to menu. `get_tree().paused = true` freezes all phases. Run state fully preserved.

### Phase Meter Conservation
**Changed:** Manual phase cancel banks remaining time. Banked time is applied to the next activation.

### Gate Flipped
**Changed:** Gate moved to bottom of screen, ghost enters from top. Reads as "descending into the dungeon."

### Out-of-Bounds Skybox
**Changed:** Dark navy vertical gradient with faint stars replaces flat gray wall beyond the play area.

### Grind Weapon Static
**Changed:** Weapon no longer rotates with the wheel. Positioned at a fixed angle against the wheel rim.

### Haunt Rebalance
**Changed:** Starter weapons and salvage weapons use weighted rolls for haunt and wear state instead of hardcoded values.

---

## v0.3 — Priority 1: Movement Feel + Phase Verb (2026-07-06)

### Movement Feel
**Changed:** Tighter accel (220, was 300), velocity-driven camera bob, ghost trail (4 fading afterimages), footstep SFX.

### Phase Verb
**Changed:** SPACE to phase (incorporeal): 2x speed, semi-transparent, bypasses fire/spikes in salvage, slows enemies in battle. 1.5s duration, 4s cooldown, 1 shard cost. New `phase` input action, removed SPACE from `interact`.

### Bug Fixes
**Changed:** Fixed battle phase verb input handling (was using `InputEventKey`, now uses `is_action_just_pressed`). Fixed oil_grindstone name position and weapon_angle. Removed dead `qte_cooldown` variable.
