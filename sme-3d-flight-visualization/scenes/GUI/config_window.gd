extends Window
# Nicholas Tran

@onready var csv_ingestion = get_node("/root/Main/IngestionManager")
@onready var vehicle_dropdown := $MarginContainer/VBoxContainer/DroneModel/OptionButton
@onready var controls_header = $MarginContainer/VBoxContainer/ControlsSection/ControlsHeader
@onready var controls_container = $MarginContainer/VBoxContainer/ControlsSection/ControlsContainer
@onready var config_dialog = $MarginContainer/VBoxContainer/ConfigFileDialog


var original_pos: Vector3
var original_rot: Vector3
var original_vel: Vector3


var pending_drone_model: String = ""
var loaded_config: Dictionary = {}


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
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
	reset_size()
	
	var load_button = $MarginContainer/VBoxContainer/HBoxContainer/LoadConfigButton
	load_button.pressed.connect(_on_load_config_button_pressed)
	var dialog = $MarginContainer/VBoxContainer/ConfigFileDialog
	dialog.file_selected.connect(_on_config_file_dialog_file_selected)
	
	vehicle_dropdown.item_selected.connect(_on_vehicle_dropdown_item_selected)

func open_config_window():
	# Load UI fields FIRST
	load_settings()

	# Store original values safely
	if Drone_Manager.current_drone:
		var d = Drone_Manager.current_drone
		original_pos = d.global_position
		original_rot = d.global_rotation

		if d.has_method("get_velocity"):
			original_vel = d.get_velocity()
		elif d.get_script() and d.get_script().has_property("velocity"):
			original_vel = d.velocity
		else:
			original_vel = Vector3.ZERO
	
	# Now actually open the window
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
		
		var vel: Vector3
		if d.has_method("get_velocity"):
			vel = d.get_velocity()
		elif d.get_script() and d.get_script().has_property("velocity"):
			vel = d.velocity
		else:
			vel = Vector3.ZERO

		$MarginContainer/VBoxContainer/Velocity/VelX.value = vel.x
		$MarginContainer/VBoxContainer/Velocity/VelY.value = vel.y
		$MarginContainer/VBoxContainer/Velocity/VelZ.value = vel.z

func _on_close_requested():
	# restore original values
	Drone_Manager.set_drone_position(original_pos)
	Drone_Manager.set_drone_rotation(original_rot)
	Drone_Manager.set_drone_velocity(original_vel)
	
	hide()

func _on_save_pressed() -> void:
	if loaded_config.size() > 0:
		apply_loaded_config(loaded_config)
	# Apply drone model if changed
	if pending_drone_model != "":
		Drone_Manager.set_drone_model(pending_drone_model)
	
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

	# Merge UI values back into loaded_config
	loaded_config["position"] = [pos.x, pos.y, pos.z]
	loaded_config["rotation"] = [rot.x, rot.y, rot.z]
	loaded_config["velocity"] = [vel.x, vel.y, vel.z]
	loaded_config["drone_model"] = pending_drone_model

	# Now save the full generic config
	var cfg = build_config_dictionary()
	var file = FileAccess.open("user://last_loaded_config.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(cfg, "\t"))
	file.close()
	# Save all keybinds
	_update_custom_config_from_ui()
	Drone_Manager.save_bindings()
	hide()

	
# Opens file dialog for CSV
func _on_csv_file_dialog_file_selected(path: String) -> void:
	csv_ingestion.replay_file_path = path
	csv_ingestion._load_file()
	TelemetryManager.telemetry_source = "CSV"


# Vehicle dropdown menu selector
func _on_vehicle_dropdown_item_selected(index: int) -> void:
	var choice = vehicle_dropdown.get_item_text(index)
	if choice == "Add Vehicle...":
		open_vehicle_file_dialog()
		return

	pending_drone_model = choice

# Vehicle Dialog
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

# Show files selectiong for config
func _on_load_config_button_pressed() -> void:
	open_config_window()
	config_dialog.popup_centered()

# Opens file access for JSON
func _on_config_file_dialog_file_selected(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Could not open config file")
		return

	var text = file.get_as_text()
	var parsed = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON config format")
		return
	
	loaded_config = parsed.duplicate(true)
	open_config_window()
	rebuild_custom_config_ui()

	
func apply_loaded_config(cfg: Dictionary):
	# Store full config (including custom fields)
	loaded_config = cfg.duplicate(true)

	# --- Apply known fields to drone + UI ---

	if cfg.has("position"):
		var p = cfg["position"]
		var pos = Vector3(p[0], p[1], p[2])
		Drone_Manager.set_drone_position(pos)

		# Update UI
		$MarginContainer/VBoxContainer/Position/PosX.value = pos.x
		$MarginContainer/VBoxContainer/Position/PosY.value = pos.y
		$MarginContainer/VBoxContainer/Position/PosZ.value = pos.z

	if cfg.has("rotation"):
		var r = cfg["rotation"]
		var rot = Vector3(r[0], r[1], r[2])
		Drone_Manager.set_drone_rotation(rot)

		# Update UI
		$MarginContainer/VBoxContainer/Rotation/RotX.value = rot.x
		$MarginContainer/VBoxContainer/Rotation/RotY.value = rot.y
		$MarginContainer/VBoxContainer/Rotation/RotZ.value = rot.z

	if cfg.has("velocity"):
		var v = cfg["velocity"]
		var vel = Vector3(v[0], v[1], v[2])
		Drone_Manager.set_drone_velocity(vel)

		# Update UI
		$MarginContainer/VBoxContainer/Velocity/VelX.value = vel.x
		$MarginContainer/VBoxContainer/Velocity/VelY.value = vel.y
		$MarginContainer/VBoxContainer/Velocity/VelZ.value = vel.z

	if cfg.has("drone_model"):
		var model = cfg["drone_model"]
		var idx = find_option_index_by_text(vehicle_dropdown, model)
		if idx != -1:
			vehicle_dropdown.select(idx)
			pending_drone_model = model

	print("Loaded config:", loaded_config)
	rebuild_custom_config_ui()
	
	
# Builds config dictionary
func build_config_dictionary() -> Dictionary:
	return loaded_config.duplicate(true)
	
# Option button for configs
func find_option_index_by_text(button: OptionButton, text: String) -> int:
	for i in range(button.item_count):
		if button.get_item_text(i) == text:
			return i
	return -1
	
func rebuild_custom_config_ui():
	var container: VBoxContainer = $MarginContainer/VBoxContainer/CustomConfigSection/CustomFieldsContainer

	# Remove old UI
	for child in container.get_children():
		child.queue_free()

	# Add fields for every custom key
	for key in loaded_config.keys():
		if key in ["position", "rotation", "velocity", "drone_model"]:
			continue  # skip known fields

		_add_custom_field(container, key, loaded_config[key])

func _add_custom_field(container: VBoxContainer, key: String, value):
	var row := HBoxContainer.new()   # <-- row container
	container.add_child(row)
	
	# Label for the key
	var label := Label.new()
	label.text = key + ":"
	row.add_child(label)
	
	var editor
	
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			editor = SpinBox.new()        # <-- SpinBox
			editor.value = value
			editor.step = 0.1
			
		TYPE_BOOL:
			editor = CheckBox.new()       # <-- CheckBox
			editor.button_pressed = value
			
		TYPE_STRING:
			editor = LineEdit.new()       # <-- LineEdit
			editor.text = value

		TYPE_DICTIONARY:
			# Flatten nested dictionaries
			for subkey in value.keys():
				_add_custom_field(container, key + "." + subkey, value[subkey])
			return
			
		_:
			editor = Label.new()          # <-- fallback Label
			editor.text = str(value)


	# Store the config key so we can save it later
	editor.set_meta("config_key", key)

	row.add_child(editor)
	
func _update_custom_config_from_ui():
	var container: VBoxContainer = $MarginContainer/VBoxContainer/CustomConfigSection/CustomFieldsContainer

	for row in container.get_children():
		if row.get_child_count() < 2:
			continue

		var editor = row.get_child(1)
		var key = editor.get_meta("config_key")

		if key == null:
			continue

		if editor is SpinBox:
			loaded_config[key] = editor.value
		elif editor is CheckBox:
			loaded_config[key] = editor.button_pressed
		elif editor is LineEdit:
			loaded_config[key] = editor.text
