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
#|   File Name   : test_playback_hud.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Unit tests for PlaybackHUD signal handlers using the GUT framework.
#|       Instances the real .tscn so all @onready nodes resolve correctly.
#|       Rather than emitting signals through mocked singletons, handlers
#|       are called directly to avoid singleton connection timing issues.
#|
#|   Notes       :
#|       Requires GUT (Godot Unit Testing) framework to be installed.
#|       Update SCENE_PATH if your .tscn lives elsewhere.
#|
#|   POC         :
#|       Aramis Hernandez
#|
#|------------------------------------------------------------------------------------

extends GutTest

# ---- Setup / Teardown ---------------------------------------------------

const SCENE_PATH := "res://scenes/GUI/playback_hud.tscn"

var _hud: Control


func before_each() -> void:
	_hud = load(SCENE_PATH).instantiate()
	add_child_autofree(_hud)
	await get_tree().process_frame


# ---- _on_recording_loaded() ---------------------------------------------

# Verifies the scrub bar max is set to frame_count - 1 after a recording loads.
func test_recording_loaded_sets_scrub_bar_max() -> void:
	_hud._on_recording_loaded("res://fake.bin", 10)
	await get_tree().process_frame

	assert_eq(int(_hud.scrub_bar.max_value), 9,
		"scrub bar max should be frame_count - 1")


# Verifies the scrub bar resets to 0 when a new recording is loaded.
func test_recording_loaded_resets_scrub_bar_to_zero() -> void:
	_hud.scrub_bar.value = 5
	_hud._on_recording_loaded("res://fake.bin", 10)
	await get_tree().process_frame

	assert_eq(_hud.scrub_bar.value, 0.0,
		"scrub bar value should reset to 0 on recording load")


# Verifies the frame count label is updated correctly on load.
func test_recording_loaded_updates_frame_label() -> void:
	_hud._on_recording_loaded("res://fake.bin", 10)
	await get_tree().process_frame

	assert_eq(_hud.frame_count_label.text, "0 / 10",
		"frame label should show '0 / <frame_count>' after load")


# Verifies transport controls become active after a recording is loaded.
func test_recording_loaded_enables_controls() -> void:
	_hud._on_recording_loaded("res://fake.bin", 10)
	await get_tree().process_frame

	assert_false(_hud.start_button.disabled, "start button should be enabled after load")
	assert_false(_hud.pause_button.disabled, "pause button should be enabled after load")
	assert_false(_hud.stop_button.disabled,  "stop button should be enabled after load")
	assert_true(_hud.scrub_bar.editable,     "scrub bar should be editable after load")


# Verifies is_playing is reset to false when a new recording is loaded.
func test_recording_loaded_resets_is_playing() -> void:
	_hud._is_playing = true
	_hud._on_recording_loaded("res://fake.bin", 10)
	await get_tree().process_frame

	assert_false(_hud._is_playing,
		"_is_playing should be false after a new recording is loaded")


# ---- _on_frame_changed() ------------------------------------------------

# Verifies the scrub bar advances to the current frame index.
func test_frame_changed_updates_scrub_bar() -> void:
	_hud._on_recording_loaded("res://fake.bin", 10)
	await get_tree().process_frame

	_hud._on_frame_changed(5, 10)
	await get_tree().process_frame

	assert_eq(_hud.scrub_bar.value, 5.0,
		"scrub bar should reflect the current frame index")


# Verifies the frame label shows current / total correctly.
func test_frame_changed_updates_label() -> void:
	_hud._on_frame_changed(3, 10)
	await get_tree().process_frame

	assert_eq(_hud.frame_count_label.text, "3 / 10",
		"frame label should show 'current / total'")


# Verifies the scrub bar does NOT move while the user is dragging it.
func test_frame_changed_skips_scrub_update_while_dragging() -> void:
	_hud._on_recording_loaded("res://fake.bin", 10)
	await get_tree().process_frame

	_hud.scrub_bar.value = 2.0
	_hud._scrub_bar_dragging = true
	_hud._on_frame_changed(7, 10)
	await get_tree().process_frame

	assert_eq(_hud.scrub_bar.value, 2.0,
		"scrub bar must not move while user is dragging")


# ---- _on_playback_completed() -------------------------------------------

# Verifies is_playing is cleared when playback finishes.
func test_playback_completed_clears_is_playing() -> void:
	_hud._is_playing = true
	_hud._on_playback_completed()
	await get_tree().process_frame

	assert_false(_hud._is_playing,
		"_is_playing should be false after playback completes")


# Verifies the pause button label switches to "Resume" when playback finishes.
func test_playback_completed_updates_pause_button_text() -> void:
	_hud._is_playing = true
	_hud._on_playback_completed()
	await get_tree().process_frame

	assert_eq(_hud.pause_button.text, "Resume",
		"pause button should read 'Resume' after playback completes")


# ---- _on_source_changed() -----------------------------------------------

# Verifies the HUD becomes visible when PLAYBACK source is active.
func test_source_changed_to_playback_shows_hud() -> void:
	_hud.visible = false
	_hud._on_source_changed("PLAYBACK")
	await get_tree().process_frame

	assert_true(_hud.visible, "HUD should be visible when source is PLAYBACK")


# Verifies the HUD hides when switching to a non-playback source.
func test_source_changed_away_hides_hud() -> void:
	_hud.visible = true
	_hud._on_source_changed("LIVE")
	await get_tree().process_frame

	assert_false(_hud.visible, "HUD should hide when source is not PLAYBACK")


# Verifies state resets when switching away from playback.
func test_source_changed_away_resets_state() -> void:
	_hud._on_recording_loaded("res://fake.bin", 10)
	await get_tree().process_frame

	_hud._is_playing = true
	_hud.scrub_bar.value = 5
	_hud._on_source_changed("LIVE")
	await get_tree().process_frame

	assert_false(_hud._is_playing,   "_is_playing should reset on source change")
	assert_eq(_hud.scrub_bar.value, 0.0, "scrub bar should reset on source change")
	assert_eq(_hud.frame_count_label.text, "0 / 0", "frame label should reset on source change")
