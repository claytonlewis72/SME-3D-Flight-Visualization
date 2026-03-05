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
#|	File Name	: camera_manager.gd
#|
#|	Target 		:GD script
#|
#|	Description	: Controls which camera is currently active and how to switch camera.
#|
#|	Notes		: This hasn't formally been united tested.
#|
#|	POC			: Aramis Hernandez
#|------------------------------------------------------------------------------------

extends Node3D

@onready var chase_camera: Camera3D = $ChaseCamera
@onready var fixed_camera: Camera3D = $FixedCamera
@onready var free_camera: Camera3D = $FreeCamera

@export_category("Chase Camera")
@export var distance: float = 15.0
@export var height: float = 6.0
@export var smoothing: float = 10.0

var cameras: Array[Camera3D] = []
var current_index: int = 0

var target: Node3D = null

func _ready() -> void:
	cameras = [chase_camera, fixed_camera, free_camera]
	await get_tree().process_frame
	_activate_camera(0)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_camera"):
		current_index = (current_index + 1) % cameras.size()
		_activate_camera(current_index)

func _activate_camera(index: int) -> void:
	# Disable all
	for i in range(cameras.size()):
		cameras[i].current = false

	# Turn off free cam controls unless it's active
	if free_camera.has_method("set_active"):
		free_camera.set_active(false)

	# If switching to chase, re-apply settings (no stale values)
	if cameras[index] == chase_camera:
		_apply_chase_settings(false)

	# If switching to free cam, spawn it near the target ONCE
	if cameras[index] == free_camera and target != null and free_camera.has_method("spawn_near"):
		free_camera.spawn_near(target)

	# Make chosen camera current
	cameras[index].make_current()

	# Enable free cam controls if active
	if cameras[index] == free_camera and free_camera.has_method("set_active"):
		free_camera.set_active(true)

	print("Active camera:", cameras[index].name)

func _apply_chase_settings(snap: bool) -> void:
	if chase_camera.has_method("set_chase_settings"):
		chase_camera.set_chase_settings(distance, height, smoothing)

	# Optional: force snap if supported (kills the weird initial zoom)
	if snap and chase_camera.has_method("snap_to_target"):
		chase_camera.snap_to_target()

func set_target(t: Node3D) -> void:
	target = t

	if chase_camera.has_method("set_target"):
		chase_camera.set_target(t)
		# Snap immediately when target arrives (prevents first-frame zoom)
		if chase_camera.has_method("snap_to_target"):
			chase_camera.snap_to_target()

	if fixed_camera.has_method("set_target"):
		fixed_camera.set_target(t)
