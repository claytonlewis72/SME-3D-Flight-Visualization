extends Node3D

@export var ingestion_path: NodePath = NodePath("../IngestionManager")
@export var drone_path: NodePath = NodePath("Drone")

var ingestion: Node = null
var drone: Node3D = null

func _ready() -> void:
	ingestion = get_node_or_null(ingestion_path)
	drone = get_node_or_null(drone_path) as Node3D

	if ingestion == null:
		push_error("IngestionManager not found. Expected at: " + str(ingestion_path))
	else:
		print("Found IngestionManager:", ingestion.name)

	if drone == null:
		push_error("Drone node not found. Expected at: " + str(drone_path))
	else:
		print("Found Drone node:", drone.name)

func _process(_delta: float) -> void:
	if ingestion == null or drone == null:
		return

	# Ingestion returns a dictionary pose contract:
	# { has_pose: bool, t: float, pos: Vector3, rot: Vector3, gap: bool }
	var pose: Dictionary = ingestion.get_pose()
	if not pose.has("has_pose") or not pose["has_pose"]:
		return

	if pose.has("pos"):
		drone.position = pose["pos"]

	if pose.has("rot"):
		drone.rotation = pose["rot"]

	# Optional: visualize a dropout (gap) in console
	if pose.has("gap") and pose["gap"]:
		print("Telemetry gap detected at t=", pose.get("t", -1.0))
