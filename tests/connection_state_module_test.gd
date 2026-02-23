extends SceneTree

const ConnectionStateModule = preload("res://src/connection_state_module.gd")

var _transitions: Array[String] = []

func _initialize() -> void:
	var failures: Array[String] = []
	_test_transition_rules(failures)
	_test_reset_and_callbacks(failures)

	if failures.is_empty():
		print("PASS gd-network connection_state_module_test")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _test_transition_rules(failures: Array[String]) -> void:
	_transitions.clear()
	var module := ConnectionStateModule.new()
	var config := ConnectionStateModule.ConnectionStateConfig.new()
	config.on_state_changed = Callable(self, "_capture_transition")
	module.setup(config)

	if module.get_state() != ConnectionStateModule.ConnectionState.DISCONNECTED:
		failures.append("Expected initial state DISCONNECTED")

	if module.transition_to(ConnectionStateModule.ConnectionState.AUTHENTICATED):
		failures.append("Expected invalid DISCONNECTED->AUTHENTICATED transition to fail")

	if not module.transition_to(ConnectionStateModule.ConnectionState.CONNECTING):
		failures.append("Expected DISCONNECTED->CONNECTING transition to succeed")
	if not module.transition_to(ConnectionStateModule.ConnectionState.CONNECTED):
		failures.append("Expected CONNECTING->CONNECTED transition to succeed")
	if not module.transition_to(ConnectionStateModule.ConnectionState.AUTHENTICATING):
		failures.append("Expected CONNECTED->AUTHENTICATING transition to succeed")
	if not module.transition_to(ConnectionStateModule.ConnectionState.AUTHENTICATED):
		failures.append("Expected AUTHENTICATING->AUTHENTICATED transition to succeed")

	if not module.is_transport_connected():
		failures.append("Expected AUTHENTICATED state to report connected")
	if not bool(module.call("is_authenticated")):
		failures.append("Expected AUTHENTICATED state to report authenticated")

	if not module.transition_to(ConnectionStateModule.ConnectionState.FAILED):
		failures.append("Expected AUTHENTICATED->FAILED transition to succeed")
	if not module.transition_to(ConnectionStateModule.ConnectionState.CONNECTING):
		failures.append("Expected FAILED->CONNECTING transition to succeed")

func _test_reset_and_callbacks(failures: Array[String]) -> void:
	var module := ConnectionStateModule.new()
	var config := ConnectionStateModule.ConnectionStateConfig.new()
	config.on_state_changed = Callable(self, "_capture_transition")
	module.setup(config)

	module.transition_to(ConnectionStateModule.ConnectionState.CONNECTING)
	module.transition_to(ConnectionStateModule.ConnectionState.FAILED)
	module.reset()

	if module.get_state() != ConnectionStateModule.ConnectionState.DISCONNECTED:
		failures.append("Expected reset to force DISCONNECTED state")
	if module.is_transport_connected():
		failures.append("Expected DISCONNECTED state to report not connected")
	if bool(module.call("is_authenticated")):
		failures.append("Expected DISCONNECTED state to report not authenticated")

	if _transitions.is_empty():
		failures.append("Expected on_state_changed callback transitions to be captured")

func _capture_transition(old_state: int, new_state: int) -> void:
	_transitions.append("%d->%d" % [old_state, new_state])
