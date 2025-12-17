extends RefCounted

# Game-agnostic error catalog for network/transport layers.
# Consumer projects can register additional error codes at runtime.

const NETWORK_TIMEOUT := "network_timeout"
const NETWORK_ERROR := "network_error"
const SERVER_ERROR := "server_error"
const RATE_LIMITED := "rate_limited"
const HTTP_4XX := "http_4xx"
const HTTP_5XX := "http_5xx"
const PARSE_ERROR := "parse_error"
const REQUEST_FAILED := "request_failed"
const EMPTY_RESPONSE := "empty_response"

static func _entry(message: String, delay: float = 0.0, severity: int = 1) -> Dictionary[String, Variant]:
	return {
		"message": message,
		"retry_delay_s": delay,
		"severity": severity
	}

static var _MAP: Dictionary[String, Dictionary] = {
	NETWORK_TIMEOUT: _entry("Request timed out", 1.0, 2),
	NETWORK_ERROR: _entry("Network error, please try again", 1.0, 2),
	SERVER_ERROR: _entry("Server error, please try again", 1.0, 2),
	RATE_LIMITED: _entry("Too many requests, please try again", 1.0, 1),
	HTTP_4XX: _entry("Request failed", 0.0, 2),
	HTTP_5XX: _entry("Server error", 1.0, 2),
	PARSE_ERROR: _entry("Failed to parse response", 0.0, 2),
	REQUEST_FAILED: _entry("Request failed", 0.0, 2),
	EMPTY_RESPONSE: _entry("Empty response", 0.0, 2),
}

static func register_error(code: String, message: String, delay: float = 0.0, severity: int = 1) -> void:
	if code.is_empty():
		return
	_MAP[code] = _entry(message, delay, severity)

static func register_errors(entries: Dictionary[String, Dictionary]) -> void:
	for code: String in entries:
		if code.is_empty():
			continue
		var entry_value: Dictionary = entries.get(code, {})
		if entry_value.is_empty():
			continue
		_MAP[code] = entry_value.duplicate(true)

static func resolve_message(code_or_message: String) -> String:
	if _MAP.has(code_or_message):
		return get_safe_message(code_or_message)
	return code_or_message

static func get_safe_message(key: String) -> String:
	var entry: Dictionary = _MAP.get(key, {})
	if not entry.is_empty():
		return str(entry.get("message", "An error occurred"))
	return "An error occurred"

static func get_retry_delay_s(key: String, attempt: int = 1) -> float:
	var entry: Dictionary = _MAP.get(key, {})
	if not entry.is_empty():
		var base_delay: float = float(entry.get("retry_delay_s", 0.0))
		if base_delay > 0.0 and key == RATE_LIMITED:
			return pow(2, max(attempt, 1)) * base_delay
		return base_delay
	return 1.0

static func get_severity(key: String) -> int:
	var entry: Dictionary = _MAP.get(key, {})
	if not entry.is_empty():
		return int(entry.get("severity", 1))
	return 1

# Compatibility helper for inputs like "http_404".
static func map_http_error(error_message: String) -> String:
	if error_message.begins_with("http_"):
		var parts: PackedStringArray = error_message.split("_", false, 2)
		if parts.size() >= 2:
			var status_code: int = int(parts[1])
			if status_code >= 400 and status_code <= 499:
				return HTTP_4XX
			if status_code >= 500 and status_code <= 599:
				return HTTP_5XX

	if error_message.begins_with("request_failed") or error_message.begins_with("request_error"):
		return REQUEST_FAILED
	if error_message == PARSE_ERROR:
		return PARSE_ERROR
	if error_message == EMPTY_RESPONSE:
		return EMPTY_RESPONSE
	return SERVER_ERROR
