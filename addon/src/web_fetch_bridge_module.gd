## Browser fetch bridge with per-client callbacks and per-request AbortControllers.
class_name WebFetchBridgeModule
extends RefCounted

const GLOBAL_REGISTRY_NAME: String = "__godotHttpClients"

static func install_callback(client_id: String, callback: JavaScriptObject) -> void:
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	JavaScriptBridge.eval("window.%s = window.%s || Object.create(null);" % [GLOBAL_REGISTRY_NAME, GLOBAL_REGISTRY_NAME])
	var registry: JavaScriptObject = window.get(GLOBAL_REGISTRY_NAME)
	var client: JavaScriptObject = JavaScriptBridge.create_object("Object")
	client.set("callback", callback)
	client.set("controllers", JavaScriptBridge.create_object("Map"))
	registry.set(client_id, client)

static func begin_request(
	client_id: String,
	request_id: String,
	url: String,
	method: String,
	headers: PackedStringArray,
	body: String,
	max_response_bytes: int,
	max_redirects: int
) -> void:
	JavaScriptBridge.eval(build_request_script(client_id, request_id, url, method, headers, body, max_response_bytes, max_redirects))

static func abort_request(client_id: String, request_id: String) -> void:
	JavaScriptBridge.eval(
		"(function(){const r=window.%s;const c=r&&r[%s];const x=c&&c.controllers.get(%s);if(x){x.abort();c.controllers.delete(%s);}})();"
		% [GLOBAL_REGISTRY_NAME, JSON.stringify(client_id), JSON.stringify(request_id), JSON.stringify(request_id)]
	)

static func cleanup_client(client_id: String) -> void:
	JavaScriptBridge.eval(
		"(function(){const r=window.%s;const c=r&&r[%s];if(!c)return;c.controllers.forEach(x=>x.abort());c.controllers.clear();delete r[%s];})();"
		% [GLOBAL_REGISTRY_NAME, JSON.stringify(client_id), JSON.stringify(client_id)]
	)

static func build_request_script(
	client_id: String,
	request_id: String,
	url: String,
	method: String,
	headers: PackedStringArray,
	body: String,
	max_response_bytes: int,
	max_redirects: int
) -> String:
	var header_dict: Dictionary[String, String] = {}
	for header_line: String in headers:
		var colon_index: int = header_line.find(":")
		if colon_index <= 0:
			continue
		var key: String = header_line.substr(0, colon_index).strip_edges()
		if not key.is_empty():
			header_dict[key] = header_line.substr(colon_index + 1).strip_edges()
	var body_line := ""
	if not body.is_empty():
		body_line = "opts.body=" + JSON.stringify(body) + ";"
	return (
		"(function(){const registry=window.%s;const client=registry&&registry[%s];if(!client)return;"
		+ "const reqId=%s;const controller=new AbortController();client.controllers.set(reqId,controller);"
		+ "const opts={method:%s,headers:%s,signal:controller.signal,redirect:'manual'};%s"
		+ "const maxBytes=%d,maxRedirects=%d;const finish=(value)=>{client.controllers.delete(reqId);if(client.callback)client.callback(reqId,JSON.stringify(value));};"
		+ "const read=async(resp)=>{const declared=Number(resp.headers.get('content-length')||0);if(declared>maxBytes)throw {key:'response_too_large'};"
		+ "if(!resp.body||!resp.body.getReader){const b=await resp.arrayBuffer();if(b.byteLength>maxBytes)throw {key:'response_too_large'};return new TextDecoder().decode(b);}"
		+ "const reader=resp.body.getReader(),chunks=[];let total=0;for(;;){const part=await reader.read();if(part.done)break;total+=part.value.byteLength;if(total>maxBytes){controller.abort();throw {key:'response_too_large'};}chunks.push(part.value);}"
		+ "const all=new Uint8Array(total);let offset=0;for(const chunk of chunks){all.set(chunk,offset);offset+=chunk.byteLength;}return new TextDecoder().decode(all);};"
		+ "const run=async(target,left)=>{const resp=await fetch(target,opts);if(resp.status>=300&&resp.status<400){if(left<=0)throw {key:'too_many_redirects'};const location=resp.headers.get('location');if(!location)throw {key:'redirect_error'};return run(new URL(location,target).href,left-1);}const text=await read(resp);return {ok:resp.ok,status:resp.status,text:text};};"
		+ "run(%s,maxRedirects).then(finish).catch(err=>finish({ok:false,status:0,error_key:(err&&err.key)||((err&&err.name)==='AbortError'?'cancelled':'network_error'),error:String(err)}));})();"
	) % [GLOBAL_REGISTRY_NAME, JSON.stringify(client_id), JSON.stringify(request_id), JSON.stringify(method), JSON.stringify(header_dict), body_line, max_response_bytes, max_redirects, JSON.stringify(url)]
