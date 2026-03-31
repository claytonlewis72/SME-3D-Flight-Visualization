extends Window
# Nicholas Tran

@onready var telemetry_dropdown = $MarginContainer/VBoxContainer/TelemetrySource/OptionButton
@onready var csv_file_dialog = $MarginContainer/VBoxContainer/CSVFileDialog
@onready var csv_ingestion = get_node("/root/Main/IngestionManager")
@onready var vehicle_dropdown := $MarginContainer/VBoxContainer/DroneModel/OptionButton
@onready var controls_header = $MarginContainer/VBoxContainer/ControlsSection/ControlsHeader
@onready var controls_container = $MarginContainer/VBoxContainer/ControlsSection/ControlsContainer


var original_pos: Vector3
var original_rot: Vector3
var original_vel: Vector3

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	telemetry_dropdown.item_selected.connect(_on_telemetry_source_selected)
	#Populates Vehicle drop down with scenes from vehicle folder
	vehicle_dropdown.clear()
	vehicle_dropdown.add_item("drone_3")
	vehicle_dropdown.add_item("plane_2_9")
	populate_vehicle_dropdown()
	
	# Contorls container starting state
	controls_container.visible = false
	controls_header.text = "Controls ▸"
	controls_header.pressed.connect(_on_controls_header_pressed)
	# Force layout update
	await get_tree().process_frame
	size = Vector2.ZERO
	
	
func open_config_window():
	load_settings()  # fill UI with current drone values

	# store originals
	if Drone_Manager.current_drone:
		original_pos = Drone_Manager.current_drone.global_position
		original_rot = Drone_Manager.current_drone.global_rotation
		original_vel = Drone_Manager.current_drone.velocity if Drone_Manager.current_drone.has_variable("velocity") else Vector3.ZERO

	popup_centered()

# Saves values prior to being saved
func load_settings() -> void:
	if Drone_Manager.current_drone:
		var d = Drone_Manager.current_drone

		$MarginContainer/VBoxContainer/Position/PosX.value = d.global_position.x
		$MarginContainer/VBoxContainer/Position/PosY.value = d.global_position.y
		$MarginContainer/VBoxContainer/Position/PosZ.value = d.global_position.z
		
		$MarginContainer/VBoxContainer/Rotation/RotX.value = d.global_rotation.x
		$MarginContainer/VBoxContainer/Rotation/RotY.value = d.global_rotation.y
		$MarginContainer/VBoxContainer/Rotation/RotZ.value = d.global_rotation.z

func _on_close_requested():
	# restore original values
	Drone_Manager.set_drone_position(original_pos)
	Drone_Manager.set_drone_rotation(original_rot)
	Drone_Manager.set_drone_velocity(original_vel)

	hide()


func _on_save_pressed() -> void:
	# Saves vehicles telemetry data
	var pos = Vector3(
		$MarginContainer/VBoxContainer/Position/PosX.value,
		$MarginContainer/VBoxContainer/Position/PosY.value,
		$MarginContainer/VBoxContainer/Position/PosZ.value
	)

	var rot = Vector3(
		$MarginContainer/VBoxContainer/Rotation/RotX.value,
		$MarginContainer/VBoxContainer/Rotation/RotY.value,
		$MarginContainer/VBoxContainer/Rotation/RotZ.value
	)

	var vel = Vector3(
	$MarginContainer/VBoxContainer/Velocity/VelX.value,
	$MarginContainer/VBoxContainer/Velocity/VelY.value,
	$MarginContainer/VBoxContainer/Velocity/VelZ.value
	)

	Drone_Manager.set_drone_position(pos)
	Drone_Manager.set_drone_rotation(rot)
	Drone_Manager.set_drone_velocity(vel)

	# Save all keybinds
	save_all_keybinds()
	hide()

	
func _on_telemetry_source_selected(index):
	var choice = telemetry_dropdown.get_item_text(index)
	TelemetryManager.telemetry_source = choice

	if choice == "CSV":
		csv_file_dialog.popup()

# Opens file dialog for CSV
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
	
# Controls header expansion
func _on_controls_header_pressed():
	controls_container.visible = !controls_container.visible
	controls_header.text = "Controls ▾" if controls_container.visible else "Controls ▸"
	# Force the window to recalc its size
	await get_tree().process_frame
	size = Vector2.ZERO

# Saves all bindings when save is pressed
func save_all_keybinds():
	var cfg := ConfigFile.new()
	cfg.load("user://controls.cfg")

	# Save every action in the InputMap
	for action in InputMap.get_actions():
		var events = InputMap.action_get_events(action)
		if events.size() > 0 and events[0] is InputEventKey:
			cfg.set_value("bindings", action, events[0].physical_keycode)

	cfg.save("user://controls.cfg")
