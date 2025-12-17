extends RefCounted

# Stores a bounded, per-key window of delta dictionaries with monotonically increasing sequence numbers.

class NetworkWindowingConfig extends RefCounted:
	var buffer_size: int

	func _init(buffer_size: int) -> void:
		self.buffer_size = buffer_size

class DeltaEntry extends RefCounted:
	var sequence_number: int
	var delta: Dictionary[String, Variant]
	var timestamp_msec: int
	var stream_key: String

	func _init(sequence_number: int, delta: Dictionary[String, Variant], stream_key: String, timestamp_msec: int) -> void:
		self.sequence_number = sequence_number
		self.delta = delta.duplicate(true)
		self.stream_key = stream_key
		self.timestamp_msec = timestamp_msec

static var _buffers: Dictionary[String, Array] = {}
static var _latest_sequences: Dictionary[String, int] = {}

static func append(
	config: NetworkWindowingConfig,
	stream_key: String,
	delta: Dictionary[String, Variant],
	now_msec: int
) -> int:
	var buffer: Array[DeltaEntry] = _get_or_create_buffer(stream_key)

	var next_sequence: int = int(_latest_sequences.get(stream_key, 0)) + 1
	_latest_sequences[stream_key] = next_sequence

	var entry := DeltaEntry.new(next_sequence, delta, stream_key, now_msec)
	buffer.append(entry)

	var max_size: int = max(config.buffer_size if config else 0, 0)
	if max_size > 0 and buffer.size() > max_size:
		buffer.pop_front()

	return next_sequence

static func get_since(stream_key: String, last_sequence: int) -> Array[DeltaEntry]:
	if not stream_key in _buffers:
		return []

	var buffer: Array[DeltaEntry] = _buffers[stream_key]
	var result: Array[DeltaEntry] = []

	for entry in buffer:
		if entry.sequence_number > last_sequence:
			result.append(entry)

	return result

static func get_latest_sequence(stream_key: String) -> int:
	return int(_latest_sequences.get(stream_key, 0))

static func prune_older_than(now_msec: int, max_age_ms: int) -> void:
	var cutoff: int = now_msec - max_age_ms
	for stream_key: String in _buffers.keys():
		var buffer: Array[DeltaEntry] = _buffers[stream_key]
		var pruned_buffer: Array[DeltaEntry] = []
		for entry in buffer:
			if entry.timestamp_msec >= cutoff:
				pruned_buffer.append(entry)
		_buffers[stream_key] = pruned_buffer

static func clear(stream_key: String) -> void:
	_buffers.erase(stream_key)
	_latest_sequences.erase(stream_key)

static func clear_all() -> void:
	_buffers.clear()
	_latest_sequences.clear()

static func _get_or_create_buffer(stream_key: String) -> Array[DeltaEntry]:
	if not stream_key in _buffers:
		var new_buffer: Array[DeltaEntry] = []
		_buffers[stream_key] = new_buffer
	return _buffers[stream_key]
