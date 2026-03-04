#Authors: Aramis Hernandez

extends Node

func _ready():
<<<<<<< Updated upstream
=======
	$CameraManager.set_target($"Rendering Manager/Drone") #Injection of drone for chased and fixed camera targeting
	
>>>>>>> Stashed changes
	$IngestionManager.pose_received.connect(
		$FlightPathRenderer.add_point
	)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
