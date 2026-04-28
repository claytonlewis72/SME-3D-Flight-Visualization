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
#|   File Name   : drone_manager.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Manages runtime drone model swapping, transform state, and player
#|       input bindings. Loads the default drone model on startup, supports
#|       hot-swapping vehicle scenes into a shared VisualRoot, and persists
#|       custom key bindings to a user config file across sessions.
#|
#|
#|------------------------------------------------------------------------------------

extends Node

## Manages runtime drone model swapping, transform state, and player input bindings.
##
## On ready this node loads the default drone model into the shared
## [code]VisualRoot[/code] node and applies any saved key bindings from
## [code]user://controls.cfg[/code]. Drone models are loaded as packed scenes
## from [code]res://vehicles/[/code] and instantiated as children of
## [code]VisualRoot[/code]. Only one model is active at a time; swapping
## removes all existing children before adding the new instance.


## The currently instantiated drone [Node].
##
## [code]null[/code] when no model has been loaded or after a swap clears
## the previous instance before the new one is added.
var current_drone: Node = null

## Filename (without extension) of the drone scene loaded on startup.
##
## Must correspond to a [code].tscn[/code] file inside [code]res://vehicles/[/code].
var default_drone_model: String = "drone_3"


## Initializes default input bindings, loads saved bindings, and defers
## loading the default drone model until the scene tree is ready.
##
## The drone load is deferred via [method call_deferred] because
## [code]VisualRoot[/code] may not yet exist in the tree at the time
## [code]_ready[/code] executes.
func _ready():
	_setup_default_controls()
	_load_saved_bindings()
	call_deferred("_load_default_drone_after_scene_ready")


## Loads the default drone model once the scene tree is fully ready.
##
## Called via [method call_deferred] from [method _ready].
func _load_default_drone_after_scene_ready():
	set_drone_model(default_drone_model)


## Reloads the current scene and restores the default drone model afterward.
##
## The restore step is deferred because [code]VisualRoot[/code] does not
## exist immediately after [method SceneTree.reload_current_scene] returns.
## See [method _restore_default_drone_after_reload] for the retry logic.
func reload_scene_and_restore_default_drone() -> void:
	get_tree().reload_current_scene()
	call_deferred("_restore_default_drone_after_reload")


## Polls for [code]VisualRoot[/code] after a scene reload and restores the default drone.
##
## Waits up to 30 frames for [code]Main/Rendering Manager/Drone/Pivot/VisualRoot[/code]
## to appear in the tree before calling [method set_drone_model] and
## [method _reset_current_drone_transform]. Pushes a warning and returns
## early if the node is still absent after all attempts are exhausted.
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


## Swaps the active drone model by loading a packed scene and adding it to [code]VisualRoot[/code].
##
## Strips whitespace from [param model_name] and constructs the scene path as
## [code]res://vehicles/<model_name>.tscn[/code]. All existing children of
## [code]VisualRoot[/code] are freed before the new instance is added.
## Pushes a warning and returns early if the scene file cannot be loaded or
## if [code]VisualRoot[/code] is not present in the tree.
##
## Parameters:
##   model_name : String
##       Filename of the vehicle scene, without the [code].tscn[/code] extension.

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


## Resets the current drone's world transform and velocity to zero.
##
## Sets [member Node3D.global_position] and [member Node3D.global_rotation]
## to [constant Vector3.ZERO] if [member current_drone] is a [Node3D].
## Velocity is cleared by calling [code]set_velocity[/code] if the drone
## exposes that method, or by writing directly to a [code]velocity[/code]
## property if one is declared on the drone's script.
## Has no effect if [member current_drone] is [code]null[/code].
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


## Moves the current drone to the specified world position.
##
## Has no effect if [member current_drone] is [code]null[/code].
##
## Parameters:
##   pos : Vector3
##       Target world position applied to [member Node3D.global_position].
func set_drone_position(pos: Vector3) -> void:
	if current_drone:
		current_drone.global_position = pos


## Sets the current drone's world rotation.
##
## Has no effect if [member current_drone] is [code]null[/code].
##
## Parameters:
##   rot : Vector3
##       Target rotation in radians applied to [member Node3D.global_rotation].
func set_drone_rotation(rot: Vector3) -> void:
	if current_drone:
		current_drone.global_rotation = rot


## Forwards a velocity vector to the current drone if it supports it.
##
## Calls [code]set_velocity[/code] on [member current_drone] if the method
## exists. Has no effect if [member current_drone] is [code]null[/code] or
## does not expose [code]set_velocity[/code].
##
## Parameters:
##   vel : Vector3
##       Velocity to apply, in world units per second.
func set_drone_velocity(vel: Vector3) -> void:
	if current_drone and current_drone.has_method("set_velocity"):
		current_drone.set_velocity(vel)


## Registers the default keyboard bindings for all player input actions.
##
## Actions are written directly into [InputMap] and will be overwritten by
## any saved bindings loaded afterward in [method _load_saved_bindings].
func _setup_default_controls():
	_set_action_key("switch_camera", KEY_C)
	_set_action_key("move_forward", KEY_W)
	_set_action_key("move_left", KEY_A)
	_set_action_key("move_back", KEY_S)
	_set_action_key("move_right", KEY_D)


## Replaces all events on an [InputMap] action with a single key event.
##
## Clears any existing events bound to [param action] before adding a new
## [InputEventKey] with the given [param keycode] as its physical keycode.
##
## Parameters:
##   action  : String
##       The [InputMap] action name to rebind.
##   keycode : int
##       A [code]KEY_*[/code] constant identifying the replacement key.
func _set_action_key(action: String, keycode: int):
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


## Loads key bindings from [code]user://controls.cfg[/code] and applies them to [InputMap].
##
## Reads the [code][bindings][/code] section of the config file. Each key is
## an action name and each value is an integer [code]KEY_*[/code] keycode.
## Actions not present in [InputMap] are silently skipped. Returns early
## without modifying any bindings if the file does not exist or cannot be parsed.
func _load_saved_bindings():
	var cfg := ConfigFile.new()
	if cfg.load("user://controls.cfg") != OK:
		return

	for action in cfg.get_section_keys("bindings"):
		if not InputMap.has_action(action):
			continue

		var keycode = int(cfg.get_value("bindings", action))
		_set_action_key(action, keycode)


## Saves the current [InputMap] key bindings to [code]user://controls.cfg[/code].
##
## Iterates all actions in [InputMap], skipping any whose names begin with
## [code]ui_[/code] (built-in engine actions). For each remaining action,
## the physical keycode of the first [InputEventKey] event is written to the
## [code][bindings][/code] section. Actions with no key events are skipped.
func save_bindings():
	var cfg := ConfigFile.new()

	for action in InputMap.get_actions():
		if action.begins_with("ui_"):
			continue

		var events = InputMap.action_get_events(action)
		if events.size() > 0 and events[0] is InputEventKey:
			cfg.set_value("bindings", action, events[0].physical_keycode)

	cfg.save("user://controls.cfg")
