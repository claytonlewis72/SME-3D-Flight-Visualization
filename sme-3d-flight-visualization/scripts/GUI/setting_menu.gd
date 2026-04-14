extends Control

#Exports
@export var sender_path: String = "res://SME-tool/sender.py"
@export var python_path: String = "python3" # Path to Python

@onready var run_button: Button = $VBoxContainer/TelemetrySource/PanelContainer/VBoxContainer/Start
@onready var stop_button: Button = $VBoxContainer/TelemetrySource/PanelContainer/VBoxContainer/Stop
@onready var position_value = get_node("../TelemetryPanel/MarginContainer/VBoxContainer/TelemetryGrid/PositionValue")
@onready var rotation_value = get_node("../TelemetryPanel/MarginContainer/VBoxContainer/TelemetryGrid/RotationValue")
@onready var drone = get_node("/root/Main/Rendering Manager/Drone/Pivot/VisualRoot")
@onready var telemetry_dropdown = $VBoxContainer/TelemetrySource/PanelContainer/VBoxContainer/HBoxContainer/OptionButton
@onready var config_window = $VBoxContainer/ConfigWindow
@onready var config_button = $VBoxContainer/ConfigButton

var sender_pid: int = -1
var is_paused := false


func _ready():
	run_button.pressed.connect(_on_run_telemetry_pressed)
	stop_button.pressed.connect(_on_stop_telemetry_pressed)

	if not telemetry_dropdown.item_selected.is_connected(_on_option_button_item_selected):
		telemetry_dropdown.item_selected.connect(_on_option_button_item_selected)

	var found := false
	for i in range(telemetry_dropdown.item_count):
		if telemetry_dropdown.get_item_text(i) == "Playback":
			found = true
			break
	if not found:
		telemetry_dropdown.add_item("Playback")

	config_button.pressed.connect(_on_config_button_pressed)


func _on_run_telemetry_pressed():
	if sender_pid == -1:
		var full_path = ProjectSettings.globalize_path(sender_path)
		var args := PackedStringArray([full_path])

		sender_pid = OS.create_process(python_path, args)

		if sender_pid == -1:
			push_error("Failed to start sender")
		else:
			print("Started sender with PID:", sender_pid)
			run_button.text = "Stop"
			is_paused = false
		return

	if not is_paused:
		print("Pausing sender...")
		OS.kill(sender_pid)
		is_paused = true
		run_button.text = "Start"
		return

	if is_paused:
		print("Resuming sender...")
		var full_path = ProjectSettings.globalize_path(sender_path)
		var args := PackedStringArray([full_path])

		sender_pid = OS.create_process(python_path, args)
		is_paused = false
		run_button.text = "Stop"
		return


func _on_stop_telemetry_pressed():
	if sender_pid != -1:
		OS.kill(sender_pid)
		sender_pid = -1

	if has_node("/root/SourceManager"):
		var source_manager = get_node("/root/SourceManager")
		if source_manager.has_method("stop"):
			source_manager.stop()

	# Ask Drone_Manager to restore the default drone after the scene reloads
	if has_node("/root/Drone_Manager"):
		var drone_manager = get_node("/root/Drone_Manager")
		if drone_manager.has_method("reload_scene_and_restore_default_drone"):
			drone_manager.reload_scene_and_restore_default_drone()
			return

	# Fallback
	get_tree().reload_current_scene()

func _reset_drone_state():
	if drone == null:
		print("[SettingMenu] Drone root not found!")
		return

	if drone is RigidBody3D:
		drone.freeze = true
		drone.linear_velocity = Vector3.ZERO
		drone.angular_velocity = Vector3.ZERO
		drone.global_position = Vector3.ZERO
		drone.global_rotation = Vector3.ZERO
		drone.freeze = false
		return

	var body = null
	if drone.get_child_count() > 0:
		body = drone.get_child(0)

	if body and body is RigidBody3D:
		body.freeze = true
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.global_position = Vector3.ZERO
		body.global_rotation = Vector3.ZERO
		body.freeze = false
		return

	if drone is Node3D:
		drone.global_position = Vector3.ZERO
		drone.global_rotation = Vector3.ZERO
		for child in drone.get_children():
			if child is Node3D:
				child.global_position = Vector3.ZERO
				child.global_rotation = Vector3.ZERO

	print("[SettingMenu] Drone reset fallback applied.")


func _on_option_button_item_selected(index):
	var choice = telemetry_dropdown.get_item_text(index)
	match choice:
		"UDP":
			SourceManager.set_source("UDP")
		"Playback":
			SourceManager.set_source("PLAYBACK")


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_cleanup_sender()

func _exit_tree():
	_cleanup_sender()

func _cleanup_sender():
	if sender_pid != -1:
		print("[SetingMenu] Killing sender on exit...")
		OS.kill(sender_pid)
		sender_pid = -1

func _on_config_button_pressed():
	$VBoxContainer/ConfigWindow.load_settings()
	$VBoxContainer/ConfigWindow.open_config_window()
