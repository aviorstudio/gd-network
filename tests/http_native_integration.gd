extends SceneTree

const HttpClientModule = preload("res://addon/src/http_client_module.gd")

var _client := HttpClientModule.new()
var _base_url := ""
var _failures: Array[String] = []
var _overlap_results: Dictionary[String, Dictionary] = {}
var _cancel_callbacks := 0
var _phase := "overlap"
var _phase_started_msec := 0

func _initialize() -> void:
	_base_url = "http://127.0.0.1:%s" % OS.get_environment("GD_NETWORK_TEST_PORT")
	var config := HttpClientModule.HttpClientConfig.new()
	config.default_timeout_s = 5.0
	_client.setup(root, config)
	call_deferred("_start_overlap")

func _start_overlap() -> void:
	for index in range(9):
		var request_id := _client.get_json("%s/slow/%d" % [_base_url, index], _on_overlap.bind(index))
		if request_id != str(index + 1):
			_failures.append("Request IDs were not monotonic")
	_phase_started_msec = Time.get_ticks_msec()

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _phase_started_msec > 10000:
		_finish_failure("Integration phase timed out: %s" % _phase)
	return false

func _on_overlap(result: Dictionary, index: int) -> void:
	_overlap_results[str(index)] = result
	if _overlap_results.size() != 9:
		return
	for expected in range(8):
		var payload: Dictionary = _overlap_results.get(str(expected), {})
		if not payload.get("success", false) or str(payload.get("json", {}).get("id", "")) != str(expected):
			_failures.append("Overlapping payload %d was not isolated" % expected)
	if _overlap_results.get("8", {}).get("error_key") != HttpClientModule.ERROR_CAPACITY:
		_failures.append("Ninth overlapping request was not typed capacity rejection")
	_phase = "cancel"
	_phase_started_msec = Time.get_ticks_msec()
	var cancel_id := _client.get_json(_base_url + "/slow/cancel", _on_cancel)
	if not _client.cancel_request(cancel_id):
		_failures.append("Expected immediate cancel to find request")
	create_timer(0.7).timeout.connect(_after_cancel, CONNECT_ONE_SHOT)

func _on_cancel(result: Dictionary) -> void:
	_cancel_callbacks += 1
	if result.get("error_key") != HttpClientModule.ERROR_CANCELLED:
		_failures.append("Cancel did not return typed cancelled outcome")

func _after_cancel() -> void:
	if _cancel_callbacks != 1:
		_failures.append("Cancel or late completion invoked %d callbacks" % _cancel_callbacks)
	_phase = "timeout"
	_phase_started_msec = Time.get_ticks_msec()
	_client.set_default_timeout(0.05)
	_client.get_json(_base_url + "/slow/timeout", _on_timeout)

func _on_timeout(result: Dictionary) -> void:
	if result.get("error_key") != HttpClientModule.ERROR_TIMEOUT:
		_failures.append("Timeout did not return network_timeout")
	_phase = "oversize"
	_phase_started_msec = Time.get_ticks_msec()
	_client.set_default_timeout(2.0)
	_client._config.max_response_body_bytes = 64
	_client.get_json(_base_url + "/large", _on_oversize)

func _on_oversize(result: Dictionary) -> void:
	if result.get("error_key") != HttpClientModule.ERROR_RESPONSE_TOO_LARGE:
		_failures.append("Oversized response did not return response_too_large")
	_phase = "redirect"
	_phase_started_msec = Time.get_ticks_msec()
	_client._config.max_response_body_bytes = 8 * 1024 * 1024
	_client._config.max_redirects = 1
	_client.get_json(_base_url + "/redirect/2", _on_redirect)

func _on_redirect(result: Dictionary) -> void:
	if result.get("error_key") != HttpClientModule.ERROR_TOO_MANY_REDIRECTS:
		_failures.append("Redirect chain above configured limit was not typed too_many_redirects")
	_phase = "reuse"
	_phase_started_msec = Time.get_ticks_msec()
	_client._config.max_redirects = 5
	_client.get_json(_base_url + "/payload/reused", _on_reuse)

func _on_reuse(result: Dictionary) -> void:
	if not result.get("success", false) or result.get("json", {}).get("id") != "reused":
		_failures.append("Successful pooled request reuse failed")
	_client.cleanup()
	if _failures.is_empty():
		print("PASS gd-network http_native_integration")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _finish_failure(message: String) -> void:
	push_error(message)
	_client.cleanup()
	quit(1)
