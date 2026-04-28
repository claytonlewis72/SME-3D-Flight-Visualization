#|------------------------------------------------------------------------------------
#|   Unclassified
#|------------------------------------------------------------------------------------
#|
#|   SME Solutions, Inc.
#|   Copyright 2026 SME Solutions, Inc. All Rights Reserved
#|   SME Solutions Proprietary Information
#|
#|------------------------------------------------------------------------------------
#|
#|   File Name   : config_window.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Modal configuration window for the application. Allows the operator
#|       to select a drone model, rebind input controls, manage custom config
#|       fields, and define which telemetry fields are displayed in the HUD.
#|       Settings are persisted to a shared JSON config file and applied
#|       immediately on save. Vehicle scenes can be added at runtime by
#|       importing external .tscn files into res://vehicles/.
#|
#|   Author      : Nicholas Tran
#|
#|------------------------------------------------------------------------------------


extends Window

## Modal configuration window for drone model selection, input rebinding,
## custom config fields, and HUD telemetry field management.
##
## On save, settings are serialized to [constant CONFIG_PATH] as JSON and
## broadcast to live systems: [DroneManager] receives the new vehicle model
## and key bindings, and [code]TelemetryPanel[/code] receives an updated
## field list via [method refresh_from_fields]. The window restores its
## internal state from [constant CONFIG_PATH] each time it is opened via
## [method open_config_window].

## Singleton reference to [IngestionManager] for CSV telemetry ingestion.
@onready var csv_ingestion = get_node("/root/Main/IngestionManager")

## Dropdown listing available vehicle scenes and an "Add Vehicle..." option.
@onready var vehicle_dropdown := $MarginContainer/VBoxContainer/DroneModel/OptionButton

## Collapsible header button for the controls rebinding section.
@onready var controls_header = $MarginContainer/VBoxContainer/ControlsSection/ControlsHeader

## Container holding the key-rebinding rows, shown or hidden by [member controls_header].
@onready var controls_container = $MarginContainer/VBoxContainer/ControlsSection/ControlsContainer

## File dialog used to browse for external [code].json[/code] config files.
@onready var config_dialog = $MarginContainer/VBoxContainer/ConfigFileDialog

## Collapsible header button for the telemetry fields section.
@onready var telemetry_header = $MarginContainer/VBoxContainer/TelemetryInfo/TelemetryInfoHeader

## Container holding the telemetry field editor rows.
@onready var telemetry_container = $MarginContainer/VBoxContainer/TelemetryInfo/TelemetryContainer/FieldsContainers


## Shared path for the persisted config JSON file.
##
## Must match [code]CONFIG_PATH[/code] in [code]telemetry_panel.gd[/code]
## so both scripts read and write the same file.
const CONFIG_PATH := "res://samples/last_loaded_config.json"


## World position of the active drone captured when the window opens.
##
## Reserved for future restore-on-cancel behaviour.
var original_pos: Vector3

## World rotation of the active drone captured when the window opens.
##
## Reserved for future restore-on-cancel behaviour.
var original_rot: Vector3

## Velocity of the active drone captured when the window opens.
##
## Reserved for future restore-on-cancel behaviour.
var original_vel: Vector3


## Vehicle scene name selected in the dropdown but not yet applied.
##
## Applied to [DroneManager] when the operator presses Save. Empty string
## when no change has been made.
var pending_drone_model: String = ""

## In-memory representation of the currently loaded configuration.
##
## Populated from [constant CONFIG_PATH] by [method load_settings] and from
## external files by [method apply_loaded_config]. Written back to disk by
## [method _on_save_pressed].
var loaded_config: Dictionary = {}


## Initialises UI state and connects all signals.
##
## Populates [member vehicle_dropdown] from [code]res://vehicles/[/code],
## collapses the controls and telemetry sections, defers a [method Window.reset_size]
## call to allow the scene tree to settle, then wires up buttons, the file
## dialog, the dropdown, and the add-field button.
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


## Opens the config window and captures current drone state.
##
## Calls [method load_settings] to refresh [member loaded_config] from disk,
## then snapshots the active drone's [member Node3D.global_position],
## [member Node3D.global_rotation], and velocity into [member original_pos],
## [member original_rot], and [member original_vel] for potential restore use.
## Enables key-listening on all rebinding widgets in [member controls_container],
## rebuilds the telemetry fields UI from [member loaded_config], and centers
## the window via [method Window.popup_centered].
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


## Loads persisted settings from disk into [member loaded_config].
##
## Currently a stub. Intended to read [constant CONFIG_PATH] and populate
## [member loaded_config] before the window is shown.
func load_settings() -> void:
	pass


## Disables key-listening on all rebinding widgets and hides the window.
##
## Connected to the window's close-requested signal. Iterates
## [member controls_container] and calls [code]enable_listening(false)[/code]
## and [code]clear_pending_key()[/code] on any child that exposes those methods,
## ensuring no stale key captures remain after the window is dismissed.
func _on_close_requested() -> void:
	for row in controls_container.get_children():
		for child in row.get_children():
			if child.has_method("enable_listening"):
				child.enable_listening(false)
			if child.has_method("clear_pending_key"):
				child.clear_pending_key()
	hide()


## Applies all pending changes and persists the config to disk.
##
## Applies [member pending_drone_model] to [DroneManager] if one is queued,
## collects telemetry fields and custom config values from the UI into
## [member loaded_config], serializes the result as indented JSON to
## [constant CONFIG_PATH] (creating [code]res://samples/[/code] if needed),
## and notifies [code]TelemetryPanel[/code] to rebuild its rows via
## [method refresh_from_fields]. Finalizes all pending key rebindings by
## walking [member controls_container] and saves bindings to
## [DroneManager] before hiding the window.
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


## Records the vehicle choice for deferred application on save.
##
## Connected to [signal OptionButton.item_selected] on [member vehicle_dropdown].
## If the operator selects "Add Vehicle...", opens the vehicle file dialog
## instead of updating [member pending_drone_model].
##
## Parameters:
##   index : int
##       Index of the selected item in [member vehicle_dropdown].
func _on_vehicle_dropdown_item_selected(index: int) -> void:
	var choice = vehicle_dropdown.get_item_text(index)
	if choice == "Add Vehicle...":
		open_vehicle_file_dialog()
		return
	pending_drone_model = choice


## Opens the vehicle file dialog to let the operator import an external scene.
func open_vehicle_file_dialog() -> void:
	$MarginContainer/VBoxContainer/VehicleFileDialog.popup_centered()


## Rebuilds [member vehicle_dropdown] from all [code].tscn[/code] files in [code]res://vehicles/[/code].
##
## Clears the dropdown, enumerates the directory, adds a separator, then
## appends an "Add Vehicle..." sentinel item at the end.
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


## Copies an externally selected vehicle scene into [code]res://vehicles/[/code] and refreshes the dropdown.
##
## Connected to the vehicle [FileDialog]'s [signal FileDialog.file_selected]
## signal. Reads the selected file as raw bytes and writes it to
## [code]res://vehicles/<filename>[/code], then calls
## [method populate_vehicle_dropdown] so the new model appears immediately.
##
## Parameters:
##   path : String
##       Absolute path to the externally selected [code].tscn[/code] file.
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



## Toggles the controls rebinding section and reflows the window.
##
## Connected to [signal Button.pressed] on [member controls_header].
## Updates the header arrow glyph and resets [member Window.size] to zero
## after a deferred frame so the window auto-fits the new content height.
func _on_controls_header_pressed() -> void:
	controls_container.visible = !controls_container.visible
	controls_header.text = "Controls ▾" if controls_container.visible else "Controls ▸"
	await get_tree().process_frame
	size = Vector2.ZERO



## Toggles the telemetry fields section and reflows the window.
##
## Connected to [signal Button.pressed] on [member telemetry_header].
## Updates the header arrow glyph and resets [member Window.size] to zero
## after a deferred frame so the window auto-fits the new content height.
func _on_telemetry_header_pressed() -> void:
	telemetry_container.visible = !telemetry_container.visible
	telemetry_header.text = "Telemetry Fields ▾" if telemetry_container.visible else "Telemetry Fields ▸"
	await get_tree().process_frame
	size = Vector2.ZERO


## Opens the config window and immediately shows the config file dialog.
##
## Connected to the Load Config button. Calls [method open_config_window]
## to refresh state before surfacing the file picker.
func _on_load_config_button_pressed() -> void:
	open_config_window()
	config_dialog.popup_centered()


## Parses a selected JSON config file and applies it to the window.
##
## Connected to [signal FileDialog.file_selected] on [member config_dialog].
## Reads the file, parses the JSON, and delegates to [method apply_loaded_config].
## Pushes an error and returns early if the file cannot be opened or the
## content is not a [Dictionary].
##
## Parameters:
##   path : String
##       Absolute path to the selected [code].json[/code] config file.
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


## Applies a parsed config dictionary to all UI controls.
##
## Deep-copies [param cfg] into [member loaded_config], selects the
## corresponding item in [member vehicle_dropdown] if a [code]drone_model[/code]
## key is present (and applies it to [DroneManager] immediately), then calls
## [method rebuild_custom_config_ui] to populate the custom fields section.
##
## Parameters:
##   cfg : Dictionary
##       Parsed config dictionary, typically from [method _on_config_file_dialog_file_selected].
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


## Returns a deep copy of [member loaded_config] for serialization.
##
## Separates the in-memory config from the value written to disk so callers
## cannot mutate [member loaded_config] through the returned dictionary.
func build_config_dictionary() -> Dictionary:
	return loaded_config.duplicate(true)


## Returns the index of the first dropdown item whose text matches [param text].
##
## Parameters:
##   button : OptionButton
##       The dropdown to search.
##   text   : String
##       The label to match exactly.
##
## Returns:
##   The zero-based item index, or [code]-1[/code] if not found.
func find_option_index_by_text(button: OptionButton, text: String) -> int:
	for i in range(button.item_count):
		if button.get_item_text(i) == text:
			return i
	return -1


## Rebuilds the custom config fields UI from [member loaded_config].
##
## Frees all existing children of [code]CustomFieldsContainer[/code], then
## iterates [member loaded_config] and calls [method _add_custom_field] for
## every key that is not [code]"drone_model"[/code] or
## [code]"telemetry_fields"[/code] (those are managed by dedicated sections).
func rebuild_custom_config_ui() -> void:
	var container: VBoxContainer = $MarginContainer/VBoxContainer/CustomConfigSection/CustomFieldsContainer
	for child in container.get_children():
		child.queue_free()
	for key in loaded_config.keys():
		if key in ["drone_model", "telemetry_fields"]:
			continue
		_add_custom_field(container, key, loaded_config[key])


## Adds a single editable row for a custom config key-value pair.
##
## Selects the appropriate editor widget based on the type of [param value]:
## [SpinBox] for numeric types, [CheckBox] for booleans, [LineEdit] for
## strings. Dictionary values are expanded recursively with dot-separated
## keys (e.g. [code]"parent.child"[/code]). Unsupported types are shown as
## a read-only [Label]. The [code]config_key[/code] metadata on each editor
## widget is used by [method _update_custom_config_from_ui] to write values
## back into [member loaded_config].
##
## Parameters:
##   container : VBoxContainer
##       Parent container to add the row to.
##   key       : String
##       Config key name shown in the row label.
##   value     : Variant
##       Current value, used to determine the editor widget type.
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


## Reads edited values from the custom config UI back into [member loaded_config].
##
## Iterates rows in [code]CustomFieldsContainer[/code] and updates
## [member loaded_config] for each editor widget that carries a
## [code]config_key[/code] metadata value. Supports [SpinBox], [CheckBox],
## and [LineEdit] editors; rows with fewer than two children are skipped.
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


## Recursively calls [code]apply_pending_key[/code] on every node in a subtree.
##
## Used during save to finalize any key-rebinding widgets that have a
## captured key awaiting confirmation. Walks the entire subtree rooted at
## [param node] depth-first.
##
## Parameters:
##   node : Node
##       Root of the subtree to walk.
func _apply_all_pending_keys(node: Node) -> void:
	if node.has_method("apply_pending_key"):
		node.apply_pending_key()
	for child in node.get_children():
		_apply_all_pending_keys(child)


## Returns whether the active telemetry source is [code]"PLAYBACK"[/code].
##
## Checks for a [code]SourceManager[/code] singleton and reads its
## [code]active_source_name[/code] property. Returns [code]false[/code] if
## the singleton is not present or the property is absent.
func _flight_path_active() -> bool:
	if Engine.has_singleton("SourceManager"):
		return false
	if has_node("/root/SourceManager"):
		var sm = get_node("/root/SourceManager")
		if "active_source_name" in sm:
			return sm.active_source_name == "PLAYBACK"
	return false


## Resets the active drone's transform to the origin via [DroneManager].
##
## Prefers [method DroneManager._reset_current_drone_transform] if available;
## otherwise calls [method DroneManager.set_drone_position],
## [method DroneManager.set_drone_rotation], and
## [method DroneManager.set_drone_velocity] individually with
## [constant Vector3.ZERO].
func _reset_drone_for_flight_path() -> void:
	if Drone_Manager.has_method("_reset_current_drone_transform"):
		Drone_Manager._reset_current_drone_transform()
	else:
		Drone_Manager.set_drone_position(Vector3.ZERO)
		Drone_Manager.set_drone_rotation(Vector3.ZERO)
		Drone_Manager.set_drone_velocity(Vector3.ZERO)


# ---- Telemetry Fields Section -------------------------------------------

## Rebuilds the telemetry field editor rows from [member loaded_config].
##
## Frees all existing rows in [code]FieldsContainers[/code], then populates
## them from the [code]"telemetry_fields"[/code] array in [member loaded_config].
## Falls back to a two-entry default ([code]position[/code] and
## [code]rotation[/code]) when the key is absent.
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


## Adds a single editable row to the telemetry fields section.
##
## Each row contains two [LineEdit] widgets (key and display label) and a
## remove button that frees the row immediately when pressed.
##
## Parameters:
##   container : VBoxContainer
##       Parent container to append the row to.
##   key       : String
##       Initial value for the key [LineEdit] (e.g. [code]"position"[/code]).
##   label     : String
##       Initial value for the label [LineEdit] (e.g. [code]"Position"[/code]).
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

## Appends a blank telemetry field row to the fields section.
##
## Connected to [signal Button.pressed] on the Add Field button.
## Delegates to [method _add_telemetry_field_row] with empty strings so
## the operator can fill in a new key and label.
func _add_field_row_pressed() -> void:
	var container = $MarginContainer/VBoxContainer/TelemetryInfo/TelemetryContainer/FieldsContainers
	_add_telemetry_field_row(container, "", "")

## Reads the current telemetry field rows from the UI and returns them as an array.
##
## Iterates [code]FieldsContainers[/code] and collects [code]{"key", "label"}[/code]
## dictionaries from each row's two [LineEdit] widgets. Rows with an empty key
## after stripping whitespace are skipped. If a label is empty the key value is
## used as the label.
##
## Returns:
##   An [Array] of [Dictionary] values each containing [code]"key"[/code] and
##   [code]"label"[/code] string entries.
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
