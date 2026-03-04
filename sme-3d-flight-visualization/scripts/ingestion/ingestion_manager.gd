extends Node

#Change done by: Aramis Hernandez
#Added a singal to decouple, 
signal pose_received(position: Vector3, rotation: Vector3, is_gap: bool)

@export var replay_file_path: String = "res://data/sample_telemetry.csv"
@export var replay_hz: float = 60.0

# Unit configuration
@export var angles_in_degrees: bool = true
@export var altitude_in_feet: bool = false

# Telemetry field mapping (allows flexible input formats)
var field_map := {
	"timestamp": 0,
	"lat": 1,
	"lon": 2,
	"alt": 3,
	"roll": 4,
	"pitch": 5,
	"yaw": 6
}

# Pose output for rendering
var has_pose: bool = false
var pose_time: float = 0.0
var pose_pos: Vector3 = Vector3.ZERO
var pose_rot: Vector3 = Vector3.ZERO
var pose_gap: bool = false

# Diagnostics
var packets_total: int = 0
var packets_valid: int = 0
var packets_invalid: int = 0
var gap_count: int = 0

# Replay internals
var _lines: PackedStringArray = []
var _idx: int = 0
var _accum: float = 0.0
var _last_timestamp: float = -INF

# Local coordinate origin
var _origin_set: bool = false
var _origin_lat: float = 0.0
var _origin_lon: float = 0.0
var _origin_alt: float = 0.0


func _ready() -> void:
	_load_file()
	if _lines.size() == 0:
		push_warning("No telemetry lines loaded.")
		set_process(false)
		return

	print("Telemetry loaded lines:", _lines.size())
	set_process(true)


func _process(delta: float) -> void:
	_accum += delta
	var interval: float = 1.0 / max(replay_hz, 1.0)

	while _accum >= interval:
		_accum -= interval
		_step_one_sample()


func _step_one_sample() -> void:
	if _idx >= _lines.size():
		_idx = 0
		_last_timestamp = -INF
		_origin_set = false

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
	_update_pose(sample)

	if packets_total % 120 == 0:
		print("Telemetry stats:",
		" total=", packets_total,
		" valid=", packets_valid,
		" invalid=", packets_invalid,
		" gaps=", gap_count)


func _parse_csv_line(line: String) -> Dictionary:
	var parts := line.split(",")

	if parts.size() < field_map.size():
		return {}

	var sample := {
		"timestamp": parts[field_map["timestamp"]].to_float(),
		"lat": parts[field_map["lat"]].to_float(),
		"lon": parts[field_map["lon"]].to_float(),
		"alt": parts[field_map["alt"]].to_float(),
		"roll": parts[field_map["roll"]].to_float(),
		"pitch": parts[field_map["pitch"]].to_float(),
		"yaw": parts[field_map["yaw"]].to_float()
	}

	return sample


func _validate_sample(sample: Dictionary) -> bool:
	for key in ["timestamp","lat","lon","alt","roll","pitch","yaw"]:
		if not sample.has(key):
			return false

	var lat: float = sample["lat"]
	var lon: float = sample["lon"]

	if lat < -90.0 or lat > 90.0:
		return false

	if lon < -180.0 or lon > 180.0:
		return false

	return true


func _update_pose(sample: Dictionary) -> void:
	var t: float = sample["timestamp"]

	# Gap detection
	pose_gap = false
	if _last_timestamp != -INF:
		var expected_dt: float = 1.0 / replay_hz
		var dt: float = t - _last_timestamp

		if dt > expected_dt * 3.0:
			pose_gap = true
			gap_count += 1

	_last_timestamp = t

	var lat: float = sample["lat"]
	var lon: float = sample["lon"]
	var alt: float = sample["alt"]

	if altitude_in_feet:
		alt = alt * 0.3048

	if not _origin_set:
		_origin_lat = lat
		_origin_lon = lon
		_origin_alt = alt
		_origin_set = true

	var meters_per_deg_lat: float = 111320.0
	var meters_per_deg_lon: float = 111320.0 * cos(deg_to_rad(_origin_lat))

	var dx: float = (lon - _origin_lon) * meters_per_deg_lon
	var dz: float = (lat - _origin_lat) * meters_per_deg_lat
	var dy: float = alt - _origin_alt

	pose_pos = Vector3(dx, dy, dz)

	var roll: float = sample["roll"]
	var pitch: float = sample["pitch"]
	var yaw: float = sample["yaw"]

	if angles_in_degrees:
		roll = deg_to_rad(roll)
		pitch = deg_to_rad(pitch)
		yaw = deg_to_rad(yaw)

	pose_rot = Vector3(roll, pitch, yaw)

	pose_time = t
	has_pose = true
	
	#Added by: Aramis Hernandez
	#Emit the signal to send data to rendering.
	emit_signal("pose_received", pose_pos, pose_rot, pose_gap)


func _load_file() -> void:
	if not FileAccess.file_exists(replay_file_path):
		push_warning("Telemetry file not found: " + replay_file_path)
		return

	var f := FileAccess.open(replay_file_path, FileAccess.READ)

	while not f.eof_reached():
		_lines.append(f.get_line())

	f.close()


func get_pose() -> Dictionary:
	return {
		"has_pose": has_pose,
		"t": pose_time,
		"pos": pose_pos,
		"rot": pose_rot,
		"gap": pose_gap
	}
