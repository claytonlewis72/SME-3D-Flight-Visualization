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

	drone.global_position = pos

	var target_rot: Vector3 = rot

	# Only lightly scale pitch, more on roll
	target_rot.x *= pitch_scale
	target_rot.z *= roll_scale

	# Ignore tiny noise
	if abs(target_rot.x) < 0.0005:
		target_rot.x = 0.0
	if abs(target_rot.z) < 0.0005:
		target_rot.z = 0.0

	var target_basis: Basis = Basis.from_euler(target_rot)
	var target_quat: Quaternion = target_basis.get_rotation_quaternion()
	var current_quat: Quaternion = drone.transform.basis.get_rotation_quaternion()

	var t: float = clamp(rotation_smoothness * get_process_delta_time(), 0.0, 1.0)
	var smoothed_quat: Quaternion = current_quat.slerp(target_quat, t)

	drone.transform.basis = Basis(smoothed_quat)

	if gap:
		print("Telemetry gap detected at t=", time)
