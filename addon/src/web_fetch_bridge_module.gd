## Browser fetch bridge isolated from transport primitives.
## This module is only used on web builds.
class_name WebFetchBridgeModule
extends RefCounted

const GLOBAL_CALLBACK_NAME: String = "__godotHttpCallback"

## Installs callback used by browser fetch result forwarding.
static func install_callback(callback: JavaScriptObject) -> void:
	JavaScriptBridge.eval("window.%s = null;" % GLOBAL_CALLBACK_NAME)
	var js_interface: JavaScriptObject = JavaScriptBridge.get_interface("window")
	js_interface.set(GLOBAL_CALLBACK_NAME, callback)

## Starts a browser fetch call and routes the serialized response to the callback.
static func begin_request(
	request_id: String,
	url: String,
	method: String,
	headers: PackedStringArray,
	body: String
) -> void:
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
		+ "    if (window." + GLOBAL_CALLBACK_NAME + ") window." + GLOBAL_CALLBACK_NAME + "(reqId, result);\n"
		+ "  });\n"
		+ "}).catch((err) => {\n"
		+ "  const result = JSON.stringify({ ok: false, status: 0, error: String(err) });\n"
		+ "  if (window." + GLOBAL_CALLBACK_NAME + ") window." + GLOBAL_CALLBACK_NAME + "(reqId, result);\n"
		+ "});\n"
		+ "})();"
	)
	JavaScriptBridge.eval(js_code)