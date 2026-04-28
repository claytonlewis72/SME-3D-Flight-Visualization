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
#|	File Name	:chase_camera.gd
#|
#|	Target 		:GD script
#|
#|	Description	: Controls chase camera for the drone.
#|
#|	Notes		: This has been formally unit tested.
#|
#|	POC			: Aramis Hernandez & Clayton Lewis
#|------------------------------------------------------------------------------------

extends Camera3D

## Controls a third-person chase camera that follows a target [Node3D].
##
## Each frame the camera computes a desired position behind and above
## [member target] using the target's local [code]-Z[/code] basis vector,
## then moves toward it with a frame-rate-independent exponential lerp.
## On the first valid frame after a target is assigned the camera snaps
## directly to the desired position to avoid a visible ease-in from the
## scene origin.
##
## Runtime tunables are applied externally by [code]CameraManager[/code]
## via [method set_chase_settings].


# Tunables (overridden by CameraManager via set_chase_settings)
## Distance to maintain behind the target along its local [code]-Z[/code] axis.
##
## Always treated as a positive offset regardless of the sign passed to
## [method set_chase_settings].
var distance: float = 0.0

## Height offset above the target's world position.
var height: float = 0.0

## Exponential smoothing coefficient controlling how quickly the camera
## catches up to the desired position.
##
## Higher values feel snappier; lower values feel more cinematic.
## Clamped to a minimum of [code]0.0[/code] by [method set_chase_settings].
var smoothing: float = 5.0

# Target is set and passed through the camera_manager
## The [Node3D] this camera tracks.
##
## Set externally via [method set_target]. [code]null[/code] disables all
## per-frame movement until a valid target is assigned.
var target: Node3D = null

# Internal state so we don't start the game "zoomed out" while lerping in
## Whether the camera has completed its initial snap to the desired position.
##
## [code]false[/code] on startup and whenever [method set_target] is called.
## Set to [code]true[/code] after the first frame in which a valid
## [member target] is present, preventing a slow ease-in from an
## uninitialized transform.
var _initialized: bool = false


## Assigns a new follow target and resets the snap flag.
##
## Setting a new target causes the camera to snap immediately to the
## correct position on the next processed frame rather than lerping in
## from its previous location.
##
## Parameters:
##   t : Node3D
##       The node the camera should follow. Pass [code]null[/code] to
##       suspend camera movement.
func set_target(t: Node3D) -> void:
	target = t
	_initialized = false # snap again when target changes


## Applies runtime chase camera tuning parameters.
##
## Called externally by [code]CameraManager[/code] to configure the camera
## without requiring an export variable or scene reload.
##
## Parameters:
##   d : float
##       Desired follow distance behind the target. The absolute value is
##       used so negative inputs behave identically to positive ones.
##   h : float
##       Vertical offset above the target's world position in metres.
##   s : float
##       Exponential smoothing coefficient. Values below [code]0.0[/code]
##       are clamped to [code]0.0[/code].
func set_chase_settings(d: float, h: float, s: float) -> void:
	# Make distance always behave like "how far behind"
	distance = abs(d)
	height = h
	smoothing = max(s, 0.0)
	print("CHASE SETTINGS:", distance, height, smoothing)


## Updates the camera position and orientation each frame.
##
## Computes the desired world position as:
## [codeblock]
##   desired = target.global_position
##           + (target.basis.z * distance)   # behind in Godot 4 +Z convention
##           + (Vector3.UP    * height)
## [/codeblock]
##
## On the first valid frame [member _initialized] is [code]false[/code] and
## the camera is snapped directly to [code]desired[/code]. On subsequent
## frames the position is smoothed with a frame-rate-independent exponential
## lerp:
## [codeblock]
##   t = 1.0 - exp(-smoothing * delta)
##   position = position.lerp(desired, t)
## [/codeblock]
##
## After repositioning, [method Node3D.look_at] is called targeting a point
## [code]2.0[/code] metres above the target's world origin so the drone
## model remains vertically centred in the frame.
##
## Has no effect if [member target] is [code]null[/code].
##
## Parameters:
##   delta : float
##       Time in seconds since the last frame, supplied by the engine.
func _process(delta: float) -> void:
	if target == null:
		return

	var target_pos: Vector3 = target.global_transform.origin
	var back_dir: Vector3 = target.global_transform.basis.z.normalized() # behind the target in Godot 4
	var desired_pos: Vector3 = target_pos + back_dir * distance + Vector3.UP * height

	# Snap on first valid frame so you don't start far away and slowly ease in
	if not _initialized:
		global_transform.origin = desired_pos
		_initialized = true
	else:
		# Frame-rate independent smoothing (feels consistent at any FPS)
		var t := 1.0 - exp(-smoothing * delta)
		global_transform.origin = global_transform.origin.lerp(desired_pos, t)

	# Look slightly above the target so the model stays in view
	look_at(target_pos + Vector3.UP * 2.0, Vector3.UP)
