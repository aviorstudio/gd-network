extends SceneTree

var _last_payload: Dictionary[String, Variant] = {}
var _callback_count: int = 0
var _transport_active := false
var _transport_server: TCPServer = null
var _transport_peers: Array[Dictionary] = []
var _captured_requests: Dictionary[String, Dictionary] = {}
var _transport_deadline_msec := 0
var _transport_module: Variant = null
var _transport_owner: Node = null
var _transport_port := 0

const _BEARER_HEADER := "Authorization: Bearer secret-token-not-in-body"
const _BEARER_TOKEN := "secret-token-not-in-body"
const _CONFIGURED_TIMEOUT_S := 8.0

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
	_test_zero_body_without_setup(failures)

	if not failures.is_empty():
		_finish(failures)
		return
	_start_zero_body_transport(failures)
	if not failures.is_empty():
		_finish(failures)

func _process(_delta: float) -> bool:
	if _transport_active:
		_poll_zero_body_transport()
	return false

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

func _test_zero_body_without_setup(failures: Array[String]) -> void:
	var http_client_module: Variant = _load_http_client_module()
	if http_client_module == null:
		failures.append("Failed to load res://addon/src/http_client_module.gd")
		return
	var fresh_config = http_client_module.HttpClientConfig.new()
	if fresh_config.default_timeout_s != 10.0:
		failures.append("Expected default per-request timeout to remain 10 seconds")
	_last_payload = {}
	var module = http_client_module.new()
	module.post_zero_body("https://example.com/sign-out", Callable(self, "_capture_payload"), PackedStringArray([_BEARER_HEADER]))
	if str(_last_payload.get("error_key", "")) != "request_failed":
		failures.append("Expected post_zero_body without setup to fail like other requests")
	if str(_last_payload).contains(_BEARER_TOKEN):
		failures.append("Expected bearer token to stay out of the zero-body error payload")

func _start_zero_body_transport(failures: Array[String]) -> void:
	_transport_port = _listen_transport()
	if _transport_port == 0:
		failures.append("Expected a local TCP listener for the native zero-body POST")
		return
	var http_client_module: Variant = _load_http_client_module()
	_transport_owner = Node.new()
	root.add_child(_transport_owner)
	var config = http_client_module.HttpClientConfig.new()
	config.default_timeout_s = _CONFIGURED_TIMEOUT_S
	_transport_module = http_client_module.new()
	_transport_module.setup(_transport_owner, config)
	call_deferred("_send_zero_body_transport")

func _send_zero_body_transport() -> void:
	var failures: Array[String] = []
	var headers := PackedStringArray([_BEARER_HEADER])
	var zero_id: String = _transport_module.post_zero_body("http://127.0.0.1:%d/zero" % _transport_port, Callable(), headers)
	var json_id: String = _transport_module.post_json("http://127.0.0.1:%d/json" % _transport_port, {}, Callable(), headers)
	_assert_native_timeout(failures, zero_id, "post_zero_body")
	_assert_native_timeout(failures, json_id, "post_json")
	if not failures.is_empty():
		_finish(failures)
		return
	_transport_deadline_msec = Time.get_ticks_msec() + 4000
	_transport_active = true

func _assert_native_timeout(failures: Array[String], request_id: String, label: String) -> void:
	var entry: Variant = _transport_module._native_requests.get(request_id, null)
	if entry == null:
		failures.append("Expected %s to enter the native request path" % label)
		return
	if entry.node.timeout != _CONFIGURED_TIMEOUT_S:
		failures.append("Expected %s to keep the configured 8-second timeout, got %s" % [label, str(entry.node.timeout)])

func _listen_transport() -> int:
	for port in range(18765, 18785):
		var server := TCPServer.new()
		if server.listen(port, "127.0.0.1") == OK:
			_transport_server = server
			return port
		server.stop()
	return 0

func _poll_zero_body_transport() -> void:
	while _transport_server != null and _transport_server.is_connection_available():
		var peer: StreamPeerTCP = _transport_server.take_connection()
		_transport_peers.append({"peer": peer, "buffer": PackedByteArray(), "done": false})
	var index := 0
	while index < _transport_peers.size():
		var state: Dictionary = _transport_peers[index]
		if not bool(state.get("done", false)):
			_read_transport_peer(state)
			_transport_peers[index] = state
			var parsed := _complete_http_request(state.get("buffer", PackedByteArray()))
			if not parsed.is_empty():
				var path := str(parsed.get("path", ""))
				_captured_requests[path] = parsed
				var peer: StreamPeerTCP = state.get("peer")
				peer.put_data("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}".to_utf8_buffer())
				state["done"] = true
				_transport_peers[index] = state
		index += 1
	if _captured_requests.has("/zero") and _captured_requests.has("/json"):
		var failures: Array[String] = []
		_assert_captured_requests(failures)
		_finish(failures)
		return
	if Time.get_ticks_msec() > _transport_deadline_msec:
		var failures: Array[String] = []
		failures.append("Timed out waiting for native POST bodies; captured %s" % str(_captured_requests.keys()))
		_finish(failures)

func _read_transport_peer(state: Dictionary) -> void:
	var peer: StreamPeerTCP = state.get("peer")
	var available := peer.get_available_bytes()
	if available <= 0:
		return
	var chunk: Array = peer.get_data(available)
	if int(chunk[0]) != OK:
		return
	var buffer: PackedByteArray = state.get("buffer", PackedByteArray())
	buffer.append_array(chunk[1])
	state["buffer"] = buffer

func _complete_http_request(buffer: PackedByteArray) -> Dictionary:
	var raw := buffer.get_string_from_utf8()
	var marker := "\r\n\r\n"
	var header_end := raw.find(marker)
	if header_end < 0:
		return {}
	var header_text := raw.substr(0, header_end)
	var body_text := raw.substr(header_end + marker.length())
	var content_length := -1
	for line in header_text.split("\r\n"):
		if line.to_lower().begins_with("content-length:"):
			content_length = int(line.substr(line.find(":") + 1).strip_edges())
	if content_length >= 0 and body_text.to_utf8_buffer().size() < content_length:
		return {}
	if content_length >= 0:
		body_text = body_text.substr(0, content_length)
	var request_line := header_text.get_slice("\r\n", 0)
	return {
		"path": request_line.get_slice(" ", 1),
		"headers": header_text,
		"body": body_text,
		"content_length": content_length,
		"raw": raw,
	}

func _assert_captured_requests(failures: Array[String]) -> void:
	var zero: Dictionary = _captured_requests.get("/zero", {})
	var json_request: Dictionary = _captured_requests.get("/json", {})
	var zero_body := str(zero.get("body", ""))
	var json_body := str(json_request.get("body", ""))
	if zero_body.to_utf8_buffer().size() != 0:
		failures.append("Expected post_zero_body to send zero bytes, got %d (%s)" % [zero_body.to_utf8_buffer().size(), zero_body])
	var zero_length_count := 0
	for line in str(zero.get("headers", "")).split("\r\n"):
		if line.to_lower().begins_with("content-length:"):
			zero_length_count += 1
	if zero_length_count != 1 or int(zero.get("content_length", -1)) != 0 or not str(zero.get("headers", "")).contains("Content-Length: 0"):
		failures.append("Expected exactly one native Content-Length: 0, got count %d value %s" % [zero_length_count, str(zero.get("content_length", -1))])
	if str(zero.get("raw", "")).contains("{}"):
		failures.append("Expected native zero-body POST to exclude '{}'")
	if json_body != "{}":
		failures.append("Expected post_json({}) to remain '{}', got %s" % json_body)
	if json_body.to_utf8_buffer().size() != 2:
		failures.append("Expected post_json({}) to send 2 bytes")
	if int(json_request.get("content_length", -1)) != 2:
		failures.append("Expected post_json({}) Content-Length to remain 2, got %s" % str(json_request.get("content_length", -1)))
	for path in ["/zero", "/json"]:
		var captured: Dictionary = _captured_requests.get(path, {})
		var headers := str(captured.get("headers", ""))
		var body := str(captured.get("body", ""))
		if not headers.begins_with("POST "):
			failures.append("Expected native POST for %s" % path)
		if not headers.contains("Content-Type: application/json"):
			failures.append("Expected shared JSON content type on %s" % path)
		if not headers.contains("Accept: application/json"):
			failures.append("Expected shared Accept header on %s" % path)
		if not headers.contains(_BEARER_HEADER):
			failures.append("Expected Authorization bearer header on %s" % path)
		if body.contains(_BEARER_TOKEN):
			failures.append("Expected bearer token to stay out of %s body" % path)

func _finish(failures: Array[String]) -> void:
	_transport_active = false
	if _transport_module != null:
		_transport_module.cleanup()
	if _transport_server != null:
		_transport_server.stop()
	if _transport_owner != null:
		_transport_owner.queue_free()
	if failures.is_empty():
		print("PASS gd-network http_client_module_test")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _count_payload(payload: Dictionary[String, Variant]) -> void:
	_callback_count += 1
	_last_payload = payload
