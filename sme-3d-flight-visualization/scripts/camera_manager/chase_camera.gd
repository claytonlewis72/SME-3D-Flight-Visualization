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

# Tunables (overridden by CameraManager via set_chase_settings)
var distance: float = 0.0
var height: float = 0.0
var smoothing: float = 5.0

# Target is set and passed through the camera_manager
var target: Node3D = null

# Internal state so we don't start the game "zoomed out" while lerping in
var _initialized: bool = false

func set_target(t: Node3D) -> void:
	target = t
	_initialized = false # snap again when target changes

func set_chase_settings(d: float, h: float, s: float) -> void:
	# Make distance always behave like "how far behind"
	distance = abs(d)
	height = h
	smoothing = max(s, 0.0)
	print("CHASE SETTINGS:", distance, height, smoothing)

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
