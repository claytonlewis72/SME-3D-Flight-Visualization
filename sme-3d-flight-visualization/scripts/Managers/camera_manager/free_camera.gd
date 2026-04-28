#|------------------------------------------------------------------------------------
#|   Unclassified
#|------------------------------------------------------------------------------------
#|
#|   SME Solutions, Inc.
#|   Copyright 2026 SME Solutions, Inc. All Rights Reserved
#|   SME Solutions Proprietary Information
#|
#|------------------------------------------------------------------------------------
#|
#|   File Name   : free_camera.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Controls a free-flight camera driven entirely by player input.
#|       Supports six-axis keyboard movement, mouse-look, and a sprint
#|       modifier. Spawns near a target Node3D aligned to its yaw so the
#|       camera starts behind the drone facing the same direction.
#|       Activated and deactivated externally by CameraManager.
#|
#|   Notes       : This has been formally unit tested.
#|
#|   POC         : Aramis Hernandez & Clayton Lewis
#|
#|------------------------------------------------------------------------------------


extends Camera3D

## Controls a free-flight camera driven entirely by player input.
##
## When active, the camera accepts mouse motion to update yaw and pitch and
## reads six movement actions ([code]move_forward[/code], [code]move_back[/code],
## [code]move_left[/code], [code]move_right[/code], [code]move_up[/code],
## [code]move_down[/code]) from [InputMap] each frame. A [code]sprint_hold[/code]
## action doubles movement speed while held. Processing and input handling are
## disabled entirely when the camera is inactive so it does not consume input
## events while another camera mode is in use.
##
## [method spawn_near] positions the camera relative to a target [Node3D]
## using only the target's yaw, keeping the camera level regardless of the
## drone's pitch or roll at the moment of activation.



#Camera settings
## World-space movement speed in metres per second at normal pace.
@export var speed: float = 10.0

## Degrees of rotation applied per pixel of mouse movement.
@export var mouse_sensitivity: float = 0.2


## Spawn offset relative to the target's yaw-only orientation.
##
## Expressed in the target's local yaw frame so [code]Z[/code] is always
## "behind" and [code]Y[/code] is always "above" regardless of which
## direction the drone is facing. Defaults to 12 m behind and 3 m above.
@export var spawn_offset_local: Vector3 = Vector3(0, 3, 12) # behind + above by default


## Current horizontal look angle in degrees.
##
## Accumulated from mouse X-axis input and seeded by [method spawn_near]
## to match the target's world yaw at spawn time.
var yaw := 0.0

## Current vertical look angle in degrees.
##
## Accumulated from mouse Y-axis input and clamped to [-90, 90] to prevent
## the camera from flipping past straight up or straight down.
var pitch := 0.0

## Whether this camera is currently the active camera.
##
## When [code]false[/code], [method _process] and [method _input] are
## disabled via [method set_process] and [method set_process_input] so the
## node consumes no per-frame resources.
var active := false


## Activates or deactivates this camera's input and processing.
##
## Enabling or disabling both [method _process] and [method _input] together
## ensures the camera neither moves nor consumes mouse events while inactive.
## Called externally by [code]CameraManager[/code] when switching modes.
##
## Parameters:
##   v : bool
##       [code]true[/code] to enable input and processing; [code]false[/code]
##       to suspend them.
func set_active(v: bool) -> void:
	active = v
	#only read input when this camera is the active one
	set_process(v)
	set_process_input(v)


## Positions the camera near a target and aligns it to the target's yaw.
##
## Constructs a yaw-only [Basis] from [member Node3D.global_rotation].y of
## [param target], ignoring pitch and roll so the camera spawns level. The
## world transform is computed by offsetting [param offset_local] through
## that yaw-only transform, then [member yaw] and [member pitch] are seeded
## so subsequent mouse-look begins from the correct heading.
##
## Has no effect if [param target] is [code]null[/code].
##
## Parameters:
##   target       : Node3D
##       The node to spawn near. Typically the active drone.
##   offset_local : Vector3
##       Spawn offset in the target's yaw-only local frame. Defaults to
##       [member spawn_offset_local].
func spawn_near(target: Node3D, offset_local: Vector3 = spawn_offset_local) -> void:
	if target == null:
		return

	# Get plane yaw only (ignore pitch/roll so camera stays level)
	var yaw_rad := target.global_rotation.y
	var yaw_basis := Basis(Vector3.UP, yaw_rad)

	# Apply yaw-only transform at the plane position
	var t := Transform3D(yaw_basis, target.global_position)

	# Offset relative to yaw (behind/side stays correct, but camera stays level)
	global_transform = t * Transform3D(Basis(), offset_local)

	# Initialize mouse look angles (camera starts level)
	pitch = 0.0
	yaw = rad_to_deg(yaw_rad)
	rotation_degrees = Vector3(pitch, yaw, 0.0)
	
	
## Starts the camera in an inactive state so [code]CameraManager[/code] controls activation.
func _ready() -> void:
	#start inactive, camera manager will activate
	set_active(false)	


## Handles mouse motion to update the camera's look direction.
##
## Accumulates horizontal mouse movement into [member yaw] and vertical
## movement into [member pitch], then clamps pitch to [-90, 90] degrees
## and applies both to [member Node3D.rotation_degrees]. Has no effect
## if [member active] is [code]false[/code].
##
## Parameters:
##   event : InputEvent
##       The engine-supplied input event. Only [InputEventMouseMotion]
##       events are handled; all others are ignored.
func _input(event):
	if not active:
		return
		
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -90, 90)
		rotation_degrees = Vector3(pitch, yaw, 0)


## Translates the camera each frame based on held movement actions.
##
## Builds a direction vector from the camera's local basis axes according
## to which movement actions are currently pressed, normalizes it to prevent
## faster diagonal movement, and applies it scaled by [member speed],
## [param delta], and an optional sprint multiplier. The sprint multiplier
## is [code]2[/code] while [code]sprint_hold[/code] is pressed and
## [code]1[/code] otherwise. Has no effect if [member active] is
## [code]false[/code] or no movement actions are held.
##
## Parameters:
##   delta : float
##       Time in seconds since the last frame, supplied by the engine.
func _process(delta):
	if not active:
		return
	
	var dir = Vector3.ZERO
	var speed_modifier = 1
	if Input.is_action_pressed("sprint_hold"):
		speed_modifier = 2
	if Input.is_action_just_released("sprint_hold"):
		speed_modifier = 1
	if Input.is_action_pressed("move_down"):
		dir -= transform.basis.y
	if Input.is_action_pressed("move_up"):
		dir += transform.basis.y
	if Input.is_action_pressed("move_forward"):
		dir -= transform.basis.z
	if Input.is_action_pressed("move_back"):
		dir += transform.basis.z
	if Input.is_action_pressed("move_left"):
		dir -= transform.basis.x
	if Input.is_action_pressed("move_right"):
		dir += transform.basis.x
	if dir != Vector3.ZERO:
		global_translate(dir.normalized() * speed * delta * speed_modifier)
