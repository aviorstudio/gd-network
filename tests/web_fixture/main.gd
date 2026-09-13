extends Node

const HttpClientModule = preload("res://addons/@aviorstudio_gd-network/src/http_client_module.gd")

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

func _publish_if_complete() -> void:
	if _results.size() != 11:
		return
	var success := true
	for index in range(8):
		var result: Dictionary = _results.get(str(index), {})
		success = success and result.get("success", false) and result.get("json", {}).get("id") == "web-%d" % index
	success = success and _results.get("8", {}).get("error_key") == HttpClientModule.ERROR_CAPACITY
	success = success and _results.get("second", {}).get("json", {}).get("id") == "second"
	success = success and _results.get("cancel", {}).get("error_key") == HttpClientModule.ERROR_CANCELLED and _cancel_count == 1
	var evidence := {"success": success, "first_count": 9, "second": _results.get("second"), "cancel_count": _cancel_count, "capacity": _results.get("8", {}).get("error_key"), "clients": 2}
	var evidence_json := JSON.stringify(evidence)
	JavaScriptBridge.eval("window.__gdNetworkEvidence=" + evidence_json + ";const p=document.createElement('pre');p.id='network-evidence';p.textContent='gd-network web acceptance\\n'+JSON.stringify(window.__gdNetworkEvidence,null,2);p.style='position:fixed;inset:16px;z-index:99;background:#102033;color:#d8f3ff;padding:24px;font:18px monospace;white-space:pre-wrap';document.body.appendChild(p);")
