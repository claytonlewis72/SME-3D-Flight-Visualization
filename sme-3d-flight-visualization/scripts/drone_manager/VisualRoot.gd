extends Node3D

@onready var plane_model = $plane2_9
@onready var drone_model = $drone3

var using_plane := true

func _ready():
	update_models()

func _input(event):
	if event.is_action_pressed("vehicle_swap"):
		using_plane = !using_plane
		update_models()

func update_models():
	plane_model.visible = using_plane
	drone_model.visible = !using_plane
