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
http.setup(self)

http.get_json("https://example.com/api/profile", func(result: Dictionary) -> void:
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

## Bounded Transport Contract

`HttpClientConfig` defaults to eight concurrent requests per client. A ninth
request is rejected immediately with `capacity_exceeded`; a busy request is
never canceled or reused. Request bodies are limited to 1 MiB, response bodies
to 8 MiB, redirects to five, and retained error text to 1 KiB. Absolute HTTP
and HTTPS URLs are supported; relative endpoints require an HTTP(S) `base_url`.

Every accepted request has a generation identity. Capacity, validation,
explicit cancellation, timeout, transport failure, and completion invoke the
request callback exactly once with a typed `error_key`. `cleanup()` and owner
destruction invalidate pending callbacks without invoking consumer code.
Browser requests use a per-client namespace and one `AbortController` per
request; native requests disconnect stale completion signals before reuse.

## Zero-body POST

`HttpClientModule.post_zero_body(endpoint, callback, headers)` sends a POST with exactly zero body bytes. `post_json({})` still serializes and sends `{}`. Put authorization in `headers`; it is not a body field. Headers, timeout, and error callbacks are the same as `post_json`.

Native POST sets `Content-Length: 0` only on the Godot `HTTPRequest` path. Web POST omits the fetch body and does not set `Content-Length`, which browsers forbid.

Web fetch uses `redirect: 'manual'`. A conforming browser exposes an opaque redirect, so the bridge does not follow it and does not send a second request. A visible cross-origin `Location` is also rejected. Native GET still follows redirects through Godot `HTTPRequest` and can resend `Authorization` to the redirect target, including another host. This release does not change that pre-existing native GET behavior.

Added in addon version 0.0.4.

`WebSocketClientModule` uses 1 MiB inbound/outbound buffers, at most 64 queued
packets, and rejects outbound UTF-8 text larger than 1 MiB.

## Notes

- No project settings are required.
- Native HTTP uses Godot `HTTPRequest` nodes.
- Web HTTP uses `JavaScriptBridge` through `WebFetchBridgeModule`.
- WebSocket support follows Godot `WebSocketPeer` platform behavior.

## Repository Layout

- `addon/`: Godot plugin source packaged for GDAM and manual installation.
- `addon/plugin.cfg`: plugin name, version, description, and entry script.
- `addon/src/`: reusable GDScript modules.
- `tests/`: Godot test project/scripts for addon behavior.
- `.github/workflows/ci.yml`: validates package shape and runs tests.
- `.github/workflows/release.yml`: creates GitHub release ZIPs and publishes to GDAM. A verified retry can republish an existing immutable release without creating another tag or ZIP.

## Versioning And Releases

The version in `addon/plugin.cfg` is the addon package version. `0.0.4` adds `post_zero_body`. Releases are created from protected `main` with the manual release workflow and plain semver tags like `v0.0.4`; the workflow verifies `plugin.cfg`, builds `@aviorstudio_gd-network.zip`, and publishes `@aviorstudio/gd-network` to GDAM.

To republish an existing immutable tag after a failed registry publish, dispatch that same workflow from protected `main` with `retry-tag` and `retry-sha256` set together. Retry requires the tag commit to be the current main commit or an ancestor of it, `plugin.cfg` at that tag and on main to equal the tag version, the GitHub release target to match the tag, and the existing `@aviorstudio_gd-network.zip` digest to match `retry-sha256`. Retry downloads and checksums that ZIP. It does not build a package, create a tag, or create a GitHub release. Leave both retry inputs empty for a normal bump.

## Testing

Run locally with:

```sh
./tests/test.sh
./tests/release_recovery_test.sh
```

**Correction ([fieldsofrevik#145](https://github.com/aviorstudio/fieldsofrevik/issues/145)):** the prior text said CI ran the test script
“when available,” which could describe a missing suite as green. CI and Release
now require the Godot 4.7.2 suite, runner negative controls, reachable PASS
sentinels, and tests of the exact closed-manifest ZIP. Missing tests fail.

## License

MIT
