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
#|   File Name   : ingestion_UDP.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       UDP telemetry ingestion source. Extends TelemetrySource.
#|       Receives raw UDP telemetry packets, parses and validates them,
#|       converts them to local pose data, and forwards them through
#|       TelemetryManager only when telemetry_source == "UDP".
#|
#|   POC         :
#|       Aramis Hernandez
#| Edited by Carson Wood and expanded after initial implementation to align with the current
#| ingestion pipeline interface and rendering signal contract.
#|
#|------------------------------------------------------------------------------------

extends TelemetrySource

@export var udp_port: int = 5005
@export var angles_in_degrees: bool = true
@export var altitude_in_feet: bool = false

@export var use_fixed_origin: bool = false
@export var fixed_origin_lat: float = 0.0
@export var fixed_origin_lon: float = 0.0
@export var fixed_origin_alt: float = 0.0

var udp: PacketPeerUDP = PacketPeerUDP.new()

# pose output
var has_pose: bool = false
var pose_time: float = 0.0
var pose_pos: Vector3 = Vector3.ZERO
var pose_rot: Vector3 = Vector3.ZERO
var pose_gap: bool = false

# diagnostics
var packets_total: int = 0
var packets_valid: int = 0
var packets_invalid: int = 0
var gap_count: int = 0

var _last_timestamp: float = -INF

# origin tracking
var _origin_state: Dictionary = {
	"set": false,
	"lat": 0.0,
	"lon": 0.0,
	"alt": 0.0
}

# modular components
var _parser: TelemetryParser = TelemetryParser.new()
var _processor: TelemetryProcessor = TelemetryProcessor.new()


func _ready() -> void:
	if SourceManager:
		SourceManager.register_source("UDP", self)
	start()


func start() -> void:
	if udp.is_bound():
		print("[UDPSource] Already bound on port: %d" % udp_port)
		return

	# fixed origin support
	if use_fixed_origin:
		_origin_state["set"] = true
		_origin_state["lat"] = fixed_origin_lat
		_origin_state["lon"] = fixed_origin_lon
		_origin_state["alt"] = fixed_origin_alt

	var result: int = udp.bind(udp_port)
	if result != OK:
		push_error("[UDPSource] Failed to bind UDP socket on port: %d" % udp_port)
		return

	print("[UDPSource] Listening on UDP port: %d" % udp_port)


func stop() -> void:
	if udp.is_bound():
		udp.close()
		print("[UDPSource] Socket closed.")


func _process(_delta: float) -> void:
	if SourceManager and SourceManager.active_source_name != "UDP":
		return

	while udp.get_available_packet_count() > 0:
		var packet: PackedByteArray = udp.get_packet()
		var msg: String = packet.get_string_from_utf8()
		_handle_line(msg)


func _handle_line(line: String) -> void:
	packets_total += 1

	var sample: Dictionary = _parser.parse_udp_packet(line)
	if sample.is_empty():
		packets_invalid += 1
		return

	if not _processor.validate_sample(sample):
		packets_invalid += 1
		return

	packets_valid += 1
	_update_pose(sample)

	if packets_total % 120 == 0:
		print("[UDPSource] total=%d valid=%d invalid=%d gaps=%d" % [
			packets_total, packets_valid, packets_invalid, gap_count
		])


func _update_pose(sample: Dictionary) -> void:
	var t: float = sample["timestamp"]

	pose_gap = false
	if _last_timestamp != -INF:
		var dt: float = t - _last_timestamp
		if dt > 0.05 * 3.0:
			pose_gap = true
			gap_count += 1

	_last_timestamp = t

	var pose: Dictionary = _processor.build_pose(
		sample,
		_origin_state,
		angles_in_degrees,
		altitude_in_feet
	)

	pose_pos = pose["pos"]

	# IMPORTANT: keep original axis mapping (THIS FIXES YOUR SPIN ISSUE)
	var raw_rot: Vector3 = pose["rot"]
	pose_rot = Vector3(raw_rot.z, raw_rot.x, raw_rot.y)

	pose_time = t
	has_pose = true

	_forward_pose()


func _forward_pose() -> void:
	if SourceManager and SourceManager.active_source_name == "UDP":
		TelemetryManager.forward_pose(pose_pos, pose_rot, pose_gap, pose_time)


func get_pose() -> Dictionary:
	return {
		"has_pose": has_pose,
		"t": pose_time,
		"pos": pose_pos,
		"rot": pose_rot,
		"gap": pose_gap
	}
