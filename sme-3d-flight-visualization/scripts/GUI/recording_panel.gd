extends Control

@onready var file_name_input: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/FileNameRow/FileNameInput
@onready var record_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonRow/RecordButton
@onready var panel_container: PanelContainer = $PanelContainer

## Reference to TelemetryPanel so we can track it when if it's size changes
@export var telemetry_panel_path: NodePath

var _telemetry_panel: Control = null

var _is_recording: bool = false

func _ready() -> void:
	
	if telemetry_panel_path:
		_telemetry_panel = get_node(telemetry_panel_path)
	else:
		_telemetry_panel = get_parent().get_node_or_null("TelemetryPanel")
	
	if _telemetry_panel == null:
		push_error("[RecordingPanel] Could not find TelemetryPanel")
	else:
		# Connect to size changes so we reposition if TelemetryPanel resizes
		_telemetry_panel.resized.connect(_reposition)
		_reposition()
	file_name_input.placeholder_text = "e.g flight_test"
	file_name_input.text = ""
	file_name_input.editable = true
	
	record_button.text = "Start Recording"
	record_button.disabled = false
	record_button.pressed.connect(_on_record_pressed)
	
	TelemetryManager.recording_started.connect(_on_recording_started)
	TelemetryManager.recording_stopped.connect(_on_recording_stopped)
	
	SourceManager.source_changed.connect(_on_source_changed)

func _reposition() -> void:
	if _telemetry_panel == null:
		return
	
	global_position = Vector2(
		_telemetry_panel.global_position.x,
		_telemetry_panel.global_position.y + _telemetry_panel.size.y
	)
	
	size.x = _telemetry_panel.size.x


func _on_record_pressed() -> void:
	if _is_recording:
		RecordingManager.stop_recording()
	else:
		var filename := file_name_input.text.strip_edges()
		
		#Fall back on the timestamp if the user left eh field blank
		if filename.is_empty():
			var dt := Time.get_datetime_dict_from_system()
			filename = "flight_%04d%02d%02d_%02d%02d%02d" % [
				dt["year"], dt["month"], dt["day"],
				dt["hour"], dt["minute"], dt["second"]
			]
			
			file_name_input.placeholder_text = filename
		
		RecordingManager.start_recording(filename)


func _on_recording_started(file_path: String) -> void:
	_is_recording = true
	record_button.text = "Stop Recording"
	record_button.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	file_name_input.editable = false
	print("[RecordingPanel] Recording started -> %s" % file_path)

func _on_recording_stopped(file_path: String, frame_count: int) -> void:
	_is_recording = false
	record_button.text = "Start Recording"
	record_button.remove_theme_color_override("font_color")
	file_name_input.editable = true
	file_name_input.text = ""
	print("[RecordingPanel] Recording stopped. %d frames saved -> %s" % [frame_count, file_path])

func _on_source_changed(source_name: String) -> void:
	var is_udp := (source_name == "UDP")
	
	# Stop any active recording if user switches away from UDP
	if not is_udp and _is_recording:
		RecordingManager.stop_recording()
	
	#Disable controls when not in UDP mode
	record_button.disabled = not is_udp
	file_name_input.editable = is_udp and not _is_recording
