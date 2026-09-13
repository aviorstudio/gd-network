extends SceneTree

var _last_payload: Dictionary[String, Variant] = {}
var _callback_count: int = 0

func _load_http_client_module() -> Variant:
	return load("res://addon/src/http_client_module.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	_test_missing_setup_returns_error(failures)
	_test_error_mapper_applied(failures)
	_test_native_request_pool_reuse(failures)
	_test_bounds_validation_and_capacity(failures)
	_test_cancel_generation_and_cleanup(failures)
	_test_two_client_instances(failures)

	if failures.is_empty():
		print("PASS gd-network http_client_module_test")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _test_missing_setup_returns_error(failures: Array[String]) -> void:
	var http_client_module: Variant = _load_http_client_module()
	if http_client_module == null:
		failures.append("Failed to load res://addon/src/http_client_module.gd")
		return
	_last_payload = {}
	var module = http_client_module.new()
	var request_id: String = module.get_json("/health", Callable(self, "_capture_payload"))

	if request_id != "1":
		failures.append("Expected request id 1 for first request")
	if bool(_last_payload.get("success", true)):
		failures.append("Expected request without setup to fail")
	if str(_last_payload.get("error_key", "")) != "request_failed":
		failures.append("Expected request_failed error key when setup is missing")

func _test_error_mapper_applied(failures: Array[String]) -> void:
	var http_client_module: Variant = _load_http_client_module()
	if http_client_module == null:
		failures.append("Failed to load res://addon/src/http_client_module.gd")
		return
	var owner := Node.new()
	root.add_child(owner)

	var config = http_client_module.HttpClientConfig.new()
	config.base_url = "https://example.com"
	config.error_mapper = func(status_code: int) -> String:
		return "mapped_%d" % status_code

	var module = http_client_module.new()
	module.setup(owner, config)
	var response = module._build_response(404, PackedByteArray())

	if response.error_key != "mapped_404":
		failures.append("Expected error mapper to set mapped_404 error_key")
	if response.error_message != "mapped_404":
		failures.append("Expected error mapper to set mapped_404 error_message")
	if module._resolve_full_url("/v1/ping") != "https://example.com/v1/ping":
		failures.append("Expected base URL to be prefixed in resolved endpoint")

	owner.queue_free()

func _test_native_request_pool_reuse(failures: Array[String]) -> void:
	var http_client_module: Variant = _load_http_client_module()
	if http_client_module == null:
		failures.append("Failed to load res://addon/src/http_client_module.gd")
		return

	var owner := Node.new()
	root.add_child(owner)
	var module = http_client_module.new()
	module.setup(owner, http_client_module.HttpClientConfig.new())

	var entry: Variant = module.HttpPoolModule.acquire_request(owner, module._pool, 5.0)
	entry.callback = Callable(self, "_capture_payload")
	entry.request_id = "1"
	module._native_requests["1"] = entry
	module._on_native_request_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray(), "1", entry.generation)

	if module._pool.size() != 1:
		failures.append("Expected pooled request array size to remain 1 after completion")

	var reused_entry: Variant = module.HttpPoolModule.acquire_request(owner, module._pool, 5.0)
	if reused_entry.node != entry.node:
		failures.append("Expected second native request acquisition to reuse pooled HTTPRequest node")

	module.cleanup()
	owner.queue_free()

func _test_bounds_validation_and_capacity(failures: Array[String]) -> void:
	var script: Variant = _load_http_client_module()
	var owner := Node.new()
	root.add_child(owner)
	var config = script.HttpClientConfig.new()
	config.max_concurrent_requests = 0
	config.max_request_body_bytes = 4
	config.max_error_message_bytes = 8
	var module = script.new()
	module.setup(owner, config)
	module.get_json("ftp://example.com/file", Callable(self, "_capture_payload"))
	if _last_payload.get("error_key") != script.ERROR_UNSUPPORTED_SCHEME:
		failures.append("Expected unsupported_scheme for ftp URL")
	module.get_json("/relative", Callable(self, "_capture_payload"))
	if _last_payload.get("error_key") != script.ERROR_INVALID_URL:
		failures.append("Expected invalid_url for relative URL without base")
	module.post_json("https://example.com", {"long": "payload"}, Callable(self, "_capture_payload"))
	if _last_payload.get("error_key") != script.ERROR_CAPACITY:
		failures.append("Expected capacity check before transport at zero capacity")
	config.max_concurrent_requests = 8
	module.post_json("https://example.com", {"long": "payload"}, Callable(self, "_capture_payload"))
	if _last_payload.get("error_key") != script.ERROR_REQUEST_TOO_LARGE:
		failures.append("Expected typed request_too_large")
	if str(_last_payload.get("error_message", "")).to_utf8_buffer().size() > 8:
		failures.append("Expected retained error text to respect byte bound")
	module.cleanup()
	owner.queue_free()

func _test_cancel_generation_and_cleanup(failures: Array[String]) -> void:
	var script: Variant = _load_http_client_module()
	var owner := Node.new()
	root.add_child(owner)
	var module = script.new()
	module.setup(owner)
	_callback_count = 0
	var entry: Variant = module.HttpPoolModule.acquire_request(owner, module._pool, 5.0)
	entry.callback = Callable(self, "_count_payload")
	entry.request_id = "old"
	module._native_requests["old"] = entry
	if not module.cancel_request("old"):
		failures.append("Expected active native request cancellation")
	if _callback_count != 1 or _last_payload.get("error_key") != script.ERROR_CANCELLED:
		failures.append("Expected exactly one typed cancellation callback")
	module._on_native_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "{}".to_utf8_buffer(), "old", entry.generation)
	if _callback_count != 1:
		failures.append("Expected late cancelled completion to be ignored")
	var current: Variant = module.HttpPoolModule.acquire_request(owner, module._pool, 5.0)
	current.callback = Callable(self, "_count_payload")
	current.request_id = "current"
	module._native_requests["current"] = current
	var stale_generation: int = current.generation - 1
	module._on_native_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "{}".to_utf8_buffer(), "current", stale_generation)
	if _callback_count != 1 or not module._native_requests.has("current"):
		failures.append("Expected stale generation to leave current request untouched")
	module.cleanup()
	module._on_native_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "{}".to_utf8_buffer(), "current", current.generation)
	if _callback_count != 1:
		failures.append("Expected cleanup and owner teardown to suppress callbacks")
	owner.queue_free()

func _test_two_client_instances(failures: Array[String]) -> void:
	var script: Variant = _load_http_client_module()
	var owner_a := Node.new()
	var owner_b := Node.new()
	root.add_child(owner_a)
	root.add_child(owner_b)
	var first = script.new()
	var second = script.new()
	first.setup(owner_a)
	second.setup(owner_b)
	if first._client_id.is_empty() or first._client_id == second._client_id:
		failures.append("Expected per-instance browser client namespaces")
	first.cleanup()
	second.cleanup()
	owner_a.queue_free()
	owner_b.queue_free()

func _capture_payload(payload: Dictionary[String, Variant]) -> void:
	_last_payload = payload

func _count_payload(payload: Dictionary[String, Variant]) -> void:
	_callback_count += 1
	_last_payload = payload
