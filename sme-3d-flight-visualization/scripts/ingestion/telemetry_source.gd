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
#|   File Name   : telemetry_source.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Abstract base class defining the interface all telemetry sources must
#|       implement. Concrete subclasses (live UDP, file playback, simulation,
#|       etc.) override start, stop, pause, and resume to manage their own
#|       data pipeline, and emit telemetry_packet whenever a new data frame
#|       is ready for consumption by TelemetryManager.
#|
#|   POC         : Aramis Hernandez
#|
#|------------------------------------------------------------------------------------


extends Node
class_name TelemetrySource

## Abstract base class defining the interface all telemetry sources must implement.
##
## Concrete subclasses represent distinct data origins — live UDP streams,
## binary file playback, simulated data generators, and so on. Each subclass
## overrides [method start], [method stop], [method pause], and [method resume]
## to manage its own acquisition pipeline, and emits [signal telemetry_packet]
## whenever a new frame of telemetry data is ready.
##
## [TelemetryManager] depends on this interface to remain source-agnostic;
## it connects to [signal telemetry_packet] without needing to know whether
## data originates from hardware or a recording file.


## Emitted by a concrete subclass whenever a new telemetry frame is available.
##
## Subscribers should read the following keys from [param data]:
## [codeblock]
##   data["pos"]  : Vector3  # vehicle position in world coordinates
##   data["rot"]  : Vector3  # vehicle rotation as Euler angles in radians
##   data["time"] : float    # frame timestamp in seconds
##   data["gap"]  : bool     # true if a discontinuity precedes this frame
## [/codeblock]
## Concrete subclasses are responsible for populating all expected keys before
## emitting. Consumers should treat missing keys as a malformed packet.
##
## Parameters:
##   data : Dictionary
##       Key-value payload for one telemetry frame.
signal telemetry_packet(data: Dictionary)


## Begins telemetry acquisition.
##
## Concrete subclasses override this method to open sockets, begin file
## reads, start timers, or perform any other setup required to produce
## [signal telemetry_packet] emissions. The base implementation is a no-op.
func start() -> void:
	pass


## Halts telemetry acquisition and releases any held resources.
##
## Concrete subclasses override this method to close sockets, stop threads,
## or finalize any open file handles. After this call, no further
## [signal telemetry_packet] emissions should occur until [method start]
## is called again. The base implementation is a no-op.
func stop() -> void:
	pass



## Temporarily suspends telemetry packet emission without releasing resources.
##
## Concrete subclasses override this method to pause playback timers, halt
## polling loops, or otherwise stop emitting [signal telemetry_packet] while
## keeping the underlying source ready to resume. The base implementation is
## a no-op.
func pause() -> void:
	pass



## Resumes a previously paused telemetry source.
##
## Concrete subclasses override this method to restart playback timers or
## polling loops that were suspended by [method pause]. Has no defined
## behavior if called without a preceding [method pause]. The base
## implementation is a no-op.
func resume() -> void:
	pass
