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

func _blip() -> PackedFloat32Array:
	var n := int(0.12 * SR); var e := _env(n, 0.005, 0.06); var o := PackedFloat32Array(); o.resize(n)
	var ph := 0.0
	for i in n:
		ph += (880.0 - 300.0 * float(i)/n) / SR
		o[i] = (1.0 if fmod(ph,1.0) < 0.5 else -1.0) * e[i] * 0.3
	return o

func _chime() -> PackedFloat32Array:
	var n := int(0.5 * SR); var e := _env(n, 0.01, 0.4); var o := PackedFloat32Array(); o.resize(n)
	for i in n:
		var t := float(i)/SR
		var s := sin(TAU*880*t) + 0.6*sin(TAU*1318*t) + 0.4*sin(TAU*1760*t)
		o[i] = s * e[i] * 0.2
	return o

func _thud() -> PackedFloat32Array:
	# Soft low impact — triangle wave (not square) + minimal noise.
	# Triangle waves are what NES used for soft percussion — warmer than
	# square, less buzzy. Notes: A2 (110Hz) descending to E2 (82Hz).
	var n := int(0.18 * SR); var e := _env(n, 0.002, 0.06); var o := PackedFloat32Array(); o.resize(n)
	var ph := 0.0
	for i in n:
		ph += (110.0 - 28.0*float(i)/n) / SR
		# Triangle wave (softer than square): 2*abs(2*(ph-floor(ph+0.5)))-1
		var tri: float = 2.0 * abs(2.0 * fmod(ph, 1.0) - 1.0) - 1.0
		o[i] = (tri * 0.7 + randf_range(-1,1) * 0.15) * e[i] * 0.5
	return o

func _hit() -> PackedFloat32Array:
	# Soft impact — sine wave with second harmonic (not square+noise).
	# Notes: A3 (220Hz) descending to A2 (110Hz). The harmonic at 2x
	# adds warmth without harshness. Low noise just for texture.
	var n := int(0.14 * SR); var e := _env(n, 0.001, 0.04); var o := PackedFloat32Array(); o.resize(n)
	var ph := 0.0
	for i in n:
		var f := 220.0 - 110.0*float(i)/n
		ph += f / SR
		var t := float(i)/SR
		o[i] = (sin(ph) * 0.5 + 0.3 * sin(ph * 2.0) + randf_range(-1,1) * 0.1) * e[i] * 0.4
	return o

func _shatter() -> PackedFloat32Array:
	# Crystal break — descending sine arpeggio (not noise burst).
	# Notes: C7 (2093Hz) -> G6 (1568Hz) -> E6 (1319Hz) -> A5 (880Hz).
	# Each note is a short sine with quick decay — reads as crystalline
	# without the harsh white noise of the old version.
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
		o[i] = sin(TAU * f * t) * e_val * 0.25
	return o

func _coin() -> PackedFloat32Array:
	var n := int(0.22 * SR); var e := _env(n, 0.003, 0.12); var o := PackedFloat32Array(); o.resize(n)
	var split := n / 2
	for i in n:
		var t := float(i)/SR
		var f := 988.0 if i < split else 1319.0
		o[i] = sin(TAU*f*t) * e[i] * 0.3
	return o

func _select() -> PackedFloat32Array:
	var n := int(0.05 * SR); var e := _env(n, 0.002, 0.02); var o := PackedFloat32Array(); o.resize(n)
	for i in n:
		o[i] = sin(TAU*1200*float(i)/SR) * e[i] * 0.25
	return o

func _deny() -> PackedFloat32Array:
	# Soft denial — sine wave (not square) descending from E3 (165Hz) to A2 (110Hz).
	# Sine reads as a gentle "no" rather than a buzzy error tone.
	var n := int(0.2 * SR); var e := _env(n, 0.005, 0.12); var o := PackedFloat32Array(); o.resize(n)
	var ph := 0.0
	for i in n:
		ph += (165.0 - 55.0*float(i)/n) / SR
		o[i] = sin(ph) * e[i] * 0.25
	return o

func _bell() -> PackedFloat32Array:
	var n := int(0.8 * SR); var e := _env(n, 0.01, 0.6); var o := PackedFloat32Array(); o.resize(n)
	for i in n:
		var t := float(i)/SR
		var s := sin(TAU*523*t) + 0.5*sin(TAU*659*t) + 0.3*sin(TAU*784*t)
		o[i] = s * e[i] * 0.25
	return o

func _death() -> PackedFloat32Array:
	# Spirit death — descending sine arpeggio (not noise).
	# Notes: A4 (440Hz) -> F4 (349Hz) -> D4 (294Hz) -> A3 (220Hz).
	# Each note decays quickly — reads as a fading spirit, not a crash.
	var n := int(0.5 * SR); var o := PackedFloat32Array(); o.resize(n)
	var notes := [440.0, 349.0, 294.0, 220.0]
	var note_len := n / notes.size()
	for i in n:
		var note_idx := i / note_len
		if note_idx >= notes.size():
			note_idx = notes.size() - 1
		var f: float = notes[note_idx]
		var local_i := i - note_idx * note_len
		var e_val: float = exp(-float(local_i) / float(note_len) * 3.0)
		var t := float(i)/SR
		o[i] = sin(TAU * f * t) * e_val * 0.3
	return o

func _repair() -> PackedFloat32Array:
	var n := int(0.3 * SR); var e := _env(n, 0.01, 0.2); var o := PackedFloat32Array(); o.resize(n)
	for i in n:
		var t := float(i)/SR
		o[i] = (sin(TAU*660*t) + 0.5*sin(TAU*990*t)) * e[i] * 0.2
	return o

func _recruit() -> PackedFloat32Array:
	var n := int(0.4 * SR); var e := _env(n, 0.01, 0.3); var o := PackedFloat32Array(); o.resize(n)
	for i in n:
		var t := float(i)/SR
		var f := 523.0 if i < n / 2 else 784.0
		o[i] = sin(TAU*f*t) * e[i] * 0.25
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
	# Descending sweep ~250ms, 880Hz -> 220Hz. Sine + filtered noise swell.
	# Reads as the ghost thinning out / dropping into the spectral layer.
	var n := int(0.25 * SR); var e := _env(n, 0.005, 0.18); var o := PackedFloat32Array(); o.resize(n)
	var ph := 0.0
	for i in n:
		var f := 880.0 - 660.0 * (float(i) / n)
		ph += f / SR
		o[i] = (sin(ph) * 0.4 + randf_range(-1, 1) * 0.25 * (1.0 - float(i) / n)) * e[i] * 0.32
	return o

func _phase_out() -> PackedFloat32Array:
	# Soft rising chime ~200ms, 330Hz -> 660Hz. The snap-back from
	# incorporeal — brighter and shorter than phase_in.
	var n := int(0.20 * SR); var e := _env(n, 0.004, 0.14); var o := PackedFloat32Array(); o.resize(n)
	var ph := 0.0
	for i in n:
		var f := 330.0 + 330.0 * (float(i) / n)
		ph += f / SR
		o[i] = (sin(ph) * 0.5 + 0.3 * sin(ph * 2.0)) * e[i] * 0.25
	return o
