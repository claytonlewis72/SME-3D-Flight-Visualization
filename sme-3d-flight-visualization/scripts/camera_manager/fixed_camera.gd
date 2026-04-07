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
#|	File Name	:fixed_camera.gd
#|
#|	Target 		:GD script
#|
#|	Description	: Controls the fixed camera, and looks at the target.
#|
#|	Notes		: This has formally been united tested. The target is passed set through the manager set_target function.
#|
#|	POC			: Aramis Hernandez
#|------------------------------------------------------------------------------------


extends Camera3D


var target: Node3D #Target is given to the camera_manager then passed through them.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if target:
		look_at(target.global_transform.origin, Vector3.UP)
	else:
		return

func set_target(t: Node3D):
	target = t
