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
#|   File Name   : setting_menu.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Main settings panel that manages the telemetry sender process,
#|       telemetry source selection, drone state reset, and config window
#|       access. Spawns and kills an external Python sender process for UDP
#|       telemetry, supports pause and resume via process restart, and
#|       delegates source switching to SourceManager. On stop, reloads the
#|       scene and restores the default drone through DroneManager.
#|
#|   Authors     : Nicholas Tran, Aramis Hernandez
#|
#|------------------------------------------------------------------------------------

extends Control

## Main settings panel controlling the telemetry sender process, source
## selection, drone state, and config window access.
##
## The panel spawns an external Python process ([member sender_path]) to
## stream UDP telemetry into the application. Because Godot has no built-in
## process suspend API, "pause" is implemented by killing the process and
## "resume" by relaunching it. Stopping telemetry kills the process, halts
## [SourceManager], and triggers a full scene reload via [DroneManager] so
## the drone returns to its default state. Source switching between UDP and
## PLAYBACK modes is forwarded directly to [SourceManager].

#Exports
## Resource-relative path to the Python sender script.
##
## Globalized via [method ProjectSettings.globalize_path] before being
## passed to [method OS.create_process].
@export var sender_path: String = "res://SME-tool/sender.py"

## System path or name of the Python interpreter used to launch [member sender_path].
##
## Defaults to [code]"python3"[/code]. Override if the target machine requires
## a specific interpreter path (e.g. [code]"python"[/code] on Windows).
@export var python_path: String = "python3" # Path to Python


## Start/pause/resume button for the telemetry sender process.
##
## Label cycles between [code]"Stop"[/code] and [code]"Start"[/code] to
## reflect the current sender state.
@onready var run_button: Button = $VBoxContainer/TelemetrySource/PanelContainer/VBoxContainer/Start

## Button that stops the sender process and reloads the scene.
@onready var stop_button: Button = $VBoxContainer/TelemetrySource/PanelContainer/VBoxContainer/Stop

## Label displaying the current vehicle world position from telemetry.
@onready var position_value = get_node("../TelemetryPanel/MarginContainer/VBoxContainer/TelemetryGrid/PositionValue")

## Label displaying the current vehicle world rotation from telemetry.
@onready var rotation_value = get_node("../TelemetryPanel/MarginContainer/VBoxContainer/TelemetryGrid/RotationValue")

## Reference to the [code]VisualRoot[/code] node holding the active drone mesh.
##
## [code]null[/code] if the node is not present in the tree at startup.
## Used by [method _reset_drone_state] to zero the drone's transform.
@onready var drone = get_node_or_null("/root/Main/Rendering Manager/Drone/Pivot/VisualRoot")

## Dropdown for selecting the active telemetry source ([code]UDP[/code] or [code]Playback[/code]).
@onready var telemetry_dropdown = $VBoxContainer/TelemetrySource/PanelContainer/VBoxContainer/HBoxContainer/OptionButton

## Reference to the config window node opened by [member config_button].
@onready var config_window = $VBoxContainer/ConfigWindow

## Button that opens the configuration window.
@onready var config_button = $VBoxContainer/ConfigButton

## OS process ID of the currently running sender process.
##
## [code]-1[/code] when no process is active. Used to send kill signals
## via [method OS.kill] on pause, stop, and application exit.
var sender_pid: int = -1


## Whether the sender process has been temporarily killed to simulate a pause.
##
## [code]true[/code] after a pause kill; [code]false[/code] when the process
## is running or has been fully stopped.
var is_paused := false


## Connects button signals and ensures the Playback option exists in the dropdown.
##
## Guards the dropdown signal connection with [method Signal.is_connected]
## to prevent duplicate connections if [method _ready] is called more than
## once. Appends a [code]"Playback"[/code] item to [member telemetry_dropdown]
## if one is not already present.
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


## Starts, pauses, or resumes the external Python sender process.
##
## Connected to [signal Button.pressed] on [member run_button]. Behaviour
## depends on the current state of [member sender_pid] and [member is_paused]:
##
## - If [member sender_pid] is [code]-1[/code]: launches a new sender process
##   via [method OS.create_process] and updates the button label to
##   [code]"Stop"[/code].
## - If the process is running and not paused: kills the process to simulate
##   a pause, sets [member is_paused] to [code]true[/code], and resets the
##   button label to [code]"Start"[/code].
## - If the process is paused: relaunches the sender to resume, clears
##   [member is_paused], and updates the label to [code]"Stop"[/code].
##
## Pushes an error if the initial process launch fails.
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


## Stops the sender process, halts the telemetry source, and reloads the scene.
##
## Connected to [signal Button.pressed] on [member stop_button]. Kills the
## sender process if one is running, then calls [method SourceManager.stop]
## if [SourceManager] is present in the tree. Delegates scene reload and
## drone restoration to [method DroneManager.reload_scene_and_restore_default_drone]
## if available; falls back to [method SceneTree.reload_current_scene]
## directly if [DroneManager] is absent or does not expose that method.
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


## Resets the active drone's transform and velocity to zero.
##
## Walks a priority chain to find the most appropriate reset target:
##
## 1. If [member drone] is a [RigidBody3D], freezes it, zeroes all physics
##    state, then unfreezes.
## 2. If [member drone]'s first child is a [RigidBody3D], applies the same
##    freeze-zero-unfreeze sequence to that child.
## 3. Falls back to zeroing [member Node3D.global_position] and
##    [member Node3D.global_rotation] on [member drone] and all its
##    [Node3D] children if no [RigidBody3D] is found.
##
## Has no effect and logs a warning if [member drone] is [code]null[/code].
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


## Forwards the selected telemetry source to [SourceManager].
##
## Connected to [signal OptionButton.item_selected] on [member telemetry_dropdown].
## Maps [code]"UDP"[/code] to [code]SourceManager.set_source("UDP")[/code] and
## [code]"Playback"[/code] to [code]SourceManager.set_source("PLAYBACK")[/code].
## Unrecognised selections are silently ignored.
##
## Parameters:
##   index : int
##       Index of the selected item in [member telemetry_dropdown].
func _on_option_button_item_selected(index):
	var choice = telemetry_dropdown.get_item_text(index)
	match choice:
		"UDP":
			SourceManager.set_source("UDP")
		"Playback":
			SourceManager.set_source("PLAYBACK")



## Kills the sender process when the application window is closed.
##
## Handles [constant NOTIFICATION_WM_CLOSE_REQUEST] to ensure the external
## Python process is not left running as an orphan after the application exits.
##
## Parameters:
##   what : int
##       The notification constant received from the engine.
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_cleanup_sender()


## Kills the sender process when this node is removed from the scene tree.
##
## Guards against orphaned processes in cases where the node is freed before
## the application window closes (e.g. during scene reloads).
func _exit_tree():
	_cleanup_sender()


## Kills the sender process and resets [member sender_pid] to [code]-1[/code].
##
## Called by both [method _notification] and [method _exit_tree] to ensure
## the external Python process is always terminated on exit regardless of
## which lifecycle event fires first.
func _cleanup_sender():
	if sender_pid != -1:
		print("[SetingMenu] Killing sender on exit...")
		OS.kill(sender_pid)
		sender_pid = -1

## Opens the configuration window.
##
## Connected to [signal Button.pressed] on [member config_button]. Calls
## [method load_settings] then [method open_config_window] on the config
## window node to ensure settings are refreshed from disk before the window
## is shown.
func _on_config_button_pressed():
	$VBoxContainer/ConfigWindow.load_settings()
	$VBoxContainer/ConfigWindow.open_config_window()
	
