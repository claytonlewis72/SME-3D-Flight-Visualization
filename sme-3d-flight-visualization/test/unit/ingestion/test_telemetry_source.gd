extends GutTest

func test_telemetry_source_methods_exist():
	var source = TelemetrySource.new()
	assert_true(source.has_method("start"))
	assert_true(source.has_method("stop"))
	assert_true(source.has_method("pause"))
	assert_true(source.has_method("resume"))
