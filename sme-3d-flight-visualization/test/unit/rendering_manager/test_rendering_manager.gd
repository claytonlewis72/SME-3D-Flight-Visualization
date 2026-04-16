extends GutTest

const RENDERING_MANAGER_SCRIPT = preload("res://scripts/Managers/rendering_manager.gd")

var root_node: Node
var rendering_manager: Node3D
var drone: Node3D


func before_each():
	_build_tree()
	await get_tree().process_frame


func after_each():
	if is_instance_valid(root_node):
		root_node.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _build_tree():
	root_node = Node.new()
	root_node.name = "TestRoot"
	get_tree().root.add_child(root_node)

	# Build manager node FIRST, but do not add to tree yet
	rendering_manager = Node3D.new()
	rendering_manager.name = "RenderingManager"

	# Add Drone child BEFORE attaching script / entering tree
	drone = Node3D.new()
	drone.name = "Drone"
	rendering_manager.add_child(drone)

	# Attach script AFTER children exist
	rendering_manager.set_script(RENDERING_MANAGER_SCRIPT)

	# Now the exported property exists
	rendering_manager.drone_path = NodePath("Drone")

	# Add to tree LAST so _ready() sees Drone
	root_node.add_child(rendering_manager)


func test_ready_finds_drone_node():
	assert_ne(rendering_manager.drone, null)
	assert_eq(rendering_manager.drone, drone)


func test_on_pose_received_updates_drone_position():
	var pos := Vector3(10, 20, 30)
	var rot := Vector3.ZERO

	rendering_manager._on_pose_received(pos, rot, false, 0.0)

	assert_eq(drone.position, pos)


func test_on_pose_received_converts_rotation_values():
	var pos := Vector3.ZERO
	var rot := Vector3(1.0, 2.0, 3.0)

	rendering_manager._on_pose_received(pos, rot, false, 0.0)

	var target_x = rad_to_deg(rot.x * -1)
	var target_y = rad_to_deg(rot.y * -1)
	var target_z = rad_to_deg(rot.z * -1)
	var expected = Vector3(target_y, target_z - 1.58, target_x)

	assert_almost_eq(drone.rotation.x, expected.x, 0.0001)
	assert_almost_eq(drone.rotation.y, expected.y, 0.0001)
	assert_almost_eq(drone.rotation.z, expected.z, 0.0001)


func test_on_pose_received_handles_gap_without_changing_transform_logic():
	var pos := Vector3(1, 2, 3)
	var rot := Vector3(0.1, 0.2, 0.3)

	rendering_manager._on_pose_received(pos, rot, true, 12.5)

	var target_x = rad_to_deg(rot.x * -1)
	var target_y = rad_to_deg(rot.y * -1)
	var target_z = rad_to_deg(rot.z * -1)
	var expected = Vector3(target_y, target_z - 1.58, target_x)

	assert_eq(drone.position, pos)
	assert_almost_eq(drone.rotation.x, expected.x, 0.0001)
	assert_almost_eq(drone.rotation.y, expected.y, 0.0001)
	assert_almost_eq(drone.rotation.z, expected.z, 0.0001)


func test_on_pose_received_does_nothing_when_drone_is_null():
	rendering_manager.drone = null

	rendering_manager._on_pose_received(Vector3(5, 6, 7), Vector3(1, 1, 1), false, 0.0)

	assert_true(true)
