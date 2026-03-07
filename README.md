# gd-network

Narrow transport primitives for Godot 4 (pooling, retry/backoff, rate limiting, and bounded delta windowing).

This addon intentionally avoids app-level connection orchestration. Keep match/session lifecycle policy in game code.

## Installation

### Via gdpm
`gdpm install @aviorstudio/gd-network`

### Manual
Copy this directory into `addons/@aviorstudio_gd-network/` and enable the plugin.

## Quick Start

```gdscript
const RetryBackoffModule = preload("res://addons/@aviorstudio_gd-network/src/retry_backoff_module.gd")

var state := RetryBackoffModule.RetryState.new()
var config := RetryBackoffModule.RetryConfig.new(250, 2.0, 5, 5000)
state = RetryBackoffModule.next_retry(Time.get_ticks_msec(), state, config)
```

## API Reference

- `HttpPoolModule`: acquire/release pooled `HTTPRequest` instances.
- `RetryBackoffModule`: deterministic retry scheduling primitives.
- `RateLimitModule`: token-bucket request limiting.
- `NetworkWindowingModule`: append/get/prune ordered delta buffers.
- `ErrorCatalogModule`: reusable network error code and metadata catalog.
- `WebSocketClientModule`: minimal reconnecting websocket node (transport only).
- `WebFetchBridgeModule`: web-only JS interop boundary used by `HttpClientModule`.

## Scope Boundary

- In scope: transport helpers that are reusable across games.
- Out of scope: app-level reconnect policy/state machines, session orchestration, and route-driven networking behavior.

## Configuration

No project settings are required.

## Testing

`./tests/test.sh`

## License

MIT
