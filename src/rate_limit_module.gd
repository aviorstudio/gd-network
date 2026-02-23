## Token-bucket rate limiting primitives.
class_name RateLimitModule
extends RefCounted

## Rate limit configuration values.
class RateLimitConfig extends RefCounted:
	var max_tokens: float
	var tokens_per_second: float
	var consume_amount: float
	var burst_tokens: float

	func _init(max_tokens: float, tokens_per_second: float, consume_amount: float, burst_tokens: float = 0.0) -> void:
		self.max_tokens = max_tokens
		self.tokens_per_second = tokens_per_second
		self.consume_amount = consume_amount
		self.burst_tokens = burst_tokens

## Mutable bucket state container.
class RateLimitState extends RefCounted:
	var tokens: float
	var last_update_msec: int

	func _init(tokens: float, last_update_msec: int) -> void:
		self.tokens = tokens
		self.last_update_msec = last_update_msec

	## Returns whether the bucket has enough tokens for the requested cost.
	func can_consume(cost: float) -> bool:
		return tokens >= cost

## Result of a consume attempt.
class RateLimitResult extends RefCounted:
	var state: RateLimitState
	var allowed: bool

	func _init(state: RateLimitState, allowed: bool) -> void:
		self.state = state
		self.allowed = allowed

## Consumes tokens and returns allowance status with updated state.
static func consume(
	config: RateLimitConfig,
	state: RateLimitState,
	now_msec: int
) -> RateLimitResult:
	var resolved_config: RateLimitConfig = config if config else RateLimitConfig.new(0.0, 0.0, 0.0)
	var token_capacity: float = resolved_config.max_tokens + maxf(resolved_config.burst_tokens, 0.0)
	var resolved_state: RateLimitState = _ensure_state(state, token_capacity, now_msec)
	_refill(resolved_state, now_msec, token_capacity, resolved_config.tokens_per_second)

	var allowed: bool = resolved_state.can_consume(resolved_config.consume_amount)
	if allowed:
		resolved_state.tokens -= resolved_config.consume_amount

	return RateLimitResult.new(resolved_state, allowed)

## Ensures a non-null rate limit state.
static func _ensure_state(
	state: RateLimitState,
	max_tokens: float,
	now_msec: int
) -> RateLimitState:
	if state:
		return state
	return RateLimitState.new(max_tokens, now_msec)

## Refills tokens based on elapsed time and configured refill rate.
static func _refill(
	state: RateLimitState,
	now_msec: int,
	max_tokens: float,
	tokens_per_second: float
) -> void:
	var elapsed_msec: int = max(now_msec - state.last_update_msec, 0)
	var elapsed_seconds: float = float(elapsed_msec) / 1000.0
	var replenished_tokens: float = elapsed_seconds * tokens_per_second
	state.tokens = min(max_tokens, state.tokens + replenished_tokens)
	state.last_update_msec = now_msec
