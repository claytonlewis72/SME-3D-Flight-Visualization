extends GutTest

func test_parse_udp_packet_valid():
	var ReceiverSource = load("res://scripts/ingestion/receiver_source.gd")
	var receiver = ReceiverSource.new()

	var result = receiver._parse_udp_packet("telemetry,1.0,40.0,-75.0,100.0,0.1,0.2,0.3")

	assert_false(result.is_empty())
	assert_eq(result["lat"], 40.0)

func test_parse_udp_packet_invalid():
	var ReceiverSource = load("res://scripts/ingestion/receiver_source.gd")
	var receiver = ReceiverSource.new()

	var result = receiver._parse_udp_packet("bad,data")

	assert_true(result.is_empty())
