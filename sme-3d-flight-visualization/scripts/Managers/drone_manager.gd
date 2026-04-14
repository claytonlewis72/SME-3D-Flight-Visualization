extends Node

var current_drone: Node = null
var default_drone_model: String = "drone_3"

func _ready():
	_setup_default_controls()
	_load_saved_bindings()
	call_deferred("_load_default_drone_after_scene_ready")
	
func _load_default_drone_after_scene_ready():
	set_drone_model(default_drone_model)

func reload_scene_and_restore_default_drone() -> void:
	get_tree().reload_current_scene()
	call_deferred("_restore_default_drone_after_reload")

func _restore_default_drone_after_reload() -> void:
	# Wait until the rebuilt scene actually has VisualRoot again
	var visual_root = get_tree().get_root().get_node_or_null("Main/Rendering Manager/Drone/Pivot/VisualRoot")

	var attempts := 0
	while visual_root == null and attempts < 30:
		await get_tree().process_frame
		visual_root = get_tree().get_root().get_node_or_null("Main/Rendering Manager/Drone/Pivot/VisualRoot")
		attempts += 1

	if visual_root == null:
		push_warning("VisualRoot not found after scene reload.")
		return

	set_drone_model(default_drone_model)
	_reset_current_drone_transform()

func set_drone_model(model_name: String):
	model_name = model_name.strip_edges()

	var path = "res://vehicles/%s.tscn" % model_name
	var scene := load(path)

	if scene == null:
		push_warning("Could not load path: " + path)
		return

	var visual_root = get_tree().get_root().get_node_or_null("Main/Rendering Manager/Drone/Pivot/VisualRoot")
	if visual_root == null:
		push_warning("VisualRoot not found: Main/Rendering Manager/Drone/Pivot/VisualRoot")
		return

	for child in visual_root.get_children():
		child.queue_free()

	current_drone = null

	current_drone = scene.instantiate()
	visual_root.add_child(current_drone)

func _reset_current_drone_transform() -> void:
	if current_drone == null:
		return

	if current_drone is Node3D:
		current_drone.global_position = Vector3.ZERO
		current_drone.global_rotation = Vector3.ZERO

	if current_drone.has_method("set_velocity"):
		current_drone.set_velocity(Vector3.ZERO)
	elif current_drone.get_script() and current_drone.get_script().has_property("velocity"):
		current_drone.velocity = Vector3.ZERO


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
	_set_action_key("move_forward", KEY_W)
	_set_action_key("move_left", KEY_A)
	_set_action_key("move_back", KEY_S)
	_set_action_key("move_right", KEY_D)


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
		if not InputMap.has_action(action):
			continue

		var keycode = int(cfg.get_value("bindings", action))
		_set_action_key(action, keycode)


func save_bindings():
	var cfg := ConfigFile.new()

	for action in InputMap.get_actions():
		if action.begins_with("ui_"):
			continue

		var events = InputMap.action_get_events(action)
		if events.size() > 0 and events[0] is InputEventKey:
			cfg.set_value("bindings", action, events[0].physical_keycode)

	cfg.save("user://controls.cfg")
