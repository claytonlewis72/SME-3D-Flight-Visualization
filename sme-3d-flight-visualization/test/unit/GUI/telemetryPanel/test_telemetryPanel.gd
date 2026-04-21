#Author Aramis Hernandez 

extends "res://addons/gut/test.gd"

const TelemetryPanel = preload("res://scripts/GUI/telemetry_panel.gd")

var panel

func before_each():
	panel = TelemetryPanel.new()

	# Mock the required node structure
	var margin = MarginContainer.new()
	var vbox = VBoxContainer.new()
	var grid = GridContainer.new()
	grid.name = "TelemetryGrid"

	panel.add_child(margin)
	margin.add_child(vbox)
	vbox.add_child(grid)

	panel.telemetry_grid = grid


func after_each():
	panel.free()



# ------ UI build test -------------

func test_build_ui_creates_correct_number_of_labels():
	var fields = [
		{"key": "pos_x", "label": "X"},
		{"key": "pos_y", "label": "Y"}
	]

	panel.refresh_from_fields(fields)

	# Each field creates 2 labels (header + value)
	assert_eq(panel.telemetry_grid.get_child_count(), 4)


func test_field_labels_dictionary_populated():
	var fields = [
		{"key": "pos_x", "label": "X"}
	]

	panel.refresh_from_fields(fields)

	assert_true(panel._field_labels.has("pos_x"))


# ----- Flatten pose test -------------------
func test_flatten_pose_outputs_expected_keys():
	var result = panel._flatten_pose(
		Vector3(1, 2, 3),
		Vector3(4, 5, 6),
		false,
		1.2345
	)

	assert_true(result.has("pos_x"))
	assert_true(result.has("rot_z"))
	assert_true(result.has("time"))


func test_flatten_pose_formats_values_correctly():
	var result = panel._flatten_pose(
		Vector3(1, 2, 3),
		Vector3(4, 5, 6),
		true,
		1.23456
	)

	assert_eq(result["pos_x"], "1.000")
	assert_eq(result["gap"], "true")
	assert_eq(result["time"], "1.235") # rounded


# ----- Update pose test ------------- 

func test_update_pose_updates_ui_labels():
	var fields = [
		{"key": "pos_x", "label": "X"}
	]

	panel.refresh_from_fields(fields)

	panel._update_pose(
		Vector3(10, 0, 0),
		Vector3.ZERO,
		false,
		0.0
	)

	var label = panel._field_labels["pos_x"]
	assert_eq(label.text, "10.000")


func test_update_pose_ignores_unknown_keys():
	var fields = [
		{"key": "not_real", "label": "Fake"}
	]

	panel.refresh_from_fields(fields)

	panel._update_pose(
		Vector3(1, 2, 3),
		Vector3.ZERO,
		false,
		0.0
	)

	var label = panel._field_labels["not_real"]
	assert_eq(label.text, "---") # unchanged
