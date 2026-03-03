#Author: Aramis Hernandez

extends Camera3D

@export var speed: float = 10.0
@export var mouse_sensitivity: float = 0.2

var yaw := 0.0
var pitch := 0.0

func _input(event):
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -90, 90)
		rotation_degrees = Vector3(pitch, yaw, 0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var dir = Vector3.ZERO
	
	if Input.is_action_pressed("move_forward"):
		dir -= transform.basis.z
	if Input.is_action_pressed("move_back"):
		dir += transform.basis.z
	if Input.is_action_pressed("move_left"):
		dir -= transform.basis.x
	if Input.is_action_pressed("move_right"):
		dir += transform.basis.x
	
	global_translate(dir.normalized() * speed * delta)
