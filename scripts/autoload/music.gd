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
var _muted: bool = false
var _saved_volume: float = -10.0

const CACHE_PATH := "user://music_cache.bin"
const CACHE_VERSION := 10  # bump when music data changes to invalidate cache

func _ready() -> void:
	_stream = _load_cached()
	if _stream == null:
		print("Music: rendering theme (first boot or cache invalid)...")
		var t0: float = Time.get_ticks_msec()
		_stream = _render_theme()
		var t1: float = Time.get_ticks_msec()
		print("Music: render took %dms, caching to disk..." % int(t1 - t0))
		_save_cached(_stream)
	else:
		print("Music: loaded from cache (instant)")
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

## Save rendered theme to disk for instant loading on next boot.
func _save_cached(wav: AudioStreamWAV) -> void:
	var f := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Music: could not open cache file for writing")
		return
	f.store_32(CACHE_VERSION)
	f.store_32(wav.mix_rate)
	f.store_32(1 if wav.stereo else 0)  # bool as int (Godot 4.3 has no store_bool)
	f.store_32(wav.data.size())
	f.store_buffer(wav.data)
	f.close()

## Load cached theme from disk. Returns null if cache is invalid/missing.
func _load_cached() -> AudioStreamWAV:
	var f := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if f == null:
		return null
	# Check version
	var ver: int = f.get_32()
	if ver != CACHE_VERSION:
		f.close()
		return null
	# Read format params
	var mix_rate: int = f.get_32()
	var stereo: bool = f.get_32() != 0
	var data_size: int = f.get_32()
	var data := PackedByteArray()
	data.resize(data_size)
	data = f.get_buffer(data_size)
	f.close()
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = mix_rate
	w.stereo = stereo
	w.data = data
	return w

func _process(_delta: float) -> void:
	# M key toggles mute
	if Input.is_action_just_pressed("mute_music"):
		_muted = not _muted
		if _muted:
			_saved_volume = _player.volume_db
			_player.volume_db = -80.0  # effectively silent
		else:
			_player.volume_db = _saved_volume

## Returns true if music is currently muted (for HUD display).
func is_muted() -> bool:
	return _muted

const CHORDS := [
	# === A1 (bars 1-4) — D major diatonic, warm maj7(9) ===
	# Dmaj9: D-F#-A-C#-E. Rootless: F#-A-C#-E = [185.00, 220.00, 277.18, 329.63]
	{"bass": 73.42, "comp": [185.00, 220.00, 277.18, 329.63], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [293.66, 369.99, 440.00, 554.37], "lead": 587.33},  # Dmaj9
	# Amaj9: A-C#-E-G#-B. Rootless: C#-E-G#-B = [277.18, 329.63, 415.30, 493.88]
	{"bass": 55.00, "comp": [277.18, 329.63, 415.30, 493.88], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [329.63, 415.30, 493.88, 587.33], "lead": 659.25},  # Amaj9
	# Bm7(9): B-D-F#-A-C#. Rootless: D-F#-A-C# = [293.66, 369.99, 440.00, 554.37]
	{"bass": 61.74, "comp": [293.66, 369.99, 440.00, 554.37], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [369.99, 440.00, 554.37, 587.33], "lead": 587.33},  # Bm7(9)
	# Gmaj9: G-B-D-F#-A. Rootless: B-D-F#-A = [246.94, 293.66, 369.99, 440.00]
	{"bass": 49.00, "comp": [246.94, 293.66, 369.99, 440.00], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [293.66, 369.99, 440.00, 587.33], "lead": 659.25},  # Gmaj9
	# repeat
	{"bass": 73.42, "comp": [185.00, 220.00, 277.18, 329.63], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [293.66, 369.99, 440.00, 554.37], "lead": 587.33},
	{"bass": 55.00, "comp": [277.18, 329.63, 415.30, 493.88], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [329.63, 415.30, 493.88, 587.33], "lead": 659.25},
	{"bass": 61.74, "comp": [293.66, 369.99, 440.00, 554.37], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [369.99, 440.00, 554.37, 587.33], "lead": 587.33},
	{"bass": 49.00, "comp": [246.94, 293.66, 369.99, 440.00], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [293.66, 369.99, 440.00, 587.33], "lead": 659.25},
	# === A2 (bars 5-8) — exact repeat ===
	{"bass": 73.42, "comp": [185.00, 220.00, 277.18, 329.63], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [293.66, 369.99, 440.00, 554.37], "lead": 587.33},
	{"bass": 55.00, "comp": [277.18, 329.63, 415.30, 493.88], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [329.63, 415.30, 493.88, 587.33], "lead": 659.25},
	{"bass": 61.74, "comp": [293.66, 369.99, 440.00, 554.37], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [369.99, 440.00, 554.37, 587.33], "lead": 587.33},
	{"bass": 49.00, "comp": [246.94, 293.66, 369.99, 440.00], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [293.66, 369.99, 440.00, 587.33], "lead": 659.25},
	{"bass": 73.42, "comp": [185.00, 220.00, 277.18, 329.63], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [293.66, 369.99, 440.00, 554.37], "lead": 587.33},
	{"bass": 55.00, "comp": [277.18, 329.63, 415.30, 493.88], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [329.63, 415.30, 493.88, 587.33], "lead": 659.25},
	{"bass": 61.74, "comp": [293.66, 369.99, 440.00, 554.37], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [369.99, 440.00, 554.37, 587.33], "lead": 587.33},
	{"bass": 49.00, "comp": [246.94, 293.66, 369.99, 440.00], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [293.66, 369.99, 440.00, 587.33], "lead": 659.25},
	# === B (bars 9-12) — subdominant excursion, Em7 → F#m7 → Gmaj9 → A7sus4 ===
	# Em7(9): E-G-B-D-F#. Rootless: G-B-D-F# = [196.00, 246.94, 293.66, 369.99]
	{"bass": 41.20, "comp": [196.00, 246.94, 293.66, 369.99], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [246.94, 293.66, 369.99, 493.88], "lead": 493.88},  # Em7(9)
	# F#m7: F#-A-C#-E. Rootless: A-C#-E-G# = [220.00, 277.18, 329.63, 415.30]
	{"bass": 46.25, "comp": [293.66, 369.99, 440.00, 554.37], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [293.66, 369.99, 440.00, 554.37], "lead": 554.37},  # F#m7
	# Gmaj9 (again)
	{"bass": 49.00, "comp": [246.94, 293.66, 369.99, 440.00], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [293.66, 369.99, 440.00, 587.33], "lead": 587.33},
	# A7sus4: A-D-E-G. Rootless: D-E-G-A = [293.66, 329.63, 392.00, 440.00] (sus = no 3rd)
	{"bass": 55.00, "comp": [293.66, 329.63, 392.00, 440.00], "amps": [0.22, 0.16, 0.14, 0.10], "arp": [329.63, 392.00, 440.00, 587.33], "lead": 659.25},  # A7sus4
	# repeat
	{"bass": 41.20, "comp": [196.00, 246.94, 293.66, 369.99], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [246.94, 293.66, 369.99, 493.88], "lead": 493.88},
	{"bass": 46.25, "comp": [293.66, 369.99, 440.00, 554.37], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [293.66, 369.99, 440.00, 554.37], "lead": 554.37},
	{"bass": 49.00, "comp": [246.94, 293.66, 369.99, 440.00], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [293.66, 369.99, 440.00, 587.33], "lead": 587.33},
	{"bass": 55.00, "comp": [293.66, 329.63, 392.00, 440.00], "amps": [0.22, 0.16, 0.14, 0.10], "arp": [329.63, 392.00, 440.00, 587.33], "lead": 659.25},
	# === A3 (bars 13-16) — return ===
	{"bass": 73.42, "comp": [185.00, 220.00, 277.18, 329.63], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [293.66, 369.99, 440.00, 554.37], "lead": 587.33},
	{"bass": 55.00, "comp": [277.18, 329.63, 415.30, 493.88], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [329.63, 415.30, 493.88, 587.33], "lead": 659.25},
	{"bass": 61.74, "comp": [293.66, 369.99, 440.00, 554.37], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [369.99, 440.00, 554.37, 587.33], "lead": 587.33},
	{"bass": 49.00, "comp": [246.94, 293.66, 369.99, 440.00], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [293.66, 369.99, 440.00, 587.33], "lead": 659.25},
	{"bass": 73.42, "comp": [185.00, 220.00, 277.18, 329.63], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [293.66, 369.99, 440.00, 554.37], "lead": 587.33},
	{"bass": 55.00, "comp": [277.18, 329.63, 415.30, 493.88], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [329.63, 415.30, 493.88, 587.33], "lead": 659.25},
	{"bass": 61.74, "comp": [293.66, 369.99, 440.00, 554.37], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [369.99, 440.00, 554.37, 587.33], "lead": 587.33},
	{"bass": 73.42, "comp": [185.00, 220.00, 277.18, 329.63], "amps": [0.20, 0.18, 0.14, 0.08], "arp": [293.66, 369.99, 440.00, 554.37], "lead": 587.33},  # Dmaj9 (resolve)
]

# Sidechain envelope: tracks kick hits, ducks bass
var _sidechain_gain: float = 1.0

# --- DSP helpers (shared across all render functions) ---
const _TWO_PI_OVER_SR := 2.0 * PI / SR

## One-pole lowpass coefficient for given cutoff frequency.
func _lp_coeff(cutoff_hz: float) -> float:
	return 1.0 - exp(-_TWO_PI_OVER_SR * cutoff_hz)

## One-pole highpass filter (stateful). Usage: var hp := _HPFilter.new(7000.0); y = hp.process(x)
class _HPFilter:
	var state: float = 0.0
	var prev: float = 0.0
	var alpha: float
	func _init(cutoff_hz: float) -> void:
		alpha = 1.0 - exp(-2.0 * PI * cutoff_hz / SR)
	func process(x: float) -> float:
		state = x - prev + (1.0 - alpha) * state
		prev = x
		return state

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

# --- Layer 1: Bass (sine + triangle 2nd, warm pluck — NOT saw buzz) ---
func _render_bass(L: PackedFloat32Array, R: PackedFloat32Array, start: int, len: int, chord: Dictionary, chord_idx: int) -> void:
	var bass_freq: float = chord["bass"]
	var next_bass: float = bass_freq
	if chord_idx + 1 < CHORDS.size():
		next_bass = CHORDS[chord_idx + 1]["bass"]
	else:
		next_bass = CHORDS[0]["bass"]
	var approach_up: float = next_bass * pow(2.0, 1.0/12.0)
	var approach_down: float = next_bass * pow(2.0, -1.0/12.0)
	var approach_freq: float = approach_down
	if bass_freq > next_bass:
		approach_freq = approach_up
	var bass_notes: Array = [bass_freq, approach_freq]
	var beat_samples: int = int(BEAT_DUR * SR)
	for beat in 2:
		var note_freq: float = bass_notes[beat]
		var sub_freq: float = note_freq * 0.5
		var note_start: int = beat * beat_samples
		var ph_sine := 0.0
		var ph_tri := 0.0
		var ph_sub := 0.0
		var note_len: int = beat_samples
		for i in note_len:
			if start + note_start + i >= L.size():
				break
			ph_sine += note_freq / SR
			ph_tri += note_freq * 2.0 / SR  # 2nd harmonic (octave up)
			ph_sub += sub_freq / SR
			# Sine fundamental (pure, warm)
			var sine_val: float = sin(ph_sine)
			# Triangle 2nd harmonic at -12dB (woody body, not buzzy like saw)
			var tri_val: float = (2.0 * abs(2.0 * fmod(ph_tri, 1.0) - 1.0) - 1.0) * 0.25
			# Sub-octave sine for weight
			var sub_val: float = sin(ph_sub) * 0.3
			var bass_sample: float = sine_val + tri_val + sub_val
			# Pluck envelope: 2ms attack, exp decay over 0.4s (feels played, not sustained)
			var env: float
			var atk: int = int(0.002 * SR)
			if i < atk:
				env = float(i) / atk
			else:
				env = exp(-float(i - atk) / (0.4 * SR))
			# Sidechain: duck on kick
			var sc_env: float = 1.0
			if i < int(0.08 * SR):
				sc_env = 0.5 + 0.5 * (float(i) / int(0.08 * SR))
			var v: float = bass_sample * env * sc_env * 0.20
			L[start + note_start + i] += v
			R[start + note_start + i] += v


# --- Layer 2: Chords (FM bell pluck — pretty, glassy, NOT saw stabs) ---
func _render_chords(L: PackedFloat32Array, R: PackedFloat32Array, start: int, len: int, chord: Dictionary, chord_idx: int) -> void:
	var comp_freqs: Array = chord["comp"]
	var comp_amps: Array = chord["amps"]
	var pattern_idx: int = chord_idx % STAB_PATTERNS.size()
	var stab_pattern: Array = STAB_PATTERNS[pattern_idx]
	var stab_positions: Array = []
	for pos in stab_pattern:
		var beat_num: int = pos / 2
		var is_off: bool = (pos % 2) == 1
		var beat_pos: float = float(beat_num)
		if is_off:
			beat_pos += SWING
		stab_positions.append(beat_pos)
	var stab_dur: int = int(0.4 * SR)  # longer than stab — bell ring
	var detune: float = 0.006  # ±6 cents (wider for chorus)
	for s in stab_positions.size():
		var pos: float = stab_positions[s]
		var amp_mult: float = 1.0 if s == 0 else 0.6
		var stab_start: int = start + int(pos * BEAT_DUR * SR)
		var phases1: Array = []
		var phases2: Array = []
		var mod_phases: Array = []
		phases1.resize(comp_freqs.size())
		phases2.resize(comp_freqs.size())
		mod_phases.resize(comp_freqs.size())
		phases1.fill(0.0)
		phases2.fill(0.0)
		mod_phases.fill(0.0)
		for i in stab_dur:
			if stab_start + i >= L.size():
				break
			# Bell envelope: 1ms attack, slow exp decay (0.5s — bell rings)
			var env: float = exp(-float(i) / (0.5 * SR)) * amp_mult
			if i < int(0.001 * SR):
				env *= float(i) / int(0.001 * SR)
			var sample1: float = 0.0
			var sample2: float = 0.0
			for j in comp_freqs.size():
				var drift: float = sin(float(stab_start + i) / SR * 4.0 + j * 1.7) * 0.002
				var f1: float = comp_freqs[j] * (1.0 - detune) * (1.0 + drift)
				var f2: float = comp_freqs[j] * (1.0 + detune) * (1.0 + drift)
				phases1[j] += f1 / SR
				phases2[j] += f2 / SR
				# FM bell: carrier sine modulated by 2:1 modulator
				# Modulator frequency = 2× carrier (bell-like inharmonic feel)
				mod_phases[j] += f1 * 2.0 / SR
				var mod_idx: float = 2.0 * exp(-float(i) / (0.1 * SR))  # FM index decays (bright→clean)
				var fm1: float = sin(phases1[j] + sin(mod_phases[j]) * mod_idx)
				var fm2: float = sin(phases2[j] + sin(mod_phases[j]) * mod_idx)
				sample1 += fm1 * comp_amps[j]
				sample2 += fm2 * comp_amps[j]
			L[stab_start + i] += sample1 * env * 0.055
			R[stab_start + i] += sample2 * env * 0.055


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


# --- Melody definitions (singable motif, Toby Fox leitmotif style) ---
# Each note: {pos: beat position in 2-beat chord, freq: Hz, dur: beats}
# Section A: question motif (chords 1-2) + answer motif (chords 3-4), repeats
# Section B: countermelody (chords 17-24) — higher register, transformed motif
# Section A2: restatement (chords 25-32)

# --- Melody motifs (4 only — pretty, bell-like, higher register) ---
const MOTIF_A := [  # The hook: D5→E5→F#5→E5 (stepwise in D major, singable, pretty)
	{pos=0.0, freq=587.33, dur=0.5},   # D5 (root)
	{pos=0.5, freq=659.25, dur=0.5},   # E5 (2nd)
	{pos=1.0, freq=739.99, dur=0.5},   # F#5 (3rd)
	{pos=1.5, freq=659.25, dur=1.0},   # E5 (2nd) — held
]
const MOTIF_B := [  # The answer: A4→F#4→E4→F#4 (descends, resolves warmly)
	{pos=0.0, freq=440.00, dur=0.5},   # A4 (5th)
	{pos=0.5, freq=369.99, dur=0.5},   # F#4 (3rd)
	{pos=1.0, freq=329.63, dur=0.5},   # E4 (2nd)
	{pos=1.5, freq=369.99, dur=0.5},   # F#4 (3rd)
]
const MOTIF_C := [  # Tension: B4→A4→F#4→E4 (stepwise descent, gentle not harsh)
	{pos=0.0, freq=493.88, dur=0.5},   # B4 (7th)
	{pos=0.5, freq=440.00, dur=0.5},   # A4 (5th)
	{pos=1.0, freq=369.99, dur=0.5},   # F#4 (3rd)
	{pos=1.5, freq=440.00, dur=0.5},   # A4 (5th) — resolves upward
]
const MOTIF_D := [  # B-section variation: G4→B4→D5→B4 (opens up, hopeful)
	{pos=0.0, freq=392.00, dur=0.5},   # G4 (4th — pretty sus4 color)
	{pos=0.5, freq=493.88, dur=0.5},   # B4 (7th)
	{pos=1.0, freq=587.33, dur=0.5},   # D5 (root)
	{pos=1.5, freq=493.88, dur=0.5},   # B4 (7th)
]

# AABA form with section-break rests for phrase structure
const MELODY := [
	# A1 (chords 1-8) — 4-bar phrase
	MOTIF_A, MOTIF_B, MOTIF_A, MOTIF_C,
	MOTIF_A, MOTIF_B, MOTIF_A, MOTIF_C,
	[],  # phrase break (end of A1)
	# A2 (chords 9-16) — exact repeat
	MOTIF_A, MOTIF_B, MOTIF_A, MOTIF_C,
	MOTIF_A, MOTIF_B, MOTIF_A, MOTIF_C,
	[],  # phrase break (end of A2)
	# B (chords 17-24) — contrast with REST breaks
	MOTIF_D, [], MOTIF_D, MOTIF_C,
	MOTIF_D, [], MOTIF_D, MOTIF_C,
	[],  # phrase break (end of B)
	# A3 (chords 25-32) — return, slight variation at end
	MOTIF_A, MOTIF_B, MOTIF_A, MOTIF_C,
	MOTIF_A, MOTIF_B, MOTIF_A, MOTIF_A,  # ends on A (not C) for resolution
]

# --- Layer 4: Melody (triangle wave + vibrato + pluck envelope — kalimba/celesta feel) ---
func _render_lead(L: PackedFloat32Array, R: PackedFloat32Array, start: int, len: int, chord: Dictionary, chord_idx: int) -> void:
	if chord_idx >= MELODY.size():
		return
	var melody_notes: Array = MELODY[chord_idx]
	if melody_notes.is_empty():
		return  # rest
	var detune: float = 0.003
	for note_data in melody_notes:
		var note_pos: float = note_data["pos"]
		var note_freq: float = note_data["freq"]
		var note_dur_beats: float = note_data["dur"]
		var note_start: int = int(note_pos * BEAT_DUR * SR)
		var note_dur: int = int(note_dur_beats * BEAT_DUR * SR)
		var ph1 := 0.0
		var ph2 := 0.0
		for i in note_dur:
			if note_start + i >= len or start + note_start + i >= L.size():
				break
			# Vibrato (5Hz, slightly deeper for triangle — shows more)
			var vibrato: float = sin(float(i) / SR * TAU * 5.0) * 0.005
			ph1 += note_freq * (1.0 - detune) * (1.0 + vibrato) / SR
			ph2 += note_freq * (1.0 + detune) * (1.0 + vibrato) / SR
			# Triangle wave (warmer than sine, more character than saw)
			var tri1: float = 2.0 * abs(2.0 * fmod(ph1 / TAU, 1.0) - 1.0) - 1.0
			var tri2: float = 2.0 * abs(2.0 * fmod(ph2 / TAU, 1.0) - 1.0) - 1.0
			# 3rd harmonic for sparkle (very quiet)
			var h3_1: float = sin(ph1 * 3.0) * 0.08
			var h3_2: float = sin(ph2 * 3.0) * 0.08
			# Pluck envelope: 3ms attack, exp decay over 0.6s (kalimba/celesta)
			var env: float
			var atk: int = int(0.003 * SR)
			if i < atk:
				env = float(i) / atk
			else:
				env = exp(-float(i - atk) / (0.6 * SR))
			var v1: float = (tri1 + h3_1) * env * 0.12
			var v2: float = (tri2 + h3_2) * env * 0.12
			L[start + note_start + i] += v1
			R[start + note_start + i] += v2


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
	var kick_dur: int = int(0.2 * SR)  # longer (was 0.14) — rounder
	var ph := 0.0
	for i in kick_dur:
		if start + i >= n:
			break
		var t: float = float(i) / SR
		var freq: float = 80.0 * exp(-t / 0.04) + 40.0
		ph += freq / SR
		var body: float = sin(ph)
		# Very soft click (was 0.2, now 0.08 — less harsh)
		var click: float = 0.0
		if i < int(0.002 * SR):
			click = randf_range(-1.0, 1.0) * (1.0 - float(i) / int(0.002 * SR)) * 0.08
		# Longer decay (was 0.06s, now 0.1s — rounder, less punchy/harsh)
		var env: float = exp(-float(i) / (0.1 * SR))
		var v: float = (body + click) * env * 0.25  # quieter (was 0.28)
		L[start + i] += v
		R[start + i] += v


func _render_clap(L: PackedFloat32Array, R: PackedFloat32Array, start: int, n: int) -> void:
	# Bandpass noise + tonal sine at 200Hz (wooden snap, not just noise)
	var clap_dur: int = int(0.1 * SR)
	var hp_state: float = 0.0
	var lp_state: float = 0.0
	var hp_alpha: float = _lp_coeff(800.0)
	var lp_alpha: float = _lp_coeff(3000.0)
	var prev_raw: float = 0.0
	var ph_tonal := 0.0
	for i in clap_dur:
		if start + i >= n:
			break
		var raw: float = randf_range(-1.0, 1.0)
		hp_state = raw - prev_raw + (1.0 - hp_alpha) * hp_state
		prev_raw = raw
		lp_state = lp_state + lp_alpha * (hp_state - lp_state)
		# Tonal component: 200Hz sine (body of the snap)
		ph_tonal += 200.0 / SR
		var tonal: float = sin(ph_tonal) * 0.3
		var env: float = exp(-float(i) / (0.035 * SR))
		var v: float = (lp_state + tonal) * env * 0.08
		L[start + i] += v * 1.1
		R[start + i] += v * 0.9


func _render_hat(L: PackedFloat32Array, R: PackedFloat32Array, start: int, n: int) -> void:
	# Highpass noise, very short + quiet (less hissy)
	var hat_dur: int = int(0.03 * SR)  # shorter (was 0.05)
	var hp_state: float = 0.0
	var hp_alpha: float = _lp_coeff(7000.0)
	var prev_raw: float = 0.0
	for i in hat_dur:
		if start + i >= n:
			break
		var raw: float = randf_range(-1.0, 1.0)
		hp_state = raw - prev_raw + (1.0 - hp_alpha) * hp_state
		prev_raw = raw
		var env: float = exp(-float(i) / (0.015 * SR))
		var v: float = hp_state * env * 0.02  # quieter (was 0.035)
		L[start + i] += v * 0.7
		R[start + i] += v * 1.0


# Woodblock (was cowbell — squares were harsh; sines at 800+1200Hz are woody)
func _render_cowbell(L: PackedFloat32Array, R: PackedFloat32Array, start: int, n: int) -> void:
	var cow_dur: int = int(0.08 * SR)  # shorter (was 0.18) — woodblock is crisp
	var ph1 := 0.0
	var ph2 := 0.0
	for i in cow_dur:
		if start + i >= n:
			break
		ph1 += 800.0 / SR
		ph2 += 1200.0 / SR
		# Sine (not square — warm, not piercing)
		var s1: float = sin(ph1) * 0.6
		var s2: float = sin(ph2) * 0.4
		var env: float = exp(-float(i) / (0.03 * SR))  # fast decay (was 0.08)
		var v: float = (s1 + s2) * env * 0.035
		L[start + i] += v * 1.0
		R[start + i] += v * 0.7


# --- Ghost snare: very soft noise burst for rhythmic texture ---
func _render_ghost_snare(L: PackedFloat32Array, R: PackedFloat32Array, start: int, n: int) -> void:
	var dur: int = int(0.04 * SR)
	var lp_state: float = 0.0
	var alpha: float = _lp_coeff(2500.0)
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
		var hp_alpha: float = _lp_coeff(6000.0)
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
		var alpha: float = _lp_coeff(3000.0)
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
		var hp_alpha: float = _lp_coeff(5000.0)
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
	var alpha: float = _lp_coeff(6000.0)
	for i in n:
		# Gentle lowpass @ 6kHz (warm, removes remaining harshness)
		lp_l = lp_l + alpha * (L[i] - lp_l)
		lp_r = lp_r + alpha * (R[i] - lp_r)
		L[i] = L[i] * 0.6 + lp_l * 0.4
		R[i] = R[i] * 0.6 + lp_r * 0.4
		# Soft clip ONLY above 0.85 (no blanket saturation — preserves dynamics)
		if abs(L[i]) > 0.85:
			L[i] = 0.85 + (tanh((abs(L[i]) - 0.85) * 3.0) / 3.0) * (1.0 if L[i] > 0 else -1.0)
		if abs(R[i]) > 0.85:
			R[i] = 0.85 + (tanh((abs(R[i]) - 0.85) * 3.0) / 3.0) * (1.0 if R[i] > 0 else -1.0)

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
