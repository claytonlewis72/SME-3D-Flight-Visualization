#Author: Aramis Hernandez

extends PanelContainer

@onready var position_value = $MarginContainer/VBoxContainer/TelemetryGrid/PositionValue

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

#NOTE
#currently this is recieving the signal from the UDP data ingester. THIS IS NOT WHAT IS WANTED PERMANTELY
#want to work on a telemetry manager singleton that will handle all of the signals for telemetry and nodes that need that info. 
func update_telemetry(pos, rot, gap):
	position_value.text = str(pos)
