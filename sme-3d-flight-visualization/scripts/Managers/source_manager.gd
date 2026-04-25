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

## Manages the active [TelemetrySource] and delegates transport commands to it.
##
## SourceManager is the single point of contact between the UI layer and the
## telemetry ingestion subsystem. It maintains a registry of all sources that
## have called [method register_source], exposes a single active source at any
## given time, and routes playback commands ([method pause], [method resume],
## [method stop], [method seek], [method load_file]) to that source.
##
## Sources registered here communicate pose data upstream through
## [TelemetryManager]. SourceManager and TelemetryManager are intentionally
## kept unaware of each other except at the [method seek] boundary, where
## SourceManager notifies [TelemetryManager] so downstream subscribers
## (e.g. renderers) can react to position changes.

#-------------------------------------------------------------------------------------
# Signals
#-------------------------------------------------------------------------------------

## Emitted when the active telemetry source changes.
##
## Parameters:
##   source_name : String
##       The registry key of the newly activated source (e.g. [code]"UDP"[/code],
##       [code]"PLAYBACK"[/code]).
signal source_changed(source_name: String)

#-------------------------------------------------------------

## Registry key of the currently active source.
##
## Defaults to [code]"UDP"[/code] on startup. Updated by [method set_source]
## whenever the active source changes.
var active_source_name: String = "UDP"


## The currently active [TelemetrySource] node.
##
## [code]null[/code] until the first call to [method set_source].
var _active_source: TelemetrySource = null


## Registry of all sources that have called [method register_source].
##
## Keys are source name strings (e.g. [code]"UDP"[/code], [code]"PLAYBACK"[/code]).
## Values are the corresponding [TelemetrySource] nodes.
var _sources: Dictionary = {}




## Adds a telemetry source to the registry under the given name.
##
## Called by each [TelemetrySource] node during its [method Node._ready] phase.
## Registering a source does not make it active; call [method set_source] to
## switch the active source.
##
## Parameters:
##   name : String
##       Unique identifier for this source (e.g. [code]"UDP"[/code], [code]"PLAYBACK"[/code]).
##   source : TelemetrySource
##       The source node to register.
func register_source(name: String, source: TelemetrySource) -> void:
	_sources[name] = source
	print("[SourceManager] Registered source: %s" % name)



## Switches the active telemetry source to the one registered under the given name.
##
## Stops the currently active source before activating the new one. Emits
## [signal source_changed] after the transition completes. Logs an error and
## returns early if the requested name is not found in the registry.
##
## Parameters:
##   name : String
##       The registry key of the source to activate.
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


 
## Pauses the active telemetry source.
##
## Has no effect if no source is currently active.
func pause() -> void: 
	if _active_source == null:
		return 
	_active_source.pause()

 
## Resumes the active telemetry source.
##
## Has no effect if no source is currently active.
func resume() -> void:
	if _active_source == null:
		return 
	_active_source.resume()


## Stops the active telemetry source.
##
## Has no effect if no source is currently active.
func stop() -> void:
	if _active_source == null:
		return
	_active_source.stop()


## Loads a recording file into the active source if it supports file loading.
##
## Delegates to the active source's [method load_file] method. This is only
## meaningful when the active source is [code]PlaybackSource[/code]. Logs an
## error and returns [code]false[/code] if no source is active or if the active
## source does not implement [method load_file].
##
## Parameters:
##   path : String
##       Absolute or [code]res://[/code] relative path to the [code].bin[/code]
##       recording file to load.
##
## Returns:
##   [code]true[/code] if the file was loaded successfully, [code]false[/code] otherwise.
func load_file(path: String) -> bool:
	if _active_source == null:
		push_error("[SourceManager] No active source.")
		return false
	if not _active_source.has_method("load_file"):
		push_error("[SourceManager] Active source does not support load_file().")
		return false
	return _active_source.load_file(path)



## Seeks the active source to the specified frame index and notifies subscribers.
##
## Delegates the seek to the active source if it implements [method seek], then
## calls [method TelemetryManager.forward_seeked] so downstream subscribers such
## as renderers can clear stale state and prepare for replay from the new position.
## Has no effect if no source is active or if the active source does not implement
## [method seek].
##
## Parameters:
##   index : int
##       The zero-based frame index to seek to.
func seek(index: int) -> void:
	if _active_source == null:
		return
	if _active_source.has_method("seek"):
		_active_source.seek(index)
		TelemetryManager.forward_seeked(index)


## Returns whether the active source has a recording loaded and ready for playback.
##
## Delegates to the active source's [method has_recording] method. Returns
## [code]false[/code] if no source is active or if the active source does not
## implement [method has_recording].
##
## Returns:
##   [code]true[/code] if a recording is loaded, [code]false[/code] otherwise.
func has_recording() -> bool:
	if _active_source == null:
		return false
	if _active_source.has_method("has_recording"):
		return _active_source.has_recording()
	return false
