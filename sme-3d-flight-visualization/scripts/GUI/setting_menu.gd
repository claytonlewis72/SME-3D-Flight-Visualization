extends Control

@export var sender_path: String = "res://SME-tool/sender.py"
@export var python_path: String = "python3" # Path to Python


@onready var run_button: Button = $VBoxContainer/TelemetrySource/PanelContainer/VBoxContainer/Start
@onready var stop_button: Button = $VBoxContainer/TelemetrySource/PanelContainer/VBoxContainer/Stop
@onready var position_value = get_node("../TelemetryPanel/MarginContainer/VBoxContainer/TelemetryGrid/PositionValue")
@onready var rotation_value = get_node("../TelemetryPanel/MarginContainer/VBoxContainer/TelemetryGrid/RotationValue")
@onready var drone = get_node("/root/Main/Rendering Manager/Drone/Pivot/VisualRoot/plane2_9/RigidBody3D")
@onready var telemetry_dropdown = $VBoxContainer/TelemetrySource/PanelContainer/VBoxContainer/HBoxContainer/OptionButton
@onready var csv_ingestion = get_node("/root/Main/IngestionManager")


#ADDED By Aramis Hernandez: support for playback and recording
@onready var playback_panel: VBoxContainer = $VBoxContainer/TelemetrySource/PanelContainer/VBoxContainer/PlaybackPanel
@onready var load_button: Button = $VBoxContainer/TelemetrySource/PanelContainer/VBoxContainer/PlaybackPanel/Load
@onready var play_pause_button: Button = $VBoxContainer/TelemetrySource/PanelContainer/VBoxContainer/PlaybackPanel/Play_pause
@onready var stop_playback_button: Button = $VBoxContainer/TelemetrySource/PanelContainer/VBoxContainer/PlaybackPanel/Stop_playback
@onready var scrub_bar: HSlider = $VBoxContainer/TelemetrySource/PanelContainer/VBoxContainer/PlaybackPanel/HSlider
@onready var playback_file_dialog: FileDialog = null



var sender_pid: int = -1
var is_paused := false
var _playback_is_playing: bool = false
var _scrub_bar_dragging: bool = false



func _ready():
	run_button.pressed.connect(_on_run_telemetry_pressed)
	stop_button.pressed.connect(_on_stop_telemetry_pressed)
	
	# Drop down
	if not telemetry_dropdown.item_selected.is_connected(_on_option_button_item_selected):
		telemetry_dropdown.item_selected.connect(_on_option_button_item_selected)
	
	#Playback buttons
	load_button.pressed.connect(_on_load_pressed)
	play_pause_button.pressed.connect(_on_play_pause_pressed)
	stop_playback_button.pressed.connect(_on_stop_playback_pressed)
	
	scrub_bar.min_value = 0
	scrub_bar.max_value = 1
	scrub_bar.value = 0
	scrub_bar.step = 1
	scrub_bar.drag_started.connect(_on_scrub_drag_started)
	scrub_bar.drag_ended.connect(_on_scrub_drag_ended)
	
	
	
	playback_file_dialog = FileDialog.new()
	playback_file_dialog.title = "Select Flight Recording"
	playback_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	playback_file_dialog.access = FileDialog.ACCESS_RESOURCES
	playback_file_dialog.filters = PackedStringArray(["*.bin ; Flight Recordings"])
	playback_file_dialog.current_dir = ProjectSettings.globalize_path("res://data/recorded_flightpath/")
	
	
	add_child(playback_file_dialog)
	playback_file_dialog.file_selected.connect(_on_playback_file_selected)
	
	var found := false
	for i in telemetry_dropdown.item_count:
		if telemetry_dropdown.get_item_text(i) == "Playback":
			found = true
			break
	if not found: 
		telemetry_dropdown.add_item("Playback")
	
	TelemetryManager.recording_loaded.connect(_on_recording_loaded)
	TelemetryManager.frame_changed.connect(_on_frame_changed)
	TelemetryManager.playback_completed.connect(_on_playback_completed)
	
	SourceManager.source_changed.connect(_on_source_chnaged)
	
	playback_panel.visible = false
	_set_playback_controls_active(false)


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
	if !is_paused:
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
		return

# Reset Position and Orientation and the run
func _on_stop_telemetry_pressed():
	# Kill sender if running
	if sender_pid != -1:
		OS.kill(sender_pid)
		print("Sender stopped")
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
		print("Drone not found!")
	
	print("Telemetry reset")


# Option Button for switching telemetry source (UDP or CSV): by Nicholas Tran
func _on_option_button_item_selected(index):
	var choice = telemetry_dropdown.get_item_text(index)
	playback_panel.visible = (choice == "Playback")
	match choice:
		"UDP": 
			SourceManager.set_source("UDP")
		"Playback": 
			SourceManager.set_source("PLAYBACK")


func _on_source_chnaged(source_name: String) -> void:
	playback_panel.visible = (source_name == "PLAYBACK")
	
	# Disable playback controls until a file is loaded 
	if source_name == "PLAYBACK":
		_set_playback_controls_active(false)
		play_pause_button.text = "Play"
		_playback_is_playing = false
		print("[UI] Playback mode active. Click Load Recording to begin.")
	else:
		_playback_is_playing = false
		scrub_bar.value = 0

func _on_load_pressed() -> void:
	playback_file_dialog.popup()

func _on_playback_file_selected(path: String) -> void:
	var full_path := ProjectSettings.globalize_path(path)
	print("[UI] Loading recording: ", full_path)
	var ok = SourceManager.load_file(full_path)
	if not ok:
		push_error("[UI] Failed to load recording: %s" % full_path)

func _on_play_pause_pressed() -> void:
	if not SourceManager.has_recording():
		push_warning("[UI] No recording loaded.")
		return
	
	if _playback_is_playing:
		SourceManager.pause()
		play_pause_button.text = "Play"
		_playback_is_playing = false
	else:
		if scrub_bar.value == 0:
			# Fresh play from beginning
			SourceManager.stop()
			SourceManager.set_source("PLAYBACK")
		else:
			SourceManager.resume()
		play_pause_button.text = "Pause"
		_playback_is_playing = true

func _on_stop_playback_pressed() -> void:
	SourceManager.stop()
	play_pause_button.text = "Play"
	_playback_is_playing = false
	scrub_bar.value = 0


func _on_scrub_drag_started() -> void:
	_scrub_bar_dragging = true
	
	# Pause while dragging so frames don't race ahead
	if _playback_is_playing:
		SourceManager.pause()


func _on_scrub_drag_ended(_value_changed: bool) -> void:
	_scrub_bar_dragging = false
	SourceManager.seek(int(scrub_bar.value))
	
	#Resume if was playing before the drag
	if _playback_is_playing:
		SourceManager.resume()


func _on_recording_loaded(_path: String, frame_count: int) -> void:
	scrub_bar.max_value = frame_count - 1
	scrub_bar.value = 0
	_set_playback_controls_active(true)
	play_pause_button.text = "Play"
	_playback_is_playing = false
	print("[UI] Recording ready. %d frames. " % frame_count)
	

func _on_frame_changed(current_index: int, _total: int) -> void:
	if not _scrub_bar_dragging:
		scrub_bar.value = current_index

func _on_playback_completed() -> void:
	play_pause_button.text = "Play"
	_playback_is_playing = false
	print("[UI] Playback complete.")

func _set_playback_controls_active(active: bool) -> void:
	play_pause_button.disabled = not active
	stop_playback_button.disabled = not active
	scrub_bar.editable = active
	
#Kill sender if app is closed or ended.
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






#File selector for csv: by Nicholas Tran
## FILE SELECTOR CRASHES FOR CSV
func _on_csv_file_dialog_file_selected(path: String) -> void:
	csv_ingestion.replay_file_path = path
	csv_ingestion._load_file()
	TelemetryManager.telemetry_source = "CSV"
