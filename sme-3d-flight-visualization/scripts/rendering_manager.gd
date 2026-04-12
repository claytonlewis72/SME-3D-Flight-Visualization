extends Node3D

@export var drone_path: NodePath = NodePath("Drone")

# Visual scaling (for subtle telemetry)
@export var pitch_scale: float = 100.0
@export var roll_scale: float = 100.0

# Smoothing factor
@export var rotation_smoothness: float = 3.0

var drone: Node3D = null


func _ready() -> void:
	drone = get_node_or_null(drone_path) as Node3D

	if drone == null:
		push_error("Drone node not found. Expected at: " + str(drone_path))
		return

	print("Found Drone node:", drone.name)

	#Connect to TelemetryManager (global singleton)
	TelemetryManager.pose_received.connect(_on_pose_received)


func _on_pose_received(pos: Vector3, rot: Vector3, gap: bool, time: float) -> void:
	if drone == null:
		return

	# Apply starting position
	drone.position = pos

	# --- ROTATION PIPELINE ---

	# Copy incoming rotation
	# Convert from Radians to Degrees
	# Rotation value is going the opposite direction so we reverse it's values
	# X = Roll
	var target_X = rad_to_deg(rot.x*-1)
	# Y = Pitch
	var target_Y = rad_to_deg(rot.y*-1)
	# Z = Yall
	var target_Z = rad_to_deg(rot.z*-1)
	
	# Fix starting rotation value to line up with drawn line
	var target_rot = Vector3(target_Y, target_Z-1.58, target_X)

	## Apply rotation
	drone.rotation = target_rot
	
	# Optional debug
	if gap:
		print("Telemetry gap detected at t=", time)
