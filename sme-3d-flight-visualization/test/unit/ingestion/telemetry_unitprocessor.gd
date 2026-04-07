extends GutTest

var processor: TelemetryProcessor

func before_each() -> void:
	processor = TelemetryProcessor.new()

func test_validate_sample_accepts_valid_sample() -> void:
	var sample := {
		"timestamp": 1.0,
		"lat": 40.0,
		"lon": -75.0,
		"alt": 100.0,
		"roll": 0.1,
		"pitch": 0.2,
		"yaw": 0.3
	}

	assert_true(processor.validate_sample(sample), "Expected valid telemetry sample to pass validation")

func test_validate_sample_rejects_invalid_latitude() -> void:
	var sample := {
		"timestamp": 1.0,
		"lat": 140.0,
		"lon": -75.0,
		"alt": 100.0,
		"roll": 0.1,
		"pitch": 0.2,
		"yaw": 0.3
	}

	assert_false(processor.validate_sample(sample), "Expected invalid latitude to fail validation")

func test_validate_sample_rejects_invalid_longitude() -> void:
	var sample := {
		"timestamp": 1.0,
		"lat": 40.0,
		"lon": -275.0,
		"alt": 100.0,
		"roll": 0.1,
		"pitch": 0.2,
		"yaw": 0.3
	}

	assert_false(processor.validate_sample(sample), "Expected invalid longitude to fail validation")

func test_build_pose_sets_origin_and_returns_zero_position_for_first_sample() -> void:
	var sample := {
		"timestamp": 1.0,
		"lat": 40.0,
		"lon": -75.0,
		"alt": 100.0,
		"roll": 10.0,
		"pitch": 20.0,
		"yaw": 30.0
	}

	var origin_state := {
		"set": false,
		"lat": 0.0,
		"lon": 0.0,
		"alt": 0.0
	}

	var pose: Dictionary = processor.build_pose(sample, origin_state, true, false)

	assert_eq(pose["pos"], Vector3.ZERO)
	assert_true(origin_state["set"], "Expected origin to be initialized on first sample")

func test_build_pose_converts_degrees_to_radians() -> void:
	var sample := {
		"timestamp": 1.0,
		"lat": 40.0,
		"lon": -75.0,
		"alt": 100.0,
		"roll": 90.0,
		"pitch": 0.0,
		"yaw": 0.0
	}

	var origin_state := {
		"set": false,
		"lat": 0.0,
		"lon": 0.0,
		"alt": 0.0
	}

	var pose: Dictionary = processor.build_pose(sample, origin_state, true, false)
	var rot: Vector3 = pose["rot"]

	# build_pose returns Godot-order rot = Vector3(pitch, yaw, roll)
	assert_almost_eq(rot.x, 0.0, 0.001)
	assert_almost_eq(rot.y, 0.0, 0.001)
	assert_almost_eq(rot.z, PI / 2.0, 0.001)
