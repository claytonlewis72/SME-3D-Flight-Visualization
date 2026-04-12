#|------------------------------------------------------------------------------------
#|	Unclassified
#|------------------------------------------------------------------------------------
#|
#|	SME Solutions, Inc.
#|	Copyright 2026 SME Solutions, Inc. All Rights Reserved
#|	SME Solutions Proprietary Information
#|
#|------------------------------------------------------------------------------------
#|
#|	File Name	:test_free_camera.gd
#|
#|	Target 		:GD script
#|
#|	Description	: Unit testing related to the functions in free_camera.gd.
#|
#|	Notes		: 
#|
#|	POC			: Clayton Lewis
#|------------------------------------------------------------------------------------

extends GutTest

const FreeCameraScript = preload("res://scripts/camera_manager/free_camera.gd")

var camera: Camera3D
var target: Node3D

func before_each():
	camera = FreeCameraScript.new()
	add_child_autofree(camera)
	
	target = Node3D.new()
	add_child_autofree(target)
	
## test that camera starts inactive
func test_ready_starts_inactive():
	await get_tree().process_frame
	
	assert_false(camera.active)
	assert_false(camera.is_processing())
	assert_false(camera.is_processing_input())
	
## test to verify that the camera is set to active
func test_set_active_true_enables_camera():
	camera.set_active(true)
	
	assert_true(camera.active)
	assert_true(camera.is_processing())
	assert_true(camera.is_processing_input())
	
## test to make sure spawn_near() does nothing with no target assigned
func test_spawn_near_with_no_target_does_nothing():
	var start_pos = camera.global_transform.origin
	
	camera.spawn_near(null)
	
	assert_eq(camera.global_transform.origin, start_pos)
	
## tests to verify that spawn_near() repositions vehicle and resets angles
func test_spawn_near_positions_camera_and_resets_angles():
	target.global_position = Vector3(10, 0, 20)
	target.global_rotation = Vector3(0, 0, 0)
	
	camera.pitch = 25.0
	camera.yaw = 40.0
	
	camera.spawn_near(target)
	
	var expected = Vector3(10, 3, 32)
	
	assert_eq(camera.global_transform.origin, expected)
	assert_eq(camera.pitch, 0.0)
	assert_eq(camera.yaw, 0.0)
	assert_eq(camera.rotation_degrees, Vector3(0, 0, 0))
	
## test that mouse and keyboard input do nothing when camera is inactive
func test_input_does_nothing_when_inactive():
	camera.set_active(false)

	var event := InputEventMouseMotion.new()
	event.relative = Vector2(10, 5)

	camera.yaw = 0.0
	camera.pitch = 0.0
	camera._input(event)

	assert_eq(camera.yaw, 0.0)
	assert_eq(camera.pitch, 0.0)
	assert_eq(camera.rotation_degrees, Vector3(0, 0, 0))

## test that input updates camera yaw and pitch when active
func test_input_mouse_motion_updates_yaw_and_pitch_when_active():
	camera.set_active(true)
	camera.mouse_sensitivity = 0.2

	var event := InputEventMouseMotion.new()
	event.relative = Vector2(10, 5)

	camera.yaw = 0.0
	camera.pitch = 0.0

	camera._input(event)

	assert_eq(camera.yaw, -2.0)
	assert_eq(camera.pitch, -1.0)
	assert_almost_eq(camera.rotation_degrees.x, -1.0, 0.001)
	assert_almost_eq(camera.rotation_degrees.y, -2.0, 0.001)
	assert_almost_eq(camera.rotation_degrees.z, 0.0, 0.001)
	

## test that process does nothing when camera is inactive
func test_process_does_nothing_when_inactive():
	camera.set_active(false)
	var start_pos = camera.global_transform.origin

	camera._process(0.5)

	assert_eq(camera.global_transform.origin, start_pos)

func test_non_mouse_input_does_nothing_when_active():
	camera.set_active(true)

	var event := InputEventKey.new()
	camera.yaw = 5.0
	camera.pitch = 10.0

	camera._input(event)

	assert_eq(camera.yaw, 5.0)
	assert_eq(camera.pitch, 10.0)
	
func test_set_active_false_disables_camera():
	camera.set_active(true)
	camera.set_active(false)

	assert_false(camera.active)
	assert_false(camera.is_processing())
	assert_false(camera.is_processing_input())
