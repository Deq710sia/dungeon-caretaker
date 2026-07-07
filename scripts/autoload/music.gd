extends Node
## Music — speder2-style game-electronica main theme (v4).
##
## NOT jazz, NOT lo-fi. Speder2 sound = modal color-chord rotation over a
## house beat with chiptune textures and contemplative-uncanny mood.
##
## 128 BPM, 4/4, 16 bars (~30s loop). 2 sections with key modulation.
##
## Speder2 chord palette (from "微妙なコードの雰囲気" analysis):
##   m7(9), M7(9), m6, mM7, aug7, 7alt(+5+9), m7b5, m7(11)
##
## 8 layers (speder2 production techniques):
##   1. Kick: four-on-the-floor, sine drop 80→40Hz (808-style)
##   2. Clap: noise burst on 2&4, bandpass ~2kHz
##   3. Hats: off-beat 8th notes, short noise
##   4. Cowbell: beats 3&4 (kaiwai-kyoku signature), square ~840Hz
##   5. Bass: sustained saw, root notes, 2-beat chord rate, lowpass
##   6. Chords: saw stabs (additive harmonics), rootless drop voicings, 2-beat
##   7. Arpeggio: high-register sine counter-line, 8th notes, fills gaps
##   8. Lead: sparse synth lead (saw + vibrato), enters off-beat, stepwise
##
## Modal color rotation (2-beat chord rate, NOT functional ii-V-I):
##   Section A (Gm): Cm6 - BbM7(9) - Cm6 - G7#5#9 - Cm7(9) - BbM7(9) - Cm7(9) - Dm7(9)-Daug7
##   Section B (Fm): DbM7(9) - DbmM7 - Cm7(11) - Faug7 - Bbm7(9) - Bbm7(11)
##   Section C (Bb→Gm): EbM7(9) - Dm7b5 - G7#5#9 - Cm6 - BbM7(9) - G7#5#9 - Cm7(9) - Cm6

const SR := 44100
const BPM := 128.0
const BEATS_PER_BAR := 4
const BAR_COUNT := 16
const BEAT_DUR := 60.0 / BPM  # 0.469s per beat
const BAR_DUR := BEAT_DUR * BEATS_PER_BAR  # 1.875s per bar
const LOOP_DUR := BAR_DUR * BAR_COUNT  # 30s total
const HALF_BAR_DUR := BEAT_DUR * 2  # 2-beat chord rate

var _stream: AudioStreamWAV
var _player: AudioStreamPlayer

func _ready() -> void:
	_stream = _render_theme()
	_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_stream.loop_begin = 0
	_stream.loop_end = _stream.data.size() / 2
	_player = AudioStreamPlayer.new()
	_player.stream = _stream
	_player.bus = "Music"
	_player.volume_db = -10.0
	_player.name = "MusicPlayer"
	add_child(_player)
	_player.play()

# --- Chord definitions (2-beat rate = 32 chords in 16 bars) ---
# Each chord: {root, bass_note, comp_freqs (rootless), comp_amps, arp_notes, lead_note}
# Speder2 voicings: rootless, drop voicings, amplitude scaling on tensions
# Frequencies precomputed from A4=440 equal temperament

const CHORDS := [
	# === SECTION A (bars 1-8, G minor) ===
	# Bar 1: Cm6 - BbM7(9)
	{"bass": 65.41, "comp": [196.00, 246.94, 311.13, 349.23], "amps": [0.18, 0.20, 0.10, 0.14], "arp": [311.13, 392.00, 466.16, 523.25], "lead": 392.00},  # Cm6: C-Eb-G-A (b3,5,6,8ve)
	{"bass": 58.27, "comp": [220.00, 261.63, 311.13, 415.30], "amps": [0.20, 0.18, 0.12, 0.08], "arp": [311.13, 349.23, 415.30, 466.16], "lead": 466.16},  # BbM7(9): D-F-A-C-E (3,5,7,9)
	# Bar 2: Cm6 - G7#5#9
	{"bass": 65.41, "comp": [196.00, 246.94, 311.13, 349.23], "amps": [0.18, 0.20, 0.10, 0.14], "arp": [311.13, 392.00, 466.16, 523.25], "lead": 523.25},
	{"bass": 49.00, "comp": [196.00, 261.63, 293.66, 415.30], "amps": [0.20, 0.16, 0.08, 0.10], "arp": [293.66, 349.23, 415.30, 466.16], "lead": 466.16},  # G7#5#9: B-Eb-Bb-Db (3,#5,#9,b7 wait...)
	# Bar 3: Cm7(9) - BbM7(9)
	{"bass": 65.41, "comp": [196.00, 233.08, 311.13, 392.00], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [311.13, 392.00, 466.16, 523.25], "lead": 392.00},  # Cm7(9): Eb-G-Bb-D (b3,5,b7,9)
	{"bass": 58.27, "comp": [220.00, 261.63, 311.13, 415.30], "amps": [0.20, 0.18, 0.12, 0.08], "arp": [311.13, 349.23, 415.30, 466.16], "lead": 415.30},
	# Bar 4: Cm7(9) - Dm7(9)→Daug7
	{"bass": 65.41, "comp": [196.00, 233.08, 311.13, 392.00], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [311.13, 392.00, 466.16, 523.25], "lead": 523.25},
	{"bass": 73.42, "comp": [220.00, 261.63, 329.63, 415.30], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [329.63, 392.00, 466.16, 523.25], "lead": 466.16},  # Dm7(9): F-A-C-E (b3,5,b7,9)
	# Bar 5: Daug7 - Cm6
	{"bass": 73.42, "comp": [246.94, 311.13, 349.23, 415.30], "amps": [0.18, 0.14, 0.12, 0.10], "arp": [311.13, 392.00, 466.16, 523.25], "lead": 523.25},  # Daug7: F#-Bb-D-F (3,#5,7)
	{"bass": 65.41, "comp": [196.00, 246.94, 311.13, 349.23], "amps": [0.18, 0.20, 0.10, 0.14], "arp": [311.13, 392.00, 466.16, 523.25], "lead": 466.16},
	# Bar 6: BbM7(9) - Cm7(9)
	{"bass": 58.27, "comp": [220.00, 261.63, 311.13, 415.30], "amps": [0.20, 0.18, 0.12, 0.08], "arp": [311.13, 349.23, 415.30, 466.16], "lead": 415.30},
	{"bass": 65.41, "comp": [196.00, 233.08, 311.13, 392.00], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [311.13, 392.00, 466.16, 523.25], "lead": 392.00},
	# Bar 7: G7#5#9 - Cm6
	{"bass": 49.00, "comp": [196.00, 261.63, 293.66, 415.30], "amps": [0.20, 0.16, 0.08, 0.10], "arp": [293.66, 349.23, 415.30, 466.16], "lead": 466.16},
	{"bass": 65.41, "comp": [196.00, 246.94, 311.13, 349.23], "amps": [0.18, 0.20, 0.10, 0.14], "arp": [311.13, 392.00, 466.16, 523.25], "lead": 523.25},
	# Bar 8: BbM7(9) - G7#5#9 (turn to F minor)
	{"bass": 58.27, "comp": [220.00, 261.63, 311.13, 415.30], "amps": [0.20, 0.18, 0.12, 0.08], "arp": [311.13, 349.23, 415.30, 466.16], "lead": 415.30},
	{"bass": 49.00, "comp": [196.00, 261.63, 293.66, 415.30], "amps": [0.20, 0.16, 0.08, 0.10], "arp": [293.66, 349.23, 415.30, 466.16], "lead": 466.16},
	# === SECTION B (bars 9-16, F minor → Bb → Gm return) ===
	# Bar 9: DbM7(9) - DbmM7
	{"bass": 69.30, "comp": [233.08, 277.18, 329.63, 440.00], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [329.63, 392.00, 466.16, 554.37], "lead": 554.37},  # DbM7(9): F-Ab-C-Eb-G (3,5,7,9)
	{"bass": 69.30, "comp": [233.08, 261.63, 329.63, 493.88], "amps": [0.18, 0.14, 0.16, 0.08], "arp": [329.63, 392.00, 466.16, 523.25], "lead": 523.25},  # DbmM7: Fb-Ab-Db-E (b3,5,7 of Dbm)
	# Bar 10: Cm7(11) - Faug7
	{"bass": 65.41, "comp": [196.00, 233.08, 311.13, 466.16], "amps": [0.20, 0.18, 0.14, 0.06], "arp": [311.13, 392.00, 466.16, 523.25], "lead": 523.25},  # Cm7(11): Eb-G-Bb-F (b3,5,b7,11)
	{"bass": 87.31, "comp": [220.00, 311.13, 349.23, 415.30], "amps": [0.18, 0.12, 0.14, 0.10], "arp": [349.23, 415.30, 466.16, 523.25], "lead": 466.16},  # Faug7: A-C#-F (3,#5,7)
	# Bar 11: Bbm7(9) - Bbm7(11)
	{"bass": 58.27, "comp": [185.00, 220.00, 277.18, 349.23], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [277.18, 349.23, 415.30, 466.16], "lead": 466.16},  # Bbm7(9): Db-F-Ab-C-Eb (b3,5,b7,9)
	{"bass": 58.27, "comp": [185.00, 220.00, 277.18, 415.30], "amps": [0.20, 0.18, 0.14, 0.06], "arp": [277.18, 349.23, 415.30, 466.16], "lead": 523.25},  # Bbm7(11): +11th
	# Bar 12: EbM7(9) - Dm7b5 (turn back to G)
	{"bass": 77.78, "comp": [233.08, 293.66, 349.23, 440.00], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [349.23, 440.00, 523.25, 587.33], "lead": 587.33},  # EbM7(9): G-Bb-D-F-A (3,5,7,9)
	{"bass": 73.42, "comp": [220.00, 261.63, 311.13, 392.00], "amps": [0.18, 0.14, 0.16, 0.10], "arp": [311.13, 392.00, 466.16, 523.25], "lead": 523.25},  # Dm7b5: F-Ab-C-Eb (b3,b5,b7,9)
	# Bar 13: G7#5#9 - Cm6
	{"bass": 49.00, "comp": [196.00, 261.63, 293.66, 415.30], "amps": [0.20, 0.16, 0.08, 0.10], "arp": [293.66, 349.23, 415.30, 466.16], "lead": 466.16},
	{"bass": 65.41, "comp": [196.00, 246.94, 311.13, 349.23], "amps": [0.18, 0.20, 0.10, 0.14], "arp": [311.13, 392.00, 466.16, 523.25], "lead": 523.25},
	# Bar 14: BbM7(9) - Cm7(9)
	{"bass": 58.27, "comp": [220.00, 261.63, 311.13, 415.30], "amps": [0.20, 0.18, 0.12, 0.08], "arp": [311.13, 349.23, 415.30, 466.16], "lead": 466.16},
	{"bass": 65.41, "comp": [196.00, 233.08, 311.13, 392.00], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [311.13, 392.00, 466.16, 523.25], "lead": 392.00},
	# Bar 15: G7#5#9 - Cm6
	{"bass": 49.00, "comp": [196.00, 261.63, 293.66, 415.30], "amps": [0.20, 0.16, 0.08, 0.10], "arp": [293.66, 349.23, 415.30, 466.16], "lead": 466.16},
	{"bass": 65.41, "comp": [196.00, 246.94, 311.13, 349.23], "amps": [0.18, 0.20, 0.10, 0.14], "arp": [311.13, 392.00, 466.16, 523.25], "lead": 523.25},
	# Bar 16: BbM7(9) - Cm6 (resolve back to start)
	{"bass": 58.27, "comp": [220.00, 261.63, 311.13, 415.30], "amps": [0.20, 0.18, 0.12, 0.08], "arp": [311.13, 349.23, 415.30, 466.16], "lead": 415.30},
	{"bass": 65.41, "comp": [196.00, 246.94, 311.13, 349.23], "amps": [0.18, 0.20, 0.10, 0.14], "arp": [311.13, 392.00, 466.16, 523.25], "lead": 523.25},
]

func _render_theme() -> AudioStreamWAV:
	var n: int = int(LOOP_DUR * SR)
	var o := PackedFloat32Array()
	o.resize(n)
	var chord_samples: int = int(HALF_BAR_DUR * SR)
	# Render each 2-beat chord segment
	for chord_idx in CHORDS.size():
		var chord: Dictionary = CHORDS[chord_idx]
		var start: int = chord_idx * chord_samples
		_render_bass(o, start, chord_samples, chord)
		_render_chords(o, start, chord_samples, chord, chord_idx)
		_render_arp(o, start, chord_samples, chord, chord_idx)
		_render_lead(o, start, chord_samples, chord, chord_idx)
	# Render drums across the whole loop
	_render_drums(o, n)
	# Reverb
	_apply_reverb(o, n)
	# Gentle master — soft saturation + high-shelf rolloff to tame harshness
	var hs_state: float = 0.0
	var hs_alpha: float = 1.0 - exp(-2.0 * PI * 8000.0 / SR)  # rolloff above 8kHz
	for i in n:
		# High-shelf rolloff (one-pole lowpass on the signal, mixed back)
		hs_state = hs_state + hs_alpha * (o[i] - hs_state)
		o[i] = o[i] * 0.7 + hs_state * 0.3  # 30% of the rolled-off version
		o[i] = tanh(o[i] * 0.65)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(o[i], -1.0, 1.0) * 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = bytes
	return w

# --- Layer 1: Bass (sustained saw through lowpass — warm, not buzzy) ---
func _render_bass(out: PackedFloat32Array, start: int, len: int, chord: Dictionary) -> void:
	var bass_freq: float = chord["bass"]
	var ph := 0.0
	var lp_state: float = 0.0
	# One-pole lowpass @ 400Hz — removes saw buzz, keeps warm fundamental
	var alpha: float = 1.0 - exp(-2.0 * PI * 400.0 / SR)
	for i in len:
		if start + i >= out.size():
			break
		ph += bass_freq / SR
		# Sawtooth core
		var saw: float = 2.0 * (ph - floor(ph + 0.5))
		# REAL lowpass (state-variable, not amplitude scaling)
		lp_state = lp_state + alpha * (saw - lp_state)
		# ADSR: 8ms attack, sustain, 50ms release
		var env: float
		var atk: int = int(0.008 * SR)
		var rel: int = int(0.05 * SR)
		if i < atk:
			env = float(i) / atk
		elif i > len - rel:
			env = float(len - i) / rel
		else:
			env = 1.0
		out[start + i] += lp_state * env * 0.26

# --- Layer 2: Chord stabs (gentle harmonics + dropping lowpass — soft, not buzzy) ---
func _render_chords(out: PackedFloat32Array, start: int, len: int, chord: Dictionary, chord_idx: int) -> void:
	var comp_freqs: Array = chord["comp"]
	var comp_amps: Array = chord["amps"]
	var stab_positions: Array = [0.0, 1.0]
	var stab_amps: Array = [1.0, 0.55]
	var stab_dur: int = int(0.3 * SR)
	var phases: Array = []
	phases.resize(comp_freqs.size())
	phases.fill(0.0)
	for s in stab_positions.size():
		var pos: float = stab_positions[s]
		var amp_mult: float = stab_amps[s]
		var stab_start: int = start + int(pos * BEAT_DUR * SR)
		var lp_state: float = 0.0
		for i in stab_dur:
			if stab_start + i >= out.size():
				break
			# Exp decay (softer)
			var env: float = exp(-float(i) / (0.15 * SR)) * amp_mult
			if i < int(0.005 * SR):
				env *= float(i) / int(0.005 * SR)
			# Soft noise attack (very low amplitude)
			var noise_atk: float = 0.0
			if i < int(0.004 * SR):
				noise_atk = randf_range(-1.0, 1.0) * (1.0 - float(i) / int(0.004 * SR)) * 0.08
			# Gentler harmonics (h2=0.25, h3=0.12 — was 0.5, 0.33 — too bright)
			var sample: float = 0.0
			for j in comp_freqs.size():
				var drift: float = sin(float(stab_start + i) / SR * 4.0 + j * 1.7) * 0.002
				phases[j] += comp_freqs[j] * (1.0 + drift) / SR
				var h1: float = sin(phases[j])
				var h2: float = sin(phases[j] * 2.0) * 0.25
				var h3: float = sin(phases[j] * 3.0) * 0.12
				sample += (h1 + h2 + h3) * comp_amps[j]
			# Lowpass that drops 3kHz→800Hz over the stab (bright at attack, warm in sustain)
			var cutoff: float = 3000.0 - 2200.0 * (float(i) / stab_dur)
			var alpha: float = 1.0 - exp(-2.0 * PI * cutoff / SR)
			lp_state = lp_state + alpha * (sample - lp_state)
			out[stab_start + i] += (lp_state + noise_atk) * env * 0.075

# --- Layer 3: Arpeggio (high-register sine counter-line, 8th notes) ---
func _render_arp(out: PackedFloat32Array, start: int, len: int, chord: Dictionary, chord_idx: int) -> void:
	var arp_notes: Array = chord["arp"]
	var eighth_dur: int = int(BEAT_DUR / 2.0 * SR)
	var note_idx: int = chord_idx % arp_notes.size()  # offset start per chord for variation
	var i: int = 0
	while i < len:
		var note_freq: float = arp_notes[note_idx % arp_notes.size()]
		var note_start: int = i
		var ph := 0.0
		for j in eighth_dur:
			if note_start + j >= len or start + note_start + j >= out.size():
				break
			ph += note_freq / SR
			# Sine + 2nd harmonic (bell-like, high register)
			var fundamental: float = sin(ph)
			var h2: float = sin(ph * 2.0) * 0.15
			# Quick decay (8th note pluck)
			var env: float = exp(-float(j) / (0.1 * SR))
			out[start + note_start + j] += (fundamental + h2) * env * 0.05
		note_idx += 1
		i = note_start + eighth_dur

# --- Layer 4: Lead (sparse synth, enters off-beat, stepwise) ---
func _render_lead(out: PackedFloat32Array, start: int, len: int, chord: Dictionary, chord_idx: int) -> void:
	# Lead plays only on ~60% of chords (sparse), enters on the "&" of beat 1
	if chord_idx % 5 == 4:  # rest every 5th chord for breathing
		return
	var lead_freq: float = chord["lead"]
	# Enter on & of beat 1 (swing position)
	var lead_start: int = int(0.66 * BEAT_DUR * SR)
	var lead_dur: int = int(1.2 * BEAT_DUR * SR)  # ~1.2 beats
	var ph := 0.0
	for i in lead_dur:
		if lead_start + i >= len or start + lead_start + i >= out.size():
			break
		ph += lead_freq / SR
		# Saw lead + vibrato
		var vibrato: float = sin(float(i) / SR * TAU * 5.0) * 0.003
		var saw: float = 2.0 * (ph + vibrato - floor(ph + vibrato + 0.5))
		# Lowpass the saw a bit (sine + 2nd harmonic instead for cleaner tone)
		var fundamental: float = sin(ph + vibrato)
		var h2: float = sin((ph + vibrato) * 2.0) * 0.3
		# ADSR: 8ms attack, sustain, 100ms release
		var env: float
		var atk: int = int(0.008 * SR)
		var rel: int = int(0.1 * SR)
		if i < atk:
			env = float(i) / atk
		elif i > lead_dur - rel:
			env = float(lead_dur - i) / rel
		else:
			env = 1.0
		out[start + lead_start + i] += (fundamental + h2) * env * 0.10

# --- Layer 5: Drums (kick, clap, hats, cowbell) across the whole loop ---
func _render_drums(out: PackedFloat32Array, n: int) -> void:
	var beat_samples: int = int(BEAT_DUR * SR)
	var total_beats: int = int(LOOP_DUR / BEAT_DUR)
	for beat in total_beats:
		var beat_start: int = beat * beat_samples
		var bar: int = beat / 4
		var beat_in_bar: int = beat % 4
		# Kick: four-on-the-floor (beats 1, 2, 3, 4)
		_render_kick(out, beat_start, n)
		# Clap: beats 2 and 4
		if beat_in_bar == 1 or beat_in_bar == 3:
			_render_clap(out, beat_start, n)
		# Hats: off-beat 8ths (&1, &2, &3, &4)
		_render_hat(out, beat_start + beat_samples / 2, n)
		# Cowbell: beats 3 and 4 (kaiwai-kyoku signature)
		if beat_in_bar == 2 or beat_in_bar == 3:
			_render_cowbell(out, beat_start, n)

func _render_kick(out: PackedFloat32Array, start: int, n: int) -> void:
	var kick_dur: int = int(0.14 * SR)
	var ph := 0.0
	var click_lp: float = 0.0
	var click_alpha: float = 1.0 - exp(-2.0 * PI * 2000.0 / SR)  # lowpass the click
	for i in kick_dur:
		if start + i >= n:
			break
		var t: float = float(i) / SR
		var freq: float = 80.0 * exp(-t / 0.03) + 40.0
		ph += freq / SR
		var body: float = sin(ph)
		# Soft click (lowpass-filtered, lower amplitude — was too harsh)
		var click: float = 0.0
		if i < int(0.003 * SR):
			var raw_click: float = randf_range(-1.0, 1.0) * (1.0 - float(i) / int(0.003 * SR))
			click_lp = click_lp + click_alpha * (raw_click - click_lp)
			click = click_lp * 0.25
		var env: float = exp(-float(i) / (0.06 * SR))
		out[start + i] += (body + click) * env * 0.30

func _render_clap(out: PackedFloat32Array, start: int, n: int) -> void:
	# Bandpass-filtered noise: highpass @ 800Hz + lowpass @ 3kHz = softer "psh"
	var clap_dur: int = int(0.1 * SR)
	var hp_state: float = 0.0
	var lp_state: float = 0.0
	var hp_alpha: float = 1.0 - exp(-2.0 * PI * 800.0 / SR)
	var lp_alpha: float = 1.0 - exp(-2.0 * PI * 3000.0 / SR)
	var prev_raw: float = 0.0
	for i in clap_dur:
		if start + i >= n:
			break
		var raw: float = randf_range(-1.0, 1.0)
		# Highpass: y = x - prev_x + (1-hp_alpha)*prev_y
		hp_state = raw - prev_raw + (1.0 - hp_alpha) * hp_state
		prev_raw = raw
		# Lowpass
		lp_state = lp_state + lp_alpha * (hp_state - lp_state)
		var env: float = exp(-float(i) / (0.035 * SR))
		out[start + i] += lp_state * env * 0.10

func _render_hat(out: PackedFloat32Array, start: int, n: int) -> void:
	# Highpass-filtered noise @ 7kHz (softer "tss", not harsh white noise)
	var hat_dur: int = int(0.05 * SR)
	var hp_state: float = 0.0
	var hp_alpha: float = 1.0 - exp(-2.0 * PI * 7000.0 / SR)
	var prev_raw: float = 0.0
	for i in hat_dur:
		if start + i >= n:
			break
		var raw: float = randf_range(-1.0, 1.0)
		hp_state = raw - prev_raw + (1.0 - hp_alpha) * hp_state
		prev_raw = raw
		var env: float = exp(-float(i) / (0.02 * SR))
		out[start + i] += hp_state * env * 0.035

func _render_cowbell(out: PackedFloat32Array, start: int, n: int) -> void:
	# Cowbell: two SINE oscillators (not square — squares are piercing) through bandpass
	var cow_dur: int = int(0.18 * SR)
	var ph1 := 0.0
	var ph2 := 0.0
	var lp_state: float = 0.0
	var hp_state: float = 0.0
	var prev_hp: float = 0.0
	var lp_alpha: float = 1.0 - exp(-2.0 * PI * 4000.0 / SR)
	var hp_alpha: float = 1.0 - exp(-2.0 * PI * 600.0 / SR)
	for i in cow_dur:
		if start + i >= n:
			break
		ph1 += 840.0 / SR
		ph2 += 540.0 / SR
		# Sine waves (warm, not buzzy like squares)
		var s1: float = sin(ph1) * 0.6
		var s2: float = sin(ph2) * 0.4
		var raw: float = s1 + s2
		# Bandpass: highpass then lowpass
		hp_state = raw - prev_hp + (1.0 - hp_alpha) * hp_state
		prev_hp = raw
		lp_state = lp_state + lp_alpha * (hp_state - lp_state)
		var env: float = exp(-float(i) / (0.08 * SR))
		out[start + i] += lp_state * env * 0.045

# --- Reverb (one-comb feedback delay, SNES-style room) ---
func _apply_reverb(out: PackedFloat32Array, n: int) -> void:
	var delay_samples: int = int(0.09 * SR)
	var wet := PackedFloat32Array()
	wet.resize(n)
	var lp_state: float = 0.0
	for i in n:
		var delayed: float = wet[i - delay_samples] if i >= delay_samples else 0.0
		lp_state = lp_state + (delayed - lp_state) * 0.3
		wet[i] = out[i] * 0.25 + lp_state * 0.45
		out[i] = out[i] + wet[i] * 0.35

## Set music volume (0.0 = silent, 1.0 = full).
func set_volume(v: float) -> void:
	if _player:
		_player.volume_db = linear_to_db(clampf(v, 0.0, 1.0)) - 10.0

## Stop the music.
func stop() -> void:
	if _player:
		_player.stop()

## Start the music (if stopped).
func play() -> void:
	if _player and not _player.playing:
		_player.play()
