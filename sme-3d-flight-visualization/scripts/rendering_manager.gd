extends Node3D

@export var drone_path: NodePath = NodePath("Drone")

# Keep pitch realistic
@export var pitch_scale: float = 1.5

# Roll can be exaggerated a bit for visibility
@export var roll_scale: float = 10.0

# Lower = smoother, higher = more responsive
@export var rotation_smoothness: float = 2.0

var drone: Node3D = null


func _ready() -> void:
	drone = get_node_or_null(drone_path) as Node3D

	if drone == null:
		push_error("Drone node not found. Expected at: " + str(drone_path))
		return

	print("Found Drone node:", drone.name)

	if not TelemetryManager:
		push_error("TelemetryManager not found")
		return

	TelemetryManager.pose_received.connect(_on_pose_received)


func _on_pose_received(pos: Vector3, rot: Vector3, gap: bool, time: float) -> void:
	if drone == null:
		return

	# Apply starting position
	drone.position = pos

	# --- ROTATION PIPELINE ---

	# Copy incoming rotation
	# Convert from Radians to Degrees
	var target_X = rad_to_deg(rot.x)
	# Rotation value is going the opposite direction so we reverse it's value
	var target_Y = rad_to_deg(rot.y*-1)
	var target_Z = rad_to_deg(rot.z)
	# Fix starting rotation value to line up with drawn line
	var target_rot = Vector3(target_X, target_Y-1.58, target_Z)

	## Apply rotation
	drone.rotation = target_rot
 
	# Optional debug
	if gap:
		print("Telemetry gap detected at t=", time)
