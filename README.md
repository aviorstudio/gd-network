# gd-network

Network primitives addon for Godot 4.

This package is intended to be linked/installed via `gdpm` and loaded from `res://addons/<addon-dir>/...`.

## Included scripts
- `src/http_pool_module.gd` — pooled `HTTPRequest` nodes (web exports run without threads; no JS bridge).
- `src/retry_backoff_module.gd` — exponential backoff helper.
- `src/rate_limit_module.gd` — token bucket rate limiter.
- `src/network_windowing_module.gd` — per-key delta buffers with sequence numbers + pruning.
- `src/object_serialization_module.gd` — object ↔ dictionary serialization helpers.
- `src/error_catalog_module.gd` — game-agnostic error codes/messages + retry metadata (extendable).

## Usage
Preload the script you need:

```gdscript
const HttpPoolModule = preload("res://addons/@your_addon_dir/src/http_pool_module.gd")
```

Note: scripts are intentionally loaded via `preload(...)` (they do not rely on global `class_name` registration).
