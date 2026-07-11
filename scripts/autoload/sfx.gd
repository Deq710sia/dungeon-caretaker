extends Node
## SFX — procedural retro sound effects with ZERO audio files.
## Pre-renders short PCM samples into AudioStreamWAV at startup,
## then plays them through a round-robin voice pool with pitch jitter.
## Based on research: AudioStreamWAV with raw PackedByteArray is the
## correct approach for Godot 4 (AudioStreamGenerator has latency issues
## in GDScript).

const SR := 44100
const VOICES := 8

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _cursor := 0

func _ready() -> void:
        _build_buses()
        _prerender_all()
        for i in VOICES:
                var p := AudioStreamPlayer.new()
                p.bus = "SFX"
                add_child(p)
                _players.append(p)

func _build_buses() -> void:
        if AudioServer.get_bus_count() == 1:
                AudioServer.add_bus()
                AudioServer.set_bus_name(1, "SFX")
                AudioServer.set_bus_send(1, "Master")
                AudioServer.add_bus()
                AudioServer.set_bus_name(2, "Music")
                AudioServer.set_bus_send(2, "Master")

func play(p_name: String, pitch := 1.0, vol_db := 0.0, jitter := 0.06) -> void:
        if not _streams.has(p_name):
                return
        var p := _players[_cursor]
        _cursor = (_cursor + 1) % VOICES
        p.stream = _streams[p_name]
        p.pitch_scale = clampf(pitch + randf_range(-jitter, jitter), 0.2, 4.0)
        p.volume_db = vol_db
        p.play()

func _render(gen: Callable) -> AudioStreamWAV:
        var s: PackedFloat32Array = gen.call()
        var bytes := PackedByteArray()
        bytes.resize(s.size() * 2)
        for i in s.size():
                bytes.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767))
        var w := AudioStreamWAV.new()
        w.format = AudioStreamWAV.FORMAT_16_BITS
        w.mix_rate = SR
        w.stereo = false
        w.data = bytes
        return w

func _env(n: int, atk: float, dec: float) -> PackedFloat32Array:
        var e := PackedFloat32Array()
        e.resize(n)
        var a := maxi(1, int(atk * SR))
        var d := maxi(1, int(dec * SR))
        for i in n:
                e[i] = (float(i) / a) if i < a else exp(-(i - a) / float(d) * 6.0)
        return e

func _prerender_all() -> void:
        _streams["blip"] = _render(_blip)
        _streams["chime"] = _render(_chime)
        _streams["thud"] = _render(_thud)
        _streams["hit"] = _render(_hit)
        _streams["shatter"] = _render(_shatter)
        _streams["coin"] = _render(_coin)
        _streams["select"] = _render(_select)
        _streams["deny"] = _render(_deny)
        _streams["bell"] = _render(_bell)
        _streams["death"] = _render(_death)
        _streams["repair"] = _render(_repair)
        _streams["recruit"] = _render(_recruit)
        # DESIGN_PLAN 1A: soft "whoosh" footfall tied to velocity. Short low blip,
        # pitched low enough to read as a spectral footfall rather than a UI tick.
        _streams["footstep"] = _render(_footstep)
        # DESIGN_PLAN 1B: Phase verb SFX. Descending sweep on enter (ghost going
        # incorporeal), soft rising chime on exit (snapping back to corporeal).
        _streams["phase_in"] = _render(_phase_in)
        _streams["phase_out"] = _render(_phase_out)
        # Pulse verb (v0.17+): tap-to-fire. Only pulse_release is used.
        _streams["pulse_release"] = _render(_pulse_release)

func _blip() -> PackedFloat32Array:
        # UI pulse tick — SHORT square-wave blip with quick decay. Bright, snappy,
        # distinct from sustained chord sounds (chime/bell/coin). Square wave gives
        # it the classic NES UI tick character — instantly identifiable as "tick".
        # Note: A5 (880Hz), 0.08s, no chord.
        var n := int(0.08 * SR); var e := _env(n, 0.002, 0.04); var o := PackedFloat32Array(); o.resize(n)
        var ph := 0.0
        for i in n:
                ph += 880.0 / SR
                # Square wave — sharp, buzzy, reads as UI not musical
                var sq: float = 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
                o[i] = sq * e[i] * 0.22
        return o

func _chime() -> PackedFloat32Array:
        # Maj9 chord-timbre (warm, cushion-like). BRIGHT voicing: root + 9th + 3rd(oct up) + 5th(oct up).
        # A5(880) + B5(988) + C#6(1109) + E6(1319). Sine layers with amplitude scaling.
        # Brighter than v0.11 (was 440-659, now 880-1319) so it sits in a distinct register
        # from bell/coin/recruit.
        var n := int(0.5 * SR); var e := _env(n, 0.01, 0.4); var o := PackedFloat32Array(); o.resize(n)
        var freqs := [880.0, 988.0, 1109.0, 1319.0]
        var amps := [0.35, 0.20, 0.15, 0.10]
        var phases: Array = [0.0, 0.0, 0.0, 0.0]
        for i in n:
                var sample := 0.0
                for j in freqs.size():
                        var drift: float = sin(float(i) / SR * 5.0 + j) * 0.0012
                        phases[j] += freqs[j] * (1.0 + drift) / SR
                        sample += sin(phases[j]) * amps[j]
                o[i] = sample * e[i] * 0.2
        return o

func _thud() -> PackedFloat32Array:
        # Heavy low impact — LOW triangle wave (80→50Hz) + noise burst at attack.
        # Triangle wave for soft percussion (NES technique). Lowest frequency of all
        # SFX — sits in its own sub-bass register, distinct from hit (mid) and
        # shatter (high). 0.18s with sharp attack noise for the impact transient.
        var n := int(0.18 * SR); var e := _env(n, 0.002, 0.06); var o := PackedFloat32Array(); o.resize(n)
        var ph := 0.0
        for i in n:
                ph += (80.0 - 30.0*float(i)/n) / SR
                var tri: float = 2.0 * abs(2.0 * fmod(ph, 1.0) - 1.0) - 1.0
                # Noise only in first 30ms (attack transient) then decays
                var noise_amt: float = 0.5 * exp(-float(i) / (0.03 * SR))
                o[i] = (tri * 0.7 + randf_range(-1,1) * noise_amt) * e[i] * 0.55
        return o

func _hit() -> PackedFloat32Array:
        # Sharp mid impact — SAW wave (not sine) + noise burst. Saw waves have
        # a buzzy edge that reads as "hit" / "strike" — distinct from the warm
        # sine chords and the soft triangle thud. Notes: A3 (220Hz) descending.
        # Sharp attack (1ms) for the impact transient, noise decays fast.
        var n := int(0.14 * SR); var e := _env(n, 0.001, 0.04); var o := PackedFloat32Array(); o.resize(n)
        var ph := 0.0
        for i in n:
                var f := 220.0 - 110.0*float(i)/n
                ph += f / SR
                # Sawtooth: 2*(ph - floor(ph+0.5)) — buzzy, reads as impact
                var saw: float = 2.0 * (ph - floor(ph + 0.5))
                # Noise transient — strongest at attack, decays in 25ms
                var noise_amt: float = 0.5 * exp(-float(i) / (0.025 * SR))
                o[i] = (saw * 0.5 + randf_range(-1,1) * noise_amt) * e[i] * 0.45
        return o

func _shatter() -> PackedFloat32Array:
        # Glass break — HIGH noise burst + descending sine arpeggio. The speder2
        # version removed noise entirely (pure arpeggio) which made it sound like a
        # melody, not a break. Restored noise for the glassy crunch, kept the
        # crystalline arpeggio underneath for sparkle. Highest frequency of all
        # SFX (2000→880Hz) — distinct register.
        var n := int(0.35 * SR); var o := PackedFloat32Array(); o.resize(n)
        var notes := [2093.0, 1568.0, 1319.0, 880.0]
        var note_len := n / notes.size()
        for i in n:
                var note_idx := i / note_len
                if note_idx >= notes.size():
                        note_idx = notes.size() - 1
                var f: float = notes[note_idx]
                var local_i := i - note_idx * note_len
                var e_val: float = exp(-float(local_i) / float(note_len) * 4.0)
                var t := float(i)/SR
                # Noise burst — strongest at the start of each note, decays fast.
                # Gives the "crunch" of glass breaking, not just a melody.
                var noise_amt: float = 0.5 * exp(-float(local_i) / (0.02 * SR))
                o[i] = (sin(TAU * f * t) * 0.25 + randf_range(-1,1) * noise_amt) * e_val * 0.45
        return o

func _coin() -> PackedFloat32Array:
        # Bright quick two-tone pickup — bouncy sine glissando. Distinct from
        # chime (sustained chord) and bell (inharmonic sustained) by being SHORT
        # (0.12s) and a quick two-tone bend (B5→E6, 988→1319Hz). Reads as a
        # classic coin/pickup blip.
        var n := int(0.12 * SR); var e := _env(n, 0.002, 0.06); var o := PackedFloat32Array(); o.resize(n)
        var ph := 0.0
        for i in n:
                # Quick bend from 988 to 1319 in first 40ms, then hold
                var f: float = 988.0 + (1319.0 - 988.0) * minf(1.0, float(i) / (0.04 * SR))
                ph += f / SR
                o[i] = sin(ph) * e[i] * 0.28
        return o

func _select() -> PackedFloat32Array:
        var n := int(0.05 * SR); var e := _env(n, 0.002, 0.02); var o := PackedFloat32Array(); o.resize(n)
        for i in n:
                o[i] = sin(TAU*1200*float(i)/SR) * e[i] * 0.25
        return o

func _deny() -> PackedFloat32Array:
        # Error / blocked action — descending SQUARE wave (not sine). Square waves
        # have a buzzy edge that reads as "wrong" / "no". The speder2 sine version
        # was too gentle — sounded like a melody, not an error. Two quick descending
        # notes (E3→A2, 165→110Hz) for a clear "denied" cadence.
        var n := int(0.2 * SR); var e := _env(n, 0.005, 0.12); var o := PackedFloat32Array(); o.resize(n)
        var ph := 0.0
        var split := n / 2
        for i in n:
                var f: float = 165.0 if i < split else 110.0
                ph += f / SR
                var sq: float = 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
                o[i] = sq * e[i] * 0.22
        return o

func _bell() -> PackedFloat32Array:
        # Sustained bell — INHARMONIC partials (not integer ratios) for a true
        # bell character. Speder2 used harmonic ratios which made it sound like a
        # sustained organ chord. Real bells use inharmonic partials (1.0, 2.0, 2.4,
        # 3.1, 4.2) which create the metallic ring. Notes: C5(523) + inharmonics.
        var n := int(0.8 * SR); var e := _env(n, 0.01, 0.6); var o := PackedFloat32Array(); o.resize(n)
        var freqs := [523.0, 1046.0, 1255.0, 1621.0, 2197.0]  # root + inharmonic partials
        var amps := [0.4, 0.25, 0.18, 0.12, 0.08]  # higher partials quieter
        var phases: Array = [0.0, 0.0, 0.0, 0.0, 0.0]
        for i in n:
                var sample := 0.0
                for j in freqs.size():
                        # Higher partials decay faster (bell character)
                        var partial_decay: float = exp(-float(i) / (0.3 * SR * (1.0 + j * 0.5)))
                        phases[j] += freqs[j] / SR
                        sample += sin(phases[j]) * amps[j] * partial_decay
                o[i] = sample * e[i] * 0.2
        return o

func _death() -> PackedFloat32Array:
        # Party death — LOW descending drone + sub-bass + noise swell. Distinct
        # from shatter (high arpeggio) by being LOW (220→55Hz) and DRAMATIC.
        # Speder2 arpeggio was too melodic — death should feel heavy and final.
        # Triangle wave for the drone (soft, ominous), sub-bass sine for weight,
        # noise swell for the impact. 0.6s.
        var n := int(0.6 * SR); var e := _env(n, 0.01, 0.4); var o := PackedFloat32Array(); o.resize(n)
        var ph_tri := 0.0
        var ph_sub := 0.0
        for i in n:
                # Triangle drone descending A3→A1 (220→55Hz)
                ph_tri += (220.0 - 165.0*float(i)/n) / SR
                var tri: float = 2.0 * abs(2.0 * fmod(ph_tri, 1.0) - 1.0) - 1.0
                # Sub-bass sine at half the drone freq (weight)
                ph_sub += (110.0 - 82.0*float(i)/n) / SR
                var sub: float = sin(ph_sub)
                # Noise swell — builds in the first 100ms then decays
                var noise_amt: float = 0.3 * exp(-float(i) / (0.15 * SR))
                o[i] = (tri * 0.4 + sub * 0.3 + randf_range(-1,1) * noise_amt) * e[i] * 0.45
        return o

func _repair() -> PackedFloat32Array:
        # Mechanical hammering — 4 quick metallic taps, NOT a sustained chord.
        # Speder2 made this a sine chord which sounded like recruit/bell. Repair
        # should sound like hammer-on-anvil: sharp attack, mid-high metallic ring,
        # repeated. Each tap: saw wave 880Hz + noise burst, 60ms, 4 taps at 80ms
        # intervals. Reads as mechanical work, not music.
        var n := int(0.32 * SR); var o := PackedFloat32Array(); o.resize(n)
        var tap_interval := int(0.08 * SR)
        var tap_len := int(0.06 * SR)
        var tap_count := 4
        for i in n:
                var tap_idx := i / tap_interval
                if tap_idx >= tap_count:
                        break
                var local_i := i - tap_idx * tap_interval
                if local_i >= tap_len:
                        continue
                # Sharp attack, fast decay
                var e_val: float = exp(-float(local_i) / (0.02 * SR))
                var ph: float = 880.0 * float(local_i) / SR
                var saw: float = 2.0 * (ph - floor(ph + 0.5))
                # Noise burst at the very start (hammer strike)
                var noise_amt: float = 0.6 * exp(-float(local_i) / (0.005 * SR))
                o[i] = (saw * 0.4 + randf_range(-1,1) * noise_amt) * e_val * 0.3
        return o

func _recruit() -> PackedFloat32Array:
        # Welcoming two-tone sine glissando (C5→G5, 523→784Hz). Brighter and
        # more bouncy than v0.11. Distinct from coin (988→1319) and chime (880+)
        # by sitting in the 523-784 range with a slow bend. Reads as a friendly
        # "welcome aboard" cue.
        var n := int(0.4 * SR); var e := _env(n, 0.01, 0.3); var o := PackedFloat32Array(); o.resize(n)
        var ph := 0.0
        for i in n:
                # Slow bend from 523 to 784 over the full duration
                var f: float = 523.0 + (784.0 - 523.0) * (float(i) / n)
                ph += f / SR
                o[i] = sin(ph) * e[i] * 0.25
        return o

func _footstep() -> PackedFloat32Array:
        # Soft low blip, ~80ms, low-passed sine + a touch of noise. Reads as a
        # ghostly footfall rather than a UI tick. Pitch is jittered by the
        # caller (SFX.play) so consecutive footsteps don't sound mechanical.
        var n := int(0.08 * SR); var e := _env(n, 0.003, 0.04); var o := PackedFloat32Array(); o.resize(n)
        var ph := 0.0
        for i in n:
                ph += (180.0 - 60.0 * float(i) / n) / SR
                o[i] = (sin(ph) * 0.6 + randf_range(-1, 1) * 0.25) * e[i] * 0.18
        return o

func _phase_in() -> PackedFloat32Array:
        # m6 chord-timbre (anxious, transparent). Descending sweep with layered intervals.
        # Root descends 880→220Hz. Layered: min3rd (1.189x), tritone (1.414x), 5th (1.498x).
        # The tritone creates the "going incorporeal" unease. Slow attack (15ms) lets the
        # dissonance read as texture. Extension amplitudes scaled down (Speder2 technique).
        var n := int(0.25 * SR); var e := _env(n, 0.015, 0.18); var o := PackedFloat32Array(); o.resize(n)
        var phases: Array = [0.0, 0.0, 0.0, 0.0]
        var ratios := [1.0, 1.189, 1.414, 1.498]  # root, m3, tritone, 5th
        var amps := [0.4, 0.15, 0.08, 0.12]  # tritone quietest (most dissonant)
        for i in n:
                var base_f: float = 880.0 - 660.0 * (float(i) / n)
                var sample := 0.0
                for j in ratios.size():
                        var drift: float = sin(float(i) / SR * 4.0 + j) * 0.0015
                        phases[j] += base_f * ratios[j] * (1.0 + drift) / SR
                        sample += sin(phases[j]) * amps[j]
                o[i] = sample * e[i] * 0.3
        return o

func _phase_out() -> PackedFloat32Array:
        # mM7 chord-timbre (unstable but crisp). Rising sweep 330→660Hz.
        # Layered: min3rd (1.189x), 5th (1.498x), maj7 (1.888x).
        # The maj7 against the min3rd creates the "snapping back" tension.
        # Faster attack than phase_in (5ms) for a crisper return.
        var n := int(0.20 * SR); var e := _env(n, 0.005, 0.14); var o := PackedFloat32Array(); o.resize(n)
        var phases: Array = [0.0, 0.0, 0.0, 0.0]
        var ratios := [1.0, 1.189, 1.498, 1.888]  # root, m3, 5th, maj7
        var amps := [0.4, 0.18, 0.12, 0.08]  # maj7 quietest (most dissonant)
        for i in n:
                var base_f: float = 330.0 + 330.0 * (float(i) / n)
                var sample := 0.0
                for j in ratios.size():
                        var drift: float = sin(float(i) / SR * 6.0 + j) * 0.0012
                        phases[j] += base_f * ratios[j] * (1.0 + drift) / SR
                        sample += sin(phases[j]) * amps[j]
                o[i] = sample * e[i] * 0.25
        return o

func _pulse_release() -> PackedFloat32Array:
        # Release burst — maj9 chord-timbre (speder2 warm). Lower-pitched than
        # blip/chime: root at A3 (220Hz) so it reads as a "ghost surge" not a UI
        # tick. Voicing: A3(220) + B3(247) + C#4(277) + E4(330) + B4(494, 9th up).
        # Quick attack (3ms) for the burst transient, ~0.4s decay. The 9th up high
        # adds the "shimmer" of released spectral energy.
        var n := int(0.4 * SR); var e := _env(n, 0.003, 0.18); var o := PackedFloat32Array(); o.resize(n)
        var freqs := [220.0, 247.0, 277.0, 330.0, 494.0]  # root, M2, M3, 5th, 9th(oct up)
        var amps := [0.35, 0.18, 0.15, 0.12, 0.08]  # 9th quietest (speder2 amplitude scaling)
        var phases: Array = [0.0, 0.0, 0.0, 0.0, 0.0]
        for i in n:
                var sample := 0.0
                for j in freqs.size():
                        # Micro-pitch drift to prevent static phase
                        var drift: float = sin(float(i) / SR * 4.0 + j) * 0.0014
                        phases[j] += freqs[j] * (1.0 + drift) / SR
                        sample += sin(phases[j]) * amps[j]
                o[i] = sample * e[i] * 0.28
        return o
