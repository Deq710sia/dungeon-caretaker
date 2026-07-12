extends Node
## Telemetry — structured event sink for the Design Lab.
##
## Always-present autoload. When DISARMED (default), every emit() is a single
## bool check + early return — zero overhead in normal play. When ARMED by
## PlaytestDriver, events are appended as JSONL to user://telemetry_<label>.jsonl.
##
## On game-nightly (2-state NORMAL/PHASE movement), the events emitted are
## slightly different from main's 4-state version:
##   - state_change events use NORMAL/PHASE (not FLOAT/DIVE/COAST)
##   - phase_activated, phase_expired_natural, phase_cancelled_manual events
##     (the bifurcation from v0.36 IS brought over — see ghost_movement.gd)
##   - coast_entered event emitted when is_coasting() transitions false→true
##     (since COAST isn't a discrete state here, it's a momentum threshold)
##   - dive_entered event emitted on _end_phase impulse (the one-shot DIVE
##     replacement — same telemetry event name for analyzer compatibility)
##   - pulse_fired, pulse_denied unchanged
##   - 10Hz tick snapshots include state (NORMAL/PHASE), momentum, is_coasting flag
##
## Event format (one JSON object per line):
##   {"t": 12.345, "type": "state_change", "from": "NORMAL", "to": "PHASE", ...}
## `t` is seconds since arm() was called (run-relative timestamp).

var armed: bool = false
var sink: FileAccess = null
var _start_time: float = 0.0

func _ready() -> void:
	# Default state — disarmed. Game runs normally.
	armed = false

## Arm the sink: open the JSONL file and start accepting events.
## Called by PlaytestDriver at the start of a playtest run.
func arm(label: String) -> void:
	if armed:
		push_warning("Telemetry.arm() called while already armed — ignoring")
		return
	var path: String = "user://telemetry_%s.jsonl" % label
	sink = FileAccess.open(path, FileAccess.WRITE)
	if sink == null:
		push_error("Telemetry.arm() could not open %s" % path)
		return
	armed = true
	_start_time = Time.get_ticks_msec()
	sink.store_line("{\"t\": 0.0, \"type\": \"run_start\", \"label\": \"%s\"}" % label)

## Disarm: flush + close the file. Called by PlaytestDriver at run end.
func disarm() -> void:
	if not armed:
		return
	var elapsed: float = (Time.get_ticks_msec() - _start_time) / 1000.0
	sink.store_line("{\"t\": %.3f, \"type\": \"run_end\", \"elapsed\": %.3f}" % [elapsed, elapsed])
	sink.close()
	sink = null
	armed = false

## Emit an event. No-op if disarmed. The `event` dict is supplemented with
## the current run-relative timestamp automatically.
func emit(event: Dictionary) -> void:
	if not armed or sink == null:
		return
	var elapsed: float = (Time.get_ticks_msec() - _start_time) / 1000.0
	event["t"] = elapsed
	sink.store_line(JSON.stringify(event))
	# Don't flush per-event — perf cost. File flushes on close.

## Convenience: emit a tick snapshot (called by GhostMovement at 10Hz).
func emit_tick(data: Dictionary) -> void:
	data["type"] = "tick"
	emit(data)

## Returns true if telemetry is currently armed (for game code that wants to
## gate expensive snapshot construction).
func is_armed() -> bool:
	return armed
