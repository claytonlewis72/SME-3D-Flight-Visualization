extends Control

@export var sender_path: String = "res://SME-tool/sender.py"
@export var python_path: String = "python3" # Path to Python



@onready var run_button: Button = $VBoxContainer/TelemetrySource/PanelContainer/VBoxContainer/Start
@onready var stop_button: Button = $VBoxContainer/TelemetrySource/PanelContainer/VBoxContainer/Stop

var sender_pid: int = -1


func _ready():
	run_button.pressed.connect(_on_run_telemetry_pressed)
	stop_button.pressed.connect(_on_stop_telemetry_pressed)


func _on_run_telemetry_pressed():
	# ✅ Prevent multiple instances
	if sender_pid != -1:
		print("Sender already running with PID:", sender_pid)
		return
	
	var full_path = ProjectSettings.globalize_path(sender_path)
	
	var args := PackedStringArray()
	args.append(full_path)
	
	sender_pid = OS.create_process(python_path, args)
	
	if sender_pid == -1:
		push_error("Failed to start sender")
	else:
		print("Started sender with PID:", sender_pid)

func _on_stop_telemetry_pressed():
	# Only stop if running
	if sender_pid == -1:
		print("Sender is not running")
		return
	
	var success = OS.kill(sender_pid)
	
	if success == OK:
		print("Sender stopped")
	else:
		push_error("Failed to stop sender")
	
	sender_pid = -1

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_cleanup_sender()

func _exit_tree():
	_cleanup_sender()

func _cleanup_sender():
	if sender_pid != -1:
		print("Killing sender on exit...")
		OS.kill(sender_pid)
		sender_pid = -1
