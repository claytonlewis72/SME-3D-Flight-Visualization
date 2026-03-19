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

## TelemetryManager is a global singleton responsible for distributing
## telemetry data across the visualization system.
##
##       The component acts as a centralized telemetry bus between the data
##       ingestion subsystem (e.g ingestion_UDP.gd) and any system components
##       that consume telemetry data.
##       Instead of systems directly referencing the data ingestion module,
##       they subscribe to TelemetryManager signals. This design decouples
##       telemetry producers from telemetry consumers and improves system
##       modularity.

#-------------------------------------------------------------------------------------
# Signals
#-------------------------------------------------------------------------------------

## Emitted when a new pose update is received from the telemetry source.
## 
## Parameters:
##   position : Vector3
##       Aircraft or object position in simulation space.
##
##   rotation : Vector3
##       Rotation values (Euler angles) representing orientation.
##
##   gap : bool
##       Indicates whether a telemetry discontinuity or packet gap occurred.
##
##   time : float
##       Timestamp associated with the telemetry packet.
signal pose_received(position: Vector3, rotation: Vector3, gap : bool, time)

## Emitted when a full telemetry packet is received.
##
## Parameters:
##   data : Dictionary
##       Raw telemetry data packet containing all transmitted fields.
signal telemetry_updated(data)


#-------------------------------------------------------------------------------------
# Interface Methods
#-------------------------------------------------------------------------------------

## Forwards pose telemetry to all subscribed systems.
##
## This function should be called by the telemetry ingestion module
## when a new pose update is received.
##
## Parameters:
##   position : Vector3
##   rotation : Vector3
##   gap : bool
##   time : float
func forward_pose(position: Vector3, rotation: Vector3, gap: bool, time):
	pose_received.emit(position, rotation, gap, time)

## Forwards a complete telemetry packet to subscribed components.
##
## This is typically used by debug interfaces, telemetry monitors,
## or logging systems that require access to the full packet data.
##
## Parameters:
##   data : Dictionary
##       Raw telemetry data packet.
func forward_packet(data: Dictionary):
	telemetry_updated.emit(data)
