extends GutTest

func test_get_pose_structure():
	var IngestionManager = load("res://scripts/ingestion/ingestion_manager.gd")
	var manager = IngestionManager.new()

	var pose = manager.get_pose()

	assert_true(pose.has("pos"))
	assert_true(pose.has("rot"))
	assert_true(pose.has("has_pose"))
