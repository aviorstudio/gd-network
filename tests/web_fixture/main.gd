extends Node

const HttpClientModule = preload("res://addons/@aviorstudio_gd-network/src/http_client_module.gd")

const _BEARER_HEADER := "Authorization: Bearer secret-token-not-in-body"
const _BEARER_TOKEN := "secret-token-not-in-body"

var _first := HttpClientModule.new()
var _second := HttpClientModule.new()
var _results: Dictionary[String, Dictionary] = {}
var _cancel_count := 0

func _ready() -> void:
	var config := HttpClientModule.HttpClientConfig.new()
	config.default_timeout_s = 3.0
	config.base_url = str(JavaScriptBridge.eval("window.location.origin"))
	_first.setup(self, config)
	_second.setup(self, config)
	for index in range(9):
		_first.get_json("/slow/web-%d" % index, _on_overlap.bind(index))
	_second.get_json("/payload/second", _on_second)
	var cancel_id := _second.get_json("/slow/cancel", _on_cancel)
	_second.cancel_request(cancel_id)
	var headers := PackedStringArray([_BEARER_HEADER])
	_second.post_zero_body("/zero", _on_zero, headers)
	_second.post_json("/json-empty", {}, _on_json, headers)
	_second.get_json("/redirect-cross", _on_redirect, headers)
	_second.get_json("/problem", _on_problem)

func _on_overlap(result: Dictionary, index: int) -> void:
	_results[str(index)] = result
	_publish_if_complete()

func _on_second(result: Dictionary) -> void:
	_results["second"] = result
	_publish_if_complete()

func _on_cancel(result: Dictionary) -> void:
	_cancel_count += 1
	_results["cancel"] = result
	_publish_if_complete()

func _on_zero(result: Dictionary) -> void:
	_results["zero"] = result
	_publish_if_complete()

func _on_json(result: Dictionary) -> void:
	_results["json"] = result
	_publish_if_complete()

func _on_redirect(result: Dictionary) -> void:
	_results["redirect"] = result
	_publish_if_complete()

func _on_problem(result: Dictionary) -> void:
	_results["problem"] = result
	_publish_if_complete()

func _publish_if_complete() -> void:
	if _results.size() != 15:
		return
	var success := true
	for index in range(8):
		var result: Dictionary = _results.get(str(index), {})
		success = success and result.get("success", false) and result.get("json", {}).get("id") == "web-%d" % index
	success = success and _results.get("8", {}).get("error_key") == HttpClientModule.ERROR_CAPACITY
	success = success and _results.get("second", {}).get("json", {}).get("id") == "second"
	success = success and _results.get("cancel", {}).get("error_key") == HttpClientModule.ERROR_CANCELLED and _cancel_count == 1
	var zero: Dictionary = _results.get("zero", {})
	var json_result: Dictionary = _results.get("json", {})
	var redirect: Dictionary = _results.get("redirect", {})
	var zero_json: Dictionary = zero.get("json", {})
	var problem: Dictionary = _results.get("problem", {})
	success = success and zero.get("success", false) and int(zero_json.get("bytes", -1)) == 0
	success = success and str(zero_json.get("content_type", "")) == "application/json"
	success = success and bool(zero_json.get("has_authorization", false)) and not bool(zero_json.get("token_in_body", true))
	success = success and json_result.get("success", false) and str(json_result.get("json", {}).get("body", "")) == "{}"
	success = success and not redirect.get("success", true) and str(redirect.get("error_key", "")) == "redirect_error"
	success = success and not str(zero).contains(_BEARER_TOKEN) and not str(json_result).contains(_BEARER_TOKEN) and not str(redirect).contains(_BEARER_TOKEN)
	success = success and not problem.get("success", true) and problem.get("status_code") == 409 and problem.get("error_key") == "http_409"
	success = success and problem.get("error_code") == "operation_conflict" and problem.get("server_request_id") == "server-409" and problem.get("error_message") == "Keep the saved operation"
	success = success and not str(problem.get("request_id", "")).is_empty() and problem.get("request_id") != problem.get("server_request_id")
	var evidence := {
		"success": success,
		"problem": problem,
		"first_count": 9,
		"second": _results.get("second"),
		"cancel_count": _cancel_count,
		"capacity": _results.get("8", {}).get("error_key"),
		"clients": 2,
		"zero_bytes": int(zero_json.get("bytes", -1)),
		"zero_success": bool(zero.get("success", false)),
		"json_body": str(json_result.get("json", {}).get("body", "")),
		"redirect_error": str(redirect.get("error_key", "")),
		"redirect_status": int(redirect.get("status_code", -1)),
	}
	var evidence_json := JSON.stringify(evidence)
	JavaScriptBridge.eval("window.__gdNetworkEvidence=" + evidence_json + ";const p=document.createElement('pre');p.id='network-evidence';p.textContent='gd-network web acceptance\\n'+JSON.stringify(window.__gdNetworkEvidence,null,2);p.style='position:fixed;inset:16px;z-index:99;background:#102033;color:#d8f3ff;padding:24px;font:18px monospace;white-space:pre-wrap';document.body.appendChild(p);")
