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

## Replays a binary flight recording as a telemetry source.
##
## This node loads a structured binary recording file and drives the telemetry
## pipeline by calling [method TelemetryManager.forward_pose] on each frame
## during [method _process]. It registers itself with [SourceManager] under
## the key [code]"PLAYBACK"[/code] so it can be selected as the active source
## at runtime.
##
## Playback is clock-driven: an internal clock accumulates delta time and
## emits all frames whose normalised timestamp has elapsed each process tick,
## preserving the original recording cadence regardless of engine frame rate.


## Directory scanned by [method list_recordings] for available [code].bin[/code] files.
@export var recording_dir : String = "res://data/recorded_flightpath/"

## Magic number identifying a valid flight recording file ([code]0x464C5448[/code] → "FLTH").
const FORMAT := 0x464C5448 

## Internal buffer of decoded frame dictionaries loaded from the recording file.
##
## Each entry contains the keys: [code]t[/code], [code]px[/code], [code]py[/code],
## [code]pz[/code], [code]rx[/code], [code]ry[/code], [code]rz[/code].
var _frames: Array = []

## Index of the next frame to be evaluated during [method _process].
var _current_index: int = 0

## Accumulated playback time in seconds, normalised to the first frame timestamp.
var _playback_clock: float = 0.0

## Whether the source is actively advancing and emitting frames each process tick.
var _is_playing: bool = false


## Reference to the TelemetryManager used for forwarding pose and event data.
##
## Defaults to the [TelemetryManager] autoload. Assign a mock before calling
## [method _init_managers] to override during unit testing.
var _telemetry_manager = null	#Main purpose for unit testing to allow the assignment of mock managers

## Reference to the SourceManager used to register this source.
##
## Defaults to the [SourceManager] autoload. Assign a mock before calling
## [method _init_managers] to override during unit testing.
var _source_manager = null


## Initializes manager references and registers this source with [SourceManager].
func _ready() -> void:
	_init_managers(TelemetryManager, SourceManager)

# Called by _ready() normally, or directly by tests with mocks
## Wires manager dependencies and registers [code]"PLAYBACK"[/code] with [SourceManager].
##
## Separated from [method _ready] so unit tests can inject mock managers without
## relying on autoload singletons.
##
## Parameters:
##   telemetry : Object
##       The TelemetryManager instance (or mock) to forward pose and event calls to.
##   source_mgr : Object
##       The SourceManager instance (or mock) to register this source with.
func _init_managers(telemetry, source_mgr) -> void:
	_telemetry_manager = telemetry
	_source_manager = source_mgr
	_source_manager.register_source("PLAYBACK", self)
	
	# Self-register so SourceManager knows we exist
	SourceManager.register_source("PLAYBACK", self)



## Begins playback from the first frame.
##
## Resets the frame index and internal clock before enabling the process loop.
## Has no effect and emits a warning if no recording has been loaded.
func start() -> void:
	if _frames.is_empty():
		push_warning("[PlaybackSource] No recording loaded. Call load_file() first.")
		return

	
	_current_index = 0
	_playback_clock = 0.0
	_is_playing = true
	print("[PlaybackSource] Playback started. %d frames." % _frames.size())


## Stops playback and resets state to the beginning of the recording.
func stop() -> void:
	_is_playing = false
	_current_index = 0
	_playback_clock = 0.0
	

	print("[PlaybackSource] Stopped.")


## Pauses playback at the current frame without resetting position.
##
## Call [method resume] to continue from where playback was paused.
func pause() -> void:
	_is_playing = false
	print("[PlaybackSource] Paused at frame %d / %d." % [_current_index, _frames.size()])


## Resumes playback from the current frame index.
##
## Re-anchors the internal clock to the current frame so that time-based
## frame scheduling remains accurate after a pause. Has no effect if no
## recording is loaded or if playback has already completed.
func resume() -> void:
	if _frames.is_empty():
		return
	
	if _current_index >= _frames.size():
		push_warning("[PlaybackSource] Cannot resume, playback is complete")
		return
	
	# Re-anchor clock to current frame so resume is seamless
	_playback_clock = _frames[_current_index]["t"] - _frames[0]["t"]
	_is_playing = true
	print("[PlaybackSource] Resumed from frame %d / %d." % [_current_index, _frames.size()])



## Loads a binary flight recording from disk into the frame buffer.
##
## The file must begin with the [constant FORMAT] magic number followed by a
## 32-bit frame count. Each frame is stored as seven consecutive [float] values:
## [code]t, px, py, pz, ry, rz, rx[/code]. On success, emits a recording-loaded
## event through [TelemetryManager] and returns [code]true[/code].
##
## Parameters:
##   path : String
##       Absolute or [code]res://[/code] relative path to the [code].bin[/code] file.
##
## Returns:
##   [code]true[/code] if the file was parsed successfully, [code]false[/code] otherwise.
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
	_telemetry_manager.forward_recording_loaded(path, _frames.size())
	return true


## Jumps playback to the specified frame index and immediately emits that frame.
##
## The internal clock is re-anchored to the target frame so that subsequent
## playback advances correctly from the new position. The index is clamped to
## the valid range [code][0, frames.size() - 1][/code].
##
## Parameters:
##   index : int
##       The zero-based frame index to seek to.
func seek(index: int) -> void:
	_current_index = clamp(index, 0, _frames.size() - 1)
	_playback_clock = _frames[_current_index]["t"] - _frames[0]["t"]
	_emit_frame(_frames[_current_index])
	_telemetry_manager.forward_frame_changed(_current_index, _frames.size())


## Returns [code]true[/code] if a recording has been loaded into the frame buffer.
func has_recording() -> bool:
	return not _frames.is_empty()


## Prints all [code].bin[/code] files found in [member recording_dir] to the output panel.
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



## Advances the playback clock and emits all frames whose timestamp has elapsed.
##
## Runs only when [member _is_playing] is [code]true[/code] and the frame buffer
## is non-empty. Transitions to the stopped state and notifies [TelemetryManager]
## once the final frame has been emitted.
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
		_telemetry_manager.forward_frame_changed(_current_index, _frames.size())
		
	if _current_index >= _frames.size():
		_is_playing = false
		_telemetry_manager.forward_playback_completed()
		print("[PlaybackSource] Playback complete.")


## Forwards a single frame's pose data to [TelemetryManager].
##
## Parameters:
##   frame : Dictionary
##       A frame dictionary containing the keys [code]px[/code], [code]py[/code],
##       [code]pz[/code], [code]rx[/code], [code]ry[/code], [code]rz[/code],
##       and [code]t[/code].
func _emit_frame(frame: Dictionary) -> void:
	_telemetry_manager.forward_pose(
		Vector3(frame["px"], frame["py"], frame["pz"]),
		Vector3(frame["ry"], frame["rz"], frame["rx"]),
		false,
		frame["t"]
	)
