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
#|   File Name   : recording_manager.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       RecordingManager is a global singleton responsible for managing the
#|       active flight recorder. It is the only system that holds a reference
#|       to the recorder node and delegates recording commands to it.
#|
#|       The UI talks to RecordingManager. The recorder talks to TelemetryManager.
#|       RecordingManager never interacts with telemetry data directly.
#|
#|   Autoload    :
#|       Register as "RecordingManager" in Project > Project Settings > Autoload.
#|
#|   POC         :
#|       Aramis Hernandez
#|
#|------------------------------------------------------------------------------------

extends Node

## Manages the active flight recorder and delegates recording commands to it.
##
## RecordingManager is the single point of contact between the UI layer and
## the recording subsystem. It holds a reference to the registered recorder
## node and routes start, stop, and status commands to it.
##
## The recorder node ([code]flight_recorder.gd[/code]) registers itself during
## its [method Node._ready] phase via [method register_recorder]. Until a
## recorder is registered, all command methods log an error and return early.


## The currently registered recorder node.
##
## [code]null[/code] until a recorder calls [method register_recorder].
var _recorder: Node = null


## Registers a recorder node with this manager.
##
## Called by [code]flight_recorder.gd[/code] during its [method Node._ready]
## phase. Only one recorder can be active at a time; calling this again will
## silently replace the previously registered recorder.
##
## Parameters:
##   recorder : Node
##       The recorder node to register. Expected to expose
##       [method start_recording], [method stop_recording], and the
##       [member is_recording] property.
func register_recorder(recorder: Node) -> void:
	_recorder = recorder
	print("[RecordingManager] Recorder registered.")


## Starts a new recording session on the registered recorder.
##
## Delegates to [method flight_recorder.start_recording]. Logs an error and
## returns early if no recorder has been registered.
##
## Parameters:
##   custom_name : String
##       Optional base filename for the recording (without extension). If empty,
##       the recorder generates a timestamp-based filename automatically.
func start_recording(custom_name: String = "") -> void:
	if _recorder == null:
		push_error("[RecordingManager] No recorder registered.")
		return
	_recorder.start_recording(custom_name)


## Stops the active recording session on the registered recorder.
##
## Delegates to [method flight_recorder.stop_recording], which finalizes the
## file header and closes the recording file. Logs an error and returns early
## if no recorder has been registered.
func stop_recording() -> void:
	if _recorder == null:
		push_error("[RecordingManager] No recorder registered.")
		return 
	_recorder.stop_recording()


## Returns whether a recording session is currently active.
##
## Reads the [member flight_recorder.is_recording] property from the registered
## recorder. Returns [code]false[/code] if no recorder has been registered.
##
## Returns:
##   [code]true[/code] if the recorder is actively writing frames, [code]false[/code] otherwise.
func is_recording() -> bool:
	if _recorder == null:
		return false
	return _recorder.is_recording
