extends Window

@onready var telemetry_dropdown = $MarginContainer/VBoxContainer/TelemetrySource/OptionButton
@onready var csv_file_dialog = $MarginContainer/VBoxContainer/CSVFileDialog
@onready var csv_ingestion = get_node("/root/Main/IngestionManager")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	telemetry_dropdown.item_selected.connect(_on_telemetry_source_selected)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

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
