extends Node

var current_drone: Node = null

func _ready():
	_setup_default_controls()
	_load_saved_bindings()
	set_drone_model("drone_3")
	# Do NOT load a drone here — wait for UI to request it


func set_drone_model(model_name: String):
	model_name = model_name.strip_edges()

	var path = "res://vehicles/%s.tscn" % model_name
	var scene := load(path)
	
	if scene == null:
		push_error("Could not load model: " + path)
		return

	# Get VisualRoot safely
	var visual_root = get_tree().get_root().get_node_or_null("Main/Rendering Manager/Drone/Pivot/VisualRoot")
	if visual_root == null:
		push_error("Could not find VisualRoot")
		return
		
	# Remove old drone
	for child in visual_root.get_children():
		child.queue_free()

	# Spawn new drone
	current_drone = scene.instantiate()
	visual_root.add_child(current_drone)


func set_drone_position(pos: Vector3) -> void:
	if current_drone:
		current_drone.global_position = pos


func set_drone_rotation(rot: Vector3) -> void:
	if current_drone:
		current_drone.global_rotation = rot


func set_drone_velocity(vel: Vector3) -> void:
	if current_drone and current_drone.has_method("set_velocity"):
		current_drone.set_velocity(vel)


func _setup_default_controls():
	_set_action_key("switch_camera", KEY_C)
	_set_action_key("swap_vehicle", KEY_V)
	_set_action_key("record", KEY_R)
	_set_action_key("pause", KEY_SPACE)
	_set_action_key("start_playback", KEY_P)


func _set_action_key(action: String, keycode: int):
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)

func _load_saved_bindings():
	var cfg := ConfigFile.new()
	if cfg.load("user://controls.cfg") != OK:
		return

	for action in cfg.get_section_keys("bindings"):
		var keycode = cfg.get_value("bindings", action)
		_set_action_key(action, keycode)
		
func save_bindings():
	var cfg := ConfigFile.new()

	# Rebuild bindings section from scratch
	for action in InputMap.get_actions():
		# Skip Godot UI actions
		if action.begins_with("ui_"):
			continue

		var events = InputMap.action_get_events(action)
		if events.size() > 0 and events[0] is InputEventKey:
			cfg.set_value("bindings", action, events[0].physical_keycode)

	cfg.save("user://controls.cfg")
