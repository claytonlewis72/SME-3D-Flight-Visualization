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
#|   File Name   : recording_panel.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       UI panel that exposes recording controls to the operator. Allows the
#|       user to start and stop flight recordings with an optional custom
#|       filename. Repositions itself below TelemetryPanel and mirrors its
#|       width. Disables all controls when the active telemetry source is not
#|       UDP and automatically stops any active recording if the source
#|       changes away from UDP.
#|
#|   POCs: Aramis Hernandez
#|
#|------------------------------------------------------------------------------------


extends Control

## UI panel that exposes flight recording controls to the operator.
##
## Presents a filename input and a start/stop record button. On press the
## panel delegates to [RecordingManager] to begin or end a recording, falling
## back to a timestamp-derived filename if the operator left the field blank.
## Button state and input editability are kept in sync with
## [signal TelemetryManager.recording_started],
## [signal TelemetryManager.recording_stopped], and
## [signal SourceManager.source_changed] so the UI always reflects the true
## recording state even if recording is started or stopped from outside this panel.
##
## The panel anchors itself directly below [code]TelemetryPanel[/code] and
## matches its width, reconnecting on every [signal Control.resized] emission
## so layout stays correct if the telemetry panel is resized at runtime.


## Icon displayed on the record button while no recording is active.
const ICON_RECORD: Texture2D = preload("res://assests/icons/record.svg")

## Icon displayed on the record button while a recording is in progress.
const ICON_RECORD_STOP: Texture2D = preload("res://assests/icons/record-stop.svg")

## Input field where the operator enters an optional recording filename.
##
## Placeholder text is updated to show the auto-generated timestamp filename
## when the field is left blank. Set non-editable while a recording is active.
@onready var file_name_input: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/FileNameRow/FileNameInput

## Button that starts or stops the active recording.
##
## Label, icon, and font color update to reflect the current recording state.
## Disabled when the active telemetry source is not UDP.
@onready var record_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonRow/RecordButton

## Root container of this panel, used for layout sizing.
@onready var panel_container: PanelContainer = $PanelContainer

## Scene-tree path to the [Control] this panel positions itself below.
##
## If not set, [method _ready] falls back to looking for a sibling node
## named [code]TelemetryPanel[/code] under the same parent.
@export var telemetry_panel_path: NodePath

## Resolved reference to the [Control] used as the layout anchor.
##
## [code]null[/code] if the node could not be found during [method _ready].
var _telemetry_panel: Control = null

## Whether a recording is currently in progress.
##
## Kept in sync with [signal TelemetryManager.recording_started] and
## [signal TelemetryManager.recording_stopped] rather than being set
## speculatively on button press.
var _is_recording: bool = false

## Resolves UI node references, connects signals, and positions the panel.
##
## Resolves [member _telemetry_panel] from [member telemetry_panel_path] or
## falls back to a sibling named [code]TelemetryPanel[/code]. Connects to
## [signal Control.resized] on the telemetry panel so layout updates whenever
## it changes size, then calls [method _reposition] immediately. Initialises
## the filename input and record button to their idle state and connects to
## [signal TelemetryManager.recording_started],
## [signal TelemetryManager.recording_stopped], and
## [signal SourceManager.source_changed].
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
	record_button.icon = ICON_RECORD
	record_button.disabled = false
	record_button.pressed.connect(_on_record_pressed)
	
	TelemetryManager.recording_started.connect(_on_recording_started)
	TelemetryManager.recording_stopped.connect(_on_recording_stopped)
	
	SourceManager.source_changed.connect(_on_source_changed)


## Positions this panel directly below [member _telemetry_panel] and matches its width.
##
## Sets [member Control.global_position] so this panel's top-left corner
## aligns with the bottom-left corner of [member _telemetry_panel], then
## sets [member Control.size].x to match. Has no effect if
## [member _telemetry_panel] is [code]null[/code].
func _reposition() -> void:
	if _telemetry_panel == null:
		return
	
	global_position = Vector2(
		_telemetry_panel.global_position.x,
		_telemetry_panel.global_position.y + _telemetry_panel.size.y
	)
	
	size.x = _telemetry_panel.size.x


## Handles the record button being pressed.
##
## If a recording is active, delegates to [method RecordingManager.stop_recording].
## Otherwise reads the filename input, falls back to a timestamp string of the
## form [code]flight_YYYYMMDD_HHMMSS[/code] if the field is blank (updating
## the placeholder text so the operator can see the generated name), then
## delegates to [method RecordingManager.start_recording].
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


## Responds to a recording starting by updating the button and locking the filename input.
##
## Connected to [signal TelemetryManager.recording_started]. Sets
## [member _is_recording] to [code]true[/code], updates the button label,
## icon, and font color to the active recording style, and marks the filename
## input non-editable for the duration of the recording.
##
## Parameters:
##   file_path : String
##       Absolute path of the recording file that was opened. Logged to console.
func _on_recording_started(file_path: String) -> void:
	_is_recording = true
	record_button.text = "Stop Recording"
	record_button.icon = ICON_RECORD_STOP
	record_button.add_theme_color_override("font_color", Color(1, 0.267, 0.267))
	record_button.add_theme_color_override("font_hover_color", Color(1, 0.4, 0.4))
	file_name_input.editable = false
	print("[RecordingPanel] Recording started -> %s" % file_path)


## Responds to a recording stopping by restoring the button and unlocking the filename input.
##
## Connected to [signal TelemetryManager.recording_stopped]. Sets
## [member _is_recording] to [code]false[/code], restores the button label,
## icon, and font color to their idle state, clears the filename field, and
## re-enables editing.
##
## Parameters:
##   file_path   : String
##       Absolute path of the file that was finalized. Logged to console.
##   frame_count : int
##       Total number of pose frames written to the file. Logged to console.
func _on_recording_stopped(file_path: String, frame_count: int) -> void:
	_is_recording = false
	record_button.text = "Start Recording"
	record_button.icon = ICON_RECORD
	record_button.remove_theme_color_override("font_color")
	record_button.remove_theme_color_override("font_hover_color")
	file_name_input.editable = true
	file_name_input.text = ""
	print("[RecordingPanel] Recording stopped. %d frames saved -> %s" % [frame_count, file_path])


## Responds to the active telemetry source changing.
##
## Connected to [signal SourceManager.source_changed]. Recording controls
## are only valid when the source is [code]"UDP"[/code]. If the source
## switches away from UDP while a recording is active, the recording is
## stopped immediately. The record button is disabled and the filename input
## is locked whenever the source is not UDP.
##
## Parameters:
##   source_name : String
##       Name of the newly active telemetry source as reported by
##       [SourceManager].
func _on_source_changed(source_name: String) -> void:
	var is_udp := (source_name == "UDP")
	
	# Stop any active recording if user switches away from UDP
	if not is_udp and _is_recording:
		RecordingManager.stop_recording()
	
	#Disable controls when not in UDP mode
	record_button.disabled = not is_udp
	file_name_input.editable = is_udp and not _is_recording
