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
#|   File Name   : test_recording_manager.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Unit tests for the RecordingManager script using the GUT framework.
#|       Validates recorder registration, start/stop delegation, and the
#|       is_recording state query with and without a registered recorder.
#|
#|   Notes       :
#|       Requires GUT (Godot Unit Testing) framework to be installed.
#|       FlightRecorder is replaced with a mock to isolate RecordingManager
#|       from file I/O and telemetry dependencies.
#|
#|   POC         :
#|       Aramis Hernandez
#|
#|----------------------------------------------------------------------------------

extends GutTest

#---- Mock Components ---------------------------------

class MockRecorder extends Node:
	var is_recording: bool = false
	var start_called: bool = false
	var stop_called: bool = false
	var last_custom_name: String = ""
	
	func start_recording(custom_name: String = "") -> void:
		is_recording = true
		start_called = true
		last_custom_name = custom_name
	
	func stop_recording() -> void:
		is_recording = false
		stop_called = true

# ----- Setup -------------------

# Reference to the Recording Manager node under test
var _manager: Node

# Reference to the mock recorder injected into the manager
var _mock_recorder: MockRecorder

#Runs before every test by GUT.
func before_each() -> void:
	_manager = load("res://scripts/Managers/recording_manager.gd").new()
	_mock_recorder = MockRecorder.new()
	add_child_autofree(_manager)
	
#Ensures there are no orphans
func after_each() -> void:
	_manager.free()
	_mock_recorder.free()

# ---- register_recorder() test ----------------------

# Verifies that a recorder can be registered and is stored internally
func test_register_recorder_stores_recorder() -> void:
	_manager.register_recorder(_mock_recorder)
	assert_eq(_manager._recorder, _mock_recorder, "registered recorder should be stored in _recorder")

# --- start_recording() test --------------------------

# Verifies that start_recording() delegates to the registered recorder
func test_start_recording_calls_recorder() -> void:
	_manager.register_recorder(_mock_recorder)
	_manager.start_recording()
	assert_true(_mock_recorder.start_called, "start_recording() should delegate to the registered recorder")

# Verifies that a custom name is passed through to the recorder unchanged
func test_start_recording_passes_custom_name() -> void:
	_manager.register_recorder(_mock_recorder)
	_manager.start_recording("my_flight")
	assert_eq(_mock_recorder.last_custom_name, "my_flight", "custom name should be forwarded to the recorder unchanged")


# ---- stop _recording() test ------------------------------------------

# Verifies that stop_recording() delegates to the registered recorder
func test_stop_recording_calls_recorder() -> void:
	_manager.register_recorder(_mock_recorder)
	_mock_recorder.is_recording = true
	_manager.stop_recording()
	assert_true(_mock_recorder.stop_called, "stop_recording() should delegate to the registered recorder")


#--- is_recording() ---------------------------------------------------

#Verifies that is_recording() returns false when no recorder is registered
func test_is_recording_returns_false_with_no_recorder() -> void:
	assert_false(_manager.is_recording(), "is_recording() should return false when no recorder is registered")

# Verifies that is_recording() reflects the recorder's current state
func test_is_recording_reflects_recorder_state() -> void:
	_manager.register_recorder(_mock_recorder)
	_mock_recorder.is_recording = true
	assert_true(_manager.is_recording(), "is_recording() should return true when recorder is active")

#Verifies that is_recording() returns false after the recorder stops
func test_is_recording_returns_false_after_stop() -> void:
	_manager.register_recorder(_mock_recorder)
	_mock_recorder.is_recording = true
	_manager.stop_recording()
	assert_false(_manager.is_recording(), "is_recording() should return false after stop_recording() is called ")
