#|------------------------------------------------------------------------------------
#|	Unclassified
#|------------------------------------------------------------------------------------
#|
#|	SME Solutions, Inc.
#|	Copyright 2026 SME Solutions, Inc. All Rights Reserved
#|	SME Solutions Proprietary Information
#|
#|------------------------------------------------------------------------------------
#|
#|	File Name	:test_camera_manager.gd
#|
#|	Target 		:GD script
#|
#|	Description	: Handles switching between drone models. May be changed in the future with GUI changeds 
#|                and other integrations.
#|
#|	Notes		: This hasn't been formally unit tested. 
#|
#|	POC			: Clayton Lewis
#|------------------------------------------------------------------------------------

extends Node3D

@onready var plane_model = $plane2_9
@onready var drone_model = $drone3

var using_plane := true

func _ready():
	update_models()

func _input(event):
	if event.is_action_pressed("swap_vehicle"):
		using_plane = !using_plane
		update_models()

func update_models():
	plane_model.visible = using_plane
	drone_model.visible = !using_plane
