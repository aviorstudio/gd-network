extends SceneTree

func _initialize() -> void:
	var error_catalog_module := load("res://src/error_catalog_module.gd")
	if error_catalog_module == null:
		push_error("Failed to load res://src/error_catalog_module.gd")
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

	if failures.is_empty():
		print("PASS gd-network error_catalog_module_test")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
