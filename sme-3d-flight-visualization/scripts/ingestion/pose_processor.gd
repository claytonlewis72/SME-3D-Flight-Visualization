# -----------------------------------------------------------------------------
# File: pose_processor.gd
# Description:
#   Processes validated telemetry data and converts it into a standardized
#   pose format used by the rendering system. Handles coordinate conversion
#   and rotation mapping.
#
# Responsibilities:
#   - Validates telemetry samples
#   - Converts geographic coordinates to local space
#   - Maps rotation values to engine-compatible format
#
# Author: Carson Wood
# -----------------------------------------------------------------------------
extends Node

var _origin_set = false
var _origin_lat = 0.0
var _origin_lon = 0.0
var _origin_alt = 0.0


func _ready():
	TelemetryManager.telemetry_updated.connect(_on_data)

func _on_data(sample: Dictionary):
	if sample.is_empty():
		return
	
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
	
	var pos = Vector3(dx, dy, dz)
	
	var roll: float = sample["roll"]
	var pitch: float = sample["pitch"]
	var yaw: float = sample["yaw"]
	
	var rot = Vector3(roll, pitch, yaw)
	
	TelemetryManager.forward_pose(pos, rot, false, t)
	
