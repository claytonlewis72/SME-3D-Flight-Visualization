extends GutTest

var processor: TelemetryProcessor

func before_each():
	processor = TelemetryProcessor.new()

func test_build_pose_returns_dictionary():
	var sample = {
		"timestamp": 1.0,
		"lat": 40.0,
		"lon": -75.0,
		"alt": 100.0,
		"roll": 0.0,
		"pitch": 0.0,
		"yaw": 0.0
	}

	var origin = {"set": false, "lat": 0.0, "lon": 0.0, "alt": 0.0}

	var pose = processor.build_pose(sample, origin, true, false)

	assert_true(pose.has("pos"))
	assert_true(pose.has("rot"))
