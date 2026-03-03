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

#Current Chase Camera configurations will be changed like this.
#This is temporary and will not be permanent. 
@export_category("Chase Camera")
@export var distance: float = 10.0
@export var height: float = 3.0
@export var smoothing: float = 5.0

var cameras: Array = []
var current_index := 0

# Called when the node enters the scene tree for the first time.
func _ready():
	chase_camera.set_chase_settings(distance, height, smoothing)
	cameras = [chase_camera, fixed_camera, free_camera]
	_activate_camera(0) #default camera is chase

func _input(event):
	if event.is_action_pressed("switch_camera"):
		current_index = (current_index + 1) % cameras.size()
		_activate_camera(current_index)

#Set correct current active camera
func _activate_camera(index):
	for i in cameras.size():
		cameras[i].current = (i == index)

#Pass the target to children that need it, i.e chase and fix camera.
func set_target(t: Node3D):
	chase_camera.set_target(t)
	fixed_camera.set_target(t)
