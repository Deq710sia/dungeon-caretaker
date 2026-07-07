extends Node
## Music — jazzy procedural main theme for Dungeon Caretaker.
##
## Generates an ~8.7-second looped AudioStreamWAV at startup using speder2
## chord-timbre techniques. The loop plays continuously on the Music bus.
##
## Speder2 chords used (from the "Subtle Chord Atmosphere" analysis):
##   m7(9)    — cold, crystal hardness    (Am9)
##   7alt+5+9 — high-impact emptiness     (D7#5#9, altered dominant)
##   M7(9)    — warm, fluffy cushion      (Gmaj9, major resolution)
##   m6       — anxious, transparent      (Fm6, turn-around color)
##
## Progression: Am9 → D7#5#9 → Gmaj9 → Fm6  (4 bars, ii-V-I-vi jazz feel)
## 110 BPM, 4 beats per bar = ~8.73s loop.
##
## Three layers (bouncy + rhythmic + jazzy):
##   1. Walking bass: triangle wave, quarter notes, walks chord tones +
##      chromatic approach. Back-beat (2,4) slightly louder.
##   2. Comp stabs: sine chord on syncopated 1-&2-3-&4 pattern with swing.
##      Speder2 drop voicings + amplitude scaling.
##   3. Ride cymbal: filtered noise on each beat + softer on swung off-beats.
##
## Speder2 techniques applied:
## - Drop voicings: root in octave 2, 5th in octave 3, chord tones in 4-5
## - Amplitude scaling: 9th at -8dB, altered tones (#5, #9) at -12 to -15dB
## - Micro-pitch drift: ±0.2% per voice (prevents static phase cancellation)
## - ADSR envelopes per layer

const SR := 44100
const BPM := 110.0
const BEATS_PER_BAR := 4
const BAR_COUNT := 4
const BEAT_DUR := 60.0 / BPM  # 0.5454s per beat
const BAR_DUR := BEAT_DUR * BEATS_PER_BAR  # 2.1818s per bar
const LOOP_DUR := BAR_DUR * BAR_COUNT  # 8.727s total
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
	_player.volume_db = -12.0
	_player.name = "MusicPlayer"
	add_child(_player)
	_player.play()

# --- Chord definitions ---
# Each chord has:
#   bass_walk: 4 frequencies (quarter notes 1,2,3,4) — walking bass
#   comp:      {freqs: [...], amps: [...]} — drop-voiced chord for stabs
#              (amps follow speder2 amplitude scaling: dissonant tones quieter)
#
# Speder2 chord formulas (from root):
#   m7(9):    1 - b3 - 5 - b7 - 9
#   7alt(+5+9): 1 - 3 - #5 - b7 - #9
#   M7(9):    1 - 3 - 5 - 7 - 9
#   m6:       1 - b3 - 5 - 6

const CHORDS := [
	# Bar 1: Am9 (i) — A C E G B
	# Walking bass walks A→C→E→Eb (chromatic approach to D, the next root)
	{
		"bass_walk": [110.00, 130.81, 164.81, 155.56],  # A2 C3 E3 Eb3
		"comp_freqs": [164.81, 220.00, 261.63, 392.00, 493.88],  # E3 A3 C4 G4 B4
		"comp_amps": [0.20, 0.22, 0.18, 0.10, 0.06],  # 9th (B4) quietest
	},
	# Bar 2: D7#5#9 (V7alt) — D F# A# C E#(F)
	# Walking bass walks D→F→A→Bb (chromatic approach down to A or up to G)
	# Actually Bb leads up to B = 5th of Gmaj9, or down chromatically to A
	{
		"bass_walk": [73.42, 87.31, 110.00, 116.54],  # D2 F2 A2 Bb2
		"comp_freqs": [185.00, 233.08, 261.63, 369.99, 466.16],  # F#3 Bb3 C4 F#4 Bb4
		"comp_amps": [0.18, 0.10, 0.16, 0.08, 0.06],  # #5 (Bb3) and #9 (Bb4) very quiet
	},
	# Bar 3: Gmaj9 (IV) — G B D F# A
	# Walking bass walks G→B→D→F# (chord tones leading to F root)
	{
		"bass_walk": [98.00, 123.47, 146.83, 185.00],  # G2 B2 D3 F#3
		"comp_freqs": [146.83, 196.00, 246.94, 293.66, 440.00],  # D3 G3 B3 D4 A4
		"comp_amps": [0.18, 0.22, 0.18, 0.14, 0.06],  # 9th (A4) quietest
	},
	# Bar 4: Fm6 (bVI) — F Ab C D
	# Walking bass walks F→Ab→C→B (chromatic approach to A from below)
	# Fm6 has a tritone (Ab-D) for that "anxious, transparent" speder2 mood
	{
		"bass_walk": [87.31, 103.83, 130.81, 123.47],  # F2 Ab2 C3 B2
		"comp_freqs": [130.81, 174.61, 207.65, 261.63, 293.66],  # C3 F3 Ab3 C4 D4
		"comp_amps": [0.18, 0.20, 0.12, 0.18, 0.08],  # 6th (D4) is tritone with Ab3 → quiet
	},
]

func _render_theme() -> AudioStreamWAV:
	var n: int = int(LOOP_DUR * SR)
	var o := PackedFloat32Array()
	o.resize(n)
	for bar_idx in BAR_COUNT:
		var chord: Dictionary = CHORDS[bar_idx]
		var start_sample: int = int(bar_idx * BAR_DUR * SR)
		var bar_samples: int = int(BAR_DUR * SR)
		_render_walking_bass(o, start_sample, bar_samples, chord, bar_idx)
		_render_comp_stabs(o, start_sample, bar_samples, chord)
		_render_ride(o, start_sample, bar_samples, bar_idx)
	# Master soft-clip to prevent clipping from layer sum
	for i in n:
		o[i] = tanh(o[i] * 1.2) * 0.9
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

# --- Layer 1: Walking bass ---
# Triangle wave, quarter notes, with quick attack + medium decay.
# Back-beat (beats 2, 4) slightly louder for "bouncy" feel.
# Speder2 triangle wave = soft percussion/bass timbre.
func _render_walking_bass(out: PackedFloat32Array, start: int, len: int, chord: Dictionary, bar_idx: int) -> void:
	var bass_walk: Array = chord["bass_walk"]
	var beat_samples: int = int(BEAT_DUR * SR)
	for beat in 4:
		var note_freq: float = bass_walk[beat]
		var note_start: int = beat * beat_samples
		# Back-beat emphasis (beats 2 and 4 are louder — bouncy)
		var amp_mult: float = 1.15 if (beat == 1 or beat == 3) else 1.0
		var ph := 0.0
		var note_len: int = beat_samples
		for i in note_len:
			if note_start + i >= len:
				break
			ph += note_freq / SR
			# Triangle wave (soft, warm — NES bass technique)
			var tri: float = 2.0 * abs(2.0 * fmod(ph, 1.0) - 1.0) - 1.0
			# ADSR: 8ms attack, sustain, 80ms release at end of note
			var env: float
			var atk: int = int(0.008 * SR)
			var rel: int = int(0.08 * SR)
			if i < atk:
				env = float(i) / atk
			elif i > note_len - rel:
				env = float(note_len - i) / rel
			else:
				env = 1.0
			# Slight pitch drift on bass too (speder2 micro-drift, smaller)
			var drift: float = sin(float(i) / SR * 3.0) * 0.0010
			out[start + note_start + i] += tri * env * 0.42 * amp_mult
	# Connect last note to next chord with a brief slide (portamento feel)
	# — implemented via the chromatic approach note in bass_walk already

# --- Layer 2: Comp stabs ---
# Sine chord stabs on syncopated pattern: 1, &2, 3, &4 (with swing).
# Speder2 drop voicings + amplitude scaling. Short stabs (120ms each).
func _render_comp_stabs(out: PackedFloat32Array, start: int, len: int, chord: Dictionary) -> void:
	var comp_freqs: Array = chord["comp_freqs"]
	var comp_amps: Array = chord["comp_amps"]
	var beat_samples: int = int(BEAT_DUR * SR)
	# Syncopated stab pattern: beat 1, &2, beat 3, &4
	# &2 = swing position between beat 2 and beat 3
	# &4 = swing position between beat 4 and next bar's beat 1
	var stab_positions: Array = [
		0.0,                      # beat 1
		1.0 + SWING,              # &2 (swung — 66% of the way from 2 to 3)
		2.0,                      # beat 3
		3.0 + SWING,              # &4 (swung)
	]
	var stab_dur: int = int(0.18 * SR)  # 180ms per stab
	var phases: Array = []
	phases.resize(comp_freqs.size())
	phases.fill(0.0)
	for pos in stab_positions:
		var stab_start: int = int(pos * beat_samples)
		if stab_start >= len:
			break
		for i in stab_dur:
			if stab_start + i >= len:
				break
			# ADSR: 3ms attack, 60ms decay to 0.4 sustain, 80ms release
			var env: float
			var atk: int = int(0.003 * SR)
			var dec: int = int(0.06 * SR)
			var rel: int = int(0.08 * SR)
			if i < atk:
				env = float(i) / atk
			elif i < atk + dec:
				env = 1.0 - (float(i - atk) / dec) * 0.6
			elif i < stab_dur - rel:
				env = 0.4
			else:
				env = 0.4 * float(stab_dur - i) / rel
			var sample := 0.0
			for j in comp_freqs.size():
				# Speder2 micro-pitch drift (±0.2% per voice)
				var drift: float = sin(float(stab_start + i) / SR * 4.0 + j * 1.7) * 0.002
				phases[j] += comp_freqs[j] * (1.0 + drift) / SR
				sample += sin(phases[j]) * comp_amps[j]
			out[start + stab_start + i] += sample * env * 0.20

# --- Layer 3: Ride cymbal ---
# Filtered noise bursts. Jazz ride pattern: tap on each beat (1,2,3,4)
# + softer "bell" on swung &2 and &4. Very quiet — adds rhythmic glue.
func _render_ride(out: PackedFloat32Array, start: int, len: int, bar_idx: int) -> void:
	var beat_samples: int = int(BEAT_DUR * SR)
	# Ride pattern: 4 main taps + 2 swung off-beats
	var ride_positions: Array = [
		{"pos": 0.0, "amp": 0.10, "dur": 0.12},   # beat 1
		{"pos": 1.0 + SWING, "amp": 0.06, "dur": 0.06},  # &2 (bell)
		{"pos": 2.0, "amp": 0.10, "dur": 0.12},   # beat 3
		{"pos": 3.0 + SWING, "amp": 0.06, "dur": 0.06},  # &4 (bell)
	]
	for r in ride_positions:
		var pos: float = r["pos"]
		var amp: float = r["amp"]
		var dur_s: float = r["dur"]
		var ride_start: int = int(pos * beat_samples)
		var ride_dur: int = int(dur_s * SR)
		if ride_start >= len:
			continue
		for i in ride_dur:
			if ride_start + i >= len:
				break
			# Noise burst with fast exponential decay (cymbal-ish)
			var env: float = exp(-float(i) / (0.04 * SR))
			# High-pass-ish: subtract a smoothed version (simple one-pole)
			var noise: float = randf_range(-1.0, 1.0)
			out[start + ride_start + i] += noise * env * amp
	# Also a soft "tick" on beat 2 and 4 (back-beat) for the bouncy feel
	for beat in [1, 3]:  # beats 2 and 4 (0-indexed)
		var tick_start: int = beat * beat_samples
		var tick_dur: int = int(0.02 * SR)  # 20ms
		for i in tick_dur:
			if tick_start + i >= len:
				break
			var env: float = exp(-float(i) / (0.008 * SR))
			out[start + tick_start + i] += randf_range(-1.0, 1.0) * env * 0.04

## Set music volume (0.0 = silent, 1.0 = full).
func set_volume(v: float) -> void:
	if _player:
		_player.volume_db = linear_to_db(clampf(v, 0.0, 1.0)) - 12.0

## Stop the music.
func stop() -> void:
	if _player:
		_player.stop()

## Start the music (if stopped).
func play() -> void:
	if _player and not _player.playing:
		_player.play()
