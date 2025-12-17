extends RefCounted

class RetryConfig extends RefCounted:
	var base_delay_ms: int
	var multiplier: float
	var max_retries: int
	var max_delay_ms: int
	var jitter_callable: Callable

	func _init(
		base_delay_ms: int,
		multiplier: float = 1.0,
		max_retries: int = 0,
		max_delay_ms: int = 0,
		jitter_callable: Callable = Callable()
	) -> void:
		self.base_delay_ms = base_delay_ms
		self.multiplier = multiplier
		self.max_retries = max_retries
		self.max_delay_ms = max_delay_ms
		self.jitter_callable = jitter_callable

class RetryState extends RefCounted:
	var attempt: int
	var next_retry_ms: int
	var exhausted: bool

	func _init(attempt: int = 0, next_retry_ms: int = 0, exhausted: bool = false) -> void:
		self.attempt = attempt
		self.next_retry_ms = next_retry_ms
		self.exhausted = exhausted

static func next_retry(now_msec: int, state: RetryState, config: RetryConfig) -> RetryState:
	var next_attempt: int = state.attempt + 1

	if config.max_retries > 0 and next_attempt > config.max_retries:
		return RetryState.new(next_attempt, state.next_retry_ms, true)

	var delay_ms: float = float(config.base_delay_ms) * pow(config.multiplier, max(next_attempt - 1, 0))
	if config.max_delay_ms > 0:
		delay_ms = min(delay_ms, float(config.max_delay_ms))

	if config.jitter_callable.is_valid():
		var jitter_value: Variant = config.jitter_callable.call(delay_ms)
		if jitter_value is int or jitter_value is float:
			delay_ms = float(jitter_value)

	var next_time_ms: int = now_msec + int(delay_ms)
	return RetryState.new(next_attempt, next_time_ms, false)
