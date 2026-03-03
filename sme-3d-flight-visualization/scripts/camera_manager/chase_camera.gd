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
#|	Notes		: This hasn't formally been united tested.
#|
#|	POC			: Aramis Hernandez
#|------------------------------------------------------------------------------------

extends Camera3D


var distance: float = 10.0
var height: float = 3.0
var smoothing: float = 5.0

var target: Node3D #Target is set and passed through the camera_manager.

func set_target(t: Node3D):
	target = t

func set_chase_settings(d: float, h: float, s: float): #distance, height, and smoothing
	distance = d
	height = h
	smoothing = s

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if target == null:
		return
	
	# Chase camera position
	var desired_pos = target.global_transform.origin - target.global_transform.basis.z * distance + Vector3.UP * height
	
	# "Chasing" target position
	global_transform.origin = global_transform.origin.lerp(desired_pos, smoothing * delta)
	
	look_at(target.global_transform.origin, Vector3.UP)
