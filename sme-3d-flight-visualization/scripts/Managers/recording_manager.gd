extends Node

var _recorder: Node = null

## Called by FlightRecorder in its own _ready()
func register_recorder(recorder: Node) -> void:
	_recorder = recorder
	print("[RecordingManager] Recorder registered.")


## Called by UI to start a recording
func start_recording(custom_name: String = "") -> void:
	if _recorder == null:
		push_error("[RecordingManager] No recorder registered.")
		return
	_recorder.start_recording(custom_name)

## Called by UI to stop recording
func stop_recording() -> void:
	if _recorder == null:
		push_error("[RecordingManager] No recorder registered.")
		return 
	_recorder.stop_recording()

## Returns true if a reocrding is currently active
func is_recording() -> bool:
	if _recorder == null:
		return false
	return _recorder.is_recording
