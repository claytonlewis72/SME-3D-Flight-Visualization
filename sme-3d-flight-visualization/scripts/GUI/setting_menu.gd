extends Control

#Exports
@export var sender_path: String = "res://SME-tool/sender.py"
@export var python_path: String = "python3" # Path to Python


@onready var run_button: Button = $VBoxContainer/TelemetrySource/PanelContainer/VBoxContainer/Start
@onready var stop_button: Button = $VBoxContainer/TelemetrySource/PanelContainer/VBoxContainer/Stop
@onready var position_value = get_node("../TelemetryPanel/MarginContainer/VBoxContainer/TelemetryGrid/PositionValue")
@onready var rotation_value = get_node("../TelemetryPanel/MarginContainer/VBoxContainer/TelemetryGrid/RotationValue")
@onready var drone = get_node("/root/Main/Rendering Manager/Drone/Pivot/VisualRoot/plane2_9/RigidBody3D")
@onready var telemetry_dropdown = $VBoxContainer/TelemetrySource/PanelContainer/VBoxContainer/HBoxContainer/OptionButton


var sender_pid: int = -1
var is_paused := false


func _ready():
	run_button.pressed.connect(_on_run_telemetry_pressed)
	stop_button.pressed.connect(_on_stop_telemetry_pressed)
	
	# Drop down
	if not telemetry_dropdown.item_selected.is_connected(_on_option_button_item_selected):
		telemetry_dropdown.item_selected.connect(_on_option_button_item_selected)
	
	
	var found := false
	for i in telemetry_dropdown.item_count:
		if telemetry_dropdown.get_item_text(i) == "Playback":
			found = true
			break
	if not found: 
		telemetry_dropdown.add_item("Playback")

#UDP sender controls
func _on_run_telemetry_pressed():
	# Make sure we can only run one sender at a time
	# Case 1: Not Running -> Start
	if sender_pid == -1:
		var full_path = ProjectSettings.globalize_path(sender_path)
		var args := PackedStringArray([full_path])

		sender_pid = OS.create_process(python_path, args)

		if sender_pid == -1:
			push_error("Failed to start sender")
		else:
			print("Started sender with PID:", sender_pid)
			run_button.text = "Pause"
			is_paused = false
		return
	
	# Case 2: Running and Not Paused -> Resume
	if not is_paused:
		print("Pausing sender...")
		OS.kill(sender_pid)
		is_paused = true
		run_button.text = "Resume"
		return
	
	# Case 3: Paused -> Resume
	if is_paused:
		print("Resuming sender...")
		var full_path = ProjectSettings.globalize_path(sender_path)
		var args := PackedStringArray([full_path])
		
		sender_pid = OS.create_process(python_path, args)
		is_paused = false
		run_button.text = "Pause"

# Reset Position and Orientation and the run
func _on_stop_telemetry_pressed():
	# Kill sender if running
	if sender_pid != -1:
		OS.kill(sender_pid)
		print("[SettingMenu] Sender stopped.")
		sender_pid = -1

	# Reset UI
	run_button.text = "Start"
	is_paused = false
	
	# Clear telemetry values
	position_value.text = "(0.0000, 0.0000, 0.0000)"
	rotation_value.text = "(0.0000, 0.0000, 0.0000)"
	
	# Reset Drone Position and Rotation
	## NEEDS PLAYBACK TO BE ABLE TO RESET
	if drone:
		drone.freeze = true
		drone.global_position = Vector3.ZERO
		drone.global_rotation = Vector3.ZERO
		drone.linear_velocity = Vector3.ZERO
		drone.angular_velocity = Vector3.ZERO
		drone.freeze = false
	else:
		print("[SetingMenu] Drone not found!")
	
	print("[SettingMenu] Telemetry reset")


# Option Button for switching telemetry source (UDP or CSV): by Nicholas Tran
func _on_option_button_item_selected(index):
	#Edited by Aramis Hernandez
	var choice = telemetry_dropdown.get_item_text(index)
	match choice:
		"UDP": 
			SourceManager.set_source("UDP")
		"Playback": 
			SourceManager.set_source("PLAYBACK")


#Kill sender if app is closed or ended.
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
