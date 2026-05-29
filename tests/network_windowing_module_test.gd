extends SceneTree

const NetworkWindowingModule = preload("res://addon/src/network_windowing_module.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	_test_append_get_since_and_prune(failures)
	_test_buffer_overflow_keeps_latest_entries(failures)
	_test_multi_stream_isolated_sequences(failures)
	_test_prune_preserves_fresh_order_and_latest_sequence(failures)

	if failures.is_empty():
		print("PASS gd-network network_windowing_module_test")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _test_append_get_since_and_prune(failures: Array[String]) -> void:
	var module := NetworkWindowingModule.new()
	var config := NetworkWindowingModule.NetworkWindowingConfig.new(5)
	module.append(config, "main", {"v": 1}, 100)
	module.append(config, "main", {"v": 2}, 200)
	module.append(config, "main", {"v": 3}, 300)

	var since_one: Array[NetworkWindowingModule.DeltaEntry] = module.get_since("main", 1)
	if since_one.size() != 2:
		failures.append("Expected get_since to return entries newer than last_sequence")

	module.prune_older_than(300, 50)
	var after_prune: Array[NetworkWindowingModule.DeltaEntry] = module.get_since("main", 0)
	if after_prune.size() != 1 or after_prune[0].sequence_number != 3:
		failures.append("Expected prune_older_than to remove stale entries")

func _test_buffer_overflow_keeps_latest_entries(failures: Array[String]) -> void:
	var module := NetworkWindowingModule.new()
	var config := NetworkWindowingModule.NetworkWindowingConfig.new(2)
	module.append(config, "main", {"v": 1}, 100)
	module.append(config, "main", {"v": 2}, 200)
	module.append(config, "main", {"v": 3}, 300)

	var all: Array[NetworkWindowingModule.DeltaEntry] = module.get_since("main", 0)
	if all.size() != 2:
		failures.append("Expected buffer overflow to cap entries at buffer_size")
	if all.size() == 2 and (all[0].sequence_number != 2 or all[1].sequence_number != 3):
		failures.append("Expected overflow to retain latest sequence numbers")

func _test_multi_stream_isolated_sequences(failures: Array[String]) -> void:
	var module := NetworkWindowingModule.new()
	var config := NetworkWindowingModule.NetworkWindowingConfig.new(10)
	var a1: int = module.append(config, "a", {"v": 1}, 100)
	var b1: int = module.append(config, "b", {"v": 1}, 100)
	var a2: int = module.append(config, "a", {"v": 2}, 150)

	if a1 != 1 or a2 != 2:
		failures.append("Expected independent monotonic sequence per stream")
	if b1 != 1:
		failures.append("Expected second stream to start sequence from 1")
	if module.get_latest_sequence("a") != 2 or module.get_latest_sequence("b") != 1:
		failures.append("Expected latest sequence tracking per stream")

func _test_prune_preserves_fresh_order_and_latest_sequence(failures: Array[String]) -> void:
	var module := NetworkWindowingModule.new()
	var config := NetworkWindowingModule.NetworkWindowingConfig.new(10)
	module.append(config, "main", {"v": 1}, 100)
	module.append(config, "main", {"v": 2}, 200)
	module.append(config, "main", {"v": 3}, 300)
	module.append(config, "main", {"v": 4}, 400)

	module.prune_older_than(450, 200)
	var remaining: Array[NetworkWindowingModule.DeltaEntry] = module.get_since("main", 0)
	if remaining.size() != 2:
		failures.append("Expected prefix prune to keep only fresh entries")
		return
	if remaining[0].sequence_number != 3 or remaining[1].sequence_number != 4:
		failures.append("Expected prefix prune to preserve fresh entry order")
	if module.get_latest_sequence("main") != 4:
		failures.append("Expected prefix prune not to reset latest sequence")
