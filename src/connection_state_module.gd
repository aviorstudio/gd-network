## Typed connection state machine with guarded transitions for network clients.
class_name ConnectionStateModule
extends RefCounted

enum ConnectionState {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	AUTHENTICATING,
	AUTHENTICATED,
	FAILED,
}

## Optional callbacks for state transition events.
class ConnectionStateConfig extends RefCounted:
	var on_state_changed: Callable = Callable()

var _state: ConnectionState = ConnectionState.DISCONNECTED
var _config: ConnectionStateConfig = ConnectionStateConfig.new()

## Configures state transition callbacks.
func setup(config: ConnectionStateConfig = null) -> void:
	_config = config if config != null else ConnectionStateConfig.new()

## Returns the current connection state.
func get_state() -> ConnectionState:
	return _state

## Transitions to a new state when allowed by the state graph.
func transition_to(new_state: ConnectionState) -> bool:
	if new_state == _state:
		return false
	if not _is_valid_transition(_state, new_state):
		return false

	var old_state: ConnectionState = _state
	_state = new_state
	if _config.on_state_changed.is_valid():
		_config.on_state_changed.call(old_state, new_state)
	return true

## Returns true when transport connection is established.
func is_transport_connected() -> bool:
	return _state == ConnectionState.CONNECTED or _state == ConnectionState.AUTHENTICATING or _state == ConnectionState.AUTHENTICATED

## Returns true when authentication has completed.
func is_authenticated() -> bool:
	return _state == ConnectionState.AUTHENTICATED

## Resets state back to DISCONNECTED.
func reset() -> void:
	if _state == ConnectionState.DISCONNECTED:
		return
	var old_state: ConnectionState = _state
	_state = ConnectionState.DISCONNECTED
	if _config.on_state_changed.is_valid():
		_config.on_state_changed.call(old_state, _state)

func _is_valid_transition(from_state: ConnectionState, to_state: ConnectionState) -> bool:
	match from_state:
		ConnectionState.DISCONNECTED:
			return to_state == ConnectionState.CONNECTING
		ConnectionState.CONNECTING:
			return to_state == ConnectionState.CONNECTED or to_state == ConnectionState.FAILED or to_state == ConnectionState.DISCONNECTED
		ConnectionState.CONNECTED:
			return to_state == ConnectionState.AUTHENTICATING or to_state == ConnectionState.DISCONNECTED or to_state == ConnectionState.FAILED
		ConnectionState.AUTHENTICATING:
			return to_state == ConnectionState.AUTHENTICATED or to_state == ConnectionState.FAILED or to_state == ConnectionState.DISCONNECTED
		ConnectionState.AUTHENTICATED:
			return to_state == ConnectionState.DISCONNECTED or to_state == ConnectionState.FAILED
		ConnectionState.FAILED:
			return to_state == ConnectionState.CONNECTING or to_state == ConnectionState.DISCONNECTED
		_:
			return false
