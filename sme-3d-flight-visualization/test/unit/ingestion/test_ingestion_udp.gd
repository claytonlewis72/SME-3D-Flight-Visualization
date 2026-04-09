extends GutTest

func test_ingestion_udp_initial_state():
	var IngestionUDP = load("res://scripts/ingestion/ingestion_udp.gd")
	var udp = IngestionUDP.new()

	assert_eq(udp.has_pose, false)
	assert_eq(udp.packets_total, 0)
