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
#|   File Name   : telemetry_processor.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Validates raw telemetry samples and transforms them into pose
#|       dictionaries suitable for the rendering pipeline. Handles coordinate
#|       conversion from geographic (lat/lon/alt) to local Cartesian space,
#|       unit normalization for altitude and rotation, and Godot axis remapping.
#|
#|   Author      : Carson Wood
#|   Last Updated: April 2026
#|
#|------------------------------------------------------------------------------------

extends RefCounted
class_name TelemetryProcessor



func validate_sample(sample: Dictionary) -> bool:
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


func build_pose(
	sample: Dictionary,
	origin_state: Dictionary,
	angles_in_degrees: bool,
	altitude_in_feet: bool
) -> Dictionary:
	var lat: float = sample["lat"]
	var lon: float = sample["lon"]
	var alt: float = sample["alt"]

	if altitude_in_feet:
		alt *= 0.3048

	if not origin_state.get("set", false):
		origin_state["lat"] = lat
		origin_state["lon"] = lon
		origin_state["alt"] = alt
		origin_state["set"] = true

	var origin_lat: float = origin_state["lat"]
	var origin_lon: float = origin_state["lon"]
	var origin_alt: float = origin_state["alt"]

	var meters_per_deg_lat: float = 111320.0
	var meters_per_deg_lon: float = 111320.0 * cos(deg_to_rad(origin_lat))

	var dx: float = (lon - origin_lon) * meters_per_deg_lon
	var dz: float = (lat - origin_lat) * meters_per_deg_lat
	var dy: float = alt - origin_alt

	var roll: float = sample["roll"]
	var pitch: float = sample["pitch"]
	var yaw: float = sample["yaw"]

	if angles_in_degrees:
		roll = deg_to_rad(roll)
		pitch = deg_to_rad(pitch)
		yaw = deg_to_rad(yaw)

	return {
		"pos": Vector3(dx, dy, dz),
		# Godot axis order
		"rot": Vector3(pitch, yaw, roll)
	}
