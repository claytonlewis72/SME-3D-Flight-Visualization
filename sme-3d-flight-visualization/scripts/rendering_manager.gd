extends Node3D

@export var drone_path: NodePath = NodePath("Drone")
@export var model_offset: Vector3 = Vector3(0, PI, 0)

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
	var target_X = rad_to_deg(rot.x)
	# Rotation value is going the opposite direction so we reverse it's value
	var target_Y = rad_to_deg(rot.y*-1)
	var target_Z = rad_to_deg(rot.z)
	# Fix starting rotation value to line up with drawn line
	var target_rot = Vector3(target_X, target_Y-1.58, target_Z)

	## Scale only pitch + roll for visibility
	#target_rot.x *= pitch_scale
	#target_rot.z *= roll_scale

	## Ignore tiny noise (helps jitter)
	#if abs(target_rot.x) < 0.001:
		#target_rot.x = 0
	#if abs(target_rot.z) < 0.001:
		#target_rot.z = 0

	## Convert to quaternion
	#var target_basis: Basis = Basis.from_euler(target_rot)
	#var target_quat: Quaternion = target_basis.get_rotation_quaternion()
#
	#var current_quat: Quaternion = drone.transform.basis.get_rotation_quaternion()
#
	## Smooth rotation
	#var smoothed_quat: Quaternion = current_quat.slerp(target_quat, rotation_smoothness * get_process_delta_time())

	# Old Apply rotation
	#drone.transform.basis = Basis(smoothed_quat)	

	## Apply rotation
	drone.rotation = target_rot
 
	# Optional debug
	if gap:
		print("Telemetry gap detected at t=", time)
