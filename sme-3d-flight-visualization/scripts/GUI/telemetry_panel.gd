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
#|       Telemetry panel that displays pose data received from TelemetryManager.
#|       Fields are driven entirely by the saved config file — the panel
#|       displays nothing until the user configures and saves fields via
#|       the config window. No default fields are shown.
#|
#|       refresh_from_fields(fields) accepts the array directly from the
#|       config window so the panel updates immediately on save without
#|       needing to re-read the file from disk.
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
## - config_window.gd

@onready var telemetry_grid = $MarginContainer/VBoxContainer/TelemetryGrid

# Maps field key -> Label node for its value
var _field_labels: Dictionary = {}

# Must match CONFIG_PATH in config_window.gd
const CONFIG_PATH := "res://samples/last_loaded_config.json"


func _ready() -> void:
	if not TelemetryManager:
		push_error("TelemetryManager not found")
		return

	TelemetryManager.pose_received.connect(_update_pose)
	_build_ui_from_config()


## Builds the grid rows from a fields array.
## Called both on startup (from file) and live (from config window).
func _build_ui(fields: Array) -> void:
	for child in telemetry_grid.get_children():
		child.queue_free()
	_field_labels.clear()

	for field in fields:
		var key: String = field.get("key", "")
		var label_text: String = field.get("label", key)
		if key == "":
			continue

		var header := Label.new()
		header.text = label_text + ":"
		telemetry_grid.add_child(header)

		var value_label := Label.new()
		value_label.text = "---"
		telemetry_grid.add_child(value_label)

		_field_labels[key] = value_label


func _build_ui_from_config() -> void:
	_build_ui(_load_telemetry_fields())


## Called by config_window.gd immediately after saving, passing the
## collected fields array directly so the panel updates without a disk read.
func refresh_from_fields(fields: Array) -> void:
	_build_ui(fields)


## Reads telemetry_fields from the saved config file.
## Returns an empty array if the file does not exist or contains no
## telemetry_fields key — the panel will show nothing in that case.
func _load_telemetry_fields() -> Array:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		return []

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		return []

	if parsed.has("telemetry_fields") and typeof(parsed["telemetry_fields"]) == TYPE_ARRAY:
		return parsed["telemetry_fields"]

	return []


## Flattens incoming pose data into a single dictionary so _update_pose()
## can resolve any user-configured key with a simple lookup.
##
## Available keys a user can type in the config window:
##
##   position   — full Vector3 as string  e.g. "(1.0, 2.0, 3.0)"
##   pos_x      — position X component
##   pos_y      — position Y component
##   pos_z      — position Z component
##
##   rotation   — full Vector3 as string  e.g. "(0.1, 0.2, 0.3)"
##   rot_x      — rotation X component
##   rot_y      — rotation Y component
##   rot_z      — rotation Z component
##
##   gap        — true/false packet gap flag
##   time       — timestamp in seconds (3 decimal places)
##
## Any key not in this list will remain "---" in the panel.
func _flatten_pose(pos: Vector3, rot: Vector3, gap: bool, time: float) -> Dictionary:
	return {
		"position": str(pos),
		"pos_x":    "%.3f" % pos.x,
		"pos_y":    "%.3f" % pos.y,
		"pos_z":    "%.3f" % pos.z,
		"rotation": str(rot),
		"rot_x":    "%.3f" % rot.x,
		"rot_y":    "%.3f" % rot.y,
		"rot_z":    "%.3f" % rot.z,
		"gap":      str(gap),
		"time":     "%.3f" % time,
	}


## Updates the telemetry panel when new pose data is received.
## Only keys that exist in both the config and the flattened pose
## dictionary will be updated — everything else is ignored.
##
## Connected to: TelemetryManager.pose_received
func _update_pose(pos: Vector3, rot: Vector3, gap: bool, time: float) -> void:
	var data := _flatten_pose(pos, rot, gap, time)
	for key in _field_labels:
		if data.has(key):
			_field_labels[key].text = data[key]
