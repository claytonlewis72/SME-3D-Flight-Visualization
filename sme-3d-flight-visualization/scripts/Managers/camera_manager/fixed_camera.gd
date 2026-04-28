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
#|   File Name   : fixed_camera.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Controls a fixed-position camera that rotates each frame to look at
#|       a target Node3D. The camera does not move; only its orientation
#|       updates. The target is assigned externally by CameraManager via
#|       set_target.
#|
#|   Notes       : This has been formally unit tested. The target is set
#|                 through the CameraManager set_target function.
#|
#|   POC         : Aramis Hernandez
#|
#|------------------------------------------------------------------------------------

extends Camera3D

## Controls a fixed-position camera that rotates each frame to face a target [Node3D].
##
## Unlike a chase camera, this node does not translate. Its world position is
## set entirely by its placement in the scene tree. Each frame it calls
## [method Node3D.look_at] toward [member target]'s world origin so the drone
## remains centered in the frame regardless of where it moves.
##
## The target is assigned externally by [code]CameraManager[/code] via
## [method set_target].


## The [Node3D] this camera tracks.
##
## [code]null[/code] by default. When [code]null[/code], [method _process]
## returns early and the camera holds its last orientation. Assign via
## [method set_target].
var target: Node3D #Target is given to the camera_manager then passed through them.


# Called every frame. 'delta' is the elapsed time since the previous frame.
## Rotates the camera each frame to face the current target.
##
## Calls [method Node3D.look_at] directed at [member target]'s world origin
## with [constant Vector3.UP] as the up vector. Has no effect and returns
## early if [member target] is [code]null[/code]. The camera's world
## position is never modified by this method.
##
## Parameters:
##   _delta : float
##       Time in seconds since the last frame. Not used by this method.
func _process(_delta):
	if target:
		look_at(target.global_transform.origin, Vector3.UP)
	else:
		return



## Assigns the node this camera will track.
##
## Called externally by [code]CameraManager[/code]. Replaces any previously
## assigned target immediately; the camera will orient toward the new target
## on the next processed frame.
##
## Parameters:
##   t : Node3D
##       The node to track. Pass [code]null[/code] to suspend orientation
##       updates.
func set_target(t: Node3D):
	target = t
