extends GutTest

var parser: TelemetryParser

func before_each() -> void:
	parser = TelemetryParser.new()

func test_parse_udp_packet_valid_line() -> void:
	var line := "telemetry,1.0,40.0,-75.0,100.0,0.1,0.2,0.3"
	var result: Dictionary = parser.parse_udp_packet(line)

	assert_false(result.is_empty(), "Expected parser to return a populated dictionary")
	assert_eq(result["timestamp"], 1.0)
	assert_eq(result["lat"], 40.0)
	assert_eq(result["lon"], -75.0)
	assert_eq(result["alt"], 100.0)
	assert_eq(result["roll"], 0.1)
	assert_eq(result["pitch"], 0.2)
	assert_eq(result["yaw"], 0.3)

func test_parse_udp_packet_rejects_empty_line() -> void:
	var result: Dictionary = parser.parse_udp_packet("")
	assert_true(result.is_empty(), "Expected empty line to return empty dictionary")

func test_parse_udp_packet_rejects_comment_line() -> void:
	var result: Dictionary = parser.parse_udp_packet("# comment")
	assert_true(result.is_empty(), "Expected comment line to return empty dictionary")

func test_parse_udp_packet_rejects_short_line() -> void:
	var line := "telemetry,1.0,40.0"
	var result: Dictionary = parser.parse_udp_packet(line)

	assert_true(result.is_empty(), "Expected incomplete packet to return empty dictionary")
