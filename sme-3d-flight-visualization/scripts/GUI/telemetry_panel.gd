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
#|   File Name   : telemetry_panel.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Telemetry panel that displays all necessary telemetry info.
#|
#|   Notes       :
#|       This component has not been formally unit tested.
#|
#|   POC         :
#|       Aramis Hernandez
#|
#|------------------------------------------------------------------------------------

extends PanelContainer

## TelemetryPanel UI component responsible for displaying telemetry data
## received from the TelemetryManager singleton.
##
## Data Source:
## TelemetryManager.pose_received
##
## Related Components:
## - telemetry_manager.gd
## - ingestion_udp.gd

@onready var telemetry_grid = $MarginContainer/VBoxContainer/TelemetryGrid

# Maps field key (e.g. "position", "rotation") -> Label node for its value
var _field_labels: Dictionary = {}

const DEFAULT_FIELDS = [
	{ "key": "position", "label": "Position" },
	{ "key": "rotation", "label": "Rotation" }
]

## Initializes the telemetry panel.
## Edited by Carson Wood
## Connects the panel to the TelemetryManager pose_received signal so
## that the UI can update whenever new telemetry pose data is available.
func _ready():
	if not TelemetryManager:
		push_error("TelemetryManager not found")
		return
		
	TelemetryManager.pose_received.connect(_update_pose)
	
	_build_ui_from_config()


func _build_ui_from_config() -> void:
	# Clear existing rows
	for child in telemetry_grid.get_children():
		child.queue_free()
	_field_labels.clear()

	var fields = _load_telemetry_fields()

	for field in fields:
		var key: String = field.get("key", "")
		var label_text: String = field.get("label", key)
		if key == "":
			continue

		# Header label (left column)
		var header := Label.new()
		header.text = label_text + ":"
		telemetry_grid.add_child(header)

		# Value label (right column)
		var value_label := Label.new()
		value_label.text = "---"
		telemetry_grid.add_child(value_label)

		_field_labels[key] = value_label


func _load_telemetry_fields() -> Array:
	var file = FileAccess.open("user://last_loaded_config.json", FileAccess.READ)
	if not file:
		return DEFAULT_FIELDS
		
	var parsed = JSON.parse_string(file.get_as_text())
	
	file.close()
	
	if typeof(parsed) != TYPE_DICTIONARY:
		return DEFAULT_FIELDS
		
	if parsed.has("telemetry_fields") and typeof(parsed["telemetry_fields"]) == TYPE_ARRAY:
		return parsed["telemetry_fields"]

	return DEFAULT_FIELDS


func refresh_from_config() -> void:
	_build_ui_from_config()


## Updates the telemetry panel when new pose data is received.
##
## Connected to:
## TelemetryManager.pose_received
##
## Parameters:
## - pos (Vector3): Current position of the aircraft or object.
## - rot (Vector3): Current rotation/orientation.
## - gap (bool): Indicates if a telemetry packet gap occurred.
## - time (float): Timestamp associated with the telemetry update.
func _update_pose(pos: Vector3, rot: Vector3, gap: bool, time):
	if _field_labels.has("position"):
		_field_labels["position"].text = str(pos)
	if _field_labels.has("rotation"):
		_field_labels["rotation"].text = str(rot)
	if _field_labels.has("gap"):
		_field_labels["gap"].text = str(gap)
	if _field_labels.has("time"):
		_field_labels["time"].text = str(time)
