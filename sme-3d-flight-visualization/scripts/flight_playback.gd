extends Node


@export var recording_dir : String = "res://data/recorded_flightpath/"

const FORMAT := 0x464C5448 

var _frames: Array = []
var _current_index: int = 0

var _is_playing : bool = false
var _playback_clock : float = 0.0

func _ready():
	_list_recordings()
	print("[PlaybackTest] Ready. Press P to load latest recording.")
	load_file("flight_20260327_200025.bin")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _is_playing:
			_pause()
		else:
			_resume()
	if event.is_action_pressed("start_playback"):
		_start_playback()
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if not _is_playing or _frames.is_empty():
		return
	
	_playback_clock += delta
	
	while _current_index < _frames.size():
		var frame: Dictionary = _frames[_current_index]
		var normalised_time: float = frame["t"] - _frames[0]["t"]
		
		if _playback_clock < normalised_time:
			break
		
		TelemetryManager.forward_pose(
			Vector3(frame["px"], frame["py"], frame["pz"]),
			Vector3(frame["rx"], frame["ry"], frame["rz"]),
			false,
			frame["t"]
		)
		_current_index += 1
	if _current_index >= _frames.size():
		_is_playing = false
		print("[PlaybackTest] Playback complete.")

#call this in the debugger to laod a specific recording
func load_file(fileName: String) -> void:
	var path := ProjectSettings.globalize_path(recording_dir + fileName)
	
	if not FileAccess.file_exists(path):
		print("[PlaybackTest] File not found: ", path)
		print("[PlaybackTest] Available recordings:")
		_list_recordings()
		return 
	
	_load_recording(path)
	print("[PlaybackTest] Frames loaded: ", _frames.size())  # add this
	print("[PlaybackTest] File loaded. Press P to play.")
	
func list_files() -> void:
	_list_recordings()


func _load_recording(path: String) -> void:
	_frames.clear()
	_current_index = 0
	_playback_clock = 0.0
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[PlaybackTest] Could not open: " + path)
		return
	
	var format := file.get_32()
	var count := file.get_32() 
	
	if format != FORMAT:
		push_error("[PlaybackTest] Not a valid flight file.")
		file.close()
		return
	
	for i in range(count):
		_frames.append({
			"t": file.get_float(),
			"px": file.get_float(),
			"py": file.get_float(),
			"pz": file.get_float(),
			"rx": file.get_float(),
			"ry": file.get_float(),
			"rz": file.get_float()
		})
	
	file.close()
	print("[PlaybackTest] Loaded %d frames from: %s" % [_frames.size(), path])

func _start_playback() -> void:
	if _frames.is_empty():
		print("[PlaybackTest] No file loaded. Call load_file(\"filename.bin\") first.")
		return
	TelemetryManager.telemetry_source = "PLAYBACK"
	_current_index = 0
	_playback_clock = 0.0
	_is_playing = true
	print("[PlaybackTest] Playing. Press Space to pause.")


func _pause() -> void:
	_is_playing = false
	print("[PlaybackTest] paused at frame %d  / %d." % [_current_index, _frames.size()])

func _resume() -> void:
	if _frames.is_empty():
		return
	_playback_clock = _frames[_current_index]["t"] - _frames[0]["t"]
	_is_playing	 = true
	print("[PlaybackTest] Resumed from frame %d / %d." % [_current_index, _frames.size()])


func _list_recordings() -> void:
	var dir := DirAccess.open(recording_dir)
	if dir == null:
		print("[PlaybackTest] No recordings directory found.")
		return
		
	print("[PLaybackTest] Available recordings:")
	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		if filename.ends_with(".bin"):
			print(" -> ", filename)
		filename = dir.get_next()
	dir.list_dir_end()
