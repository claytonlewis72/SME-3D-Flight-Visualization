#|------------------------------------------------------------------------------------
#|   Unclassified
#|------------------------------------------------------------------------------------
#|
#|   SME Solutions, Inc.
#|   Copyright 2026 SME Solutions, Inc. All Rights Reserved
#|   SME Solutions Proprietary Information
#|
#|------------------------------------------------------------------------------------
#|
#|   File Name   : drone_visualizer.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Drives a 3D drone node's position and rotation from live telemetry
#|       pose data. Subscribes to TelemetryManager.pose_received and applies
#|       each incoming frame directly to the drone's transform.
#|
#|   Authors     : Carson Wood
#|   Editors     : Clayton Lewis, Evan Visalli
#|
#|------------------------------------------------------------------------------------

extends Node3D

## Drives a 3D drone node's position and rotation from live telemetry pose data.
##
## This node subscribes to the [signal TelemetryManager.pose_received] signal
## and applies each incoming pose frame directly to the drone [Node3D]'s
## [member Node3D.position] and [member Node3D.rotation]. Rotation values are
## converted from radians to degrees, negated to correct axis direction, and
## remapped to match the drone mesh's local coordinate convention.


## Path to the [Node3D] representing the drone in the scene tree.
##
## Must resolve to a valid [Node3D]. If the node cannot be found at this path,
## an error is pushed and pose updates are silently ignored.
@export var drone_path: NodePath = NodePath("Drone")

## Scalar applied to pitch values for visual amplification of subtle telemetry motion.
##
## Does not affect the values written to any recording; used for display only.
@export var pitch_scale: float = 100.0


## Scalar applied to roll values for visual amplification of subtle telemetry motion.
##
## Does not affect the values written to any recording; used for display only.
@export var roll_scale: float = 100.0


## Interpolation speed used to smooth rotation transitions between frames.
##
## Higher values produce snappier motion; lower values produce more gradual blending.
@export var rotation_smoothness: float = 3.0


## Reference to the resolved drone [Node3D].
##
## Populated during [method _ready]. [code]null[/code] if the node at
## [member drone_path] could not be found or is not a [Node3D].
var drone: Node3D = null


## Resolves the drone node and subscribes to pose events.
##
## Looks up the node at [member drone_path] and casts it to [Node3D].
## Pushes an error and returns early if the node is not found. On success,
## connects to [signal TelemetryManager.pose_received] so that
## [method _on_pose_received] is called for every incoming telemetry frame.
func _ready() -> void:
	drone = get_node_or_null(drone_path) as Node3D

	if drone == null:
		push_error("Drone node not found. Expected at: " + str(drone_path))
		return

	print("Found Drone node:", drone.name)

	#Connect to TelemetryManager (global singleton)
	TelemetryManager.pose_received.connect(_on_pose_received)



## Applies a telemetry pose frame to the drone node.
##
## Connected to [signal TelemetryManager.pose_received]. Sets the drone's
## world position directly from [param pos], then constructs a corrected
## rotation by converting each Euler axis from radians to degrees and
## negating to account for the reversed axis convention in the incoming data.
## The axes are then remapped as follows before being applied:
##
## [codeblock]
##   drone.rotation.x  ←  Pitch  (incoming rot.y, negated)
##   drone.rotation.y  ←  Yaw    (incoming rot.z, negated, offset by -1.58)
##   drone.rotation.z  ←  Roll   (incoming rot.x, negated)
## [/codeblock]
##
## The [code]-1.58[/code] yaw offset aligns the drone's heading with the
## rendered flight path line at startup.
##
## Parameters:
##   pos : Vector3
##       Vehicle position in world coordinates. Applied directly to
##       [member Node3D.position].
##   rot : Vector3
##       Vehicle rotation as Euler angles in radians (roll, pitch, yaw)
##       in the telemetry coordinate frame.
##   gap : bool
##       Indicates a telemetry discontinuity. Logged to the console but
##       does not alter the applied transform.
##   time : float
##       Timestamp of this pose frame in seconds. Used only for gap logging.
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
