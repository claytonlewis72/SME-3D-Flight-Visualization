extends Node
# Carson Wood


# Change done by: Aramis Hernandez
# Signal used to decouple rendering from direct polling.
signal pose_received(position: Vector3, rotation: Vector3, is_gap: bool, time: float)

@export var replay_file_path: String = "res://data/sample_telemetry.csv"
@export var replay_hz: float = 60.0

# Unit configuration
@export var angles_in_degrees: bool = true
@export var altitude_in_feet: bool = false

# Optional fixed origin support
@export var use_fixed_origin: bool = false
@export var fixed_origin_lat: float = 0.0
@export var fixed_origin_lon: float = 0.0
@export var fixed_origin_alt: float = 0.0

# Telemetry field mapping
var field_map := {
	"timestamp": 0,
	"lat": 1,
	"lon": 2,
	"alt": 3,
	"roll": 4,
	"pitch": 5,
	"yaw": 6
}

# Public pose output for rendering
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
var _last_timestamp: float = -INF

# Local coordinate origin
var _origin_set: bool = false
var _origin_lat: float = 0.0
var _origin_lon: float = 0.0
var _origin_alt: float = 0.0

# Threading
var _thread: Thread = Thread.new()
var _mutex: Mutex = Mutex.new()
var _thread_running: bool = false

# Shared buffer from worker thread -> main thread
var _pending_pose_ready: bool = false
var _pending_has_pose: bool = false
var _pending_pose_time: float = 0.0
var _pending_pose_pos: Vector3 = Vector3.ZERO
var _pending_pose_rot: Vector3 = Vector3.ZERO
var _pending_pose_gap: bool = false

func _ready() -> void:
	_load_file()
	if _lines.size() == 0:
		push_warning("No telemetry lines loaded.")
		set_process(false)
		return

	print("Telemetry loaded lines:", _lines.size())

	_thread_running = true
	var err := _thread.start(_thread_loop)
	if err != OK:
		push_error("Failed to start ingestion thread.")
		_thread_running = false
		set_process(false)
		return

	set_process(true)

func _process(_delta: float) -> void:
	var should_emit: bool = false
	var emit_pos: Vector3 = Vector3.ZERO
	var emit_rot: Vector3 = Vector3.ZERO
	var emit_gap: bool = false
	var emit_time: float = 0.0

	_mutex.lock()

	if _pending_pose_ready:
		has_pose = _pending_has_pose
		pose_time = _pending_pose_time
		pose_pos = _pending_pose_pos
		pose_rot = _pending_pose_rot
		pose_gap = _pending_pose_gap
		_pending_pose_ready = false

		should_emit = true
		emit_pos = pose_pos
		emit_rot = pose_rot
		emit_gap = pose_gap
		emit_time = pose_time

	_mutex.unlock()

	if should_emit:
		emit_signal("pose_received", emit_pos, emit_rot, emit_gap, emit_time)

func _exit_tree() -> void:
	_thread_running = false
	if _thread.is_started():
		_thread.wait_to_finish()

func _thread_loop() -> void:
	var interval_sec: float = 1.0 / max(replay_hz, 1.0)

	while _thread_running:
		var pose_dict: Dictionary = _step_one_sample_threaded()

		if not pose_dict.is_empty():
			_mutex.lock()
			_pending_has_pose = pose_dict["has_pose"]
			_pending_pose_time = pose_dict["t"]
			_pending_pose_pos = pose_dict["pos"]
			_pending_pose_rot = pose_dict["rot"]
			_pending_pose_gap = pose_dict["gap"]
			_pending_pose_ready = true
			_mutex.unlock()

		OS.delay_msec(int(interval_sec * 1000.0))

func _step_one_sample_threaded() -> Dictionary:
	if _idx >= _lines.size():
		_idx = 0
		_last_timestamp = -INF
		_origin_set = false

	var line := _lines[_idx].strip_edges()
	_idx += 1

	if line.is_empty() or line.begins_with("#"):
		return {}

	packets_total += 1

	var sample := _parse_csv_line(line)

	if sample.is_empty():
		packets_invalid += 1
		return {}

	if not _validate_sample(sample):
		packets_invalid += 1
		return {}

	packets_valid += 1
	var pose := _build_pose(sample)

	if packets_total % 120 == 0:
		print("Telemetry stats:",
			" total=", packets_total,
			" valid=", packets_valid,
			" invalid=", packets_invalid,
			" gaps=", gap_count)

	return pose

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

func _build_pose(sample: Dictionary) -> Dictionary:
	var t: float = sample["timestamp"]

	var local_gap: bool = false
	if _last_timestamp != -INF:
		var expected_dt: float = 1.0 / replay_hz
		var dt: float = t - _last_timestamp

		if dt > expected_dt * 3.0:
			local_gap = true
			gap_count += 1

	_last_timestamp = t

	var lat: float = sample["lat"]
	var lon: float = sample["lon"]
	var alt: float = sample["alt"]

	if altitude_in_feet:
		alt *= 0.3048

	if not _origin_set:
		if use_fixed_origin:
			_origin_lat = fixed_origin_lat
			_origin_lon = fixed_origin_lon
			_origin_alt = fixed_origin_alt
		else:
			_origin_lat = lat
			_origin_lon = lon
			_origin_alt = alt

		_origin_set = true

	var meters_per_deg_lat: float = 111320.0
	var meters_per_deg_lon: float = 111320.0 * cos(deg_to_rad(_origin_lat))

	var dx: float = (lon - _origin_lon) * meters_per_deg_lon
	var dz: float = (lat - _origin_lat) * meters_per_deg_lat
	var dy: float = alt - _origin_alt

	var local_pos: Vector3 = Vector3(dx, dy, dz)

	var roll: float = sample["roll"]
	var pitch: float = sample["pitch"]
	var yaw: float = sample["yaw"]

	if angles_in_degrees:
		roll = deg_to_rad(roll)
		pitch = deg_to_rad(pitch)
		yaw = deg_to_rad(yaw)

	# FIXED AXIS ORDER
	var local_rot: Vector3 = Vector3(pitch, yaw, roll)

	return {
		"has_pose": true,
		"t": t,
		"pos": local_pos,
		"rot": local_rot,
		"gap": local_gap
	}

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

func get_pose() -> Dictionary:
	return {
		"has_pose": has_pose,
		"t": pose_time,
		"pos": pose_pos,
		"rot": pose_rot,
		"gap": pose_gap
	}
