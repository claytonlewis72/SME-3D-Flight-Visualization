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
#|   File Name   : test_recording_panel.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Unit tests for the RecordingPanel signal handlers using the GUT framework.
#|       Instances the real .tscn so all @onready nodes resolve correctly.
#|       Handlers are called directly to avoid singleton connection timing issues.
#|
#|   Notes       :
#|       Requires GUT (Godot Unit Testing) framework to be installed.
#|       Update SCENE_PATH if your .tscn lives elsewhere.
#|
#|   POC         :
#|       Aramis Hernandez
#|
#|------------------------------------------------------------------------------------
 
extends GutTest
 
# ---- Setup / Teardown ---------------------------------------------------
 
const SCENE_PATH := "res://scenes/GUI/recording_panel.tscn"
 
var _panel: Control
 
 
func before_each() -> void:
	_panel = load(SCENE_PATH).instantiate()
	add_child(_panel)
	await get_tree().process_frame
 
 
func after_each() -> void:
	if is_instance_valid(_panel):
		remove_child(_panel)
		_panel.queue_free()
 
 
# ---- _on_recording_started() --------------------------------------------
 
# Verifies the panel correctly enters a recording state when started.
func test_recording_started_updates_state_and_ui() -> void:
	_panel._on_recording_started("res://recordings/test.bin")
 
	assert_true(_panel._is_recording,          "_is_recording should be true")
	assert_eq(_panel.record_button.text,        "Stop Recording",
		"record button should read 'Stop Recording'")
	assert_false(_panel.file_name_input.editable,
		"filename input should be locked while recording")
 
 
# ---- _on_recording_stopped() --------------------------------------------
 
# Verifies the panel correctly returns to idle state when recording stops.
func test_recording_stopped_updates_state_and_ui() -> void:
	_panel._on_recording_started("res://recordings/test.bin")
	_panel._on_recording_stopped("res://recordings/test.bin", 100)
 
	assert_false(_panel._is_recording,         "_is_recording should be false")
	assert_eq(_panel.record_button.text,        "Start Recording",
		"record button should read 'Start Recording'")
	assert_true(_panel.file_name_input.editable,
		"filename input should be editable again")
 
 
# Verifies the filename input is cleared after recording stops.
func test_recording_stopped_clears_filename_input() -> void:
	_panel.file_name_input.text = "my_flight"
	_panel._on_recording_stopped("res://recordings/test.bin", 100)
 
	assert_eq(_panel.file_name_input.text, "",
		"filename input should be cleared after recording stops")
 
 
# ---- _on_source_changed() -----------------------------------------------
 
# Verifies controls are enabled when the source switches to UDP.
func test_source_changed_to_udp_enables_controls() -> void:
	_panel._on_source_changed("UDP")
 
	assert_false(_panel.record_button.disabled,
		"record button should be enabled when source is UDP")
	assert_true(_panel.file_name_input.editable,
		"filename input should be editable when source is UDP")
 
 
# Verifies controls are disabled when the source is not UDP.
func test_source_changed_away_from_udp_disables_controls() -> void:
	_panel._on_source_changed("PLAYBACK")
 
	assert_true(_panel.record_button.disabled,
		"record button should be disabled when source is not UDP")
	assert_false(_panel.file_name_input.editable,
		"filename input should be locked when source is not UDP")
