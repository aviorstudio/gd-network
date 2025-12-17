extends RefCounted

class NetworkWindowingConfig extends RefCounted:
	var buffer_size: int

	func _init(buffer_size: int) -> void:
		self.buffer_size = buffer_size

class DeltaEntry extends RefCounted:
	var sequence_number: int
	var delta: Dictionary[String, Variant]
	var timestamp_msec: int
	var match_id: String

	func _init(sequence_number: int, delta: Dictionary[String, Variant], match_id: String, timestamp_msec: int) -> void:
		self.sequence_number = sequence_number
		self.delta = delta.duplicate(true)
		self.match_id = match_id
		self.timestamp_msec = timestamp_msec

static var _buffers: Dictionary[String, Array] = {}
static var _global_sequence: int = 0

static func append(
	config: NetworkWindowingConfig,
	match_id: String,
	delta: Dictionary[String, Variant],
	now_msec: int
) -> int:
	var buffer: Array[DeltaEntry] = _get_or_create_buffer(match_id)

	_global_sequence += 1
	var entry := DeltaEntry.new(_global_sequence, delta, match_id, now_msec)

	buffer.append(entry)

	var max_size: int = max(config.buffer_size if config else 0, 0)
	if max_size > 0 and buffer.size() > max_size:
		buffer.pop_front()

	return _global_sequence

static func get_since(match_id: String, last_sequence: int) -> Array[DeltaEntry]:
	if not match_id in _buffers:
		return []

	var buffer: Array[DeltaEntry] = _buffers[match_id]
	var result: Array[DeltaEntry] = []

	for entry in buffer:
		if entry.sequence_number > last_sequence:
			result.append(entry)

	return result

static func get_latest_sequence(match_id: String) -> int:
	if not match_id in _buffers:
		return 0

	var buffer: Array[DeltaEntry] = _buffers[match_id]
	if buffer.is_empty():
		return 0

	var last_entry: DeltaEntry = buffer.back()
	return last_entry.sequence_number

static func prune_older_than(now_msec: int, max_age_ms: int) -> void:
	var cutoff: int = now_msec - max_age_ms
	for match_id in _buffers.keys():
		var buffer: Array[DeltaEntry] = _buffers[match_id]
		var pruned_buffer: Array[DeltaEntry] = []
		for entry in buffer:
			if entry.timestamp_msec >= cutoff:
				pruned_buffer.append(entry)
		_buffers[match_id] = pruned_buffer

static func _get_or_create_buffer(match_id: String) -> Array[DeltaEntry]:
	if not match_id in _buffers:
		var new_buffer: Array[DeltaEntry] = []
		_buffers[match_id] = new_buffer
	return _buffers[match_id]
