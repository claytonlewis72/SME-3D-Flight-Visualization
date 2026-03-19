#Authors: Aramis Hernandez

extends Node

func _ready():
	$CameraManager.set_target($"Rendering Manager/Drone") #Injection of drone for chased and fixed camera targeting
