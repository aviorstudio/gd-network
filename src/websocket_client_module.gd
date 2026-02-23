## Reconnecting websocket client node with retry/backoff integration.
class_name WebSocketClientModule
extends Node

const RetryBackoffModule = preload("retry_backoff_module.gd")

enum ConnectionState {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	CLOSING,
}

signal connected()
signal disconnected()
signal message_received(data: PackedByteArray)
signal connection_failed()
signal reconnecting(attempt: int)

var _ws: WebSocketPeer = null
var _url: String = ""
var _headers: PackedStringArray = PackedStringArray()
var _retry_config: RetryBackoffModule.RetryConfig = RetryBackoffModule.RetryConfig.new(1000, 1.0, 0)
var _retry_state: RetryBackoffModule.RetryState = RetryBackoffModule.RetryState.new()
var _connected: bool = false
var _active: bool = false
var state: ConnectionState = ConnectionState.DISCONNECTED
var reconnect_count: int = 0

## Initializes processing in an idle state until `start()` is called.
func _ready() -> void:
	set_process(false)

## Starts websocket connection attempts for the provided URL.
func start(url: String, headers: PackedStringArray = PackedStringArray(), retry_config: RetryBackoffModule.RetryConfig = null) -> void:
	stop()
	_url = url
	_headers = headers
	_retry_config = retry_config if retry_config != null else RetryBackoffModule.RetryConfig.new(1000, 1.0, 0)
	_retry_state = RetryBackoffModule.RetryState.new()
	_connected = false
	_active = true
	reconnect_count = 0
	state = ConnectionState.CONNECTING
	set_process(true)
	_attempt_connect()

## Stops active websocket processing and closes any current socket.
func stop() -> void:
	_active = false
	_connected = false
	state = ConnectionState.CLOSING
	_retry_state = RetryBackoffModule.RetryState.new()
	if _ws != null:
		_ws.close()
		_ws = null
	set_process(false)
	state = ConnectionState.DISCONNECTED

## Returns true when the websocket is open and ready for send calls.
func is_socket_open() -> bool:
	return _connected and _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN

## Sends a UTF-8 text message when the socket is open.
func send_text(message: String) -> bool:
	if not is_socket_open():
		return false
	var error: Error = _ws.send_text(message)
	return error == OK

func _process(_delta: float) -> void:
	if not _active:
		set_process(false)
		return
	var now_ms: int = Time.get_ticks_msec()
	if _ws == null:
		state = ConnectionState.CONNECTING if _active else ConnectionState.DISCONNECTED
		_retry_connect_if_due(now_ms)
		return
	_ws.poll()
	var ws_state: WebSocketPeer.State = _ws.get_ready_state()
	if ws_state == WebSocketPeer.STATE_OPEN:
		if not _connected:
			_connected = true
			self.state = ConnectionState.CONNECTED
			_retry_state = RetryBackoffModule.RetryState.new()
			connected.emit()
		while _ws.get_available_packet_count() > 0:
			message_received.emit(_ws.get_packet())
	elif ws_state == WebSocketPeer.STATE_CLOSED:
		var was_connected: bool = _connected
		_connected = false
		self.state = ConnectionState.DISCONNECTED
		_ws = null
		if was_connected:
			disconnected.emit()
		_retry_connect_if_due(now_ms)

func _attempt_connect() -> void:
	if not _active:
		return
	if _url.is_empty():
		state = ConnectionState.DISCONNECTED
		connection_failed.emit()
		set_process(false)
		return
	if _ws != null:
		_ws.close()
		_ws = null
	_ws = WebSocketPeer.new()
	_ws.handshake_headers = _headers
	var error: Error = _ws.connect_to_url(_url)
	if error != OK:
		_ws = null
		state = ConnectionState.DISCONNECTED
		connection_failed.emit()
		_retry_state.next_retry_ms = 0

func _retry_connect_if_due(now_ms: int) -> void:
	if _retry_state.next_retry_ms == 0:
		_retry_state = RetryBackoffModule.next_retry(now_ms, _retry_state, _retry_config)
		if _retry_state.exhausted:
			state = ConnectionState.DISCONNECTED
			connection_failed.emit()
			set_process(false)
			return
		state = ConnectionState.CONNECTING
		connection_failed.emit()
	if now_ms >= _retry_state.next_retry_ms:
		reconnecting.emit(_retry_state.attempt)
		reconnect_count += 1
		_retry_state = RetryBackoffModule.RetryState.new(_retry_state.attempt, 0, false)
		state = ConnectionState.CONNECTING
		_attempt_connect()
