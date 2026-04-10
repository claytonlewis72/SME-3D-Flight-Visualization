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
#|	Notes		: This has been formally unit tested.
#|
#|	POC			: Aramis Hernandez
#|------------------------------------------------------------------------------------

extends Node3D
## Manages camera switching and camera behavior for the application.
##
## This node maintains references to multiple camera types and allows
## switching between them using an input action (`switch_camera`).
##
## Supported camera types:
##
## - **Chase Camera** — Follows a target node with configurable distance and height.
## - **Fixed Camera** — Stationary camera that observes the target.
## - **Free Camera** — User-controlled camera that can move independently.
##
## The manager ensures that only one camera is active at any time and
## properly initializes camera state when switching modes.

## Reference to the chase camera used for following a target.
@onready var chase_camera: Camera3D = $ChaseCamera


## Reference to the fixed camera.
@onready var fixed_camera: Camera3D = $FixedCamera


## Reference to the free camera which allows user-controlled movement.
@onready var free_camera: Camera3D = $FreeCamera

@export_category("Chase Camera")

## Distance the chase camera maintains behind the target.
@export var distance: float = 15.0

## Height offset of the chase camera relative to the target.
@export var height: float = 6.0

## Interpolation factor controlling how smoothly the chase camera follows the target.
@export var smoothing: float = 10.0


## Collection of all cameras managed by this node.
var cameras: Array[Camera3D] = []

## Index of the currently active camera within the camera array.
var current_index: int = 0

## Target node the cameras should track or observe.
var target: Node3D = null

## Initializes the camera list and activates the default camera.
##
## The initialization waits one frame to ensure all child nodes
## are fully ready before attempting to activate cameras.
func _ready() -> void:
	cameras = [chase_camera, fixed_camera, free_camera]
	await get_tree().process_frame
	_activate_camera(0)


## Handles user input events for switching between cameras.
##
## The input action `switch_camera` cycles through the available cameras
## in the order defined in the `cameras` array.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_camera"):
		current_index = (current_index + 1) % cameras.size()
		_activate_camera(current_index)


## Activates a camera by index and disables all others.
##
## Parameter:
## - `index`: The index of the camera to activate within the `cameras` array.
##
## The method also performs additional setup depending on the camera type:
##
## - Resets chase camera parameters.
## - Spawns the free camera near the target when first activated.
## - Enables or disables free camera controls appropriately.
func _activate_camera(index: int) -> void:
	
	# Disable for all cameras
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

	# Enable free cam controls if active and start capturing mouse
	if cameras[index] == free_camera and free_camera.has_method("set_active"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		free_camera.set_active(true)

	print("Active camera:", cameras[index].name)

## Applies chase camera configuration parameters.
##
## Parameter:
## - `snap`: If true, forces the camera to immediately snap to the
##   target position instead of interpolating.
##
## This is useful when first assigning a target to prevent unwanted
## camera transitions during initialization.
func _apply_chase_settings(snap: bool) -> void:
	# Stops capturing mouse
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if chase_camera.has_method("set_chase_settings"):
		chase_camera.set_chase_settings(distance, height, smoothing)

	# Optional: force snap if supported (kills the weird initial zoom)
	if snap and chase_camera.has_method("snap_to_target"):
		chase_camera.snap_to_target()

## Assigns the target node that cameras should track or observe.
##
## Parameter:
## - `t`: Node3D representing the object the cameras should follow.
##
## When a new target is assigned, compatible cameras will automatically
## receive the updated target reference.
func set_target(t: Node3D) -> void:
	target = t

	if chase_camera.has_method("set_target"):
		chase_camera.set_target(t)
		# Snap immediately when target arrives (prevents first-frame zoom)
		if chase_camera.has_method("snap_to_target"):
			chase_camera.snap_to_target()

	if fixed_camera.has_method("set_target"):
		fixed_camera.set_target(t)
