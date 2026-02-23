# gd-network

Network primitives for Godot 4 including pooling, retry/backoff, rate limiting, and delta windowing.

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
- `WebSocketClientModule`: reconnecting websocket wrapper node.

## Configuration

No project settings are required.

## Testing

`./run_tests.sh`

## License

MIT
