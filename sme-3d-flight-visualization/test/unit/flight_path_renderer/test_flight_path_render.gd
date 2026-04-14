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
#|   File Name   : test_flightpath_renderer.gd
#|
#|   Target      : Godot GDScript
#|
#|   Description :
#|       Unit tests for the FlightpathRenderer script using the GUT framework.
#|       Covers point buffer management, distance filtering, gap detection,
#|       orientation color mapping, and mesh segment splitting logic.
#|
#|       MeshInstance3D and TelemetryManager dependencies are stubbed out
#|       so tests run without a full scene tree.
#|
#|   Notes       :
#|       Requires GUT (Godot Unit Testing) framework to be installed.
#|       Mesh rendering calls are not exercised — only buffer and color logic.
#|
#|   POC         :
#|       Aramis Hernandez
#|
#|------------------------------------------------------------------------------------

extends GutTest

#Mesh Instance3D stand-in
class MockMeshInstance:
	var mesh = null
	var material_override = null

#Replaces the telemetryManager autoload singleton
class MockTelemetryManager:
	signal pose_recieved(pos, rot, gap, time)

# --- Setup / Teardown -----------------------------------

# Reference to the renderer node under test
var _renderer

# Reference to the mock telemetry singleton injected into the render
var _telemetry: MockTelemetryManager

#Runs before each test
#automatically called by GUY
func before_each() -> void: 
	_telemetry = MockTelemetryManager.new()
	
	_renderer = load("res://scripts/flightPathRender/flightpath_renderer.gd").new()
	
	# Add a real MeshInstance3D child so @onready can find it
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	_renderer.add_child(mesh_instance)

	
	_renderer.set("TelemetryManager", _telemetry)
	
	add_child_autofree(_renderer)
	await get_tree().process_frame

# --- add_point() -distance filtering test -------------------------------------

#Verifies that the first point is always accepted regardless of distance.
func test_add_point_accepts_first_point() -> void:
	_renderer.add_point(Vector3(0, 0, 0), Vector3.ZERO, false, 0.0)
	assert_eq(_renderer.positions.size(), 1, "First point should always be accepted")

#Verifies that a point too close to the previous one is rejected
func test_add_point_rejects_point_below_min_distance() -> void:
	_renderer.add_point(Vector3(0, 0, 0), Vector3.ZERO, false, 0.0)
	
	#Move less then min_distance (0.2) NOTE: assuming its 0.2
	_renderer.add_point(Vector3(0.1, 0, 0), Vector3.ZERO, false, 0.0)
	assert_eq(_renderer.positions.size(), 1, "point closer than min_distance (0.2) should be rejected ")

func test_add_point_accepts_point_above_min_distance() -> void:
	_renderer.add_point(Vector3(0, 0, 0), Vector3.ZERO, false, 0.0)
	_renderer.add_point(Vector3(1, 0, 0), Vector3.ZERO, false, 0.0)
	assert_eq(_renderer.positions.size(), 2, "point further than min_distance should be accepted")


# ---- add_point() gap detection ------

# Verifies that a point beyond max_distance is flagged as a gap
# by checking that its color is set to red
func test_add_point_flags_gap_when_beyond_max_distance() -> void:
	_renderer.add_point(Vector3(0, 0, 0), Vector3.ZERO, false, 0.0)
	
	_renderer.add_point(Vector3(5, 0, 0), Vector3.ZERO, false, 0.0)
	assert_eq(_renderer.colors[1], Color(1, 0, 0), "point beyond max_distance should be colored red as a gap")

# Verifies that an explicit is_gap = true flag also results in a red vertex
func test_add_point_respects_explicit_gap_flag() -> void:
	_renderer.add_point(Vector3(0, 0, 0), Vector3.ZERO, false, 0.0)
	_renderer.add_point(Vector3(1, 0, 0), Vector3.ZERO, true, 0.1)
	assert_eq(_renderer.colors[1], Color(1, 0, 0), "explicit is_gap flag should produce a red vertex")

# Verifies that a normal point within range is not colored red
func test_add_point_normal_point_is_not_red() -> void:
	_renderer.add_point(Vector3(0, 0, 0), Vector3.ZERO, false, 0.0)
	_renderer.add_point(Vector3(1, 0, 0), Vector3.ZERO, false, 0.1)
	assert_ne(_renderer.colors[1], Color(1, 0, 0), "normal point should not be colored red")


# --- add_point() - buffer cap -------------------------------------

# Verifies that the positions buffer never exceeds max_points, 
# and that the oldest points are dropped when the limit is reached

func test_add_points_caps_buffer_at_max_points() -> void:
	_renderer.max_points = 5
	
	for i in range(10):
		_renderer.add_point(Vector3(i * 1.0, 0, 0), Vector3.ZERO, false, float(i))
	
	assert_eq(_renderer.positions.size(), 5, "positions buffer should not exceed max_points")
	assert_eq(_renderer.colors.size(), 5, "colors buffer should not exceed max_points")

# Verifies that affer capping, the buffer contains the most recent points 
# and not the oldest ones
func test_add_point_drops_oldest_points_when_capped() -> void:
	_renderer.max_points = 3
	
	for i in range(5):
		_renderer.add_point(Vector3(i * 1.0, 0, 0), Vector3.ZERO, false, float(i))
	
	# The oldest points should have been removed
	# The newest point should be contained
	assert_almost_eq(_renderer.positions[2].x, 4.0, 0.0001, "most recent point should be retained after buffer cap")

#---- add_point - dirty flag ---------------------------------

# Verifies that accepting a point marks the renderer as dirty
func test_add_point_sets_dirty_flag() -> void:
	_renderer.dirty = false
	_renderer.add_point(Vector3(0, 0, 0), Vector3.ZERO, false, 0.0)
	assert_true(_renderer.dirty, "accepting a point should set the dirty flag")


# Verifies that a rejected point (below min distance) does not set dirty
func test_rejected_point_does_not_set_dirty_flag() -> void:
	_renderer.add_point(Vector3(0, 0, 0), Vector3.ZERO, false, 0.0)
	_renderer.dirty = false 
	
	# Too close - should be rejected
	_renderer.add_point(Vector3(0.01, 0, 0), Vector3.ZERO, false, 0.1)
	assert_false(_renderer.dirty, "rejected point should not set the dirty flag")
