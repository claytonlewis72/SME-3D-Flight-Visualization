extends Node3D

@export var ingestion_manager_path: NodePath
@export var position_scale: float = 1.0  # set to 1 if meters == 1 unit in your world

@onready var ingestion = get_node(ingestion_manager_path)

func _process(_delta: float) -> void:
	var p = ingestion.get_pose()
	if not p["has_pose"]:
		return

	# Position
	global_position = p["pos"] * position_scale

	# Rotation (Godot uses X=pitch, Y=yaw, Z=roll in basis terms, but your data is roll,pitch,yaw)
	# ingestion gives Vector3(roll, pitch, yaw)
	var r: Vector3 = p["rot"]

	# Apply as Euler with correct mapping:
	# Godot's rotation Vector3 is (x=pitch, y=yaw, z=roll)
	rotation = Vector3(r.y, r.z, r.x)
