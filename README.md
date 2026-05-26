# gd-network

Use reusable HTTP, WebSocket, retry, rate-limit, and network-window helpers in Godot 4.

This addon gives you low-level transport building blocks so your game code can own authentication, sessions, matchmaking, and reconnect policy.

## Installation

### Via gdam

`gdam install @aviorstudio/gd-network`

### Manual

Copy `addon/` into `res://addons/@aviorstudio_gd-network/` and enable the plugin.

## Quick Start

```gdscript
const HttpClientModule = preload("res://addons/@aviorstudio_gd-network/src/http_client_module.gd")

var http := HttpClientModule.new()
add_child(http)

http.get_json("https://example.com/api/profile", {}, func(result: Dictionary) -> void:
	if result.success:
		print(result.json)
	else:
		push_warning(result.error_message)
)
```

## Retry Example

```gdscript
const RetryBackoffModule = preload("res://addons/@aviorstudio_gd-network/src/retry_backoff_module.gd")

var state := RetryBackoffModule.RetryState.new()
var config := RetryBackoffModule.RetryConfig.new(250, 2.0, 5, 5000)
state = RetryBackoffModule.next_retry(Time.get_ticks_msec(), state, config)
```

## What You Get

- `HttpClientModule`: callback-based JSON HTTP client for native and web exports.
- `HttpPoolModule`: acquire and release pooled `HTTPRequest` nodes.
- `RetryBackoffModule`: deterministic retry scheduling.
- `RateLimitModule`: token-bucket request limiting.
- `NetworkWindowingModule`: append, read, and prune ordered delta buffers.
- `ErrorCatalogModule`: shared network error keys and metadata.
- `WebSocketClientModule`: minimal reconnecting WebSocket node.
- `WebFetchBridgeModule`: web-only JavaScript fetch bridge used by HTTP helpers.

## HTTP Result Shape

HTTP callbacks receive a dictionary with:

- `success: bool`
- `request_id: String`
- `status_code: int`
- `json: Variant`
- `error_key: String`
- `error_message: String`

## Notes

- No project settings are required.
- Native HTTP uses Godot `HTTPRequest` nodes.
- Web HTTP uses `JavaScriptBridge` through `WebFetchBridgeModule`.
- WebSocket support follows Godot `WebSocketPeer` platform behavior.

## Testing

`./tests/test.sh`

## License

MIT
