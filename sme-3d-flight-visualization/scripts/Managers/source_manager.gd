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
#|   File Name   : source_manager.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       SourceManager is a global singleton responsible for managing the
#|       active TelemetrySource. It is the only system that holds references
#|       to source nodes and delegates transport commands to them.
#|
#|       The UI talks to SourceManager. Sources talk to TelemetryManager.
#|       TelemetryManager never knows sources exist.
#|
#|   Autoload    :
#|       Register as "SourceManager" in Project > Project Settings > Autoload.
#|
#|   POC         :
#|       Aramis Hernandez
#|
#|------------------------------------------------------------------------------------

extends Node

#-------------------------------------------------------------------------------------
# Signals
#-------------------------------------------------------------------------------------

## Emitted when the active source changes
signal source_changed(source_name: String)


## The identifier of the currently active source.
var active_source_name: String = "UDP"

## THe currently active TelemetrySource node.
var _active_source: TelemetrySource = null

## Registry of all registered sources by name.
var _sources: Dictionary = {}

func register_source(name: String, source: TelemetrySource) -> void:
	_sources[name] = source
	print("[SourceManager] Registered source: %s" % name)



func set_source(name: String) -> void:
	if not _sources.has(name):
		push_error("[SourceManager] Unknown source: %s" % name)
		return
	
	#Stop current source
	if _active_source != null:
		_active_source.stop()
	
	_active_source = _sources[name]
	active_source_name = name
	_active_source.start()
	
	source_changed.emit(name)
	print("[SourceManager] Active source -> %s" % name)

## Pause the active source
func pause() -> void: 
	if _active_source == null:
		return 
	_active_source.pause()

## Resumes the active source
func resume() -> void:
	if _active_source == null:
		return 
	_active_source.resume()
	
## Stops the active source.
func stop() -> void:
	if _active_source == null:
		return
	_active_source.stop()

## Loads a file into the active source if it supports it.
## Only meaningful when the active source is PlaybackSource.
func load_file(path: String) -> bool:
	if _active_source == null:
		push_error("[SourceManager] No active source.")
		return false
	if not _active_source.has_method("load_file"):
		push_error("[SourceManager] Active source does not support load_file().")
		return false
	return _active_source.load_file(path)

## Seeks to a frame index in the active source if it supports it.
## Notifies TelemetryManager so subscribers such as renderers
## can react to the position change.
func seek(index: int) -> void:
	if _active_source == null:
		return
	if _active_source.has_method("seek"):
		_active_source.seek(index)
		TelemetryManager.forward_seeked(index)

## Returns true if the active source has a recording loaded.
func has_recording() -> bool:
	if _active_source == null:
		return false
	if _active_source.has_method("has_recording"):
		return _active_source.has_recording()
	return false
