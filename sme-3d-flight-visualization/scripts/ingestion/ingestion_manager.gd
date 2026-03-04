extends Node

@export var replay_file_path: String = "res://data/sample_telemetry.csv"
@export var replay_hz: float = 30.0

# If your CSV angles are in degrees (most likely), set this true.
@export var angles_in_degrees: bool = true

# Dropout detection: if timestamp delta > expected_dt * gap_multiplier, mark as gap
@export var gap_multiplier: float = 3.0

# Pose output for rendering
var has_pose: bool = false
var pose_time: float = 0.0
var pose_pos: Vector3 = Vector3.ZERO       # meters, local
var pose_rot: Vector3 = Vector3.ZERO       # radians (recommended)
var pose_gap: bool = false

# Stats
var packets_total: int = 0
var packets_valid: int = 0
var packets_invalid: int = 0
var loops_completed: int = 0
var gap_count: int = 0

var _lines: PackedStringArray = []
var _idx: int = 0
var _accum: float = 0.0
var _last_timestamp: float = -INF

# Origin for local coordinate conversion
var _origin_set: bool = false
var _origin_lat: float = 0.0
var _origin_lon: float = 0.0
var _origin_alt: float = 0.0

#Author: Aramis Hernandez
#Added a signal for sending pose to renderer
signal pose_received(position: Vector3, rotation: Vector3, is_gap: bool)

func _ready() -> void:
	_load_file()
	if _lines.size() == 0:
		push_warning("No telemetry lines loaded. Check replay_file_path.")
		set_process(false)
		return

	print("Ingestion replay loaded lines:", _lines.size())
	set_process(true)

func _process(delta: float) -> void:
	_accum += delta
	var interval: float = 1.0 / max(replay_hz, 1.0)
	while _accum >= interval:
		_accum -= interval
		_step_one_sample()

func _step_one_sample() -> void:
	# Loop replay (useful for demos)
	if _idx >= _lines.size():
		_idx = 0
		_last_timestamp = -INF
		_origin_set = false
		loops_completed += 1

	var line := _lines[_idx].strip_edges()
	_idx += 1

	if line.is_empty() or line.begins_with("#"):
		return

	packets_total += 1

	var sample := _parse_csv_line(line)
	if sample.is_empty():
		packets_invalid += 1
		return

	if not _validate_sample(sample):
		packets_invalid += 1
		return

	packets_valid += 1

	_update_pose_from_sample(sample)

	if packets_total % 60 == 0:
		print("ok=", packets_valid,
			" bad=", packets_invalid,
			" gaps=", gap_count,
			" loop=", loops_completed,
			" idx=", _idx,
			" t=", pose_time)

func _update_pose_from_sample(sample: Dictionary) -> void:
	var t: float = sample["timestamp"]

	# Dropout detection (gap marker)
	pose_gap = false
	if _last_timestamp != -INF:
		var expected_dt: float = 1.0 / max(replay_hz, 1.0)
		var dt: float = t - _last_timestamp
		if dt > expected_dt * gap_multiplier:
			pose_gap = true
			gap_count += 1

	_last_timestamp = t

	# Set origin on first valid sample
	var lat: float = sample["lat"]
	var lon: float = sample["lon"]
	var alt: float = sample["alt"]
	if not _origin_set:
		_origin_lat = lat
		_origin_lon = lon
		_origin_alt = alt
		_origin_set = true

	# Convert GPS to local meters (simple approximation, good for small areas)
	# x = East, z = North, y = Up
	var meters_per_deg_lat: float = 111320.0
	var meters_per_deg_lon: float = 111320.0 * cos(deg_to_rad(_origin_lat))

	var dx_east: float = (lon - _origin_lon) * meters_per_deg_lon
	var dz_north: float = (lat - _origin_lat) * meters_per_deg_lat
	var dy_up: float = (alt - _origin_alt)

	pose_time = t
	pose_pos = Vector3(dx_east, dy_up, dz_north)

	# Orientation: store radians so Godot rotations are consistent
	var roll: float = sample["roll"]
	var pitch: float = sample["pitch"]
	var yaw: float = sample["yaw"]

	if angles_in_degrees:
		roll = deg_to_rad(roll)
		pitch = deg_to_rad(pitch)
		yaw = deg_to_rad(yaw)

	pose_rot = Vector3(roll, pitch, yaw)
	has_pose = true
	
	#Author: Aramis Hernandez
	#Just emit signal instead of having render call get_pose
	#This is so render can now get data without knowing about the ingestion_manager
	emit_signal("pose_received", pose_pos, pose_rot, pose_gap)

func _load_file() -> void:
	if not FileAccess.file_exists(replay_file_path):
		push_warning("Telemetry file not found: " + replay_file_path)
		return

	var f := FileAccess.open(replay_file_path, FileAccess.READ)
	if f == null:
		push_warning("Failed to open telemetry file: " + replay_file_path)
		return

	_lines.clear()
	while not f.eof_reached():
		_lines.append(f.get_line())
	f.close()

func _parse_csv_line(line: String) -> Dictionary:
	# timestamp,lat,lon,alt,roll,pitch,yaw,velocity(optional)
	var parts := line.split(",")
	if parts.size() < 7:
		return {}

	var t := parts[0].to_float()
	var lat := parts[1].to_float()
	var lon := parts[2].to_float()
	var alt := parts[3].to_float()
	var roll := parts[4].to_float()
	var pitch := parts[5].to_float()
	var yaw := parts[6].to_float()

	var sample := {
		"timestamp": t,
		"lat": lat,
		"lon": lon,
		"alt": alt,
		"roll": roll,
		"pitch": pitch,
		"yaw": yaw
	}

	if parts.size() >= 8:
		sample["velocity"] = parts[7].to_float()

	return sample

func _validate_sample(sample: Dictionary) -> bool:
	for key in ["timestamp", "lat", "lon", "alt", "roll", "pitch", "yaw"]:
		if not sample.has(key):
			return false

	var lat: float = sample["lat"]
	var lon: float = sample["lon"]
	if lat < -90.0 or lat > 90.0:
		return false
	if lon < -180.0 or lon > 180.0:
		return false

	return true

# What rendering should call every frame
func get_pose() -> Dictionary:
	return {
		"has_pose": has_pose,
		"t": pose_time,
		"pos": pose_pos,
		"rot": pose_rot,
		"gap": pose_gap
	}
