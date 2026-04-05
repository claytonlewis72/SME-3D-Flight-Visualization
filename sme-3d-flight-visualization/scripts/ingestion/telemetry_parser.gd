extends RefCounted
class_name TelemetryParser

func parse_udp_packet(line: String) -> Dictionary:
	line = line.strip_edges()

	if line.is_empty() or line.begins_with("#"):
		return {}

	var parts: PackedStringArray = line.split(",")

	# Expected:
	# source,timestamp,lat,lon,alt,roll,pitch,yaw
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
