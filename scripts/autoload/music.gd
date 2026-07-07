extends Node
## Music — procedural main theme for Dungeon Caretaker.
##
## Generates a 12-second looped AudioStreamWAV at startup using speder2
## chord-timbre techniques (drop voicings, amplitude scaling, micro-pitch
## drift, slow attack). The loop plays continuously on the Music bus.
##
## Chord progression: Am - F - G - Em (i - VI - VII - v in A minor)
## 80 BPM, 4 beats per chord, 4 chords = 16 beats = 12 seconds.
##
## Three layers baked into one loop:
##   1. Pad: sustained chord with drop voicing + min9/maj9 extension
##   2. Bass: root note plucked (triangle) on beat 1 of each chord
##   3. Arpeggio: 8th notes cycling through chord tones (sine, quiet)
##
## Speder2 techniques applied:
## - Drop voicings: root in octave 2, chord tones in octaves 4-5 (spread)
## - Amplitude scaling: 9th extension at -12dB relative to root
## - Micro-pitch drift: ±0.12% detuning per voice (prevents hollow robotic)
## - Slow attack: 50ms attack on pad chords (ambient, not plucked)

const SR := 44100
const BPM := 80.0
const BEATS_PER_CHORD := 4
const CHORD_COUNT := 4
const BEAT_DUR := 60.0 / BPM  # 0.75s per beat
const CHORD_DUR := BEAT_DUR * BEATS_PER_CHORD  # 3.0s per chord
const LOOP_DUR := CHORD_DUR * CHORD_COUNT  # 12.0s total

var _stream: AudioStreamWAV
var _player: AudioStreamPlayer

func _ready() -> void:
	_stream = _render_theme()
	# Configure loop
	_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_stream.loop_begin = 0
	_stream.loop_end = _stream.data.size() / 2  # sample count (16-bit mono)
	_player = AudioStreamPlayer.new()
	_player.stream = _stream
	_player.bus = "Music"
	_player.volume_db = -14.0
	_player.name = "MusicPlayer"
	add_child(_player)
	_player.play()

# --- Chord definitions (A minor key) ---
# Each chord: [root_freq, voicing_freqs, amps, ext_freq, ext_amp]
# Voicing: root in octave 2, then chord tones spread across octaves 4-5.
# Extension (9th) added at -12dB relative to root for speder2 warmth.

const CHORDS := [
	# Am9: A2(110) + E4(329.63) + A4(440) + C5(523.25) + E5(659.25) + ext G4(392, 9th)
	{
		"root": 110.0,
		"voicing": [329.63, 440.0, 523.25, 659.25],
		"amps": [0.25, 0.30, 0.20, 0.12],
		"ext_freq": 392.0,  # 9th (G)
		"ext_amp": 0.06,
		"bass_note": 110.0,  # A2
		"arp_notes": [220.0, 261.63, 329.63, 440.0]  # A3 C4 E4 A4
	},
	# Fmaj9: F2(87.31) + A3(220) + F4(349.23) + A4(440) + C5(523.25) + ext G4(392, 9th)
	{
		"root": 87.31,
		"voicing": [220.0, 349.23, 440.0, 523.25],
		"amps": [0.25, 0.28, 0.20, 0.12],
		"ext_freq": 392.0,  # 9th (G)
		"ext_amp": 0.06,
		"bass_note": 87.31,  # F2
		"arp_notes": [174.61, 220.0, 261.63, 349.23]  # F3 A3 C4 F4
	},
	# Gmaj9: G2(98) + D4(293.66) + G4(392) + B4(493.88) + D5(587.33) + ext A4(440, 9th)
	{
		"root": 98.0,
		"voicing": [293.66, 392.0, 493.88, 587.33],
		"amps": [0.25, 0.28, 0.20, 0.12],
		"ext_freq": 440.0,  # 9th (A)
		"ext_amp": 0.06,
		"bass_note": 98.0,  # G2
		"arp_notes": [196.0, 246.94, 293.66, 392.0]  # G3 B3 D4 G4
	},
	# Em9: E2(82.41) + B3(246.94) + E4(329.63) + G4(392) + B4(493.88) + ext F#4(369.99, 9th)
	{
		"root": 82.41,
		"voicing": [246.94, 329.63, 392.0, 493.88],
		"amps": [0.25, 0.28, 0.20, 0.12],
		"ext_freq": 369.99,  # 9th (F#)
		"ext_amp": 0.06,
		"bass_note": 82.41,  # E2
		"arp_notes": [164.81, 196.0, 246.94, 329.63]  # E3 G3 B3 E4
	},
]

func _render_theme() -> AudioStreamWAV:
	var n: int = int(LOOP_DUR * SR)
	var o := PackedFloat32Array()
	o.resize(n)
	# For each chord, render its segment
	for chord_idx in CHORD_COUNT:
		var chord: Dictionary = CHORDS[chord_idx]
		var start_sample: int = int(chord_idx * CHORD_DUR * SR)
		var chord_samples: int = int(CHORD_DUR * SR)
		_render_pad(o, start_sample, chord_samples, chord)
		_render_bass(o, start_sample, chord_samples, chord)
		_render_arp(o, start_sample, chord_samples, chord)
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

# --- Pad layer: sustained chord with slow attack/release ---
func _render_pad(out: PackedFloat32Array, start: int, len: int, chord: Dictionary) -> void:
	var voicing: Array = chord["voicing"]
	var amps: Array = chord["amps"]
	var ext_freq: float = chord["ext_freq"]
	var ext_amp: float = chord["ext_amp"]
	var root_freq: float = chord["root"]
	# Include root + extension in the voice list
	var all_freqs: Array = [root_freq]
	all_freqs.append_array(voicing)
	all_freqs.append(ext_freq)
	var all_amps: Array = [0.18]  # root (sub-bass, quieter to not overwhelm)
	all_amps.append_array(amps)
	all_amps.append(ext_amp)
	var phases: Array = []
	phases.resize(all_freqs.size())
	phases.fill(0.0)
	# Envelope: 50ms attack, sustain, 500ms release at end
	var atk_samples := int(0.05 * SR)
	var rel_samples := int(0.5 * SR)
	for i in len:
		var env: float
		if i < atk_samples:
			env = float(i) / atk_samples
		elif i > len - rel_samples:
			env = float(len - i) / rel_samples
		else:
			env = 1.0
		# Slight LFO amplitude modulation (1.5Hz) for "breathing" pad
		env *= 0.85 + 0.15 * sin(float(i) / SR * TAU * 1.5 + chord.root * 0.01)
		var sample := 0.0
		for j in all_freqs.size():
			# Micro-pitch drift (±0.12% per voice, speder2 technique)
			var drift: float = sin(float(i) / SR * 3.0 + j * 1.7) * 0.0012
			phases[j] += all_freqs[j] * (1.0 + drift) / SR
			sample += sin(phases[j]) * all_amps[j]
		out[start + i] += sample * env * 0.18

# --- Bass layer: root note plucked on beat 1 ---
func _render_bass(out: PackedFloat32Array, start: int, len: int, chord: Dictionary) -> void:
	var bass_freq: float = chord["bass_note"]
	var note_dur := int(2.0 * SR)  # 2-second decay (covers half the chord)
	var ph := 0.0
	for i in note_dur:
		if i >= len:
			break
		# Triangle wave for warm bass (NES bass technique)
		ph += bass_freq / SR
		var tri: float = 2.0 * abs(2.0 * fmod(ph, 1.0) - 1.0) - 1.0
		# Plucked envelope: 5ms attack, exponential decay
		var env: float
		if i < int(0.005 * SR):
			env = float(i) / int(0.005 * SR)
		else:
			env = exp(-float(i - int(0.005 * SR)) / (0.6 * SR))
		out[start + i] += tri * env * 0.35

# --- Arpeggio layer: 8th notes cycling through chord tones ---
func _render_arp(out: PackedFloat32Array, start: int, len: int, chord: Dictionary) -> void:
	var arp_notes: Array = chord["arp_notes"]
	var eighth_dur := int(BEAT_DUR / 2.0 * SR)  # 0.375s per 8th note at 80 BPM
	var note_idx := 0
	var i := 0
	while i < len:
		var note_freq: float = arp_notes[note_idx % arp_notes.size()]
		var note_end: int = min(i + eighth_dur, len)
		var ph := 0.0
		var note_len: int = note_end - i
		for j in note_len:
			ph += note_freq / SR
			# Plucked sine with quick decay
			var env: float
			if j < int(0.003 * SR):
				env = float(j) / int(0.003 * SR)
			else:
				env = exp(-float(j - int(0.003 * SR)) / (0.15 * SR))
			out[start + i + j] += sin(ph) * env * 0.07
		note_idx += 1
		i = note_end

## Set music volume (0.0 = silent, 1.0 = full).
func set_volume(v: float) -> void:
	if _player:
		_player.volume_db = linear_to_db(clampf(v, 0.0, 1.0)) - 14.0

## Stop the music.
func stop() -> void:
	if _player:
		_player.stop()

## Start the music (if stopped).
func play() -> void:
	if _player and not _player.playing:
		_player.play()
