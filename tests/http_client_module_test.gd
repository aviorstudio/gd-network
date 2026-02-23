extends SceneTree

const HttpClientModule = preload("res://src/http_client_module.gd")

var _last_payload: Dictionary[String, Variant] = {}

func _initialize() -> void:
	var failures: Array[String] = []
	_test_missing_setup_returns_error(failures)
	_test_error_mapper_applied(failures)

	if failures.is_empty():
		print("PASS gd-network http_client_module_test")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _test_missing_setup_returns_error(failures: Array[String]) -> void:
	_last_payload = {}
	var module := HttpClientModule.new()
	var request_id: String = module.get_json("/health", Callable(self, "_capture_payload"))

	if request_id != "1":
		failures.append("Expected request id 1 for first request")
	if bool(_last_payload.get("success", true)):
		failures.append("Expected request without setup to fail")
	if str(_last_payload.get("error_key", "")) != "request_failed":
		failures.append("Expected request_failed error key when setup is missing")

func _test_error_mapper_applied(failures: Array[String]) -> void:
	var owner := Node.new()
	root.add_child(owner)

	var config := HttpClientModule.HttpClientConfig.new()
	config.base_url = "https://example.com"
	config.error_mapper = func(status_code: int) -> String:
		return "mapped_%d" % status_code

	var module := HttpClientModule.new()
	module.setup(owner, config)
	var response: HttpClientModule.HttpResponse = module._build_response(404, PackedByteArray())

	if response.error_key != "mapped_404":
		failures.append("Expected error mapper to set mapped_404 error_key")
	if response.error_message != "mapped_404":
		failures.append("Expected error mapper to set mapped_404 error_message")
	if module._resolve_full_url("/v1/ping") != "https://example.com/v1/ping":
		failures.append("Expected base URL to be prefixed in resolved endpoint")

	owner.queue_free()

func _capture_payload(payload: Dictionary[String, Variant]) -> void:
	_last_payload = payload
