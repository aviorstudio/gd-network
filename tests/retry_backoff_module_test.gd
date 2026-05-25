extends SceneTree

const RetryBackoffModule = preload("res://addon/src/retry_backoff_module.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	_test_exponential_delay(failures)
	_test_max_retries_exhaustion(failures)
	_test_jitter_callable_override(failures)

	if failures.is_empty():
		print("PASS gd-network retry_backoff_module_test")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _test_exponential_delay(failures: Array[String]) -> void:
	var config := RetryBackoffModule.RetryConfig.new(100, 2.0, 0, 0)
	var state := RetryBackoffModule.RetryState.new()

	var first := RetryBackoffModule.next_retry(1000, state, config)
	var second := RetryBackoffModule.next_retry(1000, first, config)

	if first.next_retry_ms != 1100:
		failures.append("Expected first retry to use base delay")
	if second.next_retry_ms != 1200:
		failures.append("Expected second retry to apply multiplier")

func _test_max_retries_exhaustion(failures: Array[String]) -> void:
	var config := RetryBackoffModule.RetryConfig.new(50, 1.0, 2, 0)
	var state := RetryBackoffModule.RetryState.new(2, 0, false)
	var exhausted := RetryBackoffModule.next_retry(1000, state, config)
	if not exhausted.exhausted:
		failures.append("Expected retry state to be exhausted after max retries")

func _test_jitter_callable_override(failures: Array[String]) -> void:
	var jitter := func(_delay_ms: float) -> float:
		return 333.0
	var config := RetryBackoffModule.RetryConfig.new(100, 2.0, 0, 0, jitter)
	var state := RetryBackoffModule.RetryState.new()
	var next := RetryBackoffModule.next_retry(1000, state, config)
	if next.next_retry_ms != 1333:
		failures.append("Expected jitter callable to override computed delay")
