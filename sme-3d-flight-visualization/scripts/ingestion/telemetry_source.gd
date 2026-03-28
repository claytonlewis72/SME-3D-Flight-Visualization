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
#|       Abstract base class for all telemetry sources.
#|       Any source that feeds data into TelemetryManager must extend this class
#|       and implement start() and stop().
#|
#|   POC         :
#|       Aramis Hernandez
#|
#|------------------------------------------------------------------------------------

@abstract
class_name TelemetrySource
extends Node

## Emitted when a processed pose packet is ready to forward.
signal telemetry_packet(data)

## Begin producing telemetry data.
@abstract func start()

## Stop producing telemetry data.
@abstract func stop()

## Pause data emission without fully stopping the source.
func pause():
	pass

## Resume data emission after a pause.
func resume():
	pass
