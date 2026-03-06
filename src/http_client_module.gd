## Game-agnostic HTTP JSON client supporting native HTTPRequest and web fetch bridges.
class_name HttpClientModule
extends RefCounted

const HttpPoolModule = preload("http_pool_module.gd")
const HEADER_CONTENT_TYPE_JSON: String = "Content-Type: application/json"
const HEADER_ACCEPT_JSON: String = "Accept: application/json"
const ERROR_REQUEST_FAILED: String = "request_failed"
const ERROR_PARSE_ERROR: String = "parse_error"

## Runtime configuration for HttpClientModule.
class HttpClientConfig extends RefCounted:
	var base_url: String = ""
	var default_timeout_s: float = 10.0
	var error_mapper: Callable = Callable()

## Normalized HTTP response payload.
class HttpResponse extends RefCounted:
	var success: bool = false
	var status_code: int = 0
	var json: Variant = null
	var error_key: String = ""
	var error_message: String = ""

class RequestEntry extends RefCounted:
	var callback: Callable

	func _init(callback_value: Callable) -> void:
		callback = callback_value

var _owner: Node = null
var _config: HttpClientConfig = HttpClientConfig.new()
var _pending_requests: Dictionary[String, RequestEntry] = {}
var _native_requests: Dictionary[String, HttpPoolModule.PoolEntry] = {}
var _pool: Array[HttpPoolModule.PoolEntry] = []
var _request_counter: int = 0
var _js_callback: JavaScriptObject = null

## Initializes the module with an owner node used for HTTPRequest lifecycle and timers.
func setup(owner: Node, config: HttpClientConfig = null) -> void:
	_owner = owner
	_config = config if config != null else HttpClientConfig.new()
	if OS.has_feature("web"):
		_js_callback = JavaScriptBridge.create_callback(_on_web_result_ready)
		JavaScriptBridge.eval("window.__godotHttpCallback = null;")
		var js_interface: JavaScriptObject = JavaScriptBridge.get_interface("window")
		js_interface.__godotHttpCallback = _js_callback

## Executes a JSON GET request.
func get_json(endpoint: String, callback: Callable, headers: PackedStringArray = PackedStringArray()) -> String:
	return _execute_request(HTTPClient.METHOD_GET, endpoint, callback, headers)

## Executes a JSON POST request.
func post_json(endpoint: String, body: Dictionary, callback: Callable, headers: PackedStringArray = PackedStringArray()) -> String:
	return _execute_request(HTTPClient.METHOD_POST, endpoint, callback, headers, body)

## Executes a JSON PUT request.
func put_json(endpoint: String, body: Dictionary, callback: Callable, headers: PackedStringArray = PackedStringArray()) -> String:
	return _execute_request(HTTPClient.METHOD_PUT, endpoint, callback, headers, body)

## Executes a JSON DELETE request.
func delete_json(endpoint: String, callback: Callable, headers: PackedStringArray = PackedStringArray()) -> String:
	return _execute_request(HTTPClient.METHOD_DELETE, endpoint, callback, headers)

## Updates the configured base URL.
func set_base_url(url: String) -> void:
	_config.base_url = url

## Updates the default request timeout in seconds.
func set_default_timeout(timeout_s: float) -> void:
	_config.default_timeout_s = timeout_s

func _execute_request(method: HTTPClient.Method, endpoint: String, callback: Callable, extra_headers: PackedStringArray, body: Dictionary = {}) -> String:
	_request_counter += 1
	var request_id: String = str(_request_counter)
	if _owner == null:
		_send_error(callback, request_id, 0, ERROR_REQUEST_FAILED)
		return request_id

	var full_url: String = _resolve_full_url(endpoint)
	if full_url.is_empty():
		_send_error(callback, request_id, 0, ERROR_REQUEST_FAILED)
		return request_id

	var headers: PackedStringArray = PackedStringArray()
	if method == HTTPClient.METHOD_POST or method == HTTPClient.METHOD_PUT:
		headers.append(HEADER_CONTENT_TYPE_JSON)
	headers.append(HEADER_ACCEPT_JSON)
	headers.append_array(extra_headers)

	var json_body: String = ""
	if method == HTTPClient.METHOD_POST or method == HTTPClient.METHOD_PUT:
		var payload: Dictionary[String, Variant] = {}
		for key in body.keys():
			payload[str(key)] = body.get(key)
		json_body = JSON.stringify(payload)

	if OS.has_feature("web"):
		var timeout_ms: int = int(_config.default_timeout_s * 1000.0)
		_pending_requests[request_id] = RequestEntry.new(callback)
		_schedule_web_timeout(request_id, timeout_ms)
		_begin_web_request(request_id, full_url, _method_to_string(method), headers, json_body)
		return request_id

	_begin_native_request(request_id, full_url, method, headers, json_body, callback)
	return request_id

func _begin_web_request(request_id: String, url: String, method: String, headers: PackedStringArray, body: String) -> void:
	var header_dict: Dictionary[String, String] = {}
	for header_line: String in headers:
		var colon_index: int = header_line.find(":")
		if colon_index <= 0:
			continue
		var key: String = header_line.substr(0, colon_index).strip_edges()
		if key.is_empty():
			continue
		var value: String = header_line.substr(colon_index + 1).strip_edges()
		header_dict[key] = value

	var req_id_json: String = JSON.stringify(request_id)
	var url_json: String = JSON.stringify(url)
	var method_json: String = JSON.stringify(method)
	var headers_json: String = JSON.stringify(header_dict)
	var body_line: String = ""
	if not body.is_empty():
		body_line = "opts.body = " + JSON.stringify(body) + ";\n"

	var js_code: String = (
		"(function(){\n"
		+ "const reqId = " + req_id_json + ";\n"
		+ "const url = " + url_json + ";\n"
		+ "const opts = { method: " + method_json + ", headers: " + headers_json + " };\n"
		+ body_line
		+ "fetch(url, opts).then((resp) => {\n"
		+ "  return resp.text().then((text) => {\n"
		+ "    const result = JSON.stringify({ ok: resp.ok, status: resp.status, text: text });\n"
		+ "    if (window.__godotHttpCallback) window.__godotHttpCallback(reqId, result);\n"
		+ "  });\n"
		+ "}).catch((err) => {\n"
		+ "  const result = JSON.stringify({ ok: false, status: 0, error: String(err) });\n"
		+ "  if (window.__godotHttpCallback) window.__godotHttpCallback(reqId, result);\n"
		+ "});\n"
		+ "})();"
	)
	JavaScriptBridge.eval(js_code)

func _on_web_result_ready(args: Array) -> void:
	if args.size() < 2:
		return
	var request_id: String = str(args[0])
	var result_json: String = str(args[1])
	var entry: RequestEntry = _pending_requests.get(request_id, null)
	if entry == null:
		return
	_pending_requests.erase(request_id)
	var parsed: JSON = JSON.new()
	if parsed.parse(result_json) != OK or not (parsed.data is Dictionary):
		_send_error(entry.callback, request_id, 0, ERROR_PARSE_ERROR)
		return

	var payload: Dictionary[String, Variant] = _coerce_dict(parsed.data)
	var ok: bool = bool(payload.get("ok", false))
	var status_code: int = int(payload.get("status", 0))
	if not ok:
		_send_error(entry.callback, request_id, status_code, _map_error_key(status_code, ERROR_REQUEST_FAILED))
		return

	var body_text: String = str(payload.get("text", ""))
	_finalize_response(status_code, body_text.to_utf8_buffer(), entry.callback)

func _schedule_web_timeout(request_id: String, timeout_ms: int) -> void:
	if timeout_ms <= 0 or _owner == null or _owner.get_tree() == null:
		return
	var timeout_seconds: float = float(timeout_ms) / 1000.0
	var timer: SceneTreeTimer = _owner.get_tree().create_timer(timeout_seconds)
	timer.timeout.connect(_on_web_request_timeout.bind(request_id), CONNECT_ONE_SHOT)

func _on_web_request_timeout(request_id: String) -> void:
	var entry: RequestEntry = _pending_requests.get(request_id, null)
	if entry == null:
		return
	_pending_requests.erase(request_id)
	_send_error(entry.callback, request_id, 0, ERROR_REQUEST_FAILED)

func _begin_native_request(request_id: String, url: String, method: HTTPClient.Method, headers: PackedStringArray, body: String, callback: Callable) -> void:
	var entry: HttpPoolModule.PoolEntry = HttpPoolModule.acquire_request(_owner, _pool, _config.default_timeout_s)
	entry.callback = callback
	entry.request_id = request_id
	var request: HTTPRequest = entry.node
	_native_requests[request_id] = entry
	request.request_completed.connect(_on_native_request_completed.bind(request_id), CONNECT_ONE_SHOT)
	var err: int = request.request(url, headers, method, body)
	if err != OK:
		_native_requests.erase(request_id)
		HttpPoolModule.release_request(entry)
		_send_error(callback, request_id, 0, ERROR_REQUEST_FAILED)

func _on_native_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request_id: String) -> void:
	var entry: HttpPoolModule.PoolEntry = _native_requests.get(request_id, null)
	if entry == null:
		return
	_native_requests.erase(request_id)
	var callback: Callable = entry.callback
	HttpPoolModule.release_request(entry)
	if result != HTTPRequest.RESULT_SUCCESS:
		_send_error(callback, request_id, response_code, _map_error_key(response_code, ERROR_REQUEST_FAILED))
		return
	_finalize_response(response_code, body, callback)

func cleanup() -> void:
	for request_id in _native_requests.keys():
		var entry: HttpPoolModule.PoolEntry = _native_requests.get(request_id, null)
		if entry:
			HttpPoolModule.release_request(entry)
	_native_requests.clear()
	_pending_requests.clear()
	for entry in _pool:
		if entry and entry.node and is_instance_valid(entry.node):
			entry.node.queue_free()
	_pool.clear()

func _send_error(callback: Callable, _request_id: String, status_code: int, error_key: String) -> void:
	var response := HttpResponse.new()
	response.success = false
	response.status_code = status_code
	response.error_key = error_key
	response.error_message = _resolve_error_message(status_code, error_key)
	callback.call(_response_to_dict(response))

func _finalize_response(status_code: int, body_bytes: PackedByteArray, callback: Callable) -> void:
	var response: HttpResponse = _build_response(status_code, body_bytes)
	callback.call(_response_to_dict(response))

func _coerce_dict(value: Variant) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	if value is Dictionary:
		out.merge(value)
	return out

func _build_response(code: int, raw: PackedByteArray) -> HttpResponse:
	var out := HttpResponse.new()
	out.success = false
	out.status_code = code
	out.json = null
	out.error_key = ""
	out.error_message = ""

	var body_str: String = raw.get_string_from_utf8()
	if code >= 200 and code < 300:
		if body_str.is_empty():
			out.success = true
			out.json = {}
			return out
		var json_parser: JSON = JSON.new()
		if json_parser.parse(body_str) == OK:
			out.success = true
			out.json = json_parser.data
		else:
			out.error_key = _map_error_key(code, ERROR_PARSE_ERROR)
			out.error_message = _resolve_error_message(code, out.error_key)
		return out

	out.error_key = _map_error_key(code, "http_" + str(code))
	out.error_message = _resolve_error_message(code, out.error_key)

	if not body_str.is_empty():
		var json_parser: JSON = JSON.new()
		if json_parser.parse(body_str) == OK and json_parser.data is Dictionary:
			var error_data: Dictionary[String, Variant] = _coerce_dict(json_parser.data)
			if error_data.has("msg"):
				out.error_message = str(error_data.get("msg"))
			elif error_data.has("error_message"):
				out.error_message = str(error_data.get("error_message"))
			elif error_data.has("errorMessage"):
				out.error_message = str(error_data.get("errorMessage"))
	return out

func _response_to_dict(response: HttpResponse) -> Dictionary[String, Variant]:
	return {
		"success": response.success,
		"status_code": response.status_code,
		"json": response.json,
		"error_key": response.error_key,
		"error_message": response.error_message,
	}

func _resolve_full_url(endpoint: String) -> String:
	if endpoint.begins_with("http://") or endpoint.begins_with("https://"):
		return endpoint
	if _config.base_url.is_empty():
		return endpoint
	if _config.base_url.ends_with("/") and endpoint.begins_with("/"):
		return _config.base_url.trim_suffix("/") + endpoint
	if not _config.base_url.ends_with("/") and not endpoint.begins_with("/"):
		return _config.base_url + "/" + endpoint
	return _config.base_url + endpoint

func _method_to_string(method: HTTPClient.Method) -> String:
	match method:
		HTTPClient.METHOD_GET:
			return "GET"
		HTTPClient.METHOD_POST:
			return "POST"
		HTTPClient.METHOD_PUT:
			return "PUT"
		HTTPClient.METHOD_DELETE:
			return "DELETE"
		_:
			return "GET"

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
