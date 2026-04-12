extends Node3D

var previous_position: Vector3

func _ready():
	previous_position = global_position

func _process(delta):
	var move_dir = global_position - previous_position

	if move_dir.length() > 0.001:
		look_at(global_position + move_dir.normalized(), Vector3.UP)

	previous_position = global_position
