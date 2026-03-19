extends Control

@export var sender_path: String = "res://SME-tool/sender.py"
@export var python_path: String = "python3" # Path to Python

#THIS IS TEMP. THE SAVE BUTTON WILL NOT BE USED TO PLAY THE SENDER.
@onready var run_button: Button = $VBoxContainer/Save


func _ready():
	run_button.pressed.connect(_on_run_telemetry_pressed)

#Makes sure we have the python script in the app even when exported
#Godot when exported hides files in res:// 
# This ensures python scripts instead exists in user://
func _ensure_python_script() -> String:
	var script_path = "user://sender.py"
	
	# Check if the file exists in user://
	if not FileAccess.file_exists(script_path):
		# Open the source file from res://
		var src := FileAccess.open(sender_path, FileAccess.READ)
		if src == null:
			push_error("Failed to open sender.py in res://")
			return ""
		var content := src.get_as_text()
		src.close()
		
		# Create the destination file in user://
		var dst := FileAccess.open(script_path, FileAccess.WRITE)
		if dst == null:
			push_error("Failed to write sender.py to user://")
			return ""
		dst.store_string(content)
		dst.close()
		
		print("Python script copied to user://sender.py")
		
	return script_path

func _on_run_telemetry_pressed():
	#var script_path = _ensure_python_script()
	var script_path = sender_path
	
	#Safety check
	if script_path == "" or not FileAccess.file_exists(script_path):
		push_error("Cannot run sender.py - script path invalid")
		return
	
	print("script path:", script_path)
	#OS.execute needs a packed string to run.
	var args := PackedStringArray()
	args.append(script_path)
	
	
	# Run sender.py without any arguments
	#COME BACK TO THIS. THESE TWO LINES ARE BUGGED.
	var result := OS.execute(python_path, args)
	print("Running sender.py via OS.execute()", result)
