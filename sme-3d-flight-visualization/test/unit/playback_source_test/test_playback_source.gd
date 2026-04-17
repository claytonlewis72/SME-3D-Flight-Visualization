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
#|   File Name   : test_playback_source.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Unit tests for the PlaybackSource script using the GUT framework.
#|       Validates file loading, playback lifecycle, seeking, and
#|       telemetry forwarding behavior.
#|
#|       TelemetryManager and SourceManager are replaced with mocks to
#|       isolate PlaybackSource from real singletons.
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

extends GutTest

# -- Mock Classes -------
class MockTelemetryManager: 
	var pose_calls : Array = []
	
	var frame_changed_calls: Array = []
	
	var recording_loaded_calls: Array = []
	
	var playback_completed_count: int = 0
	
	func forward_pose(pos: Vector3, rot: Vector3, flag: bool, t: float) -> void:
		pose_calls.append({"pos": pos, "rot": rot, "flag": flag, "t":t})
	
	func forward_frame_changed(current: int, total: int) -> void:
		frame_changed_calls.append({"current": current, "total": total})
	
	func forward_recording_loaded(path: String, count: int) -> void:
		recording_loaded_calls.append({"path": path, "count": count})
	
	func forward_playback_completed() -> void:
		playback_completed_count += 1

class MockSourceManager:
	func register_source(_key: String, _node) -> void:
		pass

#----- Setup -----------------------
var _source: Node
var _telemetry: MockTelemetryManager

const TEST_SAVE_DIR := "res://test/tmp_recording/"
const VAILD_FORMAT := 0x464C5448 #Magic number
const TMP_FILE := TEST_SAVE_DIR + "test_recording.bin"

func before_each() -> void:
	_telemetry = MockTelemetryManager.new()
	
	_source = load("res://scripts/playback/playback_source.gd").new()
	_source.set("TelemetryManager", _telemetry)
	_source.set("SourceManager", MockSourceManager.new())
	
	add_child_autofree(_source)
	await get_tree().process_frame

func after_each() -> void:
	if _source.has_recording():
		_source.stop()
	
	var dir := DirAccess.open(ProjectSettings.globalize_path(TEST_SAVE_DIR))
	if dir == null:
		return
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".bin"):
			dir.remove(f)
		f = dir.get_next()


#---- Helper -------

#Writes a minimal vaild binary recording with the given frames.
func _write_recording(frames: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_SAVE_DIR))
	
	var file := FileAccess.open(TMP_FILE, FileAccess.WRITE)
	file.store_32(VAILD_FORMAT)
	file.store_32(frames.size())
	
	for fr in frames:
		file.store_float(fr["t"])
		file.store_float(fr["px"])
		file.store_float(fr["py"])
		file.store_float(fr["pz"])
		file.store_float(fr["ry"])
		file.store_float(fr["rz"])
		file.store_float(fr["rx"])
	file.close()

func _default_frames() -> Array:
	return [
		{"t": 0.0, "px": 1.0, "py": 2.0, "pz": 3.0, "ry": 0.1, "rz": 0.2, "rx": 0.3},
		{"t": 0.1, "px": 4.0, "py": 5.0, "pz": 6.0, "ry": 0.4, "rz": 0.5, "rx": 0.6},
		{"t": 0.2, "px": 7.0, "py": 8.0, "pz": 9.0, "ry": 0.7, "rz": 0.8, "rx": 0.9},
	]
		
#----- load_file() test-----------

#Ensures when we load a fake file it returns correctly false.
func test_load_file_returns_false_for_missing_file() -> void:
	var result = _source.load_file("res://nonexistent.bin")
	assert_false(result, "load_file() must return false when file does not exist")
 
#Verifies that a file will not load if it is not a vaild format
func test_load_file_returns_false_for_invalid_format() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(TEST_SAVE_DIR))
	var file := FileAccess.open(TMP_FILE, FileAccess.WRITE)
	file.store_32(0xDEADBEEF)
	file.store_32(0)
	file.close()
 
	assert_false(_source.load_file(TMP_FILE),
		"load_file() must return false when magic number is wrong")

#Verifies recording will return true when it is actually a vaild recording.
func test_load_file_returns_true_for_valid_recording() -> void:
	_write_recording(_default_frames())
	assert_true(_source.load_file(TMP_FILE),
		"load_file() must return true for a valid recording")



#--- has_recording() test--------
 
#Ensures that has recording is correctly false if it does not contain any recording
func test_has_recording_false_before_load() -> void:
	assert_false(_source.has_recording(),
		"has_recording() should be false before any file is loaded")
 
#Does the same as the previous test but checks if true when it does contain a recording
func test_has_recording_true_after_load() -> void:
	_write_recording(_default_frames())
	_source.load_file(TMP_FILE)
	assert_true(_source.has_recording(),
		"has_recording() should be true after a valid file is loaded")
 

#---- Start() / stop() test ---------------

#Ensures that no poses are passed after playback is stopped
func test_stop_halts_frame_emission() -> void:
	_write_recording(_default_frames())
	_source.load_file(TMP_FILE)
	_source.start()
	_source.stop()
 
	var count_before := _telemetry.pose_calls.size()
	_source._process(1.0)
	assert_eq(_telemetry.pose_calls.size(), count_before,
		"_process() after stop() must not emit any additional poses")	
	
#--- pause() / resume() test --------------

#verifies poses are not passed when paused
func test_pause_prevents_frame_emission() -> void:
	_write_recording(_default_frames())
	_source.load_file(TMP_FILE)
	_source.start()
	_source._process(0.05)
	_source.pause()
 
	var count_at_pause := _telemetry.pose_calls.size()
	_source._process(1.0)
	assert_eq(_telemetry.pose_calls.size(), count_at_pause,
		"_process() while paused must not emit any additional poses")
 
#Verifies that resume cotinues the playback correctly where it was left off.
func test_resume_continues_playback() -> void:
	_write_recording(_default_frames())
	_source.load_file(TMP_FILE)
	_source.start()
	_source._process(0.05)
	_source.pause()
	_source.resume()
 
	_source._process(0.2)
	assert_gt(_telemetry.pose_calls.size(), 1,
		"resume() must allow further frames to be emitted")
 
#--- seek() ----------------

#Testing frame positions to ensure they are emitted correctly
func test_seek_emits_correct_frame_position() -> void:
	_write_recording(_default_frames())
	_source.load_file(TMP_FILE)
	_source.seek(2)
 
	var fr = _default_frames()[2]
	assert_eq(_telemetry.pose_calls.back()["pos"],
		Vector3(fr["px"], fr["py"], fr["pz"]),
		"seek(2) must emit the position of frame index 2")


#Verifies we dont get out of bounds error due to clamping
func test_seek_clamps_out_of_bounds_index() -> void:
	_write_recording(_default_frames())
	_source.load_file(TMP_FILE)
	_source.seek(9999)
 
	var last_fr = _default_frames().back()
	assert_eq(_telemetry.pose_calls.back()["pos"],
		Vector3(last_fr["px"], last_fr["py"], last_fr["pz"]),
		"seek() with an out-of-bounds index must clamp to the last frame")
		


#-------- process() test-------------

#Ensure all frames are still not lost even when application frame rate is low
func test_process_emits_all_frames_on_large_delta() -> void:
	_write_recording(_default_frames())
	_source.load_file(TMP_FILE)
	_source.start()
	_source._process(1.0)
 
	assert_eq(_telemetry.pose_calls.size(), 3,
		"A delta large enough to cover all frames must emit all 3 poses")
 
 
func test_process_calls_playback_completed_at_end() -> void:
	_write_recording(_default_frames())
	_source.load_file(TMP_FILE)
	_source.start()
	_source._process(1.0)
 
	assert_eq(_telemetry.playback_completed_count, 1,
		"forward_playback_completed() must be called exactly once when all frames are exhausted")
