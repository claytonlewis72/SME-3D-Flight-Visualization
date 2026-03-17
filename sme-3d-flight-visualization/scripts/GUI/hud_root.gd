#TEMP SCRIPT NOT PERMANT: Aramis Herandez

extends CanvasLayer


@onready var telemetry_panel = $TelemetryPanel

func connectToIngestion(ingestion):
	ingestion.pose_received.connect(telemetry_panel.update_telemetry)
