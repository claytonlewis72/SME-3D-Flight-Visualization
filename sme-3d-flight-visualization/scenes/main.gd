#Authors: Aramis Hernandez

extends Node

func _ready():
	$CameraManager.set_target($"Rendering Manager/Drone") #Injection of drone for chased and fixed camera targeting
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
