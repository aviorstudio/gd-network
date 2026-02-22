extends SceneTree

const WebSocketClientModule = preload("res://src/websocket_client_module.gd")
const RetryBackoffModule = preload("res://src/retry_backoff_module.gd")

var _reconnecting_attempt: int = -1

func _initialize() -> void:
	var failures: Array[String] = []
	_test_initial_state_and_reconnect_signal(failures)

	if failures.is_empty():
		print("PASS gd-network websocket_client_module_state_test")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _test_initial_state_and_reconnect_signal(failures: Array[String]) -> void:
	var module := WebSocketClientModule.new()
	if module.state != WebSocketClientModule.ConnectionState.DISCONNECTED:
		failures.append("Expected initial websocket state to be DISCONNECTED")
	if module.reconnect_count != 0:
		failures.append("Expected initial reconnect_count to be 0")

	module.reconnecting.connect(Callable(self, "_capture_reconnecting"))	
	module._active = true
	module._url = "ws://127.0.0.1:65535"
	module._retry_config = RetryBackoffModule.RetryConfig.new(1, 1.0, 3)
	module._retry_state = RetryBackoffModule.RetryState.new(1, Time.get_ticks_msec() - 1, false)

	module._retry_connect_if_due(Time.get_ticks_msec())

	if _reconnecting_attempt != 1:
		failures.append("Expected reconnecting signal with current retry attempt")
	if module.reconnect_count != 1:
		failures.append("Expected reconnect_count to increment on retry attempt")

func _capture_reconnecting(attempt: int) -> void:
	_reconnecting_attempt = attempt
