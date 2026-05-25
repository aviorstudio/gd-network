extends SceneTree

const HttpPoolModule = preload("res://addon/src/http_pool_module.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	_test_acquire_and_release_marks_busy_state(failures)
	_test_pool_growth_for_concurrent_acquire(failures)
	_test_reuse_after_release(failures)

	if failures.is_empty():
		print("PASS gd-network http_pool_module_test")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _test_acquire_and_release_marks_busy_state(failures: Array[String]) -> void:
	var owner := Node.new()
	root.add_child(owner)
	var pool: Array[HttpPoolModule.PoolEntry] = []
	var entry := HttpPoolModule.acquire_request(owner, pool, 3.0)
	if not entry.busy:
		failures.append("Expected acquired entry to be marked busy")
	HttpPoolModule.release_request(entry)
	if entry.busy:
		failures.append("Expected released entry to be marked idle")
	owner.queue_free()

func _test_pool_growth_for_concurrent_acquire(failures: Array[String]) -> void:
	var owner := Node.new()
	root.add_child(owner)
	var pool: Array[HttpPoolModule.PoolEntry] = []
	var first := HttpPoolModule.acquire_request(owner, pool, 3.0)
	var second := HttpPoolModule.acquire_request(owner, pool, 3.0)
	if pool.size() != 2:
		failures.append("Expected pool to grow when all entries are busy")
	if first == second:
		failures.append("Expected second acquire to allocate a new entry when first is busy")
	owner.queue_free()

func _test_reuse_after_release(failures: Array[String]) -> void:
	var owner := Node.new()
	root.add_child(owner)
	var pool: Array[HttpPoolModule.PoolEntry] = []
	var first := HttpPoolModule.acquire_request(owner, pool, 3.0)
	HttpPoolModule.release_request(first)
	var reused := HttpPoolModule.acquire_request(owner, pool, 4.0)
	if reused != first:
		failures.append("Expected acquire to reuse first idle entry")
	if not is_equal_approx(reused.node.timeout, 4.0):
		failures.append("Expected reused node timeout to update on acquire")
	owner.queue_free()
