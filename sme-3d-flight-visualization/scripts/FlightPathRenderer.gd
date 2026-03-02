extends Node3D

@export var ingestion_path: NodePath = NodePath("../IngestionManager")
@export var max_points: int = 10000 # cap for memory/performance

var ingestion: Node = null
var positions: Array = []

#Using ImmediateMeshInstance now for simplicity
var line_mesh_instance: MeshInstance3D = null
var line_mesh: ImmediateMesh = null

# Called when the node enters the scene tree for the first time.
func _ready():
	ingestion = get_node_or_null(ingestion_path)
	if ingestion == null:
		push_error("IngestionManager not found at " + str(ingestion_path))
		return
	
	line_mesh = ImmediateMesh.new()
	line_mesh_instance = MeshInstance3D.new()
	line_mesh_instance.mesh = line_mesh
	add_child(line_mesh_instance)
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if ingestion == null:
		return
	
	#Get our latest pose
	var pose = ingestion.get_pose()
	if not pose.has("has_pose") or not pose["has_pose"]:
		return
	
	#Append position to the flight path
	positions.append(pose["pos"])
	if positions.size() > max_points:
		positions.pop_front() # Keep our memory bounded
	
	#Update the mesh
	_update_line_mesh()

func _update_line_mesh() -> void:
	if positions.size() < 2:
		return # At least two points are needed for a line
	
	line_mesh.clear_surfaces()
	
	#Start drawing
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	
	for pos in positions:
		line_mesh.surface_add_vertex(pos)
	
	line_mesh.surface_end()
