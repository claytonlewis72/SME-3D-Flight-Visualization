#Author: Aramis Hernandez

@abstract
class_name TelemetrySource

extends Node


signal telemetry_packet(data)

@abstract func start()
@abstract func stop()

func pause():
	pass

func resume():
	pass
