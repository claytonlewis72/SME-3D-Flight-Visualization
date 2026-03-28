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

	# Apply position
	drone.global_position = pos

	# --- ROTATION PIPELINE ---

	# Copy incoming rotation
	var target_rot: Vector3 = rot

	# Scale only pitch + roll for visibility
	target_rot.x *= pitch_scale
	target_rot.z *= roll_scale

	# Ignore tiny noise (helps jitter)
	if abs(target_rot.x) < 0.001:
		target_rot.x = 0
	if abs(target_rot.z) < 0.001:
		target_rot.z = 0

	# Convert to quaternion
	var target_basis: Basis = Basis.from_euler(target_rot)
	var target_quat: Quaternion = target_basis.get_rotation_quaternion()

	var current_quat: Quaternion = drone.transform.basis.get_rotation_quaternion()

	# Smooth rotation
	var smoothed_quat: Quaternion = current_quat.slerp(target_quat, rotation_smoothness * get_process_delta_time())

	# Apply rotation
	drone.transform.basis = Basis(smoothed_quat)

	# Optional debug
	if gap:
		print("Telemetry gap detected at t=", time)
