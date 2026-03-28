# Author: Aramis Hernandez
# Edited and expanded after initial implementation to align with the current
# ingestion pipeline interface and rendering signal contract.

extends Node

## Emitted whenever a new valid telemetry pose is processed.
## position: local-space position in meters
## rotation: local-space rotation in radians
## is_gap: true if a timing gap was detected
## time: telemetry timestamp
signal pose_received(position: Vector3, rotation: Vector3, is_gap: bool, time: float)

@export var udp_port: int = 5005

## If true, incoming roll/pitch/yaw values are treated as degrees and converted to radians.
@export var angles_in_degrees: bool = true

## If true, incoming altitude is treated as feet and converted to meters.
@export var altitude_in_feet: bool = false

## Optional fixed origin support for aligning with an external tool/config.
@export var use_fixed_origin: bool = false
@export var fixed_origin_lat: float = 0.0
@export var fixed_origin_lon: float = 0.0
@export var fixed_origin_alt: float = 0.0

## UDP socket used to receive telemetry packets.
var udp: PacketPeerUDP = PacketPeerUDP.new()

## Public pose output for rendering and other systems.
var has_pose: bool = false
var pose_time: float = 0.0
var pose_pos: Vector3 = Vector3.ZERO
var pose_rot: Vector3 = Vector3.ZERO
var pose_gap: bool = false

## Diagnostics.
var packets_total: int = 0
var packets_valid: int = 0
var packets_invalid: int = 0
var gap_count: int = 0

## Local coordinate origin.
var _origin_set: bool = false
var _origin_lat: float = 0.0
var _origin_lon: float = 0.0
var _origin_alt: float = 0.0

## Used for gap detection.
var _last_timestamp: float = -INF


func _ready() -> void:
	var bind_result := udp.bind(udp_port)
	if bind_result != OK:
		push_error("Failed to bind UDP socket on port: " + str(udp_port))
		return

	print("Listening for telemetry on UDP port:", udp_port)


func _process(_delta: float) -> void:
	while udp.get_available_packet_count() > 0:
		var packet: PackedByteArray = udp.get_packet()
		var msg: String = packet.get_string_from_utf8()
		_process_udp_line(msg)


## Processes a single UDP telemetry message line.
func _process_udp_line(line: String) -> void:
	line = line.strip_edges()

	if line.is_empty() or line.begins_with("#"):
		return

	packets_total += 1

	var sample: Dictionary = _parse_udp_packet(line)
	if sample.is_empty():
		packets_invalid += 1
		return

	if not _validate_sample(sample):
		packets_invalid += 1
		return

	packets_valid += 1
	_update_pose(sample)

	if packets_total % 120 == 0:
		print("UDP telemetry stats:",
			" total=", packets_total,
			" valid=", packets_valid,
			" invalid=", packets_invalid,
			" gaps=", gap_count)


## Parses an incoming UDP telemetry string into a structured sample.
##
## Expected format:
## source,timestamp,lat,lon,alt,roll,pitch,yaw
##
## Example:
## telemetry,12.53,39.95,-75.17,100.0,0.2,0.1,1.2
func _parse_udp_packet(line: String) -> Dictionary:
	var parts: PackedStringArray = line.split(",")

	if parts.size() < 8:
		return {}

	return {
		"timestamp": parts[1].to_float(),
		"lat": parts[2].to_float(),
		"lon": parts[3].to_float(),
		"alt": parts[4].to_float(),
		"roll": parts[5].to_float(),
		"pitch": parts[6].to_float(),
		"yaw": parts[7].to_float()
	}


## Validates the parsed telemetry sample before it is used.
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


## Converts a validated telemetry sample into local pose data.
##
## The first valid sample is used as the local origin unless fixed origin mode is enabled.
func _update_pose(sample: Dictionary) -> void:
	var t: float = sample["timestamp"]

	pose_gap = false
	if _last_timestamp != -INF:
		var dt: float = t - _last_timestamp
		if dt > 0.05 * 3.0:
			pose_gap = true
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

	pose_pos = Vector3(dx, dy, dz)

	var roll: float = sample["roll"]
	var pitch: float = sample["pitch"]
	var yaw: float = sample["yaw"]
	print("RAW ROT:", roll, pitch, yaw)

	if angles_in_degrees:
		roll = deg_to_rad(roll)
		pitch = deg_to_rad(pitch)
		yaw = deg_to_rad(yaw)

	#FIXED AXIS ORDER (Godot expects pitch, yaw, roll)
	pose_rot = Vector3(pitch, yaw, roll)

	pose_time = t
	has_pose = true

	TelemetryManager.forward_pose(pose_pos, pose_rot, pose_gap, pose_time)


## Returns the latest processed pose in a shared format used by rendering.
func get_pose() -> Dictionary:
	return {
		"has_pose": has_pose,
		"t": pose_time,
		"pos": pose_pos,
		"rot": pose_rot,
		"gap": pose_gap
	}

#Added by Aramis Hernandez
#Modified for telemetry source change by Nicholas Tran
func _process_packet(pos, rot, gap, time):
	if TelemetryManager.telemetry_source == "UDP":
		TelemetryManager.forward_pose(pos, rot, gap, time)
