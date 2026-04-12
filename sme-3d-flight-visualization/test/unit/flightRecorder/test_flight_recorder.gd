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
#|   File Name   : test_flight_recorder.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Unit tests for the FlightRecorder script using the GUT framework.
#|       Validates recording lifecycle, binary file output correctness,
#|       and telemetry forwarding behavior.
#|
#|       TelemetryManager is replaced with a mock to isolate the recorder
#|       from the real singleton and allow signal emission control.
#|
#|   Notes       :
#|       Requires GUT (Godot Unit Testing) framework to be installed.
#|       Test recordings are written to res://tests/tmp_recordings/ and
#|       cleaned up automatically after each test.
#|
#|   POC         :
#|       Aramis Hernandez
#|
#|------------------------------------------------------------------------------------

# test_flight_recorder.gd
# Unit tests for the FlightRecorder script.
# Validates recording lifecycle, binary file output, and telemetry forwarding.
extends GutTest

# ---- Mock Classes ---------------------------------------

# Replaces the TelemetryManager autoload singleton during testing.
# Provides a real signal for the recorder to connect to, and captures
# any calls made to forward_recording_started / forward_recording_stopped
# so tests can assert on them without touching the real singleton.
class MockTelemetryManager:
	signal pose_received(pos, rot, gap, time)
	var _recording_started_path := ""
	var _recording_stopped_path := ""
	var _recording_stopped_frames := -1

	func forward_recording_started(path: String) -> void:
		_recording_started_path = path

	func forward_recording_stopped(path: String, frames: int) -> void:
		_recording_stopped_path = path
		_recording_stopped_frames = frames

# Replaces the RecordingManager autoload singleton during testing.
# Absorbs the register_recorder() call made in _ready() so the recorder
# does not error attempting to call it on a null reference.
class MockRecordingManager:
	func register_recorder(_node) -> void:
		pass


# ----- Setup / Teardown ---------------------------------------

var _recorder: Node
var _telemetry: MockTelemetryManager
var _recording_mgr: MockRecordingManager

# Isolated output directory for test recordings — kept separate from
# production recordings to avoid polluting real data
const TEST_SAVE_DIR := "res://tests/tmp_recordings/"


# Runs before every test.
# Creates fresh mock objects, injects them into a new recorder instance,
# and waits one frame for _ready() to complete.
func before_each() -> void:
	_telemetry = MockTelemetryManager.new()
	_recording_mgr = MockRecordingManager.new()

	# Load the script but don't add to tree yet
	_recorder = load("res://scripts/flight_recorder.gd").new()
	_recorder.save_path = TEST_SAVE_DIR

	# Inject mocks before _ready() fires
	_recorder.set("TelemetryManager", _telemetry)
	_recorder.set("RecordingManager", _recording_mgr)

	add_child_autofree(_recorder)
	await get_tree().process_frame

# Runs after every test.
# Ensures any active recording is stopped cleanly, then deletes all
# .bin files written during the test to keep the tmp directory clean.
func after_each() -> void:
	# Stop any recording left open by a failing test
	if _recorder.is_recording:
		_recorder.stop_recording()

	# Globalize path the same way _get_save_path() does
	var global_dir := ProjectSettings.globalize_path(TEST_SAVE_DIR)
	var dir := DirAccess.open(global_dir)
	if dir:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f.ends_with(".bin"):
				dir.remove(f)
			f = dir.get_next()


# ---- Helper--------------------------------------------

# Opens a recorded .bin file for reading after validating the path.
# Fails the test with a descriptive message if the path is empty or
# the file cannot be opened, then returns null so the caller can
# bail early with: if f == null: return
func _open_recording(path: String) -> FileAccess:
	assert_ne(path, "", "recording path must not be empty — check mock is wired correctly")
	if path == "":
		return null

	var f := FileAccess.open(path, FileAccess.READ)
	assert_not_null(f, "FileAccess.open failed for path: '%s'" % path)
	return f


# --- start_recording() -----------------

# Verifies that is_recording is set to true after a recording session begins
func test_start_recording_sets_is_recording() -> void:
	_recorder.start_recording("test_start")
	assert_true(_recorder.is_recording)

# Verifies that starting a new session after a previous one resets
# the frame counter to zero
func test_start_recording_resets_frame_count() -> void:
	_recorder.start_recording("test_reset_a")
	_telemetry.pose_received.emit(Vector3.ZERO, Vector3.ZERO, false, 0.0)
	_recorder.stop_recording()

	_recorder.start_recording("test_reset_b")
	assert_eq(_recorder._frame_count, 0,
		"frame count should reset to 0 on a new recording")


# Verifies that calling start_recording() while already recording is ignored
# the recorder should not open a second file or overwrite the current session
func test_start_recording_while_already_recording_is_noop() -> void:
	_recorder.start_recording("test_double_start_a")
	var path_before := _telemetry._recording_started_path

	_recorder.start_recording("test_double_start_b")
	assert_eq(_telemetry._recording_started_path, path_before,
		"calling start_recording() twice should not open a second file")

# Verifies that the binary file begins with the FLTH magic number (0x464C5448),
# which identifies it as a valid flight path recording
func test_start_recording_writes_magic_header() -> void:
	_recorder.start_recording("test_header")
	_recorder.stop_recording()

	var f := _open_recording(_telemetry._recording_stopped_path)
	if f == null:
		return

	var magic := f.get_32()
	f.close()

	assert_eq(magic, 0x464C5448, "first 4 bytes must be the FLTH magic number")


# --- stop_recording() ----------------------------------

# Verifies that is_recording is cleared after a session ends
func test_stop_recording_clears_is_recording() -> void:
	_recorder.start_recording("test_stop")
	_recorder.stop_recording()
	assert_false(_recorder.is_recording)

# Verifies that calling stop_recording() with no active session does nothing —
# no path or frame count should be forwarded to TelemetryManager
func test_stop_recording_when_not_recording_is_noop() -> void:
	_recorder.stop_recording()
	assert_eq(_telemetry._recording_stopped_path, "",
		"stop_recording() with no active session should not forward anything")

# Verifies that the frame count forwarded to TelemetryManager on stop
# matches the number of pose frames actually received during the session
func test_stop_recording_passes_correct_frame_count_to_telemetry() -> void:
	_recorder.start_recording("test_stop_frames")
	_telemetry.pose_received.emit(Vector3(1, 2, 3), Vector3(0.1, 0.2, 0.3), false, 0.016)
	_telemetry.pose_received.emit(Vector3(4, 5, 6), Vector3(0.4, 0.5, 0.6), false, 0.032)
	_recorder.stop_recording()

	assert_eq(_telemetry._recording_stopped_frames, 2,
		"frame count forwarded to TelemetryManager should match frames written")


# --- _on_pose_received() / frame writing -----------------------

# Verifies that each pose emission increments the frame counter by one
func test_pose_increments_frame_count() -> void:
	_recorder.start_recording("test_pose_count")
	_telemetry.pose_received.emit(Vector3.ONE, Vector3.ONE, false, 1.0)
	_telemetry.pose_received.emit(Vector3.ONE, Vector3.ONE, false, 2.0)
	assert_eq(_recorder._frame_count, 2)


# Verifies that pose emissions received before start_recording() is called
# are ignored and do not increment the frame counter
func test_pose_not_written_when_not_recording() -> void:
	_telemetry.pose_received.emit(Vector3.ONE, Vector3.ONE, false, 0.5)
	assert_eq(_recorder._frame_count, 0)

# Verifies that the frame count written back into the file header on stop
# matches the number of frames emitted during the session.
# This catches any mismatch between the in-memory counter and the on-disk value.
func test_written_frame_count_in_header_matches_actual_frames() -> void:
	_recorder.start_recording("test_header_count")
	for i in range(5):
		_telemetry.pose_received.emit(
			Vector3(i, i, i), Vector3(0.0, 0.0, 0.0), false, float(i) * 0.016
		)
	_recorder.stop_recording()

	var f := _open_recording(_telemetry._recording_stopped_path)
	if f == null:
		return

	f.get_32()  # skip magic
	var stored_count := f.get_32()
	f.close()

	assert_eq(stored_count, 5,
		"frame count written back into header should equal frames emitted")

# Verifies that a single pose frame survives a full write-then-read cycle
# with no data loss or byte offset errors.
# Checks every field individually: timestamp, position XYZ, rotation XYZ.
func test_pose_data_round_trips_correctly() -> void:
	var pos := Vector3(1.5, 2.5, 3.5)
	var rot := Vector3(0.1, 0.2, 0.3)
	var t    := 42.0

	_recorder.start_recording("test_roundtrip")
	_telemetry.pose_received.emit(pos, rot, false, t)
	_recorder.stop_recording()

	var f := _open_recording(_telemetry._recording_stopped_path)
	if f == null:
		return

	f.get_32()  # magic
	f.get_32()  # frame count

	var rt    := f.get_float()
	var rx    := f.get_float()
	var ry    := f.get_float()
	var rz    := f.get_float()
	var rrotx := f.get_float()
	var rroty := f.get_float()
	var rrotz := f.get_float()
	f.close()

	assert_almost_eq(rt,    t,     0.0001, "timestamp should round-trip")
	assert_almost_eq(rx,    pos.x, 0.0001, "pos.x should round-trip")
	assert_almost_eq(ry,    pos.y, 0.0001, "pos.y should round-trip")
	assert_almost_eq(rz,    pos.z, 0.0001, "pos.z should round-trip")
	assert_almost_eq(rrotx, rot.x, 0.0001, "rot.x should round-trip")
	assert_almost_eq(rroty, rot.y, 0.0001, "rot.y should round-trip")
	assert_almost_eq(rrotz, rot.z, 0.0001, "rot.z should round-trip")


# ---- _get_save_path() --------------------------------------------------

# Verifies that spaces in a custom recording name are replaced with underscores
# and that the file extension is always .bin
func test_custom_name_used_in_filename() -> void:
	_recorder.start_recording("my custom flight")
	_recorder.stop_recording()

	var path := _telemetry._recording_stopped_path
	assert_true(path.contains("my_custom_flight"),
		"spaces in custom name should become underscores in filename")
	assert_true(path.ends_with(".bin"),
		"custom-named recording should still use .bin extension")

# Verifies that when no custom name is provided, the filename uses
# the auto-generated timestamp format prefixed with 'flight_'
func test_default_name_contains_flight_prefix() -> void:
	_recorder.start_recording()
	_recorder.stop_recording()

	var path := _telemetry._recording_stopped_path
	assert_true(path.contains("flight_"),
		"auto-generated filename should begin with 'flight_'")
