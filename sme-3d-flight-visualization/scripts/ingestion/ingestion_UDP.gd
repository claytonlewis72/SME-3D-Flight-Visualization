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
#|       UDP telemetry ingestion source. Extends TelemetrySource. Binds a
#|       UDP socket on a configurable port, parses and validates incoming
#|       packets each frame via TelemetryParser and TelemetryProcessor,
#|       converts geographic coordinates to local Cartesian pose data, and
#|       forwards each frame to TelemetryManager. Only active when
#|       SourceManager reports the active source as "UDP". Supports an
#|       optional fixed geographic origin and diagnostics counters.
#|
#|   POC         : Aramis Hernandez
#|   Editors     : Carson Wood — expanded to align with the current ingestion
#|                 pipeline interface and rendering signal contract.
#|
#|------------------------------------------------------------------------------------


extends TelemetrySource

## UDP telemetry ingestion source that receives, parses, and forwards live pose data.
##
## Each frame [method _process] drains all pending UDP packets and passes each
## line to [method _handle_line], which routes it through [TelemetryParser] and
## [TelemetryProcessor] before calling [method _forward_pose]. Forwarding is
## gated on [member SourceManager.active_source_name] equalling [code]"UDP"[/code]
## so packets are silently dropped when another source is active.
##
## A gap flag is raised on any frame where the timestamp delta exceeds three
## times the expected 50 ms inter-packet interval (150 ms). The gap is
## forwarded to [TelemetryManager] alongside the pose so downstream consumers
## can handle telemetry discontinuities appropriately.
##
## The local coordinate origin is established from the first valid sample
## unless [member use_fixed_origin] is [code]true[/code], in which case the
## origin is seeded from the exported lat/lon/alt values before the socket
## is bound.


## UDP port to listen on for incoming telemetry packets.
@export var udp_port: int = 5005

## Whether incoming rotation values are in degrees.
##
## When [code]true[/code], [TelemetryProcessor] converts roll, pitch, and yaw
## to radians before building the pose. When [code]false[/code], values are
## assumed to already be in radians.
@export var angles_in_degrees: bool = true

## Whether incoming altitude values are in feet.
##
## When [code]true[/code], [TelemetryProcessor] multiplies altitude by
## [code]0.3048[/code] to convert to metres before computing the pose.
@export var altitude_in_feet: bool = false

## Whether to use a manually configured geographic origin instead of
## deriving it from the first received packet.
##
## When [code]true[/code], [member _origin_state] is seeded from
## [member fixed_origin_lat], [member fixed_origin_lon], and
## [member fixed_origin_alt] during [method start] so all positions are
## expressed relative to that fixed point from the very first packet.
@export var use_fixed_origin: bool = false

## Latitude of the fixed origin in decimal degrees. Used when [member use_fixed_origin] is [code]true[/code].
@export var fixed_origin_lat: float = 0.0

## Longitude of the fixed origin in decimal degrees. Used when [member use_fixed_origin] is [code]true[/code].
@export var fixed_origin_lon: float = 0.0

## Altitude of the fixed origin in metres. Used when [member use_fixed_origin] is [code]true[/code].
@export var fixed_origin_alt: float = 0.0

## Underlying UDP socket used to receive telemetry packets.
var udp: PacketPeerUDP = PacketPeerUDP.new()

# pose output
## Whether at least one valid pose has been computed since the source started.
var has_pose: bool = false

## Timestamp of the most recently computed pose frame in seconds.
var pose_time: float = 0.0

## World position of the most recently computed pose in local Cartesian metres.
var pose_pos: Vector3 = Vector3.ZERO

## Rotation of the most recently computed pose as Euler angles in radians,
## remapped to Godot's axis convention (X=roll, Y=pitch, Z=yaw).
var pose_rot: Vector3 = Vector3.ZERO

## Whether a telemetry gap was detected immediately before the current pose frame.
##
## [code]true[/code] when the timestamp delta between the previous and current
## packets exceeded 150 ms (three times the expected 50 ms interval).
var pose_gap: bool = false

# diagnostics
## Total number of UDP packets received since the source started.
var packets_total: int = 0

## Number of packets that passed parsing and validation.
var packets_valid: int = 0

## Number of packets that failed parsing or validation and were discarded.
var packets_invalid: int = 0

## Number of telemetry gaps detected since the source started.
var gap_count: int = 0

## Timestamp of the last successfully processed packet, used for gap detection.
##
## Initialised to [code]-INF[/code] so the first packet never triggers a gap.
var _last_timestamp: float = -INF

# origin tracking
## Mutable origin state passed to [TelemetryProcessor.build_pose] on every call.
##
## Seeded automatically from the first valid sample unless
## [member use_fixed_origin] is [code]true[/code], in which case it is
## populated during [method start].
var _origin_state: Dictionary = {
	"set": false,
	"lat": 0.0,
	"lon": 0.0,
	"alt": 0.0
}

# modular components
## Parser instance responsible for converting raw UDP packet strings into
## telemetry sample dictionaries.
var _parser: TelemetryParser = TelemetryParser.new()

## Processor instance responsible for validating samples and building
## local-space pose dictionaries from geographic coordinates.
var _processor: TelemetryProcessor = TelemetryProcessor.new()

## Registers this source with [SourceManager] and binds the UDP socket.
##
## Calls [method start] immediately so the socket is ready to receive packets
## as soon as the node enters the scene tree.
func _ready() -> void:
	if SourceManager:
		SourceManager.register_source("UDP", self)
	start()


## Binds the UDP socket and optionally seeds the fixed origin.
##
## Returns early without rebinding if the socket is already bound. When
## [member use_fixed_origin] is [code]true[/code], [member _origin_state] is
## populated from the exported lat/lon/alt values before the socket is opened
## so the first packet is immediately expressed relative to the fixed origin.
## Pushes an error if [method PacketPeerUDP.bind] fails.
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


## Closes the UDP socket if it is currently bound.
func stop() -> void:
	if udp.is_bound():
		udp.close()
		print("[UDPSource] Socket closed.")


## Drains all pending UDP packets and processes each one.
##
## Skips processing entirely when [member SourceManager.active_source_name]
## is not [code]"UDP"[/code] so incoming packets are discarded without parsing
## while another source is active. Each available packet is decoded from UTF-8
## and forwarded to [method _handle_line].
##
## Parameters:
##   _delta : float
##       Time in seconds since the last frame. Not used by this method.
func _process(_delta: float) -> void:
	if SourceManager and SourceManager.active_source_name != "UDP":
		return

	while udp.get_available_packet_count() > 0:
		var packet: PackedByteArray = udp.get_packet()
		var msg: String = packet.get_string_from_utf8()
		_handle_line(msg)


## Parses, validates, and processes a single telemetry packet string.
##
## Increments [member packets_total] unconditionally, then passes [param line]
## to [method TelemetryParser.parse_udp_packet]. Empty results and samples
## that fail [method TelemetryProcessor.validate_sample] are counted in
## [member packets_invalid] and discarded. Valid samples are counted in
## [member packets_valid] and forwarded to [method _update_pose]. A diagnostic
## summary is printed to the console every 120 packets.
##
## Parameters:
##   line : String
##       UTF-8 decoded contents of a single UDP packet.
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

## Converts a validated sample into a pose and updates internal pose state.
##
## Computes [member pose_gap] by comparing the sample timestamp against
## [member _last_timestamp]. A gap is flagged when the delta exceeds
## [code]0.15[/code] seconds (three times the expected 50 ms packet interval)
## and [member gap_count] is incremented. The first packet never triggers a
## gap because [member _last_timestamp] is initialised to [code]-INF[/code].
##
## After gap detection, delegates to [method TelemetryProcessor.build_pose]
## to produce a local-space position and rotation, then remaps the rotation
## axes from [TelemetryProcessor]'s output convention to Godot's rendering
## convention:
## [codeblock]
##   pose_rot.x = raw_rot.z   # roll
##   pose_rot.y = raw_rot.x   # pitch
##   pose_rot.z = raw_rot.y   # yaw
## [/codeblock]
##
## Sets [member has_pose] to [code]true[/code] and calls [method _forward_pose].
##
## Parameters:
##   sample : Dictionary
##       A telemetry sample that has passed [method TelemetryProcessor.validate_sample].
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


## Forwards the current pose to [TelemetryManager] if the UDP source is active.
##
## Guards the call behind an [member SourceManager.active_source_name] check
## so pose data is never injected into [TelemetryManager] while a different
## source (e.g. PLAYBACK) is active.
func _forward_pose() -> void:
	if SourceManager and SourceManager.active_source_name == "UDP":
		TelemetryManager.forward_pose(pose_pos, pose_rot, pose_gap, pose_time)


## Returns the most recently computed pose as a snapshot dictionary.
##
## Intended for consumers that poll pose state rather than subscribing to
## [signal TelemetryManager.pose_received]. The returned dictionary is a
## value copy and will not reflect subsequent updates.
##
## Returns:
##   A [Dictionary] with the following keys:
##   [codeblock]
##     {
##       "has_pose": bool,    # false until the first valid packet is processed
##       "t":        float,   # timestamp of the last pose frame in seconds
##       "pos":      Vector3, # local Cartesian position in metres
##       "rot":      Vector3, # Euler angles in radians (Godot axis convention)
##       "gap":      bool     # true if a discontinuity preceded the last frame
##     }
##   [/codeblock]
func get_pose() -> Dictionary:
	return {
		"has_pose": has_pose,
		"t": pose_time,
		"pos": pose_pos,
		"rot": pose_rot,
		"gap": pose_gap
	}
