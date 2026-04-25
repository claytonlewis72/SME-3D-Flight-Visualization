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
#|   File Name   : flight_recorder.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Records live telemetry pose data to a structured binary file.
#|       Subscribes to TelemetryManager.pose_received and writes each
#|       frame sequentially. Registers itself with RecordingManager on ready.
#|
#|   POC         :
#|       Aramis Hernandez
#|
#|------------------------------------------------------------------------------------


extends Node

## Records live telemetry pose data to a structured binary flight recording file.
##
## This node subscribes to the [signal TelemetryManager.pose_received] signal
## and serializes each incoming pose frame as seven consecutive [float] values
## into a [code].bin[/code] file. The file begins with a fixed-length header
## containing a magic number and a frame count that is back-filled when
## recording stops.
##
## The node registers itself with [RecordingManager] on ready so it can be
## started and stopped externally at runtime.
 

## Directory where completed [code].bin[/code] recording files are written.
@export var save_path = "res://data/recorded_flightpath/"


#Unique fingerprint, for our binary format to ensure we are reading a flight path file and not any random binary file
#ASCII values that is equalivent to FLTH
## Magic number written to the file header to identify a valid flight recording.
##
## Encodes the ASCII string [code]"FLTH"[/code] ([code]0x464C5448[/code]) so
## consumers can reject arbitrary binary files that do not originate from this
## recorder.
const FORMAT := 0x464C5448 


## Handle to the currently open recording file.
##
## [code]null[/code] when no recording is in progress.
var _file : FileAccess = null

## Running count of pose frames written to the current recording file.
##
## Written into the file header at byte offset 4 when recording stops.
var _frame_count : int = 0

## Whether the recorder is actively writing frames to disk.
var is_recording: bool = false


## Reference to the TelemetryManager used to subscribe to pose events and
## forward recording lifecycle notifications.
##
## Defaults to the [TelemetryManager] autoload singleton. Assign before
## [method _ready] is called to inject a mock during unit testing.
var TelemetryManager = null  # injected; falls back to singleton in _ready()

## Reference to the RecordingManager used to register this recorder.
##
## Defaults to the [RecordingManager] autoload singleton. Assign before
## [method _ready] is called to inject a mock during unit testing.
var RecordingManager = null  # injected; falls back to singleton in _ready()


## Resolves manager singletons, registers this recorder, and subscribes to pose events.
##
## If [member TelemetryManager] or [member RecordingManager] have not been
## injected, they are resolved from the scene tree autoloads. The recorder
## then registers itself with [RecordingManager] and connects to
## [signal TelemetryManager.pose_received].
func _ready():
	if TelemetryManager == null:
		TelemetryManager = get_node("/root/TelemetryManager")
	if RecordingManager == null:
		RecordingManager = get_node("/root/RecordingManager")

	RecordingManager.register_recorder(self)
	TelemetryManager.pose_received.connect(_on_pose_received)
	print("[RecorderTest] Recording to: ", save_path)
	#print("Debugging: Singleton list", Engine.get_singleton_list())



## Opens a new recording file and begins capturing incoming pose frames.
##
## The file is created at the path returned by [method _get_save_path]. A
## fixed-length header is written immediately containing the [constant FORMAT]
## magic number and a placeholder frame count of [code]0[/code]. The real
## count is back-filled by [method stop_recording]. Has no effect and emits
## a warning if a recording is already active.
##
## Parameters:
##   custom_name : String
##       Optional filename (without extension). If empty, a timestamp-based
##       name is generated automatically.
func start_recording(custom_name: String = "") -> void:
	if is_recording:
		push_warning("[FlightRecorder] Already recording.")
		return
	
	var path := _get_save_path(custom_name)
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_error("[RecorderTest] Could not open file: " + path)
		return
	
	#Write file header
	_file.store_32(FORMAT)
	_file.store_32(0) #placeholder frame count
	
	_frame_count = 0
	is_recording = true
	
	TelemetryManager.forward_recording_started(path)
	print("[RecorderTest] Recording started -> ", path)


## Finalizes the recording file and notifies [TelemetryManager].
##
## Seeks back to byte offset 4 in the file header and overwrites the
## placeholder frame count with the actual value before closing the file.
## Has no effect and emits a warning if no recording is currently active.
func stop_recording() -> void:
	if not is_recording or  _file == null:
		push_warning("[FlightRecorder] No active recording.")
		return
	
	var path := _file.get_path()
	
	#Go back and write the real frame count into the header to replace the placeholder
	_file.seek(4)
	_file.store_32(_frame_count)
	_file.close()
	_file = null
	
	is_recording = false
	TelemetryManager.forward_recording_stopped(path, _frame_count)
	print("[RecorderTest] Recording Stopped. Total frames: %d" % _frame_count)


## Writes a single pose frame to the open recording file.
##
## Connected to [signal TelemetryManager.pose_received]. Each frame is
## serialized as seven consecutive [float] values in the order:
## [code]t, px, py, pz, rx, ry, rz[/code]. Gap frames are not treated
## differently at the binary level; the gap flag is intentionally ignored
## so the file stores continuous positional data.
##
## Parameters:
##   pos : Vector3
##       Vehicle position in world coordinates.
##   rot : Vector3
##       Vehicle rotation as Euler angles in radians (roll, pitch, yaw).
##   _gap : bool
##       Indicates a telemetry discontinuity. Not written to the file.
##   time : float
##       Timestamp associated with this pose frame in seconds.
func _on_pose_received(pos : Vector3, rot : Vector3, _gap: bool, time: float):
	if not is_recording or _file == null:
		return
	
	_file.store_float(time)
	_file.store_float(pos.x)
	_file.store_float(pos.y)
	_file.store_float(pos.z)
	# Keep written data to file in XYZ Format as XYZ is read in as YZX
	_file.store_float(rot.x)
	_file.store_float(rot.y)
	_file.store_float(rot.z)
	
	_frame_count += 1
	print("[RecorderTest] Frame %d - t=%.3f pos=%s rot=%s" % [_frame_count, time, pos, rot])


## Handles engine lifecycle notifications to ensure recordings are finalized safely.
##
## Calls [method stop_recording] when the application window is closed or the
## node is about to be freed, preventing a partially-written file from being
## left without a valid frame count in its header.
##
## Parameters:
##   what : int
##       The notification constant received from the engine.
func _notification(what : int) -> void:
	# Called when the scene is closing
	# go back and write the real frame count into the header
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if is_recording:
			stop_recording()


## Flushes the frame count to the file header and closes the file handle.
##
## Unlike [method stop_recording], this method does not update [member is_recording]
## or notify [TelemetryManager]. It is intended as a low-level flush for
## emergency close paths. Has no effect if no file is currently open.
func _close() -> void:
	if _file == null:
		return
	
	_file.seek(8)
	_file.store_32(_frame_count)
	_file.close()
	_file = null
	print("[RecorderTest] Closed. Total frames written: %d" % _frame_count)


## Constructs the full output path for a new recording file.
##
## Ensures [member save_path] exists on disk before returning. If
## [param custom_name] is provided, spaces are replaced with underscores and
## the result is sanitized with [method String.validate_filename]. Otherwise,
## a timestamp string of the form [code]flight_YYYYMMDD_HHMMSS.bin[/code]
## is generated from the current system time.
##
## Parameters:
##   custom_name : String
##       Optional base filename without extension.
##
## Returns:
##   The absolute file path including the [code].bin[/code] extension.
func _get_save_path(custom_name: String = "") -> String:
	var dir := ProjectSettings.globalize_path(save_path)
	DirAccess.make_dir_recursive_absolute(dir)
	
	if not custom_name.is_empty():
		var safe := custom_name.replace(" ", "_").validate_filename()
		return dir + safe + ".bin"
	
	var dt := Time.get_datetime_dict_from_system()
	var stamp := "%04d%02d%02d_%02d%02d%02d" % [
		dt["year"], dt["month"], dt["day"],
		dt["hour"], dt["minute"], dt["second"]
	]
	return dir + "flight_%s.bin" % stamp
