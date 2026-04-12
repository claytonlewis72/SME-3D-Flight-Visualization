extends TelemetrySource

@export var UDP_PORT: int = 5005
var udp := PacketPeerUDP.new()


func start():
	var err = udp.bind(UDP_PORT)
	if err != OK:
		push_error("UDP bind failed")
		return
	set_process(true)
	print("Listening on port:", UDP_PORT)
	

func stop():
	udp.close()
	set_process(false)
	
func _process(_delta):
	while udp.get_available_packet_count() > 0:
		var packet := udp.get_packet()
		var msg := packet.get_string_from_utf8()
		_handle_line(msg)

func _handle_line(line: String):
	line = line.strip_edges()
	
	if line.is_empty() or line.begins_with("#"):
		return
	
	var sample := _parse_udp_packet(line)
	
	if sample.is_empty():
		return

#Parser
func _parse_udp_packet(line: String) -> Dictionary:
	var parts := line.split(",")
	
	if parts.size() < 0:
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
