#Author: Aramis Hernandez

extends Node3D

@onready var chase_camera: Camera3D = $ChaseCamera
@onready var fixed_camera: Camera3D = $FixedCamera
@onready var free_camera: Camera3D = $FreeCamera

var cameras: Array = []
var current_index := 0

# Called when the node enters the scene tree for the first time.
func _ready():
	cameras = [chase_camera, fixed_camera, free_camera]
	_activate_camera(0)

func _input(event):
	if event.is_action_pressed("switch_camera"):
		current_index = (current_index + 1) % cameras.size()
		_activate_camera(current_index)


func _activate_camera(index):
	for i in cameras.size():
		cameras[i].current = (i == index)

func set_target(t: Node3D):
	chase_camera.set_target(t)
