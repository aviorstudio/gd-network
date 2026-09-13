## Bounded JSON HTTP client supporting native HTTPRequest and browser fetch.
class_name HttpClientModule
extends RefCounted

const HttpPoolModule = preload("http_pool_module.gd")
const WebFetchBridgeModule = preload("web_fetch_bridge_module.gd")
const HEADER_CONTENT_TYPE_JSON := "Content-Type: application/json"
const HEADER_ACCEPT_JSON := "Accept: application/json"
const ERROR_REQUEST_FAILED := "request_failed"
const ERROR_PARSE_ERROR := "parse_error"
const ERROR_CAPACITY := "capacity_exceeded"
const ERROR_CANCELLED := "cancelled"
const ERROR_TIMEOUT := "network_timeout"
const ERROR_INVALID_URL := "invalid_url"
const ERROR_UNSUPPORTED_SCHEME := "unsupported_scheme"
const ERROR_REQUEST_TOO_LARGE := "request_too_large"
const ERROR_RESPONSE_TOO_LARGE := "response_too_large"
const ERROR_TOO_MANY_REDIRECTS := "too_many_redirects"

class HttpClientConfig extends RefCounted:
	var base_url := ""
	var default_timeout_s := 10.0
	var error_mapper: Callable = Callable()
	var max_concurrent_requests := 8
	var max_request_body_bytes := 1024 * 1024
	var max_response_body_bytes := 8 * 1024 * 1024
	var max_redirects := 5
	var max_error_message_bytes := 1024

class HttpResponse extends RefCounted:
	var success := false
	var request_id := ""
	var status_code := 0
	var json: Variant = null
	var error_key := ""
	var error_message := ""

class RequestEntry extends RefCounted:
	var callback: Callable
	var generation: int
	func _init(callback_value: Callable, generation_value: int) -> void:
		callback = callback_value
		generation = generation_value

var _owner: Node = null
var _config := HttpClientConfig.new()
var _pending_requests: Dictionary[String, RequestEntry] = {}
var _native_requests: Dictionary[String, HttpPoolModule.PoolEntry] = {}
var _pool: Array[HttpPoolModule.PoolEntry] = []
var _request_counter := 0
var _generation_counter := 0
var _client_id := ""
var _js_callback: JavaScriptObject = null
var _active := false

func setup(owner: Node, config: HttpClientConfig = null) -> void:
	cleanup()
	_owner = owner
	_config = config if config != null else HttpClientConfig.new()
	_active = owner != null
	_client_id = str(get_instance_id())
	if _owner != null and not _owner.tree_exiting.is_connected(_on_owner_tree_exiting):
		_owner.tree_exiting.connect(_on_owner_tree_exiting)
	if _active and OS.has_feature("web"):
		_js_callback = JavaScriptBridge.create_callback(_on_web_result_ready)
		WebFetchBridgeModule.install_callback(_client_id, _js_callback)

func get_json(endpoint: String, callback: Callable, headers: PackedStringArray = PackedStringArray()) -> String:
	return _execute_request(HTTPClient.METHOD_GET, endpoint, callback, headers)

func post_json(endpoint: String, body: Dictionary, callback: Callable, headers: PackedStringArray = PackedStringArray()) -> String:
	return _execute_request(HTTPClient.METHOD_POST, endpoint, callback, headers, body)

func put_json(endpoint: String, body: Dictionary, callback: Callable, headers: PackedStringArray = PackedStringArray()) -> String:
	return _execute_request(HTTPClient.METHOD_PUT, endpoint, callback, headers, body)

func delete_json(endpoint: String, callback: Callable, headers: PackedStringArray = PackedStringArray()) -> String:
	return _execute_request(HTTPClient.METHOD_DELETE, endpoint, callback, headers)

func set_base_url(url: String) -> void:
	_config.base_url = url

func set_default_timeout(timeout_s: float) -> void:
	_config.default_timeout_s = timeout_s

func cancel_request(request_id: String) -> bool:
	var pending: RequestEntry = _pending_requests.get(request_id, null)
	if pending != null:
		_pending_requests.erase(request_id)
		if OS.has_feature("web"):
			WebFetchBridgeModule.abort_request(_client_id, request_id)
		_send_error(pending.callback, request_id, 0, ERROR_CANCELLED)
		return true
	var entry: HttpPoolModule.PoolEntry = _native_requests.get(request_id, null)
	if entry == null:
		return false
	_native_requests.erase(request_id)
	_disconnect_entry(entry)
	entry.node.cancel_request()
	var callback := entry.callback
	HttpPoolModule.release_request(entry)
	_send_error(callback, request_id, 0, ERROR_CANCELLED)
	return true

func _execute_request(method: HTTPClient.Method, endpoint: String, callback: Callable, extra_headers: PackedStringArray, body: Dictionary = {}) -> String:
	_request_counter += 1
	_generation_counter += 1
	var request_id := str(_request_counter)
	if not _active or not _owner_is_alive():
		_send_error(callback, request_id, 0, ERROR_REQUEST_FAILED)
		return request_id
	var full_url := _resolve_full_url(endpoint)
	var validation_error := _validate_url(full_url)
	if not validation_error.is_empty():
		_send_error(callback, request_id, 0, validation_error)
		return request_id
	if _active_request_count() >= max(_config.max_concurrent_requests, 0):
		_send_error(callback, request_id, 0, ERROR_CAPACITY)
		return request_id

	var headers := PackedStringArray([HEADER_ACCEPT_JSON])
	if method == HTTPClient.METHOD_POST or method == HTTPClient.METHOD_PUT:
		headers.insert(0, HEADER_CONTENT_TYPE_JSON)
	headers.append_array(extra_headers)
	var json_body := ""
	if method == HTTPClient.METHOD_POST or method == HTTPClient.METHOD_PUT:
		json_body = JSON.stringify(body)
		if json_body.to_utf8_buffer().size() > _config.max_request_body_bytes:
			_send_error(callback, request_id, 0, ERROR_REQUEST_TOO_LARGE)
			return request_id

	if OS.has_feature("web"):
		_pending_requests[request_id] = RequestEntry.new(callback, _generation_counter)
		_schedule_web_timeout(request_id, _generation_counter)
		WebFetchBridgeModule.begin_request(_client_id, request_id, full_url, _method_to_string(method), headers, json_body, _config.max_response_body_bytes, _config.max_redirects)
	else:
		_begin_native_request(request_id, full_url, method, headers, json_body, callback)
	return request_id

func _begin_native_request(request_id: String, url: String, method: HTTPClient.Method, headers: PackedStringArray, body: String, callback: Callable) -> void:
	var entry := HttpPoolModule.acquire_request(_owner, _pool, _config.default_timeout_s, HttpPoolModule.DEFAULT_DOWNLOAD_CHUNK_SIZE, _config.max_concurrent_requests)
	if entry == null:
		_send_error(callback, request_id, 0, ERROR_CAPACITY)
		return
	entry.callback = callback
	entry.request_id = request_id
	entry.node.body_size_limit = _config.max_response_body_bytes
	entry.node.max_redirects = _config.max_redirects
	entry.completion_callable = _on_native_request_completed.bind(request_id, entry.generation)
	entry.node.request_completed.connect(entry.completion_callable, CONNECT_ONE_SHOT)
	_native_requests[request_id] = entry
	var error := entry.node.request(url, headers, method, body)
	if error != OK:
		_native_requests.erase(request_id)
		_disconnect_entry(entry)
		HttpPoolModule.release_request(entry)
		_send_error(callback, request_id, 0, ERROR_REQUEST_FAILED)

func _on_native_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request_id: String, generation: int) -> void:
	var entry: HttpPoolModule.PoolEntry = _native_requests.get(request_id, null)
	if entry == null or entry.generation != generation or entry.request_id != request_id:
		return
	_native_requests.erase(request_id)
	var callback := entry.callback
	HttpPoolModule.release_request(entry)
	if not _owner_is_alive():
		return
	if result == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
		_send_error(callback, request_id, response_code, ERROR_RESPONSE_TOO_LARGE)
	elif result == HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
		_send_error(callback, request_id, response_code, ERROR_TOO_MANY_REDIRECTS)
	elif result == HTTPRequest.RESULT_TIMEOUT:
		_send_error(callback, request_id, response_code, ERROR_TIMEOUT)
	elif result != HTTPRequest.RESULT_SUCCESS:
		_send_error(callback, request_id, response_code, _map_error_key(response_code, ERROR_REQUEST_FAILED))
	else:
		_finalize_response(request_id, response_code, body, callback)

func _on_web_result_ready(args: Array) -> void:
	if args.size() < 2:
		return
	var request_id := str(args[0])
	var entry: RequestEntry = _pending_requests.get(request_id, null)
	if entry == null:
		return
	_pending_requests.erase(request_id)
	if not _owner_is_alive():
		return
	var parsed := JSON.new()
	if parsed.parse(str(args[1])) != OK or not parsed.data is Dictionary:
		_send_error(entry.callback, request_id, 0, ERROR_PARSE_ERROR)
		return
	var payload: Dictionary = parsed.data
	var status_code := int(payload.get("status", 0))
	if not bool(payload.get("ok", false)):
		var key := str(payload.get("error_key", ""))
		if key.is_empty():
			key = _map_error_key(status_code, ERROR_REQUEST_FAILED)
		_send_error(entry.callback, request_id, status_code, key)
		return
	var body_bytes := str(payload.get("text", "")).to_utf8_buffer()
	if body_bytes.size() > _config.max_response_body_bytes:
		_send_error(entry.callback, request_id, status_code, ERROR_RESPONSE_TOO_LARGE)
		return
	_finalize_response(request_id, status_code, body_bytes, entry.callback)

func _schedule_web_timeout(request_id: String, generation: int) -> void:
	if _config.default_timeout_s <= 0.0 or not _owner_is_alive() or _owner.get_tree() == null:
		return
	_owner.get_tree().create_timer(_config.default_timeout_s).timeout.connect(_on_web_request_timeout.bind(request_id, generation), CONNECT_ONE_SHOT)

func _on_web_request_timeout(request_id: String, generation: int) -> void:
	var entry: RequestEntry = _pending_requests.get(request_id, null)
	if entry == null or entry.generation != generation:
		return
	_pending_requests.erase(request_id)
	if OS.has_feature("web"):
		WebFetchBridgeModule.abort_request(_client_id, request_id)
	_send_error(entry.callback, request_id, 0, ERROR_TIMEOUT)

func cleanup() -> void:
	_active = false
	if OS.has_feature("web") and not _client_id.is_empty():
		WebFetchBridgeModule.cleanup_client(_client_id)
	for request_id in _native_requests.keys():
		var entry: HttpPoolModule.PoolEntry = _native_requests.get(request_id, null)
		if entry != null:
			_disconnect_entry(entry)
			entry.node.cancel_request()
			HttpPoolModule.release_request(entry)
	_native_requests.clear()
	_pending_requests.clear()
	for entry in _pool:
		if entry != null and is_instance_valid(entry.node):
			entry.node.queue_free()
	_pool.clear()
	if _owner != null and is_instance_valid(_owner) and _owner.tree_exiting.is_connected(_on_owner_tree_exiting):
		_owner.tree_exiting.disconnect(_on_owner_tree_exiting)
	_owner = null
	_js_callback = null

func _on_owner_tree_exiting() -> void:
	cleanup()

func _disconnect_entry(entry: HttpPoolModule.PoolEntry) -> void:
	if entry.completion_callable.is_valid() and entry.node.request_completed.is_connected(entry.completion_callable):
		entry.node.request_completed.disconnect(entry.completion_callable)

func _owner_is_alive() -> bool:
	return _active and _owner != null and is_instance_valid(_owner) and not _owner.is_queued_for_deletion()

func _active_request_count() -> int:
	return _pending_requests.size() if OS.has_feature("web") else _native_requests.size()

func _send_error(callback: Callable, request_id: String, status_code: int, error_key: String) -> void:
	if not callback.is_valid():
		return
	var response := HttpResponse.new()
	response.request_id = request_id
	response.status_code = status_code
	response.error_key = error_key
	response.error_message = _truncate_utf8(_resolve_error_message(status_code, error_key), _config.max_error_message_bytes)
	callback.call(_response_to_dict(response))

func _finalize_response(request_id: String, status_code: int, body_bytes: PackedByteArray, callback: Callable) -> void:
	if body_bytes.size() > _config.max_response_body_bytes:
		_send_error(callback, request_id, status_code, ERROR_RESPONSE_TOO_LARGE)
		return
	var response := _build_response(status_code, body_bytes)
	response.request_id = request_id
	if callback.is_valid():
		callback.call(_response_to_dict(response))

func _build_response(code: int, raw: PackedByteArray) -> HttpResponse:
	var out := HttpResponse.new()
	out.status_code = code
	var body_str := raw.get_string_from_utf8()
	if code >= 200 and code < 300:
		if body_str.is_empty():
			out.success = true
			out.json = {}
			return out
		var parser := JSON.new()
		if parser.parse(body_str) == OK:
			out.success = true
			out.json = parser.data
		else:
			out.error_key = _map_error_key(code, ERROR_PARSE_ERROR)
			out.error_message = _resolve_error_message(code, out.error_key)
		return out
	out.error_key = _map_error_key(code, "http_" + str(code))
	out.error_message = _resolve_error_message(code, out.error_key)
	if not body_str.is_empty():
		var parser := JSON.new()
		if parser.parse(body_str) == OK and parser.data is Dictionary:
			for key in ["msg", "error_message", "errorMessage"]:
				if parser.data.has(key):
					out.error_message = _truncate_utf8(str(parser.data.get(key)), _config.max_error_message_bytes)
					break
	return out

func _response_to_dict(response: HttpResponse) -> Dictionary[String, Variant]:
	return {"success": response.success, "request_id": response.request_id, "status_code": response.status_code, "json": response.json, "error_key": response.error_key, "error_message": response.error_message}

func _resolve_full_url(endpoint: String) -> String:
	if endpoint.contains("://"):
		return endpoint
	if _config.base_url.is_empty():
		return endpoint
	if _config.base_url.ends_with("/") and endpoint.begins_with("/"):
		return _config.base_url.trim_suffix("/") + endpoint
	if not _config.base_url.ends_with("/") and not endpoint.begins_with("/"):
		return _config.base_url + "/" + endpoint
	return _config.base_url + endpoint

func _validate_url(url: String) -> String:
	var delimiter := url.find("://")
	if delimiter <= 0:
		return ERROR_INVALID_URL
	var scheme := url.substr(0, delimiter).to_lower()
	if scheme != "http" and scheme != "https":
		return ERROR_UNSUPPORTED_SCHEME
	var authority := url.substr(delimiter + 3).get_slice("/", 0)
	if authority.is_empty() or authority.contains(" "):
		return ERROR_INVALID_URL
	return ""

func _method_to_string(method: HTTPClient.Method) -> String:
	return ["GET", "HEAD", "POST", "PUT", "DELETE", "CONNECT", "OPTIONS", "TRACE", "PATCH"][int(method)] if int(method) >= 0 and int(method) <= 8 else "GET"

func _map_error_key(status_code: int, fallback_key: String) -> String:
	if _config.error_mapper.is_valid():
		var mapped: Variant = _config.error_mapper.call(status_code)
		if mapped is String and not str(mapped).is_empty():
			return str(mapped)
	return fallback_key

func _resolve_error_message(status_code: int, error_key: String) -> String:
	if _config.error_mapper.is_valid():
		var mapped: Variant = _config.error_mapper.call(status_code)
		if mapped is String and not str(mapped).is_empty():
			return str(mapped)
	return error_key

func _truncate_utf8(value: String, max_bytes: int) -> String:
	if max_bytes <= 0:
		return ""
	var bytes := value.to_utf8_buffer()
	if bytes.size() <= max_bytes:
		return value
	bytes.resize(max_bytes)
	return bytes.get_string_from_utf8()
