extends Node

const RetryBackoffModule = preload("res://addons/@aviorstudio_gd-network/src/retry_backoff_module.gd")

signal connected()
signal disconnected()
signal message_received(data: PackedByteArray)
signal connection_failed()

var _ws: WebSocketPeer = null
var _url: String = ""
var _headers: PackedStringArray = PackedStringArray()
var _retry_config: RetryBackoffModule.RetryConfig = RetryBackoffModule.RetryConfig.new(1000, 1.0, 0)
var _retry_state: RetryBackoffModule.RetryState = RetryBackoffModule.RetryState.new()
var _connected: bool = false
var _active: bool = false

func _ready() -> void:
	set_process(false)

func start(url: String, headers: PackedStringArray = PackedStringArray(), retry_config: RetryBackoffModule.RetryConfig = null) -> void:
	stop()
	_url = url
	_headers = headers
	_retry_config = retry_config if retry_config != null else RetryBackoffModule.RetryConfig.new(1000, 1.0, 0)
	_retry_state = RetryBackoffModule.RetryState.new()
	_connected = false
	_active = true
	set_process(true)
	_attempt_connect()

func stop() -> void:
	_active = false
	_connected = false
	_retry_state = RetryBackoffModule.RetryState.new()
	if _ws != null:
		_ws.close()
		_ws = null
	set_process(false)

func is_socket_open() -> bool:
	return _connected and _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN

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
		_retry_connect_if_due(now_ms)
		return
	_ws.poll()
	var state: WebSocketPeer.State = _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _connected:
			_connected = true
			_retry_state = RetryBackoffModule.RetryState.new()
			connected.emit()
		while _ws.get_available_packet_count() > 0:
			message_received.emit(_ws.get_packet())
	elif state == WebSocketPeer.STATE_CLOSED:
		var was_connected: bool = _connected
		_connected = false
		_ws = null
		if was_connected:
			disconnected.emit()
		_retry_connect_if_due(now_ms)

func _attempt_connect() -> void:
	if not _active:
		return
	if _url.is_empty():
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
		connection_failed.emit()
		_retry_state.next_retry_ms = 0

func _retry_connect_if_due(now_ms: int) -> void:
	if _retry_state.next_retry_ms == 0:
		_retry_state = RetryBackoffModule.next_retry(now_ms, _retry_state, _retry_config)
		if _retry_state.exhausted:
			connection_failed.emit()
			set_process(false)
			return
		connection_failed.emit()
	if now_ms >= _retry_state.next_retry_ms:
		_retry_state = RetryBackoffModule.RetryState.new(_retry_state.attempt, 0, false)
		_attempt_connect()
