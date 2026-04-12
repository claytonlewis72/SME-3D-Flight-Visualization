extends Node

@export var save_path = "res://data/recorded_flightpath/"


#Unique fingerprint, for our binary format to ensure we are reading a flight path file and not any random binary file
#ASCII values that is equalivent to FLTH
const FORMAT := 0x464C5448 

var _file : FileAccess = null
var _frame_count : int = 0

var is_recording: bool = false

func _ready():
	RecordingManager.register_recorder(self)
	
	TelemetryManager.pose_received.connect(_on_pose_received)
	print("[RecorderTest] Recording to: ", save_path)

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

func _notification(what : int) -> void:
	# Called when the scene is closing
	# go back and write the real frame count into the header
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if is_recording:
			stop_recording()


func _close() -> void:
	if _file == null:
		return
	
	_file.seek(8)
	_file.store_32(_frame_count)
	_file.close()
	_file = null
	print("[RecorderTest] Closed. Total frames written: %d" % _frame_count)


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
