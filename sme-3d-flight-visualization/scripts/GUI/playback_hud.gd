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
#|   File Name   : playback_hud.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Self-contained playback HUD shown only when the active telemetry
#|       source is "PLAYBACK". Provides transport controls (load, start,
#|       pause/resume, stop) and a scrub bar for frame-level seeking.
#|       Delegates all transport operations to SourceManager and listens to
#|       TelemetryManager for recording and playback state events. Has no
#|       knowledge of any TelemetrySource implementation.
#|
#|   POC         : Aramis Hernandez
#|
#|------------------------------------------------------------------------------------

extends Control

## Self-contained playback HUD for flight recording review.
##
## Visibility is driven entirely by [signal SourceManager.source_changed];
## the panel shows itself when the active source is [code]"PLAYBACK"[/code]
## and hides when any other source is selected, resetting all state on hide.
##
## Transport commands (start, pause, resume, stop, seek) are forwarded to
## [SourceManager]. Scrub bar position and the frame counter label are kept
## in sync via [signal TelemetryManager.frame_changed]. During a scrub drag
## the source is paused automatically and resumed on release so seeking does
## not produce playback glitches.

## Icon displayed on the pause/resume button while playback is active.
const ICON_PLAY: Texture2D = preload("res://assests/icons/play.svg")

## Icon displayed on the pause/resume button while playback is paused or stopped.
const ICON_PAUSE: Texture2D = preload("res://assests/icons/pause.svg")


## Slider the operator drags to seek to an arbitrary frame.
##
## Range is set to [code][0, frame_count - 1][/code] when a recording is
## loaded. Updated each frame via [signal TelemetryManager.frame_changed]
## unless a drag is in progress.
@onready var scrub_bar: HSlider = $PanelContainer/MarginContainer/VBoxContainer/FrameBarRow/Framebar

## Label displaying the current frame index and total frame count.
##
## Format: [code]"<current> / <total>"[/code]. Reset to [code]"0 / 0"[/code]
## when no recording is loaded.
@onready var frame_count_label: Label = $PanelContainer/MarginContainer/VBoxContainer/FrameBarRow/FrameCount

## Button that opens the file dialog to select a recording file.
@onready var load_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonRow/LoadButton

## Button that starts playback from frame zero.
##
## Disabled until a recording is successfully loaded.
@onready var start_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonRow/StartButton

## Button that toggles between paused and playing states.
##
## Label and icon swap between "Pause" / [constant ICON_PAUSE] and
## "Resume" / [constant ICON_PLAY] to reflect the current state.
## Disabled until a recording is successfully loaded.
@onready var pause_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonRow/PauseButton

## Button that stops playback and resets all HUD state.
##
## Disabled until a recording is successfully loaded.
@onready var stop_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonRow/StopButton

#States
## Whether playback is currently running.
##
## Toggled by [method _on_start_pressed], [method _on_pause_pressed],
## [method _on_stop_pressed], and [method _on_playback_completed].
var _is_playing: bool = false

## Whether the operator is actively dragging the scrub bar.
##
## While [code]true[/code], [method _on_frame_changed] does not update
## the scrub bar position so the drag value is not overwritten mid-gesture.
var _scrub_bar_dragging: bool = false

## File dialog used to browse for [code].bin[/code] recording files.
##
## Created and added as a child during [method _ready]. Opened on demand
## by [method _on_load_pressed].
var _file_dialog: FileDialog = null


## Initialises controls, constructs the file dialog, and connects all signals.
##
## Sets the scrub bar to a [code][0, 1][/code] range as a safe default,
## connects drag signals and button presses, then builds and adds a
## [FileDialog] filtered to [code].bin[/code] files rooted at
## [code]res://data/recorded_flightpath/[/code]. Connects to
## [signal TelemetryManager.recording_loaded],
## [signal TelemetryManager.frame_changed],
## [signal TelemetryManager.playback_completed], and
## [signal SourceManager.source_changed]. Starts hidden with controls
## disabled until a recording is loaded.
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


## Shows or hides the HUD based on the active telemetry source.
##
## Connected to [signal SourceManager.source_changed]. The panel is visible
## only when [param source_name] equals [code]"PLAYBACK"[/code]. On hide,
## [method _reset_state] is called to clear scrub position, frame label,
## and playing state so stale data is not shown if the operator returns to
## playback mode later.
##
## Parameters:
##   source_name : String
##       Name of the newly active telemetry source.
func _on_source_changed(source_name: String) -> void:
	visible = (source_name == "PLAYBACK")
	if not visible:
		# Clean up state when switching away from playback
		_reset_state()


## Opens the file dialog so the operator can select a recording.
##
## Connected to [signal Button.pressed] on [member load_button]. The dialog
## is centered at 800 × 600 pixels.
func _on_load_pressed() -> void:
	_file_dialog.popup_centered(Vector2i(800, 600))



## Forwards the selected file path to [SourceManager] for loading.
##
## Connected to [signal FileDialog.file_selected]. Converts the resource-
## relative path to an absolute path before passing it to
## [method SourceManager.load_file]. Pushes an error if loading fails.
##
## Parameters:
##   path : String
##       Resource-relative path to the selected [code].bin[/code] file.
func _on_file_selected(path: String) -> void:
	print("[PlaybackHUD] Loading: ", path)
	var full_path := ProjectSettings.globalize_path(path)
	var ok := SourceManager.load_file(full_path)
	if not ok:
		push_error("[PlaybackHUD] Failed to load: %s" % full_path)


# Transport controls
## Starts playback from frame zero.
##
## Connected to [signal Button.pressed] on [member start_button]. Stops any
## active playback, resets the source to [code]"PLAYBACK"[/code], resets
## the scrub bar to zero, then sets [member _is_playing] to [code]true[/code]
## and refreshes button states. Has no effect and pushes a warning if no
## recording is currently loaded.
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

## Toggles between paused and playing states.
##
## Connected to [signal Button.pressed] on [member pause_button]. Calls
## [method SourceManager.pause] or [method SourceManager.resume] depending
## on the current [member _is_playing] state, then flips the flag and
## refreshes button states.
func _on_pause_pressed() -> void: 
	if _is_playing:
		SourceManager.pause()
		_is_playing = false
	else:
		SourceManager.resume()
		_is_playing = true
	_update_button_states()
	

## Stops playback and resets all HUD state to idle.
##
## Connected to [signal Button.pressed] on [member stop_button]. Calls
## [method SourceManager.stop] then delegates to [method _reset_state].
func _on_stop_pressed() -> void:
	SourceManager.stop()
	_reset_state()


# Scrub Bar
## Pauses playback while the operator is dragging the scrub bar.
##
## Connected to [signal HSlider.drag_started] on [member scrub_bar]. Sets
## [member _scrub_bar_dragging] to [code]true[/code] and pauses the source
## if playback is active so frames do not advance during the gesture.
func _on_scrub_drag_started() -> void:
	_scrub_bar_dragging = true
	if _is_playing:
		SourceManager.pause()

## Seeks to the selected frame and resumes playback after a scrub drag ends.
##
## Connected to [signal HSlider.drag_ended] on [member scrub_bar]. Clears
## [member _scrub_bar_dragging], forwards the current slider integer value
## to [method SourceManager.seek], then resumes the source if playback was
## active before the drag began.
##
## Parameters:
##   _value_changed : bool
##       Whether the slider value changed during the drag. Not used; the
##       seek is always forwarded so the source stays in sync.
func _on_scrub_drag_ended(_value_changed: bool) -> void:
	_scrub_bar_dragging = false
	SourceManager.seek(int(scrub_bar.value))
	
	if _is_playing:
		SourceManager.resume()

# Telemetry Manager Singal Handlers
## Configures the scrub bar range and enables controls when a recording is ready.
##
## Connected to [signal TelemetryManager.recording_loaded]. Sets the scrub
## bar maximum to [code]frame_count - 1[/code], resets its value and the
## frame label to zero, enables transport controls, and clears
## [member _is_playing].
##
## Parameters:
##   _path       : String
##       Absolute path of the loaded file. Not used by this handler.
##   frame_count : int
##       Total number of frames in the loaded recording.
func _on_recording_loaded(_path: String, frame_count: int) -> void:
	scrub_bar.max_value = frame_count - 1
	scrub_bar.value = 0
	frame_count_label.text = "0 / %d" % frame_count
	_set_controls_active(true)
	_is_playing = false
	_update_button_states()
	print("[PlaybackHUD] Recording ready - %d frames." % frame_count)


## Updates the scrub bar position and frame counter label each frame.
##
## Connected to [signal TelemetryManager.frame_changed]. The scrub bar is
## only updated when [member _scrub_bar_dragging] is [code]false[/code] to
## avoid overwriting the operator's drag position mid-gesture.
##
## Parameters:
##   current_index : int
##       Zero-based index of the frame just emitted.
##   total_frames  : int
##       Total number of frames in the active recording.
func _on_frame_changed(current_index: int, total_frames: int) -> void:
	if not _scrub_bar_dragging:
		scrub_bar.value = current_index
	frame_count_label.text = "%d / %d" % [current_index, total_frames]


## Responds to playback reaching the final frame.
##
## Connected to [signal TelemetryManager.playback_completed]. Clears
## [member _is_playing] and refreshes button states so the pause/resume
## button returns to its idle appearance.
func _on_playback_completed() -> void:
	_is_playing = false
	_update_button_states()
	print("[PlaybackHUD] Playback complete.")


# Helper functions
## Resets all HUD state to idle without stopping the source.
##
## Clears [member _is_playing], resets the scrub bar to zero, resets the
## frame label to [code]"0 / 0"[/code], disables transport controls, and
## refreshes button states. Called on stop and whenever the panel is hidden.
func _reset_state() -> void:
	_is_playing = false
	scrub_bar.value = 0
	frame_count_label.text = "0 / 0"
	_set_controls_active(false)
	_update_button_states()


## Enables or disables all transport controls and the scrub bar.
##
## Called with [code]false[/code] on startup and reset, and [code]true[/code]
## once a recording is successfully loaded.
##
## Parameters:
##   active : bool
##       [code]true[/code] to enable controls; [code]false[/code] to disable.
func _set_controls_active(active: bool) -> void:
	start_button.disabled = not active
	pause_button.disabled = not active
	stop_button.disabled = not active
	scrub_bar.editable = active


## Updates the pause/resume button label and icon to match the current playing state.
##
## Displays "Resume" and [constant ICON_PLAY] when paused or stopped, and
## "Pause" and [constant ICON_PAUSE] when playing.
func _update_button_states() -> void:
	pause_button.text = "Resume" if not _is_playing else "Pause"
	pause_button.icon = ICON_PLAY if not _is_playing else ICON_PAUSE
