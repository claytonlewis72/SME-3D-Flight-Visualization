extends Node

@export var replay_file_path: String = "res://data/sample_telemetry.csv"
@export var replay_hz: float = 30.0

var latest_sample: Dictionary = {}
var has_sample: bool = false

var packets_total: int = 0
var packets_valid: int = 0
var packets_invalid: int = 0

var loops_completed: int = 0

var _lines: PackedStringArray = []
var _idx: int = 0
var _accum: float = 0.0
var _last_timestamp: float = -INF

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
	# Option A: loop replay (good for continuous demos)
	if _idx >= _lines.size():
		_idx = 0
		_last_timestamp = -INF
		loops_completed += 1

	# Option B: stop replay when file ends (more realistic)
	# if _idx >= _lines.size():
	# 	set_process(false)
	# 	print("Replay complete.")
	# 	return

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
	latest_sample = sample
	has_sample = true

	# Log occasionally (every 60 packets)
	if packets_total % 60 == 0:
		print("ok=", packets_valid,
			" bad=", packets_invalid,
			" loop=", loops_completed,
			" idx=", _idx,
			" t=", sample["timestamp"])

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
	# Expected CSV:
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
	# Basic schema check
	for key in ["timestamp", "lat", "lon", "alt", "roll", "pitch", "yaw"]:
		if not sample.has(key):
			return false

	# GPS range
	var lat: float = sample["lat"]
	var lon: float = sample["lon"]
	if lat < -90.0 or lat > 90.0:
		return false
	if lon < -180.0 or lon > 180.0:
		return false

	# Timestamp monotonic for replay stability (resets per loop)
	var t: float = sample["timestamp"]
	if _last_timestamp != -INF and t < _last_timestamp:
		return false
	_last_timestamp = t

	return true

func get_latest_sample() -> Dictionary:
	return latest_sample
