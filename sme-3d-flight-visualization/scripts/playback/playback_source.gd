#|------------------------------------------------------------------------------------
#|   Unclassified
#|------------------------------------------------------------------------------------
#|
#|   SME Solutions, Inc.
#|   Copyright 2026 SME Solutions, Inc. All Rights Reserved
#|   SME Solutions Proprietary Information
#|
#|------------------------------------------------------------------------------------
#|
#|   File Name   : playback_source.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Playback telemetry source. Extends TelemetrySource.
#|       Loads a binary flight recording and replays it by calling
#|       TelemetryManager.forward_pose() directly each frame.
#|       Registers itself with SourceManager on ready.
#|
#|   POC         :
#|       Aramis Hernandez
#|
#|------------------------------------------------------------------------------------

extends TelemetrySource


@export var recording_dir : String = "res://data/recorded_flightpath/"
const FORMAT := 0x464C5448 
#const FRAME_SIZE := 28 #7x float32 (7 values)

#signal recording_loaded(file_path: String, framecount: int)

#signal frame_changed(current_index: int, total_frames: int)

#signal playback_completed()

var _frames: Array = []
var _current_index: int = 0
var _playback_clock: float = 0.0
var _is_playing: bool = false

#Main purpose for unit testing to allow the assignment of mock managers
#If none is assigned falls back on the autoload singletons
var _telemetry_manager = null
var _source_manger = null

func _ready() -> void:
	#Fall back on autoloads if not assigned
	if _telemetry_manager == null:
		_telemetry_manager = TelemetryManager
	
	if _source_manger == null:
		_source_manger = SourceManager
	
	# Self-register so SourceManager knows we exist
	SourceManager.register_source("PLAYBACK", self)

func start() -> void:
	if _frames.is_empty():
		push_warning("[PlaybackSource] No recording loaded. Call load_file() first.")
		return

	
	_current_index = 0
	_playback_clock = 0.0
	_is_playing = true
	print("[PlaybackSource] Playback started. %d frames." % _frames.size())

func stop() -> void:
	_is_playing = false
	_current_index = 0
	_playback_clock = 0.0
	

	print("[PlaybackSource] Stopped.")

func pause() -> void:
	_is_playing = false
	print("[PlaybackSource] Paused at frame %d / %d." % [_current_index, _frames.size()])


func resume() -> void:
	if _frames.is_empty():
		return
	
	# Re-anchor clock to current frame so resume is seamless
	_playback_clock = _frames[_current_index]["t"] - _frames[0]["t"]
	_is_playing = true
	print("[PlaybackSource] Resumed from frame %d / %d." % [_current_index, _frames.size()])

func load_file(path: String) -> bool:
	#var full_path := ProjectSettings.globalize_path(recording_dir)
	if not FileAccess.file_exists(path):
		push_warning("[PlaybackSource] File not found: %s" % path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[PlaybackSource] Could not open: %s" % path)
		return false
	
	var format := file.get_32()
	var count := file.get_32()
	
	if format != FORMAT:
		push_warning("[PlaybackSource] Invaild file - invaild format")
		file.close()
		return false
	
	_frames.clear()
	for i in range(count):
		_frames.append({
			"t": file.get_float(),
			"px": file.get_float(),
			"py": file.get_float(),
			"pz": file.get_float(),
			"ry": file.get_float(),
			"rz": file.get_float(),
			"rx": file.get_float()
		})
	file.close()
	_current_index = 0
	_playback_clock = 0.0
	
	print("[PlaybackSource] Loaded %d frames from %s" % [_frames.size(), path])
	#recording_loaded.emit(path, _frames.size())
	TelemetryManager.forward_recording_loaded(path, _frames.size())
	return true

## Seeks to a specific frame index and immediately emits that frame
func seek(index: int) -> void:
	_current_index = clamp(index, 0, _frames.size() - 1)
	_playback_clock = _frames[_current_index]["t"] - _frames[0]["t"]
	_emit_frame(_frames[_current_index])
	TelemetryManager.forward_frame_changed(_current_index, _frames.size())

## Returns true if a recording has been added
func has_recording() -> bool:
	return not _frames.is_empty()


## Lists all available .bin recording to the output panel
func list_recordings() -> void:
	var dir := DirAccess.open(recording_dir)
	if dir == null:
		print("[PlaybackSource] No recordings directory found.")
		return
	print("[PlaybackSource] Available recordings:")
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".bin"):
			print("  -> ", f)
		f = dir.get_next()
	dir.list_dir_end()



func _process(delta) -> void:
	if not _is_playing or _frames.is_empty():
		return
	
	_playback_clock += delta
	
	while _current_index < _frames.size():
		var frame: Dictionary = _frames[_current_index]
		var normalised_time: float = frame["t"] - _frames[0]["t"]
		
		if _playback_clock < normalised_time:
			break # Not the time for this frame yet
		
		_emit_frame(frame)
		_current_index += 1
		TelemetryManager.forward_frame_changed(_current_index, _frames.size())
		
	if _current_index >= _frames.size():
		_is_playing = false
		TelemetryManager.forward_playback_completed()
		print("[PlaybackSource] Playback complete.")



func _emit_frame(frame: Dictionary) -> void:
	TelemetryManager.forward_pose(
		Vector3(frame["px"], frame["py"], frame["pz"]),
		Vector3(frame["ry"], frame["rz"], frame["rx"]),
		false,
		frame["t"]
	)
