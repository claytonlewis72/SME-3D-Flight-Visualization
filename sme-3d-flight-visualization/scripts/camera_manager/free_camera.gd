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
#|	File Name	:free_camera.gd
#|
#|	Target 		:GD script
#|
#|	Description	: Controls free camera allowing user input to chnage position and oration of the free camera.
#|
#|	Notes		: This has formally been united tested.
#|
#|	POC			: Aramis Hernandez & Clayton Lewis
#|------------------------------------------------------------------------------------


extends Camera3D

#Free Camera Settings
@export var speed: float = 10.0
@export var mouse_sensitivity: float = 0.2

# Where to spawn relative to the plane (local to plane orientation)
@export var spawn_offset_local: Vector3 = Vector3(0, 3, 12) # behind + above by default

var yaw := 0.0
var pitch := 0.0
var active := false

func set_active(v: bool) -> void:
	active = v
	#only read input when this camera is the active one
	set_process(v)
	set_process_input(v)

func spawn_near(target: Node3D, offset_local: Vector3 = spawn_offset_local) -> void:
	if target == null:
		return

	# Get plane yaw only (ignore pitch/roll so camera stays level)
	var yaw_rad := target.global_rotation.y
	var yaw_basis := Basis(Vector3.UP, yaw_rad)

	# Apply yaw-only transform at the plane position
	var t := Transform3D(yaw_basis, target.global_position)

	# Offset relative to yaw (behind/side stays correct, but camera stays level)
	global_transform = t * Transform3D(Basis(), offset_local)

	# Initialize mouse look angles (camera starts level)
	pitch = 0.0
	yaw = rad_to_deg(yaw_rad)
	rotation_degrees = Vector3(pitch, yaw, 0.0)
	
func _ready() -> void:
	#start inactive, camera manager will activate
	set_active(false)	

func _input(event):
	if not active:
		return
		
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -90, 90)
		rotation_degrees = Vector3(pitch, yaw, 0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if not active:
		return
	
	var dir = Vector3.ZERO
	
	if Input.is_action_pressed("move_forward"):
		dir -= transform.basis.z
	if Input.is_action_pressed("move_back"):
		dir += transform.basis.z
	if Input.is_action_pressed("move_left"):
		dir -= transform.basis.x
	if Input.is_action_pressed("move_right"):
		dir += transform.basis.x
		
	if dir != Vector3.ZERO:
		global_translate(dir.normalized() * speed * delta)
