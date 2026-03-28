#|   Unclassified
#|------------------------------------------------------------------------------------
#|
#|   SME Solutions, Inc.
#|   Copyright 2026 SME Solutions, Inc. All Rights Reserved
#|   SME Solutions Proprietary Information
#|
#|------------------------------------------------------------------------------------
#|
#|   File Name   : playback_hud.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Self-contained playback HUD. Shown only when the active telemetry
#|       source is "PLAYBACK". Talks to SourceManager for all transport
#|       controls and listens to TelemetryManager for all data events.
#|       Has no knowledge of any TelemetrySource implementation.
#|
#|   POC         :
#|       Aramis Hernandez
#|
#|------------------------------------------------------------------------------------
extends Control

@onready var scrub_bar: HSlider = $PanelContainer/MarginContainer/VBoxContainer/FrameBarRow/Framebar
@onready var frame_count_label: Label = $PanelContainer/MarginContainer/VBoxContainer/FrameBarRow/FrameCount
@onready var load_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonRow/LoadButton
@onready var start_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonRow/StartButton
@onready var pause_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonRow/PauseButton
@onready var stop_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonRow/StopButton

#States
var _is_playing: bool = false
var _scrub_bar_dragging: bool = false

var _file_dialog: FileDialog = null

func _ready():
	# Anchor to bottom of screen
	scrub_bar.min_value = 0
	scrub_bar.max_value = 1
	scrub_bar.value = 0
	scrub_bar.step = 1
	scrub_bar.drag_started.connect(_on_scrub_drag_started)
	scrub_bar.drag_ended.connect(_on_scrub_drag_ended)
	
	load_button.pressed.connect(_on_load_pressed)
	start_button.pressed.connect(_on_start_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	
	_file_dialog = FileDialog.new()
	_file_dialog.title = "Select Flight Recording"
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.filters = PackedStringArray(["*.bin ; Flight Recordings"])
	_file_dialog.current_dir = "res://data/recorded_flightpath/"
	add_child(_file_dialog)
	_file_dialog.file_selected.connect(_on_file_selected)
	
	TelemetryManager.recording_loaded.connect(_on_recording_loaded)
	TelemetryManager.frame_changed.connect(_on_frame_changed)
	TelemetryManager.playback_completed.connect(_on_playback_completed)
	
	SourceManager.source_changed.connect(_on_source_changed)
	
	#Inital State
	_set_controls_active(false)
	frame_count_label.text = "0 / 0"
	visible = false


func _on_source_changed(source_name: String) -> void:
	visible = (source_name == "PLAYBACK")
	if not visible:
		# Clean up state when switching away from playback
		_reset_state()

func _on_load_pressed() -> void:
	_file_dialog.popup_centered(Vector2i(800, 600))

func _on_file_selected(path: String) -> void:
	print("[PlaybackHUD] Loading: ", path)
	var full_path := ProjectSettings.globalize_path(path)
	var ok := SourceManager.load_file(full_path)
	if not ok:
		push_error("[PlaybackHUD] Failed to load: %s" % full_path)


# Transport controls
func _on_start_pressed() -> void:
	if not SourceManager.has_recording():
		push_warning("[PlaybackHUD] No recording loaded.")
		return
	
	#Always start fresh from frame 0
	SourceManager.stop()
	SourceManager.set_source("PLAYBACK")
	scrub_bar.value = 0
	_is_playing = true
	_update_button_states()

func _on_pause_pressed() -> void: 
	if _is_playing:
		SourceManager.pause()
		_is_playing = false
	else:
		SourceManager.resume()
		_is_playing = true
	_update_button_states()
	

func _on_stop_pressed() -> void:
	SourceManager.stop()
	_reset_state()


# Scrub Bar
func _on_scrub_drag_started() -> void:
	_scrub_bar_dragging = true
	if _is_playing:
		SourceManager.pause()

func _on_scrub_drag_ended(_value_changed: bool) -> void:
	_scrub_bar_dragging = false
	SourceManager.seek(int(scrub_bar.value))
	
	if _is_playing:
		SourceManager.resume()

# Telemetry Manager Singal Handlers
func _on_recording_loaded(_path: String, frame_count: int) -> void:
	scrub_bar.max_value = frame_count - 1
	scrub_bar.value = 0
	frame_count_label.text = "0 / %d" % frame_count
	_set_controls_active(true)
	_is_playing = false
	_update_button_states()
	print("[PlaybackHUD] Recording ready - %d frames." % frame_count)

func _on_frame_changed(current_index: int, total_frames: int) -> void:
	if not _scrub_bar_dragging:
		scrub_bar.value = current_index
	frame_count_label.text = "%d / %d" % [current_index, total_frames]

func _on_playback_completed() -> void:
	_is_playing = false
	_update_button_states()
	print("[PlaybackHUD] Playback complete.")


# Helper functions
func _reset_state() -> void:
	_is_playing = false
	scrub_bar.value = 0
	frame_count_label.text = "0 / 0"
	_set_controls_active(false)
	_update_button_states()

func _set_controls_active(active: bool) -> void:
	start_button.disabled = not active
	pause_button.disabled = not active
	stop_button.disabled = not active
	scrub_bar.editable = active

func _update_button_states() -> void:
	pause_button.text = "Resume" if not _is_playing else "Pause"
