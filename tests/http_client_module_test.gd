extends SceneTree

var _last_payload: Dictionary[String, Variant] = {}

func _load_http_client_module() -> Variant:
	return load("res://addon/src/http_client_module.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	_test_missing_setup_returns_error(failures)
	_test_error_mapper_applied(failures)
	_test_native_request_pool_reuse(failures)

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
	module._on_native_request_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray(), "1")

	if module._pool.size() != 1:
		failures.append("Expected pooled request array size to remain 1 after completion")

	var reused_entry: Variant = module.HttpPoolModule.acquire_request(owner, module._pool, 5.0)
	if reused_entry.node != entry.node:
		failures.append("Expected second native request acquisition to reuse pooled HTTPRequest node")

	module.cleanup()
	owner.queue_free()

func _capture_payload(payload: Dictionary[String, Variant]) -> void:
	_last_payload = payload
