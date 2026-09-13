extends SceneTree

const WebFetchBridgeModule = preload("res://addon/src/web_fetch_bridge_module.gd")

func _initialize() -> void:
	var script := WebFetchBridgeModule.build_request_script(
		"client-a", "request-1", "https://example.com", "POST",
		PackedStringArray(["X-Test: value"]), "{}", 8388608, 5
	)
	var failures: Array[String] = []
	for required in ["client-a", "request-1", "AbortController", "controllers.set", "controllers.delete", "maxBytes=8388608", "maxRedirects=5", "response_too_large", "too_many_redirects", "redirect:'manual'"]:
		if not script.contains(required):
			failures.append("Generated browser transport omitted %s" % required)
	if failures.is_empty():
		print("PASS gd-network web_fetch_bridge_module_test")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
