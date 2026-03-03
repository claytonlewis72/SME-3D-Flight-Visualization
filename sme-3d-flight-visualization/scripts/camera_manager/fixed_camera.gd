#Author: Aramis Hernandez

extends Camera3D

@export var target_path: NodePath
var target: Node3D

# Called when the node enters the scene tree for the first time.
func _ready():
	target = get_node_or_null(target_path)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if target:
		look_at(target.global_transform.origin, Vector3.UP)
