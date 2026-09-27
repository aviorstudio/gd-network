extends SceneTree

const WebFetchBridgeModule = preload("res://addon/src/web_fetch_bridge_module.gd")
const BEARER_HEADER := "Authorization: Bearer secret-token-not-in-body"
const BEARER_TOKEN := "secret-token-not-in-body"

func _initialize() -> void:
	var failures: Array[String] = []
	var json_script := WebFetchBridgeModule.build_request_script(
		"client-a", "request-1", "https://example.com", "POST",
		PackedStringArray(["X-Test: value", BEARER_HEADER]), "{}", 8388608, 5
	)
	for required in ["client-a", "request-1", "AbortController", "controllers.set", "controllers.delete", "maxBytes=8388608", "maxRedirects=5", "response_too_large", "too_many_redirects", "redirect:'manual'"]:
		if not json_script.contains(required):
			failures.append("Generated browser transport omitted %s" % required)
	_assert_browser_body(failures, json_script, true)
	var empty_script := WebFetchBridgeModule.build_request_script(
		"client-a", "request-0", "https://example.com/sign-out", "POST",
		PackedStringArray([BEARER_HEADER, "Content-Type: application/json", "Accept: application/json"]),
		"", 8388608, 5
	)
	_assert_browser_body(failures, empty_script, false)
	if failures.is_empty():
		print("PASS gd-network web_fetch_bridge_module_test")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _assert_browser_body(failures: Array[String], script: String, expect_json_object: bool) -> void:
	if not script.contains(BEARER_TOKEN):
		failures.append("Expected bearer token in browser header script")
	var body_at := script.find("opts.body=")
	if expect_json_object:
		if not script.contains("opts.body=\"{}\""):
			var snippet := script.substr(maxi(script.find("opts."), 0), 48)
			failures.append("Expected browser script to include opts.body for '{}', saw %s" % snippet)
		if body_at >= 0 and script.substr(body_at).contains(BEARER_TOKEN):
			failures.append("Expected bearer token to stay out of opts.body")
		return
	if script.contains("opts.body"):
		failures.append("Expected browser script to omit opts.body for empty string")
