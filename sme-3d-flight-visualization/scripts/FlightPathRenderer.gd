extends Node3D

@export var max_points: int = 2000 # cap for memory/performance
@export var min_distance = 0.2
@export var line_color: Color = Color(0, 1, 0)

var positions: PackedVector3Array = PackedVector3Array()
var colors: PackedColorArray = PackedColorArray()

var last_position: Vector3
var dirty := false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
var mesh: ArrayMesh


# Called when the node enters the scene tree for the first time.
func _ready():
	mesh = ArrayMesh.new()
	mesh_instance.mesh = mesh
	
	# UnShader material (important for Jetson)
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	#enable vertex color usage
	material.vertex_color_use_as_albedo = true
	
	mesh_instance.material_override = material

#Note for signals need my signal to match pose_recieved
func add_point(new_pos: Vector3, rot: Vector3, is_gap: bool) -> void:
	if positions.size() > 0:
		if new_pos.distance_to(last_position) < min_distance:
			return 
	positions.append(new_pos)
	
	
	var c = line_color
	if is_gap:
		c = Color(1, 0, 0) #Red for gaps
	
	colors.append(c)
	last_position = new_pos
	
	if positions.size() > max_points:
		positions.remove_at(0) # This may be changed. It's expensive, it shifts the whole array every time.
		colors.remove_at(0)
	
	dirty = true	


func _physics_process(delta):
	if dirty:
		_rebuild_mesh()
		dirty = false

func _rebuild_mesh():
	if positions.size() < 2:
		return
	
	mesh.clear_surfaces()
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_COLOR] = colors
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
