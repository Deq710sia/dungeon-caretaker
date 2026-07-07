extends Node
## Music — jazzy procedural main theme for Dungeon Caretaker (v2, SNES-informed).
##
## 8-bar loop with A section (ii-V-I-vi) + B section (IV-vii-iii-vi turn-around).
## All voices synthesized as additive PCM with proper harmonics, transients,
## and a one-comb feedback reverb for "in a room" space.
##
## Speder2 chords (from "Subtle Chord Atmosphere" analysis):
##   m7(9), 7alt(+5+9), M7(9), m6 — for A section
##   maj7, m7, m7b5, 7alt — for B section turn-around
##
## Three layers (properly synthesized, not pure sines):
##   1. Walking bass: sine + 2nd/3rd harmonic + 2ms pluck transient + humanized
##      timing (+8ms laid-back). Stays in one octave (D2-D3).
##   2. Comp stabs: SAW (additive 1/n harmonics) + 3ms noise attack + exp decay
##      (no sustain). Rootless drop-2 voicings. Varied rhythm per bar.
##   3. Ride cymbal: 6 inharmonic square oscillators + bandpass noise + 0.5s decay.
##      Spang-a-lang pattern (1, &2, 3, &4) + hi-hat chick on 2 & 4.
##   4. Melody motif: sine lead playing a recurring 4-note Toby-Fox-style motif.
##
## Speder2 techniques:
## - Drop voicings (root in octave 2, chord tones spread across octaves 4-5)
## - Amplitude scaling (9ths at -8dB, altered tones at -12 to -15dB)
## - Micro-pitch drift (±0.2% per voice)
## - ADSR envelopes per layer
##
## Reverb: one-comb feedback delay (90ms, 45% fb, lowpass in fb path) — SNES-style.

const SR := 44100
const BPM := 110.0
const BEATS_PER_BAR := 4
const BAR_COUNT := 8  # extended from 4 to 8 bars (A + B sections)
const BEAT_DUR := 60.0 / BPM  # 0.5454s per beat
const BAR_DUR := BEAT_DUR * BEATS_PER_BAR  # 2.1818s per bar
const LOOP_DUR := BAR_DUR * BAR_COUNT  # 17.45s total
const SWING := 0.66  # long-short ratio for 8th notes (0.5 = straight, 0.66 = swung)

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
	_player.volume_db = -10.0  # gentler master, no over-compression
	_player.name = "MusicPlayer"
	add_child(_player)
	_player.play()

# --- Chord definitions ---
# Each chord has:
#   bass_walk: 4 frequencies (quarter notes) — STAYS IN ONE OCTAVE (D2-D3),
#              connects by step to next chord's root, no octave jumps.
#   comp_freqs: rootless drop-2 voicing (bass plays the root)
#   comp_amps: amplitude scaling (9ths quiet, altered tones quieter)
#   comp_rhythm: which stab positions to use this bar (varies per bar)
#
# A section (bars 1-4): Am9 - D7#5#9 - Gmaj9 - Fm6 (ii-V-I-vi in G, then bVI color)
# B section (bars 5-8): Cmaj7 - Fmaj7 - Bm7b5 - E7#5#9 - Am9 (turn-around back to A)
#                     wait, 4 chords in 4 bars: Cmaj7 - Fmaj7 - Bm7b5 - E7#5#9
#                     then loop back to Am9 (bar 1).

const CHORDS := [
	# === A SECTION ===
	# Bar 1: Am9 (m7(9)) — i. Rootless: E-G-B-D wait that's Em7; Am9 rootless = C-E-G-B
	# Actually Am9 = A-C-E-G-B. Rootless (drop root A, keep 3-5-7-9): C-E-G-B
	# Bass walk: A - C - E - Eb (chromatic approach to D, next root)
	{
		"bass_walk": [110.00, 130.81, 164.81, 155.56],  # A2 C3 E3 Eb3
		"comp_freqs": [261.63, 329.63, 392.00, 493.88],  # C4 E4 G4 B4 (3,5,7,9)
		"comp_amps": [0.20, 0.18, 0.14, 0.08],  # 9th (B4) quietest
		"comp_rhythm": [0, 1, 2, 3],  # 1, &2, 3, &4 (all four)
	},
	# Bar 2: D7#5#9 (7alt +5+9) — V7 altered. FIXED voicing:
	# Rootless from 3rd: F#(3), C(b7), F(#9), A#(#5) — #9 ABOVE the 3rd
	# Bass walk: D - F - A - Bb (chromatic approach up to B = 3rd of G)
	{
		"bass_walk": [73.42, 87.31, 110.00, 116.54],  # D2 F2 A2 Bb2
		"comp_freqs": [185.00, 261.63, 349.23, 466.16],  # F#3 C4 F4 A#4 (3,b7,#9,#5)
		"comp_amps": [0.22, 0.18, 0.07, 0.10],  # #9 (F4) very quiet, #5 (A#4) quiet
		"comp_rhythm": [0, 2, 3],  # 1, 3, &4 (drop &2 for variation)
	},
	# Bar 3: Gmaj9 (M7(9)) — IV. Rootless: B-D-F#-A (3,5,7,9)
	# Bass walk: G - B - D - F# (chord tones leading to F root)
	{
		"bass_walk": [98.00, 123.47, 146.83, 185.00],  # G2 B2 D3 F#3
		"comp_freqs": [246.94, 293.66, 369.99, 440.00],  # B3 D4 F#4 A4 (3,5,7,9)
		"comp_amps": [0.20, 0.18, 0.14, 0.08],  # 9th (A4) quietest
		"comp_rhythm": [0, 1, 2],  # 1, &2, 3 (drop &4 — leave space)
	},
	# Bar 4: Fm6 (m6) — bVI. F-Ab-C-D. With bass on F, comp = Ab-C-D-F(oct)
	# The Ab-D tritone gives the "anxious, transparent" speder2 mood
	# Bass walk: F - Ab - C - B (chromatic approach to A from below)
	{
		"bass_walk": [87.31, 103.83, 130.81, 123.47],  # F2 Ab2 C3 B2
		"comp_freqs": [207.65, 261.63, 293.66, 349.23],  # Ab3 C4 D4 F4 (b3,5,6,8ve)
		"comp_amps": [0.14, 0.20, 0.10, 0.16],  # 6th (D4) is tritone with Ab3 → quiet
		"comp_rhythm": [1, 2, 3],  # &2, 3, &4 (drop beat 1 — Basie-style)
	},
	# === B SECTION ===
	# Bar 5: Cmaj7 (I in C major, borrowed) — C-E-G-B. Rootless: E-G-B-D
	# Bass walk: C - E - G - B (chord tones leading to A or F)
	{
		"bass_walk": [65.41, 82.41, 98.00, 123.47],  # C2 E2 G2 B2
		"comp_freqs": [164.81, 196.00, 246.94, 293.66],  # E3 G3 B3 D4 (3,5,7,9)
		"comp_amps": [0.20, 0.18, 0.14, 0.08],
		"comp_rhythm": [0, 1, 2, 3],  # full pattern again
	},
	# Bar 6: Fmaj7 (IV in C) — F-A-C-E. Rootless: A-C-E-G
	# Bass walk: F - A - C - E (chord tones)
	{
		"bass_walk": [87.31, 110.00, 130.81, 164.81],  # F2 A2 C3 E3
		"comp_freqs": [220.00, 261.63, 329.63, 392.00],  # A3 C4 E4 G4 (3,5,7,9)
		"comp_amps": [0.20, 0.18, 0.14, 0.08],
		"comp_rhythm": [0, 2, 3],  # 1, 3, &4
	},
	# Bar 7: Bm7b5 (ii° in A minor) — B-D-F-A. Rootless: D-F-A-C
	# Bass walk: B - D - F - A (chord tones leading to E)
	{
		"bass_walk": [61.74, 73.42, 87.31, 110.00],  # B2 D2 F2 A2
		"comp_freqs": [146.83, 174.61, 220.00, 261.63],  # D3 F3 A3 C4 (b3,b5,b7,b9)
		"comp_amps": [0.18, 0.14, 0.16, 0.10],  # b5 (F3) and b9 (C4) quiet (dissonant)
		"comp_rhythm": [1, 2],  # &2, 3 (sparse — turn-around building)
	},
	# Bar 8: E7#5#9 (V7alt in A minor) — E-G#-Bb-D-F. Rootless: G#-Bb-D-F (#9 above 3rd)
	# Bass walk: E - G# - Bb - B (chromatic approach to A from below, B leads to A or C)
	# Actually Bb→A is the chromatic approach down. Let me use: E - G# - B - Bb
	{
		"bass_walk": [82.41, 103.83, 123.47, 116.54],  # E2 G#2 B2 Bb2 (Bb approaches A)
		"comp_freqs": [207.65, 233.08, 293.66, 349.23],  # G#3 Bb3 D4 F4 (3,#5,b7,#9)
		"comp_amps": [0.22, 0.10, 0.16, 0.07],  # #5 and #9 very quiet
		"comp_rhythm": [0, 1, 2, 3],  # full pattern — turn-around resolve back to Am9
	},
]

# Melody motif (Toby Fox style — recurring 4-note cell, transposed per chord)
# Each bar plays a 4-note motif derived from the chord's upper extensions.
# Notes are placed on beats 1, &2, 3, &4 (syncopated like the comp).
# Motif is a simple arpeggio of the comp voicing + a neighbor tone.
const MELODY_MOTIFS := [
	# Bar 1 (Am9): E4 - G4 - B4 - A4 (5-7-9-6 of Am, the A4 is a neighbor)
	[329.63, 392.00, 493.88, 440.00],
	# Bar 2 (D7alt): C4 - F4 - A#4 - G#4 (b7-#9-#5-...color tones)
	[261.63, 349.23, 466.16, 415.30],
	# Bar 3 (Gmaj9): D4 - F#4 - A4 - G4 (5-7-9-6 of G)
	[293.66, 369.99, 440.00, 392.00],
	# Bar 4 (Fm6): C4 - D4 - F4 - Eb4 (5-6-8-b7 of Fm)
	[261.63, 293.66, 349.23, 311.13],
	# Bar 5 (Cmaj7): E4 - G4 - B4 - A4
	[329.63, 392.00, 493.88, 440.00],
	# Bar 6 (Fmaj7): A4 - C5 - E5 - D5
	[440.00, 523.25, 659.25, 587.33],
	# Bar 7 (Bm7b5): D4 - F4 - A4 - G4
	[293.66, 349.23, 440.00, 392.00],
	# Bar 8 (E7alt): G#4 - Bb4 - D5 - C#5 (color tones leading back to A)
	[415.30, 466.16, 587.33, 554.37],
]

func _render_theme() -> AudioStreamWAV:
	var n: int = int(LOOP_DUR * SR)
	var o := PackedFloat32Array()
	o.resize(n)
	for bar_idx in BAR_COUNT:
		var chord: Dictionary = CHORDS[bar_idx]
		var start_sample: int = int(bar_idx * BAR_DUR * SR)
		var bar_samples: int = int(BAR_DUR * SR)
		_render_walking_bass(o, start_sample, bar_samples, chord)
		_render_comp_stabs(o, start_sample, bar_samples, chord)
		_render_ride(o, start_sample, bar_samples)
		_render_melody(o, start_sample, bar_samples, bar_idx)
	# Apply reverb (one-comb feedback delay)
	_apply_reverb(o, n)
	# Gentle master (no over-compression) — only soft-clip if needed
	for i in n:
		o[i] = tanh(o[i] * 0.7)  # gentle saturation, preserves dynamics
	# Convert to 16-bit PCM
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

# --- Layer 1: Walking bass (sine + harmonics + pluck transient + humanized) ---
func _render_walking_bass(out: PackedFloat32Array, start: int, len: int, chord: Dictionary) -> void:
	var bass_walk: Array = chord["bass_walk"]
	var beat_samples: int = int(BEAT_DUR * SR)
	for beat in 4:
		var note_freq: float = bass_walk[beat]
		# Humanize: laid-back timing, +6-10ms random delay (never ahead)
		var human_delay: int = int((0.006 + 0.004 * randf()) * SR)
		var note_start: int = beat * beat_samples + human_delay
		var ph := 0.0
		var note_len: int = beat_samples - human_delay
		for i in note_len:
			if note_start + i >= len:
				break
			ph += note_freq / SR
			# Sine fundamental + 2nd harmonic at -12dB + 3rd at -18dB (woody body)
			var fundamental: float = sin(ph)
			var h2: float = sin(ph * 2.0) * 0.25  # -12dB
			var h3: float = sin(ph * 3.0) * 0.125  # -18dB
			var bass_sample: float = fundamental + h2 + h3
			# Pluck transient: 2ms bright noise at note onset
			var pluck: float = 0.0
			if i < int(0.002 * SR):
				pluck = randf_range(-1.0, 1.0) * exp(-float(i) / (0.001 * SR)) * 0.5
			# ADSR: 2ms attack, exp decay (no sustain — let note decay slightly)
			var env: float
			var atk: int = int(0.002 * SR)
			if i < atk:
				env = float(i) / atk
			else:
				env = exp(-float(i - atk) / (0.4 * SR))  # slow decay across the note
			out[start + note_start + i] += (bass_sample + pluck) * env * 0.32

# --- Layer 2: Comp stabs (SAW additive + noise attack + exp decay) ---
func _render_comp_stabs(out: PackedFloat32Array, start: int, len: int, chord: Dictionary) -> void:
	var comp_freqs: Array = chord["comp_freqs"]
	var comp_amps: Array = chord["comp_amps"]
	var comp_rhythm: Array = chord["comp_rhythm"]
	var beat_samples: int = int(BEAT_DUR * SR)
	# Stab positions: 0=beat1, 1=&2, 2=beat3, 3=&4 (with swing on the & positions)
	var stab_positions: Array = [
		0.0,                      # beat 1
		1.0 + SWING,              # &2 (swung)
		2.0,                      # beat 3
		3.0 + SWING,              # &4 (swung)
	]
	var stab_dur: int = int(0.18 * SR)  # 180ms per stab
	var phases: Array = []
	phases.resize(comp_freqs.size())
	phases.fill(0.0)
	for rhythm_idx in comp_rhythm:
		var pos: float = stab_positions[rhythm_idx]
		var stab_start: int = int(pos * beat_samples)
		if stab_start >= len:
			continue
		for i in stab_dur:
			if stab_start + i >= len:
				break
			# Exp decay (NO sustain — piano/guitar stabs die)
			var env: float = exp(-float(i) / (0.08 * SR))  # τ=80ms
			# Attack: 3ms ramp at very start
			var atk_env: float = 1.0
			if i < int(0.003 * SR):
				atk_env = float(i) / int(0.003 * SR)
			# Noise attack transient: 3ms bright noise (hammer/pick)
			var noise_atk: float = 0.0
			if i < int(0.003 * SR):
				noise_atk = randf_range(-1.0, 1.0) * (1.0 - float(i) / int(0.003 * SR)) * 0.3
			# SAW (additive 1/n harmonics) per voice — much richer than pure sine
			var sample: float = 0.0
			for j in comp_freqs.size():
				# Micro-pitch drift (±0.2% per voice, speder2 technique)
				var drift: float = sin(float(stab_start + i) / SR * 4.0 + j * 1.7) * 0.002
				phases[j] += comp_freqs[j] * (1.0 + drift) / SR
				# Additive harmonics: fundamental + 2nd + 3rd (saw-ish)
				var h1: float = sin(phases[j]) * 1.0
				var h2: float = sin(phases[j] * 2.0) * 0.5  # 1/2 amplitude
				var h3: float = sin(phases[j] * 3.0) * 0.33  # 1/3 amplitude
				sample += (h1 + h2 + h3) * comp_amps[j]
			out[start + stab_start + i] += (sample + noise_atk) * env * atk_env * 0.10

# --- Layer 3: Ride cymbal (inharmonic squares + bandpass noise + 0.5s decay) ---
func _render_ride(out: PackedFloat32Array, start: int, len: int) -> void:
	var beat_samples: int = int(BEAT_DUR * SR)
	# Spang-a-lang pattern: hits on 1, &2, 3, &4 (with swing)
	var ride_positions: Array = [
		{"pos": 0.0, "amp": 0.10, "dur": 0.8},    # beat 1 — full ride ring
		{"pos": 1.0 + SWING, "amp": 0.07, "dur": 0.5},  # &2 (bell, shorter)
		{"pos": 2.0, "amp": 0.10, "dur": 0.8},    # beat 3
		{"pos": 3.0 + SWING, "amp": 0.07, "dur": 0.5},  # &4 (bell)
	]
	# Inharmonic ratios for the metallic ping (TR-808 style)
	var inharm_ratios: Array = [1.0, 1.34, 1.56, 1.78, 2.0, 2.4]
	var base_freq: float = 2200.0  # ~2.2kHz base for the metallic body
	for r in ride_positions:
		var pos: float = r["pos"]
		var amp: float = r["amp"]
		var dur_s: float = r["dur"]
		var ride_start: int = int(pos * beat_samples)
		var ride_dur: int = int(dur_s * SR)
		if ride_start >= len:
			continue
		# Pre-generate the 6 oscillator phases (offset for shimmer)
		var phases: Array = []
		for k in inharm_ratios.size():
			phases.append(randf() * TAU)  # random initial phase
		for i in ride_dur:
			if ride_start + i >= len:
				break
			# Long exp decay (τ=0.5s — ride RINGS, not a closed hi-hat)
			var env: float = exp(-float(i) / (0.5 * SR))
			# Stick click: 1.5ms bright noise at very start
			var stick: float = 0.0
			if i < int(0.0015 * SR):
				stick = randf_range(-1.0, 1.0) * exp(-float(i) / (0.0005 * SR)) * 0.4
			# 6 inharmonic square oscillators (metallic ping body)
			var metallic: float = 0.0
			for k in inharm_ratios.size():
				var f: float = base_freq * inharm_ratios[k]
				phases[k] += f / SR
				var sq: float = 1.0 if fmod(phases[k], TAU) < PI else -1.0
				metallic += sq
			metallic *= 0.15  # tame the sum
			# Bandpass-ish noise (high-pass via simple diff, then low-pass) for the wash
			var noise: float = randf_range(-1.0, 1.0) * 0.6
			var ride_sample: float = metallic + noise * 0.3
			out[start + ride_start + i] += (ride_sample + stick) * env * amp
	# Hi-hat chick on beats 2 and 4 (0-indexed 1 and 3) — short, tight
	for beat in [1, 3]:
		var hat_start: int = beat * beat_samples
		var hat_dur: int = int(0.04 * SR)  # 40ms (closed hi-hat, NOT ride)
		for i in hat_dur:
			if hat_start + i >= len:
				break
			var env: float = exp(-float(i) / (0.012 * SR))  # τ=12ms
			out[start + hat_start + i] += randf_range(-1.0, 1.0) * env * 0.04

# --- Layer 4: Melody motif (sine lead with 2nd harmonic, recurring 4-note cell) ---
func _render_melody(out: PackedFloat32Array, start: int, len: int, bar_idx: int) -> void:
	var motif: Array = MELODY_MOTIFS[bar_idx]
	var beat_samples: int = int(BEAT_DUR * SR)
	# Place melody notes on 1, &2, 3, &4 (syncopated like the comp)
	var positions: Array = [0.0, 1.0 + SWING, 2.0, 3.0 + SWING]
	var note_dur: int = int(0.35 * SR)  # 350ms per melody note (overlaps slightly)
	for note_idx in motif.size():
		var note_freq: float = motif[note_idx]
		var pos: float = positions[note_idx]
		var note_start: int = int(pos * beat_samples)
		if note_start >= len:
			continue
		var ph := 0.0
		for i in note_dur:
			if note_start + i >= len:
				break
			ph += note_freq / SR
			# Sine + 2nd harmonic (lead tone, not too buzzy)
			var fundamental: float = sin(ph)
			var h2: float = sin(ph * 2.0) * 0.2  # subtle 2nd harmonic
			# ADSR: 5ms attack, sustain, 80ms release
			var env: float
			var atk: int = int(0.005 * SR)
			var rel: int = int(0.08 * SR)
			if i < atk:
				env = float(i) / atk
			elif i > note_dur - rel:
				env = float(note_dur - i) / rel
			else:
				env = 1.0
			# Vibrato: subtle 5Hz pitch wobble for life
			var vibrato: float = sin(float(i) / SR * TAU * 5.0) * 0.003
			out[start + note_start + i] += (fundamental + h2) * env * 0.13 * (1.0 + vibrato)

# --- Reverb: one-comb feedback delay (SNES-style "in a room") ---
func _apply_reverb(out: PackedFloat32Array, n: int) -> void:
	var delay_samples: int = int(0.09 * SR)  # 90ms delay
	var wet := PackedFloat32Array()
	wet.resize(n)
	var lp_state: float = 0.0  # one-pole lowpass state in feedback path
	for i in n:
		var delayed: float = wet[i - delay_samples] if i >= delay_samples else 0.0
		# Lowpass in feedback path to kill harshness
		lp_state = lp_state + (delayed - lp_state) * 0.3
		# 25% dry send, 45% feedback
		wet[i] = out[i] * 0.25 + lp_state * 0.45
		# Add 35% wet into master
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
