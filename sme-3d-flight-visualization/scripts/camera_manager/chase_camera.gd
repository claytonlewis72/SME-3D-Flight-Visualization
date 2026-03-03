#Author: Aramis Hernandez

extends Camera3D


@export var distance: float = 10.0
@export var height: float = 3.0
@export var smoothing: float = 5.0

var target: Node3D

func set_target(t: Node3D):
	target = t

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if target == null:
		return
	var desired_pos = target.global_transform.origin
	- target.global_transform.basis.z * distance 
	+ Vector3.UP * height
	
	global_transform.origin = global_transform.origin.lerp(desired_pos, smoothing * delta)
	look_at(target.global_transform.origin, Vector3.UP)
