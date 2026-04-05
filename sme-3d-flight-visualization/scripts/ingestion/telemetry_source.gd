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
#|       Bass Class / Interface
#|
#|   POC         :
#|       Aramis Hernandez
#|
#|------------------------------------------------------------------------------------

extends Node
class_name TelemetrySource

signal telemetry_packet(data: Dictionary)

func start() -> void:
	pass

func stop() -> void:
	pass

func pause() -> void:
	pass

func resume() -> void:
	pass
