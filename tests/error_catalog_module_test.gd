extends SceneTree

func _initialize() -> void:
	var error_catalog_module := load("res://addon/src/error_catalog_module.gd")
	if error_catalog_module == null:
		push_error("Failed to load res://addon/src/error_catalog_module.gd")
		quit(1)
		return

	var catalog: Dictionary[String, Dictionary] = error_catalog_module.DEFAULT_CATALOG.duplicate(true)
	error_catalog_module.register_error(catalog, "custom_error", "Custom message", 2.5, 3)

	var resolved_message: String = error_catalog_module.resolve_message(catalog, "custom_error")
	var safe_message: String = error_catalog_module.get_safe_message(catalog, "custom_error")
	var delay_s: float = error_catalog_module.get_retry_delay_s(catalog, "custom_error")
	var severity: int = error_catalog_module.get_severity(catalog, "custom_error")

	var failures: Array[String] = []
	if resolved_message != "Custom message":
		failures.append("resolve_message did not return registered message")
	if safe_message != "Custom message":
		failures.append("get_safe_message did not return registered message")
	if not is_equal_approx(delay_s, 2.5):
		failures.append("get_retry_delay_s did not return registered delay")
	if severity != 3:
		failures.append("get_severity did not return registered severity")

	_test_register_errors_bulk(error_catalog_module, catalog, failures)
	_test_map_http_error_edges(error_catalog_module, catalog, failures)

	if failures.is_empty():
		print("PASS gd-network error_catalog_module_test")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _test_register_errors_bulk(error_catalog_module: Variant, catalog: Dictionary[String, Dictionary], failures: Array[String]) -> void:
	var entries: Dictionary[String, Dictionary] = {}
	entries["bulk_a"] = {
		"message": "Bulk A",
		"retry_delay_s": 1.0,
		"severity": 2,
	}
	entries[""] = {
		"message": "ignored",
	}
	entries["bulk_empty"] = {}
	error_catalog_module.register_errors(catalog, entries)

	if error_catalog_module.resolve_message(catalog, "bulk_a") != "Bulk A":
		failures.append("register_errors did not add valid bulk entry")
	if catalog.has(""):
		failures.append("register_errors should ignore empty error code")
	if catalog.has("bulk_empty"):
		failures.append("register_errors should ignore empty entry dictionaries")

func _test_map_http_error_edges(error_catalog_module: Variant, catalog: Dictionary[String, Dictionary], failures: Array[String]) -> void:
	var mapped_404: String = error_catalog_module.map_http_error(catalog, "http_404")
	if mapped_404 != error_catalog_module.HTTP_4XX:
		failures.append("map_http_error should map 4xx status codes to HTTP_4XX")

	var mapped_500: String = error_catalog_module.map_http_error(catalog, "http_500")
	if mapped_500 != error_catalog_module.HTTP_5XX:
		failures.append("map_http_error should map 5xx status codes to HTTP_5XX")

	var mapped_request_error: String = error_catalog_module.map_http_error(catalog, "request_error_1")
	if mapped_request_error != error_catalog_module.REQUEST_FAILED:
		failures.append("map_http_error should map request_error* to REQUEST_FAILED")

	var mapped_parse_error: String = error_catalog_module.map_http_error(catalog, error_catalog_module.PARSE_ERROR)
	if mapped_parse_error != error_catalog_module.PARSE_ERROR:
		failures.append("map_http_error should preserve parse_error key")

	var mapped_unknown: String = error_catalog_module.map_http_error(catalog, "something_else")
	if mapped_unknown != error_catalog_module.SERVER_ERROR:
		failures.append("map_http_error should default unknown values to SERVER_ERROR")
