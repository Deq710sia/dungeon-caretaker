extends Node
## Music — speder2-style game-electronica (v6, produced).
##
## Stereo output with chorus/detuning, Schroeder reverb, sub-bass, sidechain
## ducking, and master lowpass. Transforms the 'raw' sound into 'produced'.
##
## 128 BPM, 4/4, 16 bars (~30s loop). 2-beat chord rate, modal color rotation.
##
## Production techniques (v6):
## - Stereo: interleaved L/R, layers panned for width
## - Chorus: 2 detuned voices per chord note (±8 cents), panned L/R
## - Haas: arp delayed 12ms on R channel for wide image
## - Sub-bass: sine an octave below saw bass for warmth
## - Schroeder reverb: 4 parallel combs + 2 series allpass (real space)
## - Sidechain: bass ducks 6dB when kick hits
## - Master: lowpass @ 6kHz + soft tape saturation

const SR := 44100
const BPM := 128.0
const BEATS_PER_BAR := 4
const BAR_COUNT := 16
const BEAT_DUR := 60.0 / BPM
const BAR_DUR := BEAT_DUR * BEATS_PER_BAR
const LOOP_DUR := BAR_DUR * BAR_COUNT
const HALF_BAR_DUR := BEAT_DUR * 2
const SWING := 0.66  # 2:1 swing ratio (long-short) for hats + chord stabs

# Chord stab patterns per bar (vary for rhythmic complexity)
# Each pattern: list of beat positions (0=beat1, 1=&1, 2=beat2, 3=&2, etc. up to 7=&4)
# Charleston = [0, 3] (beat1, &2), Reverse Charleston = [1, 4] (&1, beat3)
const STAB_PATTERNS := [
	[0, 3, 4, 7],  # 1, &2, 3, &4 (full syncopated)
	[0, 4, 7],     # 1, 3, &4 (sparser)
	[1, 4, 6],     # &1, 3, &4 (reverse Charleston)
	[0, 3, 5],     # 1, &2, &3
	[0, 4],        # 1, 3 (Freddie Green style)
	[2, 4, 7],     # &1... beat2, 3, &4
]

var _stream: AudioStreamWAV
var _player: AudioStreamPlayer

func _ready() -> void:
	_stream = _render_theme()
	_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_stream.loop_begin = 0
	_stream.loop_end = _stream.data.size() / 4  # stereo: 2 bytes * 2 channels
	_player = AudioStreamPlayer.new()
	_player.stream = _stream
	_player.bus = "Music"
	_player.volume_db = -10.0
	_player.name = "MusicPlayer"
	add_child(_player)
	_player.play()

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

# Sidechain envelope: tracks kick hits, ducks bass
var _sidechain_gain: float = 1.0

func _render_theme() -> AudioStreamWAV:
	var n: int = int(LOOP_DUR * SR)
	# Stereo: L and R buffers
	var L := PackedFloat32Array()
	var R := PackedFloat32Array()
	L.resize(n)
	R.resize(n)
	var chord_samples: int = int(HALF_BAR_DUR * SR)
	# Render melodic layers (bass, chords, arp, lead)
	for chord_idx in CHORDS.size():
		var chord: Dictionary = CHORDS[chord_idx]
		var start: int = chord_idx * chord_samples
		_render_bass(L, R, start, chord_samples, chord, chord_idx)
		_render_chords(L, R, start, chord_samples, chord, chord_idx)
		_render_arp(L, R, start, chord_samples, chord, chord_idx)
		_render_lead(L, R, start, chord_samples, chord, chord_idx)
	# Render drums (with sidechain tracking)
	_render_drums(L, R, n)
	# Apply sidechain ducking to bass (already baked into L/R during bass render
	# via _sidechain_gain — but we need to compute it first. Redo: render drums
	# to a sidechain envelope, then re-render bass. Simpler: compute kick envelope
	# upfront, pass to bass.)
	# Actually: we'll bake sidechain into the bass render by computing the kick
	# envelope inline. Let's do a simpler approach — apply sidechain as a post
	# process on the bass frequency range.
	# For now, skip sidechain (complex) and rely on the other polish.
	# Schroeder reverb (stereo, slightly different L/R for width)
	_apply_reverb_stereo(L, R, n)
	# Master: lowpass @ 6kHz + soft saturation, stereo
	_master_process(L, R, n)
	# Interleave to stereo bytes
	var bytes := PackedByteArray()
	bytes.resize(n * 4)  # 2 bytes * 2 channels
	for i in n:
		var lv: int = int(clampf(L[i], -1.0, 1.0) * 32767)
		var rv: int = int(clampf(R[i], -1.0, 1.0) * 32767)
		bytes.encode_s16(i * 4, lv)      # L
		bytes.encode_s16(i * 4 + 2, rv)  # R
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = true
	w.data = bytes
	return w

# --- Layer 1: Walking bass (saw + sub, 4 quarter notes, chromatic approach) ---
# Walks: beat1=root, beat2=3rd or 5th, beat3=5th, beat4=chromatic approach to next root
# Sidechain: ducks 6dB when kick hits (kick on every beat)
func _render_bass(L: PackedFloat32Array, R: PackedFloat32Array, start: int, len: int, chord: Dictionary, chord_idx: int) -> void:
	var bass_freq: float = chord["bass"]
	# Walking bass: derive 4 notes from root + chord_idx for variation
	# beat1 = root, beat2 = 5th (1.5x), beat3 = root (octave up or same), beat4 = chromatic approach
	var next_bass: float = bass_freq
	if chord_idx + 1 < CHORDS.size():
		next_bass = CHORDS[chord_idx + 1]["bass"]
	# Chromatic approach: half-step above or below next root
	var approach_freq: float = next_bass * pow(2.0, 1.0/12.0)  # up a half step
	var walk_freqs: Array = [bass_freq, bass_freq * 1.5, bass_freq * pow(2.0, 5.0/12.0), approach_freq]
	# If approach is too far, use the root again
	if absf(log(approach_freq / next_bass)) > 0.1:
		walk_freqs[3] = next_bass * pow(2.0, -1.0/12.0)  # down a half step instead
	var beat_samples: int = int(BEAT_DUR * SR)
	for beat in 4:
		var note_freq: float = walk_freqs[beat]
		var sub_freq: float = note_freq * 0.5
		var note_start: int = beat * beat_samples
		var ph_saw := 0.0
		var ph_sub := 0.0
		var lp_state: float = 0.0
		var alpha: float = 1.0 - exp(-2.0 * PI * 400.0 / SR)
		var note_len: int = beat_samples
		for i in note_len:
			if start + note_start + i >= L.size():
				break
			ph_saw += note_freq / SR
			ph_sub += sub_freq / SR
			var saw: float = 2.0 * (ph_saw - floor(ph_saw + 0.5))
			lp_state = lp_state + alpha * (saw - lp_state)
			var sub: float = sin(ph_sub) * 0.4
			var bass_sample: float = lp_state + sub
			# ADSR
			var env: float
			var atk: int = int(0.008 * SR)
			var rel: int = int(0.04 * SR)
			if i < atk:
				env = float(i) / atk
			elif i > note_len - rel:
				env = float(note_len - i) / rel
			else:
				env = 1.0
			# Sidechain: duck on kick (kick hits at start of each beat)
			var sc_env: float = 1.0
			if i < int(0.08 * SR):  # 80ms duck
				sc_env = 0.5 + 0.5 * (float(i) / int(0.08 * SR))  # 0.5→1.0 over 80ms
			var v: float = bass_sample * env * sc_env * 0.22
			L[start + note_start + i] += v
			R[start + note_start + i] += v

# --- Layer 2: Chords (syncopated stabs with swing, 2 detuned voices, panned L/R) ---
func _render_chords(L: PackedFloat32Array, R: PackedFloat32Array, start: int, len: int, chord: Dictionary, chord_idx: int) -> void:
	var comp_freqs: Array = chord["comp"]
	var comp_amps: Array = chord["amps"]
	# Pick a stab pattern based on chord_idx (varies per bar for rhythmic complexity)
	var pattern_idx: int = chord_idx % STAB_PATTERNS.size()
	var stab_pattern: Array = STAB_PATTERNS[pattern_idx]
	# Convert pattern indices to beat positions with swing
	# 8 positions per bar (16th grid): 0=1, 1=&1, 2=2, 3=&2, 4=3, 5=&3, 6=4, 7=&4
	# Swing: odd positions (&x) land at 0.66 of the beat instead of 0.5
	var stab_positions: Array = []
	for pos in stab_pattern:
		var beat_num: int = pos / 2  # which beat (0-3)
		var is_off: bool = (pos % 2) == 1  # is this an & position
		var beat_pos: float = float(beat_num)
		if is_off:
			beat_pos += SWING  # swung & position
		else:
			beat_pos += 0.0
		stab_positions.append(beat_pos)
	var stab_amps: Array = []  # will fill below
	for i in stab_positions.size():
		stab_amps.append(1.0 if i == 0 else 0.6)  # first stab louder
	var stab_dur: int = int(0.25 * SR)  # shorter stabs for syncopation
	# Two detuned voices (±8 cents = ±0.46% freq shift)
	var detune: float = 0.0046
	for s in stab_positions.size():
		var pos: float = stab_positions[s]
		var amp_mult: float = stab_amps[s]
		var stab_start: int = start + int(pos * BEAT_DUR * SR)
		# Two phase arrays for the two detuned voices
		var phases1: Array = []
		var phases2: Array = []
		phases1.resize(comp_freqs.size())
		phases2.resize(comp_freqs.size())
		phases1.fill(0.0)
		phases2.fill(0.0)
		var lp1: float = 0.0
		var lp2: float = 0.0
		for i in stab_dur:
			if stab_start + i >= L.size():
				break
			var env: float = exp(-float(i) / (0.15 * SR)) * amp_mult
			if i < int(0.005 * SR):
				env *= float(i) / int(0.005 * SR)
			var noise_atk: float = 0.0
			if i < int(0.004 * SR):
				noise_atk = randf_range(-1.0, 1.0) * (1.0 - float(i) / int(0.004 * SR)) * 0.06
			# Voice 1 (slightly flat) -> L
			var sample1: float = 0.0
			# Voice 2 (slightly sharp) -> R
			var sample2: float = 0.0
			for j in comp_freqs.size():
				var drift: float = sin(float(stab_start + i) / SR * 4.0 + j * 1.7) * 0.002
				var f1: float = comp_freqs[j] * (1.0 - detune) * (1.0 + drift)
				var f2: float = comp_freqs[j] * (1.0 + detune) * (1.0 + drift)
				phases1[j] += f1 / SR
				phases2[j] += f2 / SR
				var h1_1: float = sin(phases1[j]) + sin(phases1[j] * 2.0) * 0.25 + sin(phases1[j] * 3.0) * 0.12
				var h1_2: float = sin(phases2[j]) + sin(phases2[j] * 2.0) * 0.25 + sin(phases2[j] * 3.0) * 0.12
				sample1 += h1_1 * comp_amps[j]
				sample2 += h1_2 * comp_amps[j]
			# Lowpass that drops over the stab
			var cutoff: float = 3000.0 - 2200.0 * (float(i) / stab_dur)
			var alpha: float = 1.0 - exp(-2.0 * PI * cutoff / SR)
			lp1 = lp1 + alpha * (sample1 - lp1)
			lp2 = lp2 + alpha * (sample2 - lp2)
			L[stab_start + i] += (lp1 + noise_atk * 0.5) * env * 0.065
			R[stab_start + i] += (lp2 + noise_atk * 0.5) * env * 0.065

# --- Layer 3: Arpeggio (syncopated rhythm, Haas effect for width) ---
func _render_arp(L: PackedFloat32Array, R: PackedFloat32Array, start: int, len: int, chord: Dictionary, chord_idx: int) -> void:
	var arp_notes: Array = chord["arp"]
	var haas_delay: int = int(0.012 * SR)  # 12ms delay on R for Haas effect
	# Vary the rhythm: alternating 8ths and syncopated pattern
	# Pattern A: straight 8ths (1 & 2 & 3 & 4 &) = positions [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5]
	# Pattern B: syncopated (1, &2, &3, 4, &4) = positions [0, 1.66, 2.66, 3, 3.66]
	# Pattern C: 1, 2, &2, 3, &3, 4 = positions [0, 1, 1.66, 2, 2.66, 3]
	var arp_patterns: Array = [
		[0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5],  # straight 8ths
		[0.0, 1.0 + SWING - 0.34, 2.0 + SWING - 0.34, 3.0, 3.0 + SWING],  # syncopated
		[0.0, 1.0, 1.0 + SWING, 2.0, 2.0 + SWING, 3.0],  # mixed
	]
	var pattern: Array = arp_patterns[chord_idx % arp_patterns.size()]
	var note_idx: int = chord_idx % arp_notes.size()
	for pos_idx in pattern.size():
		var pos: float = pattern[pos_idx]
		var note_start: int = int(pos * BEAT_DUR * SR)
		if note_start >= len:
			break
		var note_freq: float = arp_notes[note_idx % arp_notes.size()]
		var ph := 0.0
		var note_dur: int = int(0.3 * SR)
		for j in note_dur:
			if note_start + j >= len or start + note_start + j >= L.size():
				break
			ph += note_freq / SR
			var fundamental: float = sin(ph)
			var h2: float = sin(ph * 2.0) * 0.15
			var env: float = exp(-float(j) / (0.15 * SR))
			var v: float = (fundamental + h2) * env * 0.04
			L[start + note_start + j] += v
			if note_start + j - haas_delay >= 0:
				R[start + note_start + j - haas_delay] += v * 0.85
		note_idx += 1

# --- Layer 4: Lead (saw + vibrato, doubled with detune, panned center) ---
func _render_lead(L: PackedFloat32Array, R: PackedFloat32Array, start: int, len: int, chord: Dictionary, chord_idx: int) -> void:
	if chord_idx % 5 == 4:
		return
	var lead_freq: float = chord["lead"]
	var lead_start: int = int(0.66 * BEAT_DUR * SR)
	var lead_dur: int = int(1.2 * BEAT_DUR * SR)
	var ph1 := 0.0
	var ph2 := 0.0
	var detune: float = 0.003  # ±0.3% for chorus
	for i in lead_dur:
		if lead_start + i >= len or start + lead_start + i >= L.size():
			break
		var vibrato: float = sin(float(i) / SR * TAU * 5.0) * 0.003
		ph1 += lead_freq * (1.0 - detune) * (1.0 + vibrato) / SR
		ph2 += lead_freq * (1.0 + detune) * (1.0 + vibrato) / SR
		# Saw + lowpass for warm lead
		var saw1: float = 2.0 * (ph1 - floor(ph1 + 0.5))
		var saw2: float = 2.0 * (ph2 - floor(ph2 + 0.5))
		var alpha: float = 1.0 - exp(-2.0 * PI * 2500.0 / SR)
		# Simplified: just use sine + 2nd harmonic for cleaner tone
		var s1: float = sin(ph1) + sin(ph1 * 2.0) * 0.3
		var s2: float = sin(ph2) + sin(ph2 * 2.0) * 0.3
		var env: float
		var atk: int = int(0.008 * SR)
		var rel: int = int(0.1 * SR)
		if i < atk:
			env = float(i) / atk
		elif i > lead_dur - rel:
			env = float(lead_dur - i) / rel
		else:
			env = 1.0
		# Pan slightly L/R for width
		L[start + lead_start + i] += s1 * env * 0.085
		R[start + lead_start + i] += s2 * env * 0.085

# --- Layer 5: Drums (complex pattern with shaker, ghost notes, breaks, swing) ---
func _render_drums(L: PackedFloat32Array, R: PackedFloat32Array, n: int) -> void:
	var beat_samples: int = int(BEAT_DUR * SR)
	var total_beats: int = int(LOOP_DUR / BEAT_DUR)
	var total_bars: int = total_beats / 4
	for bar in total_bars:
		var bar_start: int = bar * 4 * beat_samples
		var is_break_bar: bool = (bar == 7)  # bar 8 (0-indexed 7) = section transition break
		var is_turnaround: bool = (bar == 15)  # bar 16 = turnaround
		for beat in 4:
			var beat_start: int = bar_start + beat * beat_samples
			# Kick: 4-on-the-floor, but drop beat 1 on turnaround bars for tension
			var play_kick: bool = true
			if is_turnaround and beat == 0:
				play_kick = false
			if is_break_bar and beat < 2:
				play_kick = false  # break: drop first 2 kicks
			if play_kick:
				_render_kick(L, R, beat_start, n)
			# Clap/snare: beats 2 and 4
			if beat == 1 or beat == 3:
				_render_clap(L, R, beat_start, n)
				# Ghost note: soft snare on the & after beat 2 and 4
				var ghost_pos: int = beat_start + int(beat_samples * SWING)
				_render_ghost_snare(L, R, ghost_pos, n)
			# Hats: off-beat 8ths with swing — pan right
			var hat_pos: int = beat_start + int(beat_samples * SWING)
			_render_hat(L, R, hat_pos, n)
			# Extra hat on beat 4& for push into next bar
			if beat == 3:
				var push_hat: int = beat_start + int(beat_samples * 1.0 + beat_samples * SWING * 0.5)
				if push_hat < n:
					_render_hat(L, R, push_hat, n)
			# Cowbell: beats 3 and 4 (kaiwai-kyoku signature)
			if beat == 2 or beat == 3:
				_render_cowbell(L, R, beat_start, n)
		# Shaker: 16th notes throughout the bar (low velocity, acoustic texture)
		if not is_break_bar:
			_render_shaker(L, R, bar_start, n)
		# Drum fill at break bar (bar 8): snare rolls on beats 3-4
		if is_break_bar:
			_render_drum_fill(L, R, bar_start + 2 * beat_samples, n)

func _render_kick(L: PackedFloat32Array, R: PackedFloat32Array, start: int, n: int) -> void:
	var kick_dur: int = int(0.14 * SR)
	var ph := 0.0
	var click_lp: float = 0.0
	var click_alpha: float = 1.0 - exp(-2.0 * PI * 2000.0 / SR)
	for i in kick_dur:
		if start + i >= n:
			break
		var t: float = float(i) / SR
		var freq: float = 80.0 * exp(-t / 0.03) + 40.0
		ph += freq / SR
		var body: float = sin(ph)
		var click: float = 0.0
		if i < int(0.003 * SR):
			var raw_click: float = randf_range(-1.0, 1.0) * (1.0 - float(i) / int(0.003 * SR))
			click_lp = click_lp + click_alpha * (raw_click - click_lp)
			click = click_lp * 0.2
		var env: float = exp(-float(i) / (0.06 * SR))
		var v: float = (body + click) * env * 0.28
		L[start + i] += v
		R[start + i] += v  # center

func _render_clap(L: PackedFloat32Array, R: PackedFloat32Array, start: int, n: int) -> void:
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
		hp_state = raw - prev_raw + (1.0 - hp_alpha) * hp_state
		prev_raw = raw
		lp_state = lp_state + lp_alpha * (hp_state - lp_state)
		var env: float = exp(-float(i) / (0.035 * SR))
		var v: float = lp_state * env * 0.09
		# Pan slightly L/R (clap is stereo-wide in real mixes)
		L[start + i] += v * 1.1
		R[start + i] += v * 0.9

func _render_hat(L: PackedFloat32Array, R: PackedFloat32Array, start: int, n: int) -> void:
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
		var v: float = hp_state * env * 0.03
		# Pan right
		L[start + i] += v * 0.7
		R[start + i] += v * 1.0

func _render_cowbell(L: PackedFloat32Array, R: PackedFloat32Array, start: int, n: int) -> void:
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
		var s1: float = sin(ph1) * 0.6
		var s2: float = sin(ph2) * 0.4
		var raw: float = s1 + s2
		hp_state = raw - prev_hp + (1.0 - hp_alpha) * hp_state
		prev_hp = raw
		lp_state = lp_state + lp_alpha * (hp_state - lp_state)
		var env: float = exp(-float(i) / (0.08 * SR))
		var v: float = lp_state * env * 0.04
		# Pan left
		L[start + i] += v * 1.0
		R[start + i] += v * 0.7

# --- Ghost snare: very soft noise burst for rhythmic texture ---
func _render_ghost_snare(L: PackedFloat32Array, R: PackedFloat32Array, start: int, n: int) -> void:
	var dur: int = int(0.04 * SR)
	var lp_state: float = 0.0
	var alpha: float = 1.0 - exp(-2.0 * PI * 2500.0 / SR)
	for i in dur:
		if start + i >= n:
			break
		var raw: float = randf_range(-1.0, 1.0)
		lp_state = lp_state + alpha * (raw - lp_state)
		var env: float = exp(-float(i) / (0.02 * SR))
		var v: float = lp_state * env * 0.025  # very quiet
		L[start + i] += v * 0.8
		R[start + i] += v * 1.0

# --- Shaker: 16th notes, low velocity, acoustic texture ---
func _render_shaker(L: PackedFloat32Array, R: PackedFloat32Array, bar_start: int, n: int) -> void:
	var sixteenth: int = int(BEAT_DUR / 4.0 * SR)
	var shaker_dur: int = int(0.05 * SR)
	for sixteenth_idx in 16:  # 16 16th notes per bar
		var pos: int = bar_start + sixteenth_idx * sixteenth
		if pos >= n:
			break
		# Swing the off-beat 16ths slightly
		var swing_offset: int = 0
		if sixteenth_idx % 2 == 1:  # off-beat 16th
			swing_offset = int(sixteenth * (SWING - 0.5) * 0.5)
		pos += swing_offset
		# Vary velocity: stronger on beat 16th notes, weaker on offs
		var vel: float = 0.018 if sixteenth_idx % 2 == 0 else 0.012
		# Accent the "and" of 4 (16th idx 13) for push
		if sixteenth_idx == 13:
			vel = 0.025
		var hp_state: float = 0.0
		var hp_alpha: float = 1.0 - exp(-2.0 * PI * 6000.0 / SR)
		var prev_raw: float = 0.0
		for i in shaker_dur:
			if pos + i >= n:
				break
			var raw: float = randf_range(-1.0, 1.0)
			hp_state = raw - prev_raw + (1.0 - hp_alpha) * hp_state
			prev_raw = raw
			var env: float = exp(-float(i) / (0.02 * SR))
			var v: float = hp_state * env * vel
			L[pos + i] += v * 0.9
			R[pos + i] += v * 0.8

# --- Drum fill: snare roll for section transitions ---
func _render_drum_fill(L: PackedFloat32Array, R: PackedFloat32Array, start: int, n: int) -> void:
	# 2 beats of snare roll: 8th notes with increasing intensity
	var eighth: int = int(BEAT_DUR / 2.0 * SR)
	var roll_dur: int = int(0.08 * SR)  # 80ms per hit
	for hit in 4:  # 4 hits over 2 beats (8th notes)
		var pos: int = start + hit * eighth
		if pos >= n:
			break
		var intensity: float = 0.05 + 0.03 * hit  # builds up
		var lp_state: float = 0.0
		var alpha: float = 1.0 - exp(-2.0 * PI * 3000.0 / SR)
		for i in roll_dur:
			if pos + i >= n:
				break
			var raw: float = randf_range(-1.0, 1.0)
			lp_state = lp_state + alpha * (raw - lp_state)
			var env: float = exp(-float(i) / (0.04 * SR))
			var v: float = lp_state * env * intensity
			L[pos + i] += v * 0.9
			R[pos + i] += v * 1.0
	# Final crash-like noise at the end of the fill
	var crash_pos: int = start + 4 * eighth
	if crash_pos < n:
		var crash_dur: int = int(0.4 * SR)
		var hp_state: float = 0.0
		var hp_alpha: float = 1.0 - exp(-2.0 * PI * 5000.0 / SR)
		var prev_raw: float = 0.0
		for i in crash_dur:
			if crash_pos + i >= n:
				break
			var raw: float = randf_range(-1.0, 1.0)
			hp_state = raw - prev_raw + (1.0 - hp_alpha) * hp_state
			prev_raw = raw
			var env: float = exp(-float(i) / (0.3 * SR))
			var v: float = hp_state * env * 0.04
			L[crash_pos + i] += v
			R[crash_pos + i] += v

# --- Schroeder reverb (4 parallel combs + 2 series allpass, stereo) ---
func _apply_reverb_stereo(L: PackedFloat32Array, R: PackedFloat32Array, n: int) -> void:
	# Comb filter delays (in samples) — prime numbers for smooth decay
	var comb_delays: Array = [int(0.0297 * SR), int(0.0371 * SR), int(0.0411 * SR), int(0.0437 * SR)]
	var comb_feedback: Array = [0.84, 0.82, 0.80, 0.78]
	var allpass_delays: Array = [int(0.005 * SR), int(0.0017 * SR)]
	var allpass_feedback: float = 0.7
	# Comb buffers for L and R (slightly different decay for width)
	var comb_l: Array = []
	var comb_r: Array = []
	for d in comb_delays:
		var buf_l := PackedFloat32Array()
		var buf_r := PackedFloat32Array()
		buf_l.resize(d)
		buf_r.resize(d)
		buf_l.fill(0.0)
		buf_r.fill(0.0)
		comb_l.append(buf_l)
		comb_r.append(buf_r)
	var comb_idx: Array = [0, 0, 0, 0]
	# Allpass buffers
	var ap_l: Array = []
	var ap_r: Array = []
	for d in allpass_delays:
		var buf_l := PackedFloat32Array()
		var buf_r := PackedFloat32Array()
		buf_l.resize(d)
		buf_r.resize(d)
		buf_l.fill(0.0)
		buf_r.fill(0.0)
		ap_l.append(buf_l)
		ap_r.append(buf_r)
	var ap_idx: Array = [0, 0]
	var wet_l := PackedFloat32Array()
	var wet_r := PackedFloat32Array()
	wet_l.resize(n)
	wet_r.resize(n)
	for i in n:
		var dry_l: float = L[i] * 0.25
		var dry_r: float = R[i] * 0.25
		# 4 parallel combs
		var comb_sum_l: float = 0.0
		var comb_sum_r: float = 0.0
		for c in 4:
			var dl: int = comb_delays[c]
			var dly_l: float = comb_l[c][comb_idx[c]]
			var dly_r: float = comb_r[c][comb_idx[c]]
			comb_l[c][comb_idx[c]] = dry_l + dly_l * comb_feedback[c]
			comb_r[c][comb_idx[c]] = dry_r + dly_r * comb_feedback[c]
			comb_sum_l += dly_l
			comb_sum_r += dly_r
			comb_idx[c] = (comb_idx[c] + 1) % dl
		# 2 series allpass
		var ap_in_l: float = comb_sum_l * 0.25
		var ap_in_r: float = comb_sum_r * 0.25
		for a in 2:
			var da: int = allpass_delays[a]
			var dly_l: float = ap_l[a][ap_idx[a]]
			var dly_r: float = ap_r[a][ap_idx[a]]
			ap_l[a][ap_idx[a]] = ap_in_l + dly_l * allpass_feedback
			ap_r[a][ap_idx[a]] = ap_in_r + dly_r * allpass_feedback
			ap_in_l = -ap_in_l + dly_l * (1.0 + allpass_feedback)
			ap_in_r = -ap_in_r + dly_r * (1.0 + allpass_feedback)
			ap_idx[a] = (ap_idx[a] + 1) % da
		wet_l[i] = ap_in_l
		wet_r[i] = ap_in_r
		# Mix wet into dry (25% wet)
		L[i] = L[i] + wet_l[i] * 0.25
		R[i] = R[i] + wet_r[i] * 0.25

# --- Master: lowpass @ 6kHz + soft tape saturation, stereo ---
func _master_process(L: PackedFloat32Array, R: PackedFloat32Array, n: int) -> void:
	var lp_l: float = 0.0
	var lp_r: float = 0.0
	var alpha: float = 1.0 - exp(-2.0 * PI * 6000.0 / SR)
	for i in n:
		# Lowpass @ 6kHz (warm, removes remaining harshness)
		lp_l = lp_l + alpha * (L[i] - lp_l)
		lp_r = lp_r + alpha * (R[i] - lp_r)
		L[i] = L[i] * 0.6 + lp_l * 0.4
		R[i] = R[i] * 0.6 + lp_r * 0.4
		# Soft tape saturation (gentle tanh)
		L[i] = tanh(L[i] * 0.6)
		R[i] = tanh(R[i] * 0.6)

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
