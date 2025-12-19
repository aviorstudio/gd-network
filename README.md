# gd-network

Game-agnostic network primitives for Godot 4 (HTTP helpers, retry/backoff, rate limiting, windowing, serialization, and error catalog).

- Package: `@aviorstudio/gd-network`
- Godot: `4.x` (tested on `4.4`)

## Install

Place this folder under `res://addons/<addon-dir>/` (for example `res://addons/@aviorstudio_gd-network/`).

- With `gdpm`: install/link into your project's `addons/`.
- Manually: copy or symlink this repo folder into `res://addons/<addon-dir>/`.

## Files

- `plugin.cfg` / `plugin.gd`: editor plugin entry (no runtime behavior).
- `src/http_pool_module.gd`: pooled `HTTPRequest` nodes.
- `src/retry_backoff_module.gd`: exponential backoff helper.
- `src/rate_limit_module.gd`: token bucket rate limiter.
- `src/network_windowing_module.gd`: per-key delta buffers with sequence numbers + pruning.
- `src/object_serialization_module.gd`: object ↔ dictionary serialization helpers.
- `src/error_catalog_module.gd`: error codes/messages + retry metadata (extendable).

## Usage

Preload the script you need:

```gdscript
const RetryBackoff = preload("res://addons/<addon-dir>/src/retry_backoff_module.gd")

var state := RetryBackoff.RetryState.new()
var config := RetryBackoff.RetryConfig.new(250, 2.0, 5, 5000)
state = RetryBackoff.next_retry(Time.get_ticks_msec(), state, config)
```

## Configuration

None (all behavior is configured via function parameters).

## Notes

- Web exports: `HttpPoolModule` disables threads (`HTTPRequest.use_threads = false`).
- This addon intentionally contains no game-specific API; extend `ErrorCatalogModule` at runtime with `register_error(...)` / `register_errors(...)` when needed.
