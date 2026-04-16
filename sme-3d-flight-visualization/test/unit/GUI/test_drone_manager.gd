extends GutTest

const DRONE_MANAGER_SCRIPT = preload("res://scripts/Managers/drone_manager.gd")
const CONTROLS_PATH := "user://controls.cfg"

const TEST_ACTIONS := [
	"switch_camera",
	"move_forward",
	"move_left",
	"move_back",
	"move_right"
]

var manager: Node

var _controls_cfg_existed := false
var _controls_cfg_backup: PackedByteArray = PackedByteArray()
var _action_backup := {}
var _actions_originally_present := {}


class DummyVelocityDrone:
	extends Node3D

	var last_velocity := Vector3.ZERO

	func set_velocity(vel: Vector3) -> void:
		last_velocity = vel


func before_all():
	_backup_controls_cfg()
	_backup_actions()
	_ensure_test_actions_exist()


func after_all():
	_restore_controls_cfg()
	_restore_actions()


func before_each():
	_restore_controls_cfg()
	_restore_actions()
	_ensure_test_actions_exist()
	manager = DRONE_MANAGER_SCRIPT.new()


func after_each():
	if is_instance_valid(manager):
		manager.free()


func test_setup_default_controls_sets_expected_keys():
	manager._setup_default_controls()

	assert_eq(_get_first_keycode("switch_camera"), KEY_C)
	assert_eq(_get_first_keycode("move_forward"), KEY_W)
	assert_eq(_get_first_keycode("move_left"), KEY_A)
	assert_eq(_get_first_keycode("move_back"), KEY_S)
	assert_eq(_get_first_keycode("move_right"), KEY_D)


func test_load_saved_bindings_overrides_defaults():
	manager._setup_default_controls()

	var cfg := ConfigFile.new()
	cfg.set_value("bindings", "switch_camera", KEY_Z)
	cfg.set_value("bindings", "move_forward", KEY_UP)
	cfg.set_value("bindings", "move_left", KEY_LEFT)
	assert_eq(cfg.save(CONTROLS_PATH), OK)

	manager._load_saved_bindings()

	assert_eq(_get_first_keycode("switch_camera"), KEY_Z)
	assert_eq(_get_first_keycode("move_forward"), KEY_UP)
	assert_eq(_get_first_keycode("move_left"), KEY_LEFT)
	assert_eq(_get_first_keycode("move_back"), KEY_S)
	assert_eq(_get_first_keycode("move_right"), KEY_D)


func test_save_bindings_writes_current_keys_to_controls_cfg():
	_set_single_key("switch_camera", KEY_B)
	_set_single_key("move_forward", KEY_I)
	_set_single_key("move_left", KEY_J)
	_set_single_key("move_back", KEY_K)
	_set_single_key("move_right", KEY_L)

	manager.save_bindings()

	var cfg := ConfigFile.new()
	assert_eq(cfg.load(CONTROLS_PATH), OK)
	assert_eq(cfg.get_value("bindings", "switch_camera"), KEY_B)
	assert_eq(cfg.get_value("bindings", "move_forward"), KEY_I)
	assert_eq(cfg.get_value("bindings", "move_left"), KEY_J)
	assert_eq(cfg.get_value("bindings", "move_back"), KEY_K)
	assert_eq(cfg.get_value("bindings", "move_right"), KEY_L)


func test_set_drone_position_and_rotation_updates_current_drone():
	var parent := Node3D.new()
	get_tree().root.add_child(parent)

	var drone := Node3D.new()
	parent.add_child(drone)
	manager.current_drone = drone

	var target_position := Vector3(1, 2, 3)
	var target_rotation := Vector3(0.1, 0.2, 0.3)

	manager.set_drone_position(target_position)
	manager.set_drone_rotation(target_rotation)

	assert_eq(drone.global_position, target_position)
	assert_almost_eq(drone.global_rotation.x, target_rotation.x, 0.0001)
	assert_almost_eq(drone.global_rotation.y, target_rotation.y, 0.0001)
	assert_almost_eq(drone.global_rotation.z, target_rotation.z, 0.0001)

	parent.queue_free()


func test_set_drone_velocity_calls_set_velocity_when_supported():
	var drone := DummyVelocityDrone.new()
	manager.current_drone = drone

	manager.set_drone_velocity(Vector3(7, 8, 9))

	assert_eq(drone.last_velocity, Vector3(7, 8, 9))
	drone.free()

func _backup_controls_cfg() -> void:
	_controls_cfg_existed = FileAccess.file_exists(CONTROLS_PATH)
	_controls_cfg_backup = PackedByteArray()

	if _controls_cfg_existed:
		var file := FileAccess.open(CONTROLS_PATH, FileAccess.READ)
		if file != null:
			_controls_cfg_backup = file.get_buffer(file.get_length())


func _restore_controls_cfg() -> void:
	if _controls_cfg_existed:
		var file := FileAccess.open(CONTROLS_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_controls_cfg_backup)
	else:
		if FileAccess.file_exists(CONTROLS_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(CONTROLS_PATH))


func _backup_actions() -> void:
	_action_backup.clear()
	_actions_originally_present.clear()

	for action in TEST_ACTIONS:
		var existed := InputMap.has_action(action)
		_actions_originally_present[action] = existed
		_action_backup[action] = []

		if existed:
			for ev in InputMap.action_get_events(action):
				_action_backup[action].append(ev.duplicate(true))


func _restore_actions() -> void:
	for action in TEST_ACTIONS:
		var existed_before: bool = _actions_originally_present.get(action, false)

		if not existed_before:
			if InputMap.has_action(action):
				InputMap.erase_action(action)
			continue

		if not InputMap.has_action(action):
			InputMap.add_action(action)

		InputMap.action_erase_events(action)

		for ev in _action_backup.get(action, []):
			InputMap.action_add_event(action, ev.duplicate(true))


func _ensure_test_actions_exist() -> void:
	for action in TEST_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)


func _get_first_keycode(action: String) -> int:
	var events := InputMap.action_get_events(action)
	for ev in events:
		if ev is InputEventKey:
			return ev.physical_keycode
	return -1


func _set_single_key(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	InputMap.action_erase_events(action)

	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)
