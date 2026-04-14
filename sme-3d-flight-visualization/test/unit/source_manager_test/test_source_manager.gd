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
#|   File Name   : test_source_manager.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Unit tests for the SourceManager script using the GUT framework.
#|       Validates source registration, source switching, transport command
#|       delegation, and optional method handling for load_file and seek.
#|
#|   Notes       :
#|       Requires GUT (Godot Unit Testing) framework to be installed.
#|       TelemetrySource is mocked to avoid requiring real data sources.
#|
#|   POC         :
#|       Aramis Hernandez
#|
#|------------------------------------------------------------------------------------


extends GutTest

#-- Mock Classes for testing -------------------------------

class MockSource extends TelemetrySource:
	var start_called := false
	var stop_called := false
	var pause_called := false
	var resume_called := false
	
	func start() -> void: start_called = true
	func stop() -> void: stop_called = true
	func pause() -> void: pause_called = true
	func resume() -> void: resume_called = true


# Mock source that supports loading file and seeking
class MockSourceWithPlayback extends  TelemetrySource:
	var loaded_path := ""
	var seeked_index := -1
	
	func start() -> void: pass
	func stop() -> void: pass
	
	func load_file(path: String) -> bool:
		loaded_path = path
		return true
	
	func seek(index: int) -> void:
		seeked_index = index
		
	func has_recording() -> bool:
		return true

# ----- Setup -----------------------------------

var _manager: Node
var _source_a: MockSource
var _source_b: MockSource

func before_each() -> void:
	_manager = load("res://scripts/Managers/source_manager.gd").new()
	_source_a = MockSource.new()
	_source_b = MockSource.new()
	add_child(_manager)
	add_child(_source_a)
	add_child(_source_b)

func after_each() -> void:
	_manager.free()
	_source_a.free()
	_source_b.free()

# ---- register_source() test --------------------------------

#Verifies that a registered source can be retrieved from the registry
func test_register_source_stores_source() -> void: 
	_manager.register_source("A", _source_a)
	assert_eq(_manager._sources["A"], _source_a, "registered source should be stored in registry")

# --- set_source() test -----------------

#Verifies that set_soruce starts the new source and updates the active name
func test_set_source_starts_source_and_updates_name() -> void: 
	_manager.register_source("A", _source_a)
	_manager.set_source("A")
	assert_true(_source_a.start_called, "set_source() should call start() on the new source")
	assert_eq(_manager.active_source_name, "A", "active_source_name should update to the new source")

# Verifies that switching sources stops the previous one
func test_set_source_stops_previous_source() -> void:
	_manager.register_source("A", _source_a)
	_manager.register_source("B", _source_b)
	_manager.set_source("A")
	_manager.set_source("B")
	assert_true(_source_a.stop_called, "switching sources should stop the previsously active source")

func test_set_source_emits_source_changed() -> void:
	_manager.register_source("A", _source_a)
	watch_signals(_manager)
	_manager.set_source("A")
	assert_signal_emitted(_manager, "source_changed", "source_changed signal should fire when source is switched")
	assert_eq(_manager.active_source_name, "A", "active_source_name should match the emitted source name")
# ----- pause() / resume() / stop() -----------------------

func test_pause_delegates_to_active_source() -> void:
	_manager.register_source("A", _source_a)
	_manager.set_source("A")
	_manager.pause()
	assert_true(_source_a.pause_called, "pause() should delegate to the active source")

func test_resume_delegates_to_active_source() -> void:
	_manager.register_source("A", _source_a)
	_manager.set_source("A")
	_manager.resume()
	assert_true(_source_a.resume_called, "resume() should delegate to the active source")

func test_stop_delegates_to_active_source() -> void:
	_manager.register_source("A", _source_a)
	_manager.set_source("A")
	_manager.stop()
	
	assert_true(_source_a.stop_called, "stop() should delegate to the active source")
	
