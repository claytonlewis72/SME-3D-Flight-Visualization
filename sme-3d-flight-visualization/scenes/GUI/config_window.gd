extends Window

@onready var telemetry_dropdown = $MarginContainer/VBoxContainer/TelemetrySource/OptionButton
@onready var csv_file_dialog = $MarginContainer/VBoxContainer/CSVFileDialog
@onready var csv_ingestion = get_node("/root/Main/IngestionManager")
@onready var vehicle_dropdown := $MarginContainer/VBoxContainer/DroneModel/OptionButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	telemetry_dropdown.item_selected.connect(_on_telemetry_source_selected)
	vehicle_dropdown.clear()
	vehicle_dropdown.add_item("drone_3")
	vehicle_dropdown.add_item("plane_2_9")
	populate_vehicle_dropdown()


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass

#func load_settings():
	# Load current values into UI
	#$VBoxContainer/OptionButton.select(DroneManager.current_model)
	#$VBoxContainer/SpeedSpinBox.value = TelemetryManager.csv_speed


func _on_close_requested() -> void:
	hide()
	#load_settings()


func _on_save_pressed() -> void:
	#read UI values and apply them
	#var selected_model = $VBoxContainer/DroneModelOptionButton.get_selected_id()
	#var csv_speed = $VBoxContainer/SpeedSpinBox.value

	# Apply to your game directly
	# Need csv_speed
	#TelemetryManager.csv_speed = csv_speed
	#Need drone models still
	#DroneManager.set_drone_model(selected_model)
	hide()
	
func _on_telemetry_source_selected(index):
	var choice = telemetry_dropdown.get_item_text(index)
	TelemetryManager.telemetry_source = choice

	if choice == "CSV":
		csv_file_dialog.popup()


func _on_csv_file_dialog_file_selected(path: String) -> void:
	csv_ingestion.replay_file_path = path
	csv_ingestion._load_file()
	TelemetryManager.telemetry_source = "CSV"


#Vehicle dropdown menu selector
func _on_vehicle_dropdown_item_selected(index: int) -> void:
	var choice = vehicle_dropdown.get_item_text(index)
	if choice == "Add Vehicle...":
		open_vehicle_file_dialog()
		return

	Drone_Manager.set_drone_model(choice)

#Vehicle Dialog
func open_vehicle_file_dialog():
	$MarginContainer/VBoxContainer/VehicleFileDialog.popup_centered()

#Vehicle selection from directory
func populate_vehicle_dropdown():
	vehicle_dropdown.clear()

	var dir := DirAccess.open("res://vehicles")
	if dir:
		dir.list_dir_begin()
		var file = dir.get_next()
		while file != "":
			if file.ends_with(".tscn"):
				vehicle_dropdown.add_item(file.get_basename())
			file = dir.get_next()

	vehicle_dropdown.add_separator()
	vehicle_dropdown.add_item("Add Vehicle...")

#File dialog for vehicle selection
func _on_file_dialog_file_selected(path: String) -> void:
	var file_name = path.get_file()
	var new_path = "res://vehicles/" + file_name

	var src := FileAccess.open(path, FileAccess.READ)
	var data := src.get_buffer(src.get_length())
	src.close()

	var dst := FileAccess.open(new_path, FileAccess.WRITE)
	dst.store_buffer(data)
	dst.close()

	populate_vehicle_dropdown()
