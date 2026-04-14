extends GutTest

const KEYBIND_BUTTON_SCRIPT = preload("res://scripts/GUI/keybind_button.gd")
const CONTROLS_PATH := "user://controls.cfg"
const TEST_ACTION := "switch_camera"

var button: Button

var _controls_cfg_existed := false
var _controls_cfg_backup: PackedByteArray = PackedByteArray()
var _action_existed := false
var _action_backup := []


func before_all():
	_backup_controls_cfg()
	_backup_action()


func after_all():
	_restore_controls_cfg()
	_restore_action()


func before_each():
	_restore_controls_cfg()
	_restore_action()
	_ensure_action_exists()

	button = Button.new()
	button.name = TEST_ACTION
	button.set_script(KEYBIND_BUTTON_SCRIPT)
	get_tree().root.add_child(button)
	await get_tree().process_frame


func after_each():
	if is_instance_valid(button):
		button.queue_free()
	await get_tree().process_frame


func test_ready_sets_action_name_from_node_name():
	assert_eq(button.action_name, TEST_ACTION)


func test_pressed_enters_waiting_state_and_updates_text():
	button.text = "Old"
	button._pressed()

	assert_true(button.waiting)
	assert_eq(button.text, "Press a key...")


func test_unhandled_input_records_pending_key_and_refreshes_label():
	button._pressed()

	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_K

	button._unhandled_input(ev)

	assert_false(button.waiting)
	assert_eq(button.pending_keycode, KEY_K)
	assert_eq(button.text, "K")


func test_refresh_label_uses_pending_key_when_present():
	button.pending_keycode = KEY_P

	button.refresh_label()

	assert_eq(button.text, "P")


func test_refresh_label_uses_inputmap_binding_when_no_pending_key():
	_set_single_key(TEST_ACTION, KEY_C)
	button.pending_keycode = -1

	button.refresh_label()

	assert_eq(button.text, "C")


func test_refresh_label_shows_unbound_when_action_has_no_key():
	InputMap.action_erase_events(TEST_ACTION)
	button.pending_keycode = -1

	button.refresh_label()

	assert_eq(button.text, "Unbound")


func test_apply_pending_key_updates_inputmap():
	button.pending_keycode = KEY_Z

	button.apply_pending_key()

	assert_eq(_get_first_keycode(TEST_ACTION), KEY_Z)


func test_clear_pending_key_resets_pending_and_refreshes_label():
	_set_single_key(TEST_ACTION, KEY_C)
	button.pending_keycode = KEY_X

	button.clear_pending_key()

	assert_eq(button.pending_keycode, -1)
	assert_eq(button.text, "C")


func test_enable_listening_toggles_unhandled_input_processing():
	button.enable_listening(true)
	assert_true(button.is_processing_unhandled_input())

	button.enable_listening(false)
	assert_false(button.is_processing_unhandled_input())


func test_save_binding_writes_to_controls_cfg():
	button._save_binding(TEST_ACTION, KEY_V)

	var cfg := ConfigFile.new()
	assert_eq(cfg.load(CONTROLS_PATH), OK)
	assert_eq(cfg.get_value("bindings", TEST_ACTION), KEY_V)


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


func _backup_action() -> void:
	_action_existed = InputMap.has_action(TEST_ACTION)
	_action_backup.clear()

	if _action_existed:
		for ev in InputMap.action_get_events(TEST_ACTION):
			_action_backup.append(ev.duplicate(true))


func _restore_action() -> void:
	if not _action_existed:
		if InputMap.has_action(TEST_ACTION):
			InputMap.erase_action(TEST_ACTION)
		return

	if not InputMap.has_action(TEST_ACTION):
		InputMap.add_action(TEST_ACTION)

	InputMap.action_erase_events(TEST_ACTION)

	for ev in _action_backup:
		InputMap.action_add_event(TEST_ACTION, ev.duplicate(true))


func _ensure_action_exists() -> void:
	if not InputMap.has_action(TEST_ACTION):
		InputMap.add_action(TEST_ACTION)


func _set_single_key(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	InputMap.action_erase_events(action)

	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


func _get_first_keycode(action: String) -> int:
	var events := InputMap.action_get_events(action)
	for ev in events:
		if ev is InputEventKey:
			return ev.physical_keycode
	return -1
