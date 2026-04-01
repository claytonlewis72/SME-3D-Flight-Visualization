extends GutTest


# Called when the node enters the scene tree for the first time.
func get_next_camera_index(current_index: int, total:int) -> int:
	return(current_index + 1) % total


# Called every frame. 'delta' is the elapsed time since the previous frame.
func test_camera_index_moves_forward():
	assert_eq(get_next_camera_index(0, 3), 1)
	
func test_camera_index_wraps_to_zero():
	assert_eq(get_next_camera_index(2, 3), 0)
