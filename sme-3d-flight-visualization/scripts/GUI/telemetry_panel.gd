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
#|   File Name   : telemetry_panel.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Telemetry panel that displays all nesscary telemetry info.
#|       
#|
#|   Notes       :
#|       This component has not been formally unit tested.
#|
#|   POC         :
#|       Aramis Hernandez
#|
#|------------------------------------------------------------------------------------

extends PanelContainer


## TelemetryPanel UI component responsible for displaying telemetry data
## received from the TelemetryManager singleton.
##
## This panel subscribes to telemetry signals and updates its UI fields
## whenever new telemetry data is received.
##
## Data Source:
## TelemetryManager.pose_received
##
## Related Components:
## - telemetry_manager.gd
## - ingestion_udp.gd


## Label node used to display the current position value received
## from telemetry updates.
@onready var position_value = $MarginContainer/VBoxContainer/TelemetryGrid/PositionValue


## Initializes the telemetry panel.
##
## Connects the panel to the TelemetryManager pose_received signal so
## that the UI can update whenever new telemetry pose data is available.
func _ready():
	TelemetryManager.pose_received.connect(_update_pose)


## Updates the telemetry panel when new pose data is received.
##
## Connected to:
## TelemetryManager.pose_received
##
## Parameters:
## - pos (Vector3): Current position of the aircraft or object.
## - rot (Vector3): Current rotation/orientation.
## - gap (bool): Indicates if a telemetry packet gap occurred.
## - time (float): Timestamp associated with the telemetry update.
##
## Currently only the position field is displayed in the UI.
func _update_pose(pos: Vector3, rot: Vector3, gap: bool, time):
	position_value.text = str(pos)
