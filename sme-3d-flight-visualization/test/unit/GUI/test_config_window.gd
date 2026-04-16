extends GutTest

const CONFIG_WINDOW_SCRIPT = preload("res://scripts/GUI/config_window.gd")

var config_window: Window
var root_test_node: Node
var drone_parent: Node3D
var previous_current_drone = null

var vehicle_dropdown: OptionButton
var controls_header: Button
var controls_container: VBoxContainer
var custom_fields_container: VBoxContainer
var config_dialog: MockPopupNode
var vehicle_file_dialog: MockPopupNode

var pos_x: SpinBox
var pos_y: SpinBox
var pos_z: SpinBox
var rot_x: SpinBox
var rot_y: SpinBox
var rot_z: SpinBox
var vel_x: SpinBox
var vel_y: SpinBox
var vel_z: SpinBox


class MockPopupNode:
	extends Control

	signal file_selected(path: String)

	var popup_called := false

	func popup_centered():
		popup_called = true


class MockKeybindButton:
	extends Button

	var listening_enabled := false
	var clear_called := false
	var apply_called := false

	func enable_listening(enable: bool):
		listening_enabled = enable

	func clear_pending_key():
		clear_called = true

	func apply_pending_key():
		apply_called = true


class MockDrone:
	extends Node3D

	var velocity := Vector3.ZERO

	func get_velocity() -> Vector3:
		return velocity

	func set_velocity(v: Vector3) -> void:
		velocity = v


func before_each():
	previous_current_drone = Drone_Manager.current_drone
	_build_tree()
	await get_tree().process_frame


func after_each():
	Drone_Manager.current_drone = previous_current_drone

	if is_instance_valid(root_test_node):
		root_test_node.queue_free()

	if is_instance_valid(drone_parent):
		drone_parent.queue_free()

	await get_tree().process_frame
	await get_tree().process_frame


func _build_tree():
	root_test_node = Node.new()
	root_test_node.name = "TestRoot"
	get_tree().root.add_child(root_test_node)

	# Needed because script has:
	# @onready var csv_ingestion = get_node("/root/Main/IngestionManager")
	var main := Node.new()
	main.name = "Main"
	get_tree().root.add_child(main)

	var ingestion := Node.new()
	ingestion.name = "IngestionManager"
	main.add_child(ingestion)

	config_window = Window.new()
	config_window.name = "ConfigWindow"

	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	config_window.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	margin.add_child(vbox)

	# DroneModel/OptionButton
	var drone_model := VBoxContainer.new()
	drone_model.name = "DroneModel"
	vbox.add_child(drone_model)

	vehicle_dropdown = OptionButton.new()
	vehicle_dropdown.name = "OptionButton"
	drone_model.add_child(vehicle_dropdown)

	# Position
	var position_box := VBoxContainer.new()
	position_box.name = "Position"
	vbox.add_child(position_box)

	pos_x = SpinBox.new()
	pos_x.name = "PosX"
	pos_x.step = 0.1
	position_box.add_child(pos_x)

	pos_y = SpinBox.new()
	pos_y.name = "PosY"
	pos_y.step = 0.1
	position_box.add_child(pos_y)

	pos_z = SpinBox.new()
	pos_z.name = "PosZ"
	pos_z.step = 0.1
	position_box.add_child(pos_z)

	# Rotation
	var rotation_box := VBoxContainer.new()
	rotation_box.name = "Rotation"
	vbox.add_child(rotation_box)

	rot_x = SpinBox.new()
	rot_x.name = "RotX"
	rot_x.step = 0.1
	rotation_box.add_child(rot_x)

	rot_y = SpinBox.new()
	rot_y.name = "RotY"
	rot_y.step = 0.1
	rotation_box.add_child(rot_y)

	rot_z = SpinBox.new()
	rot_z.name = "RotZ"
	rot_z.step = 0.1
	rotation_box.add_child(rot_z)

	# Velocity
	var velocity_box := VBoxContainer.new()
	velocity_box.name = "Velocity"
	vbox.add_child(velocity_box)

	vel_x = SpinBox.new()
	vel_x.name = "VelX"
	vel_x.step = 0.1
	velocity_box.add_child(vel_x)

	vel_y = SpinBox.new()
	vel_y.name = "VelY"
	vel_y.step = 0.1
	velocity_box.add_child(vel_y)

	vel_z = SpinBox.new()
	vel_z.name = "VelZ"
	vel_z.step = 0.1
	velocity_box.add_child(vel_z)

	# ControlsSection
	var controls_section := VBoxContainer.new()
	controls_section.name = "ControlsSection"
	vbox.add_child(controls_section)

	controls_header = Button.new()
	controls_header.name = "ControlsHeader"
	controls_section.add_child(controls_header)

	controls_container = VBoxContainer.new()
	controls_container.name = "ControlsContainer"
	controls_section.add_child(controls_container)

	var keybind_row := HBoxContainer.new()
	controls_container.add_child(keybind_row)

	var mock_keybind := MockKeybindButton.new()
	mock_keybind.name = "switch_camera"
	keybind_row.add_child(mock_keybind)

	# HBoxContainer/LoadConfigButton
	var load_hbox := HBoxContainer.new()
	load_hbox.name = "HBoxContainer"
	vbox.add_child(load_hbox)

	var load_button := Button.new()
	load_button.name = "LoadConfigButton"
	load_hbox.add_child(load_button)

	# CustomConfigSection/CustomFieldsContainer
	var custom_section := VBoxContainer.new()
	custom_section.name = "CustomConfigSection"
	vbox.add_child(custom_section)

	custom_fields_container = VBoxContainer.new()
	custom_fields_container.name = "CustomFieldsContainer"
	custom_section.add_child(custom_fields_container)

	# Dialogs
	config_dialog = MockPopupNode.new()
	config_dialog.name = "ConfigFileDialog"
	vbox.add_child(config_dialog)

	vehicle_file_dialog = MockPopupNode.new()
	vehicle_file_dialog.name = "VehicleFileDialog"
	vbox.add_child(vehicle_file_dialog)

	config_window.set_script(CONFIG_WINDOW_SCRIPT)
	root_test_node.add_child(config_window)


func _make_test_drone(pos := Vector3(1, 2, 3), rot := Vector3(0.1, 0.2, 0.3), vel := Vector3(4, 5, 6)) -> MockDrone:
	drone_parent = Node3D.new()
	drone_parent.name = "DroneParent"
	get_tree().root.add_child(drone_parent)

	var drone := MockDrone.new()
	drone.name = "MockDrone"
	drone_parent.add_child(drone)

	drone.global_position = pos
	drone.global_rotation = rot
	drone.velocity = vel

	Drone_Manager.current_drone = drone
	return drone


func _get_mock_keybind() -> MockKeybindButton:
	var row = controls_container.get_child(0)
	return row.get_child(0) as MockKeybindButton


func test_ready_initializes_controls_and_vehicle_dropdown():
	assert_false(controls_container.visible)
	assert_eq(controls_header.text, "Controls ▸")
	assert_true(vehicle_dropdown.item_count >= 2)
	assert_eq(vehicle_dropdown.get_item_text(vehicle_dropdown.item_count - 1), "Add Vehicle...")


func test_load_settings_reads_current_drone_state():
	_make_test_drone(Vector3(11, 22, 33), Vector3(0.4, 0.5, 0.6), Vector3(7, 8, 9))

	config_window.load_settings()

	assert_almost_eq(pos_x.value, 11.0, 0.0001)
	assert_almost_eq(pos_y.value, 22.0, 0.0001)
	assert_almost_eq(pos_z.value, 33.0, 0.0001)

	assert_almost_eq(rot_x.value, 0.4, 0.0001)
	assert_almost_eq(rot_y.value, 0.5, 0.0001)
	assert_almost_eq(rot_z.value, 0.6, 0.0001)

	assert_eq(vel_x.value, 7)
	assert_eq(vel_y.value, 8)
	assert_eq(vel_z.value, 9)


func test_open_config_window_stores_original_values_and_enables_keybind_listening():
	_make_test_drone(Vector3(3, 4, 5), Vector3(0.2, 0.3, 0.4), Vector3(6, 7, 8))
	var keybind := _get_mock_keybind()

	config_window.open_config_window()

	assert_eq(config_window.original_pos, Vector3(3, 4, 5))
	assert_eq(config_window.original_vel, Vector3(6, 7, 8))
	assert_true(keybind.listening_enabled)


func test_on_close_requested_disables_listening_and_clears_pending_keys():
	var keybind := _get_mock_keybind()
	keybind.listening_enabled = true

	config_window.show()
	config_window._on_close_requested()

	assert_false(keybind.listening_enabled)
	assert_true(keybind.clear_called)
	assert_false(config_window.visible)


func test_vehicle_dropdown_item_selected_sets_pending_model():
	# pick first non-separator, non-"Add Vehicle..." real item
	var target_index := -1
	for i in range(vehicle_dropdown.item_count):
		var text = vehicle_dropdown.get_item_text(i)
		if text != "Add Vehicle..." and text != "":
			target_index = i
			break

	assert_ne(target_index, -1)

	var expected = vehicle_dropdown.get_item_text(target_index)
	config_window._on_vehicle_dropdown_item_selected(target_index)

	assert_eq(config_window.pending_drone_model, expected)


func test_find_option_index_by_text_returns_index_or_minus_one():
	var idx = config_window.find_option_index_by_text(vehicle_dropdown, "Add Vehicle...")
	assert_ne(idx, -1)

	var missing = config_window.find_option_index_by_text(vehicle_dropdown, "does_not_exist")
	assert_eq(missing, -1)


func test_apply_loaded_config_updates_ui_and_pending_model():
	var cfg := {
		"position": [9.0, 8.0, 7.0],
		"rotation": [0.7, 0.8, 0.9],
		"velocity": [1.0, 2.0, 3.0],
		"drone_model": "drone_3",
		"extra_string": "hello"
	}

	config_window.apply_loaded_config(cfg)

	assert_eq(pos_x.value, 9.0)
	assert_eq(pos_y.value, 8.0)
	assert_eq(pos_z.value, 7.0)

	assert_almost_eq(rot_x.value, 0.7, 0.0001)
	assert_almost_eq(rot_y.value, 0.8, 0.0001)
	assert_almost_eq(rot_z.value, 0.9, 0.0001)

	assert_eq(vel_x.value, 1.0)
	assert_eq(vel_y.value, 2.0)
	assert_eq(vel_z.value, 3.0)

	assert_eq(config_window.pending_drone_model, "drone_3")
	assert_eq(config_window.loaded_config["extra_string"], "hello")


func test_rebuild_custom_config_ui_adds_only_custom_fields():
	config_window.loaded_config = {
		"position": [1, 2, 3],
		"rotation": [4, 5, 6],
		"velocity": [7, 8, 9],
		"drone_model": "drone_3",
		"custom_number": 42,
		"custom_flag": true,
		"custom_text": "abc"
	}

	config_window.rebuild_custom_config_ui()

	assert_eq(custom_fields_container.get_child_count(), 3)


func test_update_custom_config_from_ui_reads_editor_values():
	config_window.loaded_config = {
		"custom_number": 1,
		"custom_flag": false,
		"custom_text": "old"
	}

	config_window.rebuild_custom_config_ui()

	for row in custom_fields_container.get_children():
		var editor = row.get_child(1)
		var key = editor.get_meta("config_key")

		if key == "custom_number" and editor is SpinBox:
			editor.value = 12.5
		elif key == "custom_flag" and editor is CheckBox:
			editor.button_pressed = true
		elif key == "custom_text" and editor is LineEdit:
			editor.text = "new value"

	config_window._update_custom_config_from_ui()

	assert_eq(config_window.loaded_config["custom_number"], 12.5)
	assert_eq(config_window.loaded_config["custom_flag"], true)
	assert_eq(config_window.loaded_config["custom_text"], "new value")


func test_build_config_dictionary_returns_deep_copy():
	config_window.loaded_config = {
		"nested": {
			"value": 10
		}
	}

	var built = config_window.build_config_dictionary()
	built["nested"]["value"] = 99

	assert_eq(config_window.loaded_config["nested"]["value"], 10)
	assert_eq(built["nested"]["value"], 99)
