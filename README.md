# gd-network

Narrow transport primitives for Godot 4 (HTTP, WebSocket, pooling, retry/backoff, rate limiting, and bounded delta windowing).

This addon intentionally avoids app-level connection orchestration. Keep match/session lifecycle policy in game code.

## Installation

### Via gdpm
`gdpm install @aviorstudio/gd-network`

### Manual
Copy `addon/` into `addons/@aviorstudio_gd-network/` and enable the plugin.

## Quick Start

```gdscript
const RetryBackoffModule = preload("res://addons/@aviorstudio_gd-network/src/retry_backoff_module.gd")

var state := RetryBackoffModule.RetryState.new()
var config := RetryBackoffModule.RetryConfig.new(250, 2.0, 5, 5000)
state = RetryBackoffModule.next_retry(Time.get_ticks_msec(), state, config)
```

## API Reference

- `HttpClientModule`: callback-based JSON HTTP client for native and web exports.
- `HttpPoolModule`: acquire/release pooled `HTTPRequest` instances.
- `RetryBackoffModule`: deterministic retry scheduling primitives.
- `RateLimitModule`: token-bucket request limiting.
- `NetworkWindowingModule`: append/get/prune ordered delta buffers.
- `ErrorCatalogModule`: reusable network error code and metadata catalog.
- `WebSocketClientModule`: minimal reconnecting websocket node (transport only).
- `WebFetchBridgeModule`: web-only JS interop boundary used by `HttpClientModule`.

`HttpClientModule.cancel_request(request_id)` cancels pending native requests and ignores late web responses for cancelled IDs.

`HttpClientModule` callbacks receive a dictionary with:

- `success: bool`
- `request_id: String`
- `status_code: int`
- `json: Variant`
- `error_key: String`
- `error_message: String`

## Scope Boundary

- In scope: transport helpers that are reusable across games.
- Out of scope: app-level reconnect policy/state machines, session orchestration, and route-driven networking behavior.

## Configuration

No project settings are required.

## Compatibility

- Godot 4.x.
- Native HTTP uses `HTTPRequest` nodes.
- Web HTTP uses `JavaScriptBridge` through `WebFetchBridgeModule`.
- WebSocket support follows Godot `WebSocketPeer` platform behavior.

## API Stability

The stable public API is the module classes under `src/`. Authentication, session refresh, matchmaking, app reconnect policy, and route-level behavior belong in game code.

## Testing

`./tests/test.sh`

## License

MIT
