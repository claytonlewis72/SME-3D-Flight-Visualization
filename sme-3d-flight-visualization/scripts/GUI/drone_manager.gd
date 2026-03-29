extends Node

var current_drone: Node = null

func set_drone_model(model_name: String):

	var path = "res://vehicles/%s.tscn" % model_name

	var scene := load(path)
	if scene == null:
		push_error("Could not load model: " + path)
		return

	# Find the VisualRoot in your scene
	var visual_root = get_tree().get_root().get_node("Main/Rendering Manager/Drone/Pivot/VisualRoot")
	
	if visual_root == null:
		push_error("Could not find VisualRoot")
		return

	# Remove old drone model
	for child in visual_root.get_children():
		child.queue_free()

	# Spawn new drone model
	current_drone = scene.instantiate()

	visual_root.add_child(current_drone)
