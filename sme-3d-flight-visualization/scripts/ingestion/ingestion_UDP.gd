#Author Aramis Hernandez
#Based on ingestion_manager

extends Node

@export var UDP_PORT: int = 5005

# UDP socket
var udp := PacketPeerUDP.new()

#Pose output 
var has_pose: bool = false
var pose_time: float = 0.0
var pose_pos: Vector3 = Vector3.ZERO
var pose_rot: Vector3 = Vector3.ZERO
var pose_gap: bool = false

#Diagnostics 
var packets_total: int = 0
var packets_vaild: int = 0
var packets_invalid: int = 0

#Local coordinate origin
var _origin_set: bool = false
var _origin_lat: float = 0.0
var _origin_lon: float = 0.0
var _origin_alt: float = 0.0

var _last_timestamp: float = -INF

signal pose_received(position: Vector3, rotation: Vector3, is_gap: bool)

func _ready():
	
	udp.bind(UDP_PORT)
	print("Listening for telemetry on UDP port:", UDP_PORT)

func _process(delta):
	
	while udp.get_available_packet_count() > 0:
		
		var packet := udp.get_packet()
		var msg := packet.get_string_from_utf8()
		#print(msg)
		_process_udp_line(msg)

func _process_udp_line(line: String):
	
	line = line.strip_edges()
	
	if line.is_empty() or line.begins_with("#"):
		return
	
	packets_total += 1
	
	var sample := _parse_udp_packet(line)
	
	if sample.is_empty():
		packets_invalid += 1
		return
	
	packets_vaild += 1 
	_update_pose(sample)
	
func _parse_udp_packet(line: String) -> Dictionary:
	var parts := line.split(",")
	
	if parts.size() < 8:
		return {}
		
	var sample := {
		"timestamp": parts[1].to_float(),
		"lat": parts[2].to_float(),
		"lon": parts[3].to_float(),
		"alt": parts[4].to_float(),
		"roll": parts[5].to_float(),
		"pitch": parts[6].to_float(),
		"yaw": parts[7].to_float()
	}
	
	return sample

func _update_pose(sample: Dictionary):
	
	var t: float = sample["timestamp"]
	
	var lat: float = sample["lat"]
	var lon: float = sample["lon"]
	var alt: float = sample["alt"]
	
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

	pose_rot = Vector3(roll, pitch, yaw)

	pose_time = t
	has_pose = true
	
	emit_signal("pose_received", pose_pos, pose_rot, pose_gap)

func get_pose():

	return {
		"has_pose": has_pose,
		"t": pose_time,
		"pos": pose_pos,
		"rot": pose_rot
	}
