extends GutTest

const FixedCameraScript = preload("res://scripts/camera_manager/fixed_camera.gd")

var camera: Camera3D
var target: Node3D

func before_each():
	camera = FixedCameraScript.new()
	add_child_autofree(camera)
	
	target = Node3D.new()
	add_child_autofree(target)
	
## tests if camera assigns target properly
func test_set_target_assigns_target():
	camera.set_target(target)
	
	assert_eq(camera.target, target)
	
## tests that _process does nothing when no target is assigned
func test_process_does_nothing_when_no_target():
	var start_basis = camera.global_transform.basis
	var start_origin = camera.global_transform.origin
	
	camera._process(0.016)
	
	assert_eq(camera.global_transform.basis, start_basis)
	assert_eq(camera.global_transform.origin, start_origin)
	assert_eq(camera.target, null)
	
## test that camera faces the target
func test_process_rotates_camera_to_target():
	camera.global_transform.origin = Vector3(0, 0, 0)
	target.global_transform.origin = Vector3(0, 0, -10)

	camera.set_target(target)
	camera._process(0.016)

	var forward = -camera.global_transform.basis.z.normalized()
	var to_target = (target.global_transform.origin - camera.global_transform.origin).normalized()

	assert_almost_eq(forward.x, to_target.x, 0.001)
	assert_almost_eq(forward.y, to_target.y, 0.001)
	assert_almost_eq(forward.z, to_target.z, 0.001)
