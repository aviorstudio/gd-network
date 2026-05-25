extends SceneTree

const RateLimitModule = preload("res://addon/src/rate_limit_module.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	_test_burst_capacity_initialization(failures)
	_test_refill_caps_at_burst_capacity(failures)

	if failures.is_empty():
		print("PASS gd-network rate_limit_module_test")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _test_burst_capacity_initialization(failures: Array[String]) -> void:
	var config := RateLimitModule.RateLimitConfig.new(10.0, 0.0, 1.0, 5.0)
	var result := RateLimitModule.consume(config, null, 1000)
	if not result.allowed:
		failures.append("Expected consume to be allowed with initial burst capacity")
	if not is_equal_approx(result.state.tokens, 14.0):
		failures.append("Expected initial token state to include burst_tokens (15 - 1 = 14)")

func _test_refill_caps_at_burst_capacity(failures: Array[String]) -> void:
	var config := RateLimitModule.RateLimitConfig.new(10.0, 10.0, 0.0, 5.0)
	var state := RateLimitModule.RateLimitState.new(0.0, 0)
	var result := RateLimitModule.consume(config, state, 3000)
	if not is_equal_approx(result.state.tokens, 15.0):
		failures.append("Expected refill to cap at max_tokens + burst_tokens")
