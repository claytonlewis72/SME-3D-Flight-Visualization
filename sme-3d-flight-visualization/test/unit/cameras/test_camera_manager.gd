extends GutTest

const TestScene = preload("res://scenes/camera_manager.tscn")

var root: Node3D
var manager
var chase_camera: Camera3D
var fixed_camera: Camera3D
var free_camera: Camera3D
var target: Node3D

func before_each():
	root = TestScene.instantiate()
	add_child_autofree(root)

	manager = root
	chase_camera = manager.get_node("ChaseCamera")
	fixed_camera = manager.get_node("FixedCamera")
	free_camera = manager.get_node("FreeCamera")

	target = Node3D.new()
	add_child_autofree(target)

## tests to make sure chase camera is set as default
func test_ready_activates_chase_camera_by_default():
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(chase_camera.current)
	assert_false(fixed_camera.current)
	assert_false(free_camera.current)
	assert_eq(manager.current_index, 0)

## tests to make sure target is passed between cameras
func test_set_target_passes_target_to_chase_and_fixed():
	manager.set_target(target)

	assert_eq(manager.target, target)
	assert_eq(chase_camera.target, target)
	assert_eq(fixed_camera.target, target)

## tests to make sure camera 0 activates chase camera
func test_activate_camera_zero_activates_chase_camera():
	manager._activate_camera(0)

	assert_true(chase_camera.current)
	assert_false(fixed_camera.current)
	assert_false(free_camera.current)
	
## test to make sure camera one activate the fixed camera
func test_activate_camera_one_activates_fixed_camera():
	manager._activate_camera(1)

	assert_false(chase_camera.current)
	assert_true(fixed_camera.current)
	assert_false(free_camera.current)

## test to make sure camera two activates the free camera
func test_activate_camera_two_activates_free_camera():
	manager.set_target(target)
	manager._activate_camera(2)

	assert_false(chase_camera.current)
	assert_false(fixed_camera.current)
	assert_true(free_camera.current)
	assert_true(free_camera.active)

## test to verify that free camera is spawned in at the rear of the target when selected
func test_activating_free_camera_spawns_it_near_target():
	target.global_position = Vector3(10, 0, 20)
	target.global_rotation = Vector3(0, 0, 0)

	manager.set_target(target)
	manager._activate_camera(2)

	var expected = Vector3(10, 3, 32)
	assert_eq(free_camera.global_transform.origin, expected)

## test to verify switching from free camera disables controls
func test_switching_away_from_free_camera_disables_controls():
	manager.set_target(target)
	manager._activate_camera(2)

	assert_true(free_camera.active)

	manager._activate_camera(0)

	assert_false(free_camera.active)
	assert_true(chase_camera.current)

## test switch camera index
func test_input_switch_camera_cycles_index():
	await get_tree().process_frame
	await get_tree().process_frame

	var event := InputEventAction.new()
	event.action = "switch_camera"
	event.pressed = true

	manager._input(event)
	assert_eq(manager.current_index, 1)

	manager._input(event)
	assert_eq(manager.current_index, 2)

	manager._input(event)
	assert_eq(manager.current_index, 0)
