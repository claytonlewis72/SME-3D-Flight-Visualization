extends GutTest

const SETTING_MENU_SCRIPT = preload("res://scripts/GUI/setting_menu.gd")

var root_test_node: Node
var main: Node3D
var setting_menu: Control

var run_button: Button
var stop_button: Button
var telemetry_dropdown: OptionButton
var config_button: Button
var config_window: MockConfigWindow
var telemetry_panel_position: Label
var telemetry_panel_rotation: Label
var drone_visual_root: RigidBody3D
var drone_body: RigidBody3D


class MockConfigWindow:
	extends Control
	var load_settings_called := false
	var open_config_window_called := false

	func load_settings():
		load_settings_called = true

	func open_config_window():
		open_config_window_called = true


func before_each():
	_build_tree()
	await get_tree().process_frame


func after_each():
	if is_instance_valid(root_test_node):
		root_test_node.queue_free()
	if is_instance_valid(main):
		main.queue_free()
	await get_tree().process_frame


func _build_tree():
	root_test_node = Node.new()
	root_test_node.name = "TestRoot"
	get_tree().root.add_child(root_test_node)

	main = Node3D.new()
	main.name = "Main"
	get_tree().root.add_child(main)

	# /root/Main/Rendering Manager/Drone/Pivot/VisualRoot
	var rendering_manager := Node3D.new()
	rendering_manager.name = "Rendering Manager"
	main.add_child(rendering_manager)

	var drone := Node3D.new()
	drone.name = "Drone"
	rendering_manager.add_child(drone)

	var pivot := Node3D.new()
	pivot.name = "Pivot"
	drone.add_child(pivot)

	# IMPORTANT:
	# VisualRoot must support freeze/linear_velocity/angular_velocity
	# because the real script writes those directly to "drone".
	drone_visual_root = RigidBody3D.new()
	drone_visual_root.name = "VisualRoot"
	pivot.add_child(drone_visual_root)

	# The script also does:
	# var body := drone.get_child(0)
	# if body and body is RigidBody3D:
	#
	# so VisualRoot needs a RigidBody3D child too.
	drone_body = RigidBody3D.new()
	drone_body.name = "DroneBody"
	drone_visual_root.add_child(drone_body)

	# ../TelemetryPanel/MarginContainer/VBoxContainer/TelemetryGrid/PositionValue
	var telemetry_panel := Control.new()
	telemetry_panel.name = "TelemetryPanel"
	root_test_node.add_child(telemetry_panel)

	var margin_container := MarginContainer.new()
	margin_container.name = "MarginContainer"
	telemetry_panel.add_child(margin_container)

	var telemetry_vbox := VBoxContainer.new()
	telemetry_vbox.name = "VBoxContainer"
	margin_container.add_child(telemetry_vbox)

	var telemetry_grid := GridContainer.new()
	telemetry_grid.name = "TelemetryGrid"
	telemetry_vbox.add_child(telemetry_grid)

	telemetry_panel_position = Label.new()
	telemetry_panel_position.name = "PositionValue"
	telemetry_panel_position.text = "old position"
	telemetry_grid.add_child(telemetry_panel_position)

	telemetry_panel_rotation = Label.new()
	telemetry_panel_rotation.name = "RotationValue"
	telemetry_panel_rotation.text = "old rotation"
	telemetry_grid.add_child(telemetry_panel_rotation)

	# Build SettingMenu completely before attaching script / adding to tree
	setting_menu = Control.new()
	setting_menu.name = "SettingMenu"

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	setting_menu.add_child(vbox)

	var telemetry_source := Control.new()
	telemetry_source.name = "TelemetrySource"
	vbox.add_child(telemetry_source)

	var panel_container := PanelContainer.new()
	panel_container.name = "PanelContainer"
	telemetry_source.add_child(panel_container)

	var source_vbox := VBoxContainer.new()
	source_vbox.name = "VBoxContainer"
	panel_container.add_child(source_vbox)

	run_button = Button.new()
	run_button.name = "Start"
	run_button.text = "Start"
	source_vbox.add_child(run_button)

	stop_button = Button.new()
	stop_button.name = "Stop"
	stop_button.text = "Stop"
	source_vbox.add_child(stop_button)

	var hbox := HBoxContainer.new()
	hbox.name = "HBoxContainer"
	source_vbox.add_child(hbox)

	telemetry_dropdown = OptionButton.new()
	telemetry_dropdown.name = "OptionButton"
	telemetry_dropdown.add_item("UDP")
	hbox.add_child(telemetry_dropdown)

	config_window = MockConfigWindow.new()
	config_window.name = "ConfigWindow"
	vbox.add_child(config_window)

	config_button = Button.new()
	config_button.name = "ConfigButton"
	vbox.add_child(config_button)

	# Important: attach script after children exist
	setting_menu.set_script(SETTING_MENU_SCRIPT)

	# Important: only now add to tree
	root_test_node.add_child(setting_menu)


func test_ready_connects_buttons_and_adds_playback_once():
	assert_eq(telemetry_dropdown.item_count, 2)
	assert_eq(telemetry_dropdown.get_item_text(0), "UDP")
	assert_eq(telemetry_dropdown.get_item_text(1), "Playback")


func test_config_button_calls_config_window_methods():
	config_button.pressed.emit()

	assert_true(config_window.load_settings_called)
	assert_true(config_window.open_config_window_called)

func test_cleanup_sender_does_nothing_when_no_sender_running():
	setting_menu.sender_pid = -1
	setting_menu._cleanup_sender()
	assert_eq(setting_menu.sender_pid, -1)
