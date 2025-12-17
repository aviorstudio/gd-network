extends RefCounted

class PoolEntry extends RefCounted:
	var node: HTTPRequest
	var busy: bool = false
	var callback: Callable
	var request_id: String = ""

const WEB_RESPONSE_POLL_LIMIT: int = 300
const WEB_POLL_DELAY_S: float = 0.1
const DEFAULT_DOWNLOAD_CHUNK_SIZE: int = 65536

static func create_entry(owner: Node, default_timeout_s: float, chunk_size: int = DEFAULT_DOWNLOAD_CHUNK_SIZE) -> PoolEntry:
	var request_node := HTTPRequest.new()
	request_node.use_threads = not OS.has_feature("web")
	request_node.timeout = default_timeout_s
	request_node.download_chunk_size = chunk_size
	if owner:
		owner.add_child(request_node)

	var entry := PoolEntry.new()
	entry.node = request_node
	return entry

static func acquire_request(owner: Node, pool: Array[PoolEntry], default_timeout_s: float, chunk_size: int = DEFAULT_DOWNLOAD_CHUNK_SIZE) -> PoolEntry:
	for entry in pool:
		if not entry.busy:
			entry.busy = true
			entry.node.timeout = default_timeout_s
			return entry

	var entry := create_entry(owner, default_timeout_s, chunk_size)
	entry.busy = true
	pool.append(entry)
	return entry

static func release_request(entry: PoolEntry) -> void:
	if not entry:
		return
	entry.busy = false
	entry.callback = Callable()
	entry.request_id = ""

static func next_request_counter(current_counter: int) -> int:
	return current_counter + 1

static func post_json_web(
	owner: Node,
	base_url: String,
	endpoint: String,
	body: Dictionary[String, Variant],
	extra_headers: PackedStringArray,
	timeout_s: float,
	default_timeout_s: float,
	request_id: String,
	on_response: Callable
) -> void:
	if not owner:
		return

	var url := base_url + endpoint if not endpoint.begins_with("http") else endpoint
	var json_body := JSON.stringify(body)
	var timeout_ms: int = int((timeout_s if timeout_s > 0.0 else default_timeout_s) * 1000.0)

	var headers_dict: Dictionary[String, String] = {
		"Content-Type": "application/json",
		"Accept": "application/json"
	}

	for header in extra_headers:
		var parts: PackedStringArray = header.split(":", false, 1)
		if parts.size() == 2:
			headers_dict[parts[0].strip_edges()] = parts[1].strip_edges()

	var js_code := """
	(function() {
		const controller = new AbortController();
		const timeoutId = setTimeout(() => controller.abort(), %d);

		fetch('%s', {
			method: 'POST',
			headers: %s,
			body: '%s',
			signal: controller.signal
		})
		.then(response => {
			clearTimeout(timeoutId);
			const status = response.status;
			return response.text().then(text => ({status, text}));
		})
		.then(({status, text}) => {
			window.godotHttpResponse_%s = {
				success: status === 200,
				status_code: status,
				body: text,
				error: null
			};
		})
		.catch(error => {
			clearTimeout(timeoutId);
			window.godotHttpResponse_%s = {
				success: false,
				status_code: 0,
				body: '',
				error: error.toString()
			};
		});
	})();
	""" % [timeout_ms, url, JSON.stringify(headers_dict), json_body.replace("'", "\\'"), request_id, request_id]

	JavaScriptBridge.eval(js_code)

	_poll_web_response(owner, request_id, on_response, 0)

static func _poll_web_response(owner: Node, request_id: String, on_response: Callable, poll_count: int) -> void:
	var check_code := "JSON.stringify(window.godotHttpResponse_%s || null)" % request_id
	var result_json: String = JavaScriptBridge.eval(check_code)

	if result_json == "null" or result_json.is_empty():
		if poll_count < WEB_RESPONSE_POLL_LIMIT:
			await owner.get_tree().create_timer(WEB_POLL_DELAY_S).timeout
			_poll_web_response(owner, request_id, on_response, poll_count + 1)
		else:
			_emit_web_response(on_response, request_id, _build_web_error_result(request_id, "Request timeout"))
		return

	var json_parser := JSON.new()
	var parse_error := json_parser.parse(result_json)
	if parse_error != OK or not (json_parser.data is Dictionary):
		_emit_web_response(on_response, request_id, _build_web_error_result(request_id, "Failed to parse response from JavaScript"))
		return

	var parsed_data: Dictionary = json_parser.data as Dictionary
	var result: Dictionary[String, Variant] = {}
	for key in parsed_data.keys():
		result[str(key)] = parsed_data.get(key)
	var cleanup_code := "delete window.godotHttpResponse_%s;" % request_id
	JavaScriptBridge.eval(cleanup_code)

	var response: Dictionary[String, Variant] = {
		"request_id": request_id,
		"success": bool(result.get("success", false)),
		"status_code": int(result.get("status_code", 0)),
		"body": str(result.get("body", "")),
		"error": result.get("error")
	}

	_emit_web_response(on_response, request_id, response)

static func _build_web_error_result(request_id: String, message: String) -> Dictionary[String, Variant]:
	return {
		"request_id": request_id,
		"success": false,
		"status_code": 0,
		"body": "",
		"error": message
	}

static func _emit_web_response(on_response: Callable, request_id: String, result: Dictionary[String, Variant]) -> void:
	if not on_response.is_valid():
		return
	on_response.call(request_id, result)
