extends Node


@export var TEST_PATH : String = "user://data/recorded_flightpath"
var full_path = ProjectSettings.globalize_path(TEST_PATH)
	

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_write()
#	_read()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _read() -> void:
	var file := FileAccess.open(full_path, FileAccess.READ)
	if file == null:
		push_error("could not open file for writing.")
		return
	var value := file.get_32()
	file.close()
	print("Read back: ", value)

func _write() -> void:
	var file := FileAccess.open(full_path, FileAccess.WRITE)
	
	if file == null:
		push_error("Could not open file for writing.")
		return
	file.store_32(80)
	file.close()
	print("Wrote 80 to ", ProjectSettings.globalize_path(TEST_PATH))
