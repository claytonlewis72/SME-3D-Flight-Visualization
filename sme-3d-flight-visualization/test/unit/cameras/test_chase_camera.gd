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
#|	File Name	:test_chase_camera.gd
#|
#|	Target 		:GD script
#|
#|	Description	: Unit testing related to the functions in chase_camera.gd.
#|
#|	Notes		: 
#|
#|	POC			: Clayton Lewis
#|------------------------------------------------------------------------------------

extends GutTest

const ChaseCameraScript = preload("res://scripts/camera_manager/chase_camera.gd")

var camera: Camera3D
var target: Node3D

func before_each():
	camera = ChaseCameraScript.new()
	add_child_autofree(camera)

	target = Node3D.new()
	add_child_autofree(target)

## verify that target gets assigned and _initalized resets to false
func test_set_target_assigns_target_and_resets_initialized():
	camera._initialized = true

	camera.set_target(target)

	assert_eq(camera.target, target)
	assert_false(camera._initialized)

## tests chase camera settings are being applied
func test_set_chase_settings_applies_expected_values():
	camera.set_chase_settings(-15.0, 6.0, -2.0)

	assert_eq(camera.distance, 15.0)
	assert_eq(camera.height, 6.0)
	assert_eq(camera.smoothing, 0.0)

## test that _process does nothing when camera has no target
func test_process_does_nothing_when_no_target():
	var start_pos = camera.global_transform.origin

	camera._process(0.016)

	assert_eq(camera.global_transform.origin, start_pos)
	assert_false(camera._initialized)

## tests first time snap behavior
func test_first_process_snaps_camera_to_desired_position():
	target.global_transform.origin = Vector3(10, 0, 20)
	target.global_transform.basis = Basis()

	camera.set_target(target)
	camera.set_chase_settings(15.0, 6.0, 5.0)

	camera._process(0.016)

	var expected = Vector3(10, 0, 20) + Vector3(0, 0, 1) * 15.0 + Vector3.UP * 6.0

	assert_eq(camera.global_transform.origin, expected)
	assert_true(camera._initialized)

## tests changing cameras forces a re-snap
func test_changing_target_resets_initialized_and_snaps_again():
	target.global_transform.origin = Vector3.ZERO
	target.global_transform.basis = Basis()

	camera.set_target(target)
	camera.set_chase_settings(10.0, 5.0, 5.0)
	camera._process(0.016)

	var new_target = Node3D.new()
	add_child_autofree(new_target)
	new_target.global_transform.origin = Vector3(100, 0, 0)
	new_target.global_transform.basis = Basis()

	camera.set_target(new_target)
	assert_false(camera._initialized)

	camera._process(0.016)

	var expected = Vector3(100, 0, 0) + Vector3(0, 0, 1) * 10.0 + Vector3.UP * 5.0
	assert_eq(camera.global_transform.origin, expected)
