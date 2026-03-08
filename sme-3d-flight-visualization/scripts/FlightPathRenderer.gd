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
#|   File Name   : FlightPathRenderer.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Flight path renderer that renders a vehicle trajectory using telemetry
#|       position updates received from the ingestion layer via signal.
#|
#|   Notes       :
#|       This component has not been formally unit tested.
#|
#|   POC         :
#|       Aramis Hernandez
#|
#|------------------------------------------------------------------------------------

extends Node3D

## Renders a dynamic 3D flight path using telemetry pose data.
##
## This node receives position and rotation updates from the ingestion layer
## (typically via a `pose_received` signal) and renders the path as a continuous
## line strip using an `ArrayMesh`.
##
## Each vertex is colored based on vehicle orientation:
##
## - **Red**   → Roll
## - **Green** → Yaw
## - **Blue**  → Pitch
##
## This allows both trajectory and orientation changes to be visualized
## simultaneously along the rendered path.


## Maximum number of vertices retained for the flight path.
##
## When the buffer exceeds this limit, the oldest points are removed.
@export var max_points: int = 2000 


## Minimum spatial distance required between consecutive points.
##
## Prevents excessive vertex density when telemetry updates occur at
## high frequency.
@export var min_distance = 0.2

## Default line color used when orientation-based coloring is not applied. 
@export var line_color: Color = Color(0, 1, 0) 

## Buffer storing vertex positions used to construct the flight path mesh.
var positions: PackedVector3Array = PackedVector3Array() 

## Buffer storing vertex colors corresponding to each path position.
var colors: PackedColorArray = PackedColorArray() 

## Stores the most recently accepted position used for distance filtering.
var last_position: Vector3 

## Indicates whether the mesh needs to be rebuilt during the next physics frame.
var dirty := false 

## Reference to the MeshInstance3D used to render the generated mesh.
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

## Internal ArrayMesh used for dynamic flight path rendering.
var mesh: ArrayMesh 



## Initializes the mesh renderer and configures rendering materials.
##
## An unshaded material is used to ensure consistent color representation
## and reduce GPU overhead on embedded systems (e.g., NVIDIA Jetson).
func _ready():
	mesh = ArrayMesh.new()
	mesh_instance.mesh = mesh
	
	# UnShaded material to improve performance and consistent colors
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	#enable vertex color usage
	material.vertex_color_use_as_albedo = true
	
	mesh_instance.material_override = material



## Adds a new telemetry point to the rendered flight path.
##
## This method is typically connected to a signal from the telemetry
## ingestion system.
##
## Parameters:
## - `new_pos`: Vehicle position in world coordinates.
## - `rot`: Rotation vector containing Euler angles (roll, pitch, yaw).
## - `is_gap`: Indicates a telemetry discontinuity. When true, the vertex
##   is rendered in red to highlight a data gap.
func add_point(new_pos: Vector3, rot: Vector3, is_gap: bool) -> void:
	
	#Enforce minimum spacing between points.
	if positions.size() > 0:
		if new_pos.distance_to(last_position) < min_distance:
			return 
	positions.append(new_pos)
	
	#Orentation color mapping 
	# roll -> red
	# pitch -> green
	# yaw -> blue
	var r := _angle_to_color_value(rot.x) # roll
	var g := _angle_to_color_value(rot.z) # yaw
	var b := _angle_to_color_value(rot.y) # pitch
	line_color = Color(r, g, b)
	
	var c = line_color
	
	#Mark telemetry gaps visually
	if is_gap:
		c = Color(1, 0, 0) 
		
	colors.append(c)
	last_position = new_pos
	
	# Maintain bounded memory usage
	if positions.size() > max_points:
		# NOTE: 
		# This operation shifts the entire array and may be expensive
		# for very large paths.
		positions.remove_at(0) 
		colors.remove_at(0)
	
	dirty = true	

## Physics update loop responsible for rebuilding the mesh when needed.
func _physics_process(delta):
	if dirty:
		_rebuild_mesh()
		dirty = false

## Rebuilds the mesh from the current position and color buffers.
##
## The mesh is rendered as a `PRIMITIVE_LINE_STRIP`, connecting each
## vertex sequentially to form a continuous trajectory path.s
func _rebuild_mesh():
	if positions.size() < 2:
		return
	
	mesh.clear_surfaces()
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_COLOR] = colors
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)

## Converts an angular value in radians into a normalized value
## suitable for use as a color component.
##
## Input range:
## -PI .. PI
##
## Output range:
## 0.0 .. 1.0
##
## Parameter:
## - `angle`: Angle in radians.
##
## Returns:
## Normalized float value suitable for RGB color channels.
func _angle_to_color_value(angle: float) -> float:
	# Convert from -PI..PI → 0..1
	return clamp((angle + PI) / (2.0 * PI), 0.0, 1.0)
