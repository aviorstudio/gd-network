## Static helpers for pooled HTTPRequest acquisition and reuse.
class_name HttpPoolModule
extends RefCounted

## Wrapper state for a pooled HTTPRequest instance.
class PoolEntry extends RefCounted:
	var node: HTTPRequest
	var busy: bool = false
	var callback: Callable
	var request_id: String = ""
	var generation: int = 0
	var completion_callable: Callable

const DEFAULT_DOWNLOAD_CHUNK_SIZE: int = 65536
const DEFAULT_MAX_POOL_SIZE: int = 8

## Creates a new pool entry and attaches request node to owner when provided.
static func create_entry(owner: Node, default_timeout_s: float, chunk_size: int = DEFAULT_DOWNLOAD_CHUNK_SIZE) -> PoolEntry:
	var request_node := HTTPRequest.new()
	request_node.use_threads = not OS.has_feature("web")
	request_node.timeout = default_timeout_s
	request_node.download_chunk_size = chunk_size
	if owner:
		owner.add_child(request_node)

	var entry := PoolEntry.new()
	entry.node = request_node
	return entry

## Acquires an available request entry, creating one when needed.
## Returns null when every entry is busy and max_pool_size has been reached.
static func acquire_request(owner: Node, pool: Array[PoolEntry], default_timeout_s: float, chunk_size: int = DEFAULT_DOWNLOAD_CHUNK_SIZE, max_pool_size: int = DEFAULT_MAX_POOL_SIZE) -> PoolEntry:
	for entry in pool:
		if not entry.busy:
			entry.busy = true
			entry.generation += 1
			entry.node.timeout = default_timeout_s
			return entry

	if max_pool_size > 0 and pool.size() >= max_pool_size:
		return null

	var entry := create_entry(owner, default_timeout_s, chunk_size)
	entry.busy = true
	entry.generation = 1
	pool.append(entry)
	return entry

## Releases a pool entry and clears per-request callbacks/state.
static func release_request(entry: PoolEntry) -> void:
	if not entry:
		return
	entry.busy = false
	entry.callback = Callable()
	entry.request_id = ""
	entry.completion_callable = Callable()

## Increments and returns a request counter value.
static func next_request_counter(current_counter: int) -> int:
	return current_counter + 1
