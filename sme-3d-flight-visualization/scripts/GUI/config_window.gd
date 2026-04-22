extends Window
# Nicholas Tran

@onready var csv_ingestion = get_node("/root/Main/IngestionManager")
@onready var vehicle_dropdown := $MarginContainer/VBoxContainer/DroneModel/OptionButton
@onready var controls_header = $MarginContainer/VBoxContainer/ControlsSection/ControlsHeader
@onready var controls_container = $MarginContainer/VBoxContainer/ControlsSection/ControlsContainer
@onready var config_dialog = $MarginContainer/VBoxContainer/ConfigFileDialog
@onready var telemetry_header = $MarginContainer/VBoxContainer/TelemetryInfo/TelemetryInfoHeader
@onready var telemetry_container = $MarginContainer/VBoxContainer/TelemetryInfo/TelemetryContainer/FieldsContainers

# Shared config path — must match CONFIG_PATH in telemetry_panel.gd
const CONFIG_PATH := "res://samples/last_loaded_config.json"

var original_pos: Vector3
var original_rot: Vector3
var original_vel: Vector3

var pending_drone_model: String = ""
var loaded_config: Dictionary = {}


func _ready() -> void:
	vehicle_dropdown.clear()
	vehicle_dropdown.add_item("drone_3")
	vehicle_dropdown.add_item("plane_2_9")
	populate_vehicle_dropdown()

	controls_container.visible = false
	controls_header.text = "Controls ▸"
	controls_header.pressed.connect(_on_controls_header_pressed)

	telemetry_container.visible = false
	telemetry_header.text = "Telemetry Fields ▸"
	telemetry_header.pressed.connect(_on_telemetry_header_pressed)

	await get_tree().process_frame
	reset_size()

	var load_button = $MarginContainer/VBoxContainer/HBoxContainer/LoadConfigButton
	load_button.pressed.connect(_on_load_config_button_pressed)
	var dialog = $MarginContainer/VBoxContainer/ConfigFileDialog
	dialog.file_selected.connect(_on_config_file_dialog_file_selected)

	vehicle_dropdown.item_selected.connect(_on_vehicle_dropdown_item_selected)

	var add_btn = $MarginContainer/VBoxContainer/TelemetryInfo/TelemetryContainer/AddField
	add_btn.pressed.connect(_add_field_row_pressed)


func open_config_window() -> void:
	load_settings()

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

	for row in controls_container.get_children():
		for child in row.get_children():
			if child.has_method("enable_listening"):
				child.enable_listening(true)

	_build_telemetry_fields_ui()
	popup_centered()


func load_settings() -> void:
	pass


func _on_close_requested() -> void:
	for row in controls_container.get_children():
		for child in row.get_children():
			if child.has_method("enable_listening"):
				child.enable_listening(false)
			if child.has_method("clear_pending_key"):
				child.clear_pending_key()
	hide()


func _on_save_pressed() -> void:
	if pending_drone_model != "":
		Drone_Manager.set_drone_model(pending_drone_model)
		loaded_config["drone_model"] = pending_drone_model

	loaded_config["telemetry_fields"] = _collect_telemetry_fields_from_ui()

	_update_custom_config_from_ui()

	var cfg = build_config_dictionary()

	# Ensure the samples folder exists before writing
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://samples/"))

	var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[ConfigWindow] Could not write config to: %s" % CONFIG_PATH)
	else:
		file.store_string(JSON.stringify(cfg, "\t"))
		file.close()

	# Tell the telemetry panel to rebuild its rows from the new config
	var panel = get_node_or_null("/root/Main/HUDRoot/TelemetryPanel")
	if panel and panel.has_method("refresh_from_fields"):
		var fields = loaded_config.get("telemetry_fields", [])
		panel.refresh_from_fields(fields)
	
	print("Panel:", panel)
	print("Has method:", panel and panel.has_method("refresh_from_fields"))

	var fields = _collect_telemetry_fields_from_ui()
	print("Fields:", fields)

	_apply_all_pending_keys(controls_container)
	Drone_Manager.save_bindings()
	hide()

func _on_vehicle_dropdown_item_selected(index: int) -> void:
	var choice = vehicle_dropdown.get_item_text(index)
	if choice == "Add Vehicle...":
		open_vehicle_file_dialog()
		return
	pending_drone_model = choice


func open_vehicle_file_dialog() -> void:
	$MarginContainer/VBoxContainer/VehicleFileDialog.popup_centered()


func populate_vehicle_dropdown() -> void:
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


func _on_controls_header_pressed() -> void:
	controls_container.visible = !controls_container.visible
	controls_header.text = "Controls ▾" if controls_container.visible else "Controls ▸"
	await get_tree().process_frame
	size = Vector2.ZERO


func _on_telemetry_header_pressed() -> void:
	telemetry_container.visible = !telemetry_container.visible
	telemetry_header.text = "Telemetry Fields ▾" if telemetry_container.visible else "Telemetry Fields ▸"
	await get_tree().process_frame
	size = Vector2.ZERO


func _on_load_config_button_pressed() -> void:
	open_config_window()
	config_dialog.popup_centered()


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
	open_config_window()
	apply_loaded_config(parsed)


func apply_loaded_config(cfg: Dictionary) -> void:
	loaded_config = cfg.duplicate(true)
	if cfg.has("drone_model"):
		var model = cfg["drone_model"]
		var idx = find_option_index_by_text(vehicle_dropdown, model)
		if idx != -1:
			vehicle_dropdown.select(idx)
			pending_drone_model = model
			Drone_Manager.set_drone_model(model)
	print("Loaded config:", loaded_config)
	rebuild_custom_config_ui()


func build_config_dictionary() -> Dictionary:
	return loaded_config.duplicate(true)


func find_option_index_by_text(button: OptionButton, text: String) -> int:
	for i in range(button.item_count):
		if button.get_item_text(i) == text:
			return i
	return -1


func rebuild_custom_config_ui() -> void:
	var container: VBoxContainer = $MarginContainer/VBoxContainer/CustomConfigSection/CustomFieldsContainer
	for child in container.get_children():
		child.queue_free()
	for key in loaded_config.keys():
		if key in ["drone_model", "telemetry_fields"]:
			continue
		_add_custom_field(container, key, loaded_config[key])


func _add_custom_field(container: VBoxContainer, key: String, value) -> void:
	var row := HBoxContainer.new()
	container.add_child(row)
	var label := Label.new()
	label.text = key + ":"
	row.add_child(label)
	var editor
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			editor = SpinBox.new()
			editor.value = value
			editor.step = 0.1
		TYPE_BOOL:
			editor = CheckBox.new()
			editor.button_pressed = value
		TYPE_STRING:
			editor = LineEdit.new()
			editor.text = value
		TYPE_DICTIONARY:
			for subkey in value.keys():
				_add_custom_field(container, key + "." + subkey, value[subkey])
			return
		_:
			editor = Label.new()
			editor.text = str(value)
	editor.set_meta("config_key", key)
	row.add_child(editor)


func _update_custom_config_from_ui() -> void:
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


func _apply_all_pending_keys(node: Node) -> void:
	if node.has_method("apply_pending_key"):
		node.apply_pending_key()
	for child in node.get_children():
		_apply_all_pending_keys(child)


func _flight_path_active() -> bool:
	if Engine.has_singleton("SourceManager"):
		return false
	if has_node("/root/SourceManager"):
		var sm = get_node("/root/SourceManager")
		if "active_source_name" in sm:
			return sm.active_source_name == "PLAYBACK"
	return false


func _reset_drone_for_flight_path() -> void:
	if Drone_Manager.has_method("_reset_current_drone_transform"):
		Drone_Manager._reset_current_drone_transform()
	else:
		Drone_Manager.set_drone_position(Vector3.ZERO)
		Drone_Manager.set_drone_rotation(Vector3.ZERO)
		Drone_Manager.set_drone_velocity(Vector3.ZERO)


# ---- Telemetry Fields Section -------------------------------------------

func _build_telemetry_fields_ui() -> void:
	var container = $MarginContainer/VBoxContainer/TelemetryInfo/TelemetryContainer/FieldsContainers
	for child in container.get_children():
		child.queue_free()

	var default_fields = [
		{ "key": "position", "label": "Position" },
		{ "key": "rotation", "label": "Rotation" }
	]

	var fields = loaded_config.get("telemetry_fields", default_fields)
	for field in fields:
		_add_telemetry_field_row(container, field.get("key", ""), field.get("label", ""))


func _add_telemetry_field_row(container: VBoxContainer, key: String, label: String) -> void:
	var row := HBoxContainer.new()
	container.add_child(row)

	var key_edit := LineEdit.new()
	key_edit.placeholder_text = "key  e.g. position"
	key_edit.text = key
	key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key_edit)

	var label_edit := LineEdit.new()
	label_edit.placeholder_text = "label  e.g. Position"
	label_edit.text = label
	label_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label_edit)

	var remove_btn := Button.new()
	remove_btn.text = "✕"
	remove_btn.pressed.connect(func(): row.queue_free())
	row.add_child(remove_btn)


func _add_field_row_pressed() -> void:
	var container = $MarginContainer/VBoxContainer/TelemetryInfo/TelemetryContainer/FieldsContainers
	_add_telemetry_field_row(container, "", "")


func _collect_telemetry_fields_from_ui() -> Array:
	var container = $MarginContainer/VBoxContainer/TelemetryInfo/TelemetryContainer/FieldsContainers
	var fields := []
	for row in container.get_children():
		if row.get_child_count() < 2:
			continue
		var key   = row.get_child(0).text.strip_edges()
		var label = row.get_child(1).text.strip_edges()
		if key != "":
			fields.append({"key": key, "label": label if label != "" else key})
	return fields
