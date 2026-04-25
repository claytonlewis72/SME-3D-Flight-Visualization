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
#|   File Name   : telemetry_manager.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       TelemetryManager is a global singleton responsible for distributing
#|       telemetry data across the visualization system.
#|
#|       The component acts as a centralized telemetry bus between the data
#|       ingestion subsystem (e.g., UDP receiver) and any system components
#|       that consume telemetry data.
#|
#|       Instead of systems directly referencing the data ingestion module,
#|       they subscribe to TelemetryManager signals. This design decouples
#|       telemetry producers from telemetry consumers and improves system
#|       modularity.
#|
#|   Notes       :
#|       This component has not been formally unit tested.
#|
#|   POC         :
#|       Aramis Hernandez
#|
#|------------------------------------------------------------------------------------

extends Node

## Centralized telemetry bus that decouples data producers from data consumers.
##
## TelemetryManager acts as a global singleton signal relay between the data
## ingestion subsystem (e.g. [code]ingestion_UDP.gd[/code], [code]playback_source.gd[/code])
## and any downstream systems that consume telemetry data such as renderers,
## UI panels, and recording components.
##
## Producers call the [code]forward_*[/code] interface methods, which emit the
## corresponding signals to all connected subscribers. No producer needs a direct
## reference to any consumer, and no consumer needs a direct reference to any
## producer — all communication flows through this node.
 

#-------------------------------------------------------------------------------------
# Signals
#-------------------------------------------------------------------------------------

## Emitted when a new pose update is received from the active telemetry source.
##
## Parameters:
##   position : Vector3
##       Vehicle position in world coordinates.
##   rotation : Vector3
##       Vehicle orientation as Euler angles in radians (roll, pitch, yaw).
##   gap : bool
##       [code]true[/code] if a telemetry discontinuity or packet loss occurred
##       immediately before this update.
##   time : float
##       Timestamp associated with this pose frame in seconds.
signal pose_received(position: Vector3, rotation: Vector3, gap : bool, time)

## Emitted when a complete raw telemetry packet is received from the ingestion layer.
##
## Parameters:
##   data : Dictionary
##       Full telemetry data packet containing all transmitted fields.
signal telemetry_updated(data)

## Emitted each process tick during playback to report progress through the recording.
##
## Parameters:
##   current_index : int
##       The index of the frame most recently emitted by the playback source.
##   total_frames : int
##       The total number of frames in the loaded recording.
signal frame_changed(current_index: int, total_frames: int)

## Emitted when a recording file has been successfully parsed and loaded into memory.
##
## Parameters:
##   file_path : String
##       Absolute path to the loaded [code].bin[/code] recording file.
##   frame_count : int
##       Total number of frames contained in the recording.
signal recording_loaded(file_path:String, frame_count: int)

## Emitted when playback reaches the final frame of the loaded recording.
signal playback_completed()

## Emitted when a new recording session is opened and data is being written to disk.
##
## Parameters:
##   file_path : String
##       Absolute path to the [code].bin[/code] file being written.
signal recording_started(file_path: String)


## Emitted when an active recording session is finalized and the file is closed.
##
## Parameters:
##   file_path : String
##       Absolute path to the completed [code].bin[/code] recording file.
##   frame_count : int
##       Total number of frames written to the file.
signal recording_stopped(file_path: String, frame_count: int)

## Emitted when the user seeks to a specific frame during playback.
##
## Subscribers such as [code]flightpath_renderer.gd[/code] use this signal to
## clear stale path data and prepare for replay from the new position.
##
## Parameters:
##   index : int
##       The zero-based frame index that was seeked to.
signal seeked(index: int)

#-------------------------------------------------------------------------------------
# Interface Methods
#-------------------------------------------------------------------------------------

 
## Relays a pose update to all subscribers of [signal pose_received].
##
## Called by the active telemetry source (e.g. [code]ingestion_UDP.gd[/code] or
## [code]playback_source.gd[/code]) whenever a new pose frame is available.
##
## Parameters:
##   position : Vector3
##       Vehicle position in world coordinates.
##   rotation : Vector3
##       Vehicle orientation as Euler angles in radians (roll, pitch, yaw).
##   gap : bool
##       [code]true[/code] if a telemetry discontinuity preceded this frame.
##   time : float
##       Timestamp associated with this pose frame in seconds.
func forward_pose(position: Vector3, rotation: Vector3, gap: bool, time):
	pose_received.emit(position, rotation, gap, time)


## Relays a complete raw telemetry packet to all subscribers of [signal telemetry_updated].
##
## Typically called by debug interfaces, telemetry monitors, or logging systems
## that require access to the full packet beyond position and rotation.
##
## Parameters:
##   data : Dictionary
##       Raw telemetry data packet containing all transmitted fields.
func forward_packet(data: Dictionary):
	telemetry_updated.emit(data)


## Relays playback frame progress to all subscribers of [signal frame_changed].
##
## Called by [code]playback_source.gd[/code] each time a frame is emitted during
## playback so UI elements such as scrub bars can reflect the current position.
##
## Parameters:
##   current_index : int
##       The index of the frame most recently emitted by the playback source.
##   total_frames : int
##       The total number of frames in the loaded recording.
func forward_frame_changed(current_index: int, total_frames: int) -> void:
	frame_changed.emit(current_index, total_frames)


## Relays a recording-loaded notification to all subscribers of [signal recording_loaded].
##
## Called by [code]playback_source.gd[/code] after a [code].bin[/code] file has
## been successfully parsed and its frames buffered in memory.
##
## Parameters:
##   file_path : String
##       Absolute path to the loaded recording file.
##   frame_count : int
##       Total number of frames contained in the recording.
func forward_recording_loaded(file_path: String, frame_count: int) -> void:
	recording_loaded.emit(file_path, frame_count)


## Relays a playback-completed notification to all subscribers of [signal playback_completed].
##
## Called by [code]playback_source.gd[/code] when the final frame of the loaded
## recording has been emitted.
func forward_playback_completed() -> void:
	playback_completed.emit()

## Relays a recording-started notification to all subscribers of [signal recording_started].
##
## Called by [code]flight_recorder.gd[/code] when a new recording session is opened
## and frame data is being written to disk.
##
## Parameters:
##   file_path : String
##       Absolute path to the [code].bin[/code] file being written.
func forward_recording_started(file_path: String) -> void:
	recording_started.emit(file_path)


## Relays a recording-stopped notification to all subscribers of [signal recording_stopped].
##
## Called by [code]flight_recorder.gd[/code] after the active recording file has
## been finalized and closed.
##
## Parameters:
##   file_path : String
##       Absolute path to the completed recording file.
##   frame_count : int
##       Total number of frames written to the file.
func forward_recording_stopped(file_path: String, frame_count: int) -> void:
	recording_stopped.emit(file_path, frame_count)

## Relays a seek event to all subscribers of [signal seeked].
##
## Called by [code]source_manager.gd[/code] when a seek operation is performed
## on the active playback source so subscribers can reset any state that depends
## on sequential frame order (e.g. clearing the rendered flight path).
##
## Parameters:
##   index : int
##       The zero-based frame index that was seeked to.
func forward_seeked(index: int) -> void:
	seeked.emit(index)
