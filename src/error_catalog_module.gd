extends RefCounted

const AUTHENTICATION_FAILED := "authentication_failed"
const AUTHENTICATION_REQUIRED := "authentication_required"
const MATCH_NOT_FOUND := "match_not_found"
const MATCH_FULL := "match_full"
const ALREADY_IN_MATCH := "already_in_match"
const NETWORK_TIMEOUT := "network_timeout"
const NETWORK_ERROR := "network_error"
const SERVER_ERROR := "server_error"
const RATE_LIMITED := "rate_limited"
const HTTP_4XX := "http_4xx"
const HTTP_5XX := "http_5xx"
const PARSE_ERROR := "parse_error"
const REQUEST_FAILED := "request_failed"
const EMPTY_RESPONSE := "empty_response"
const NOT_YOUR_TURN := "not_your_turn"
const UNIT_NOT_FOUND := "unit_not_found"
const INVALID_MOVE := "invalid_move"
const PLAYER_NOT_IN_MATCH := "player_not_in_match"
const INVALID_UNIT := "invalid_unit"
const UNIT_ALREADY_MOVED := "unit_already_moved"
const UNIT_ALREADY_ATTACKED := "unit_already_attacked"
const PATH_BLOCKED := "path_blocked"
const OUT_OF_MOVEMENT := "out_of_movement"
const INVALID_POSITION := "invalid_position"
const GAME_ALREADY_ENDED := "game_already_ended"
const INVALID_ACTION := "invalid_action"
const PROTOCOL_VERSION_MISMATCH := "protocol_version_mismatch"
const MISSING_ACCESS_TOKEN := "missing_access_token"
const SESSION_CREATION_FAILED := "session_creation_failed"
const WEBSOCKET_START_FAILED := "websocket_start_failed"
const MATCH_NOT_STARTED := "match_not_started"
const MATCH_STATE_NOT_FOUND := "match_state_not_found"
const MATCH_START_FAILED := "match_start_failed"
const JOIN_MATCH_FAILED := "join_match_failed"
const HOST_ONLY_START := "host_only_start"
const NOT_IN_MATCH := "not_in_match"
const NOT_IN_ANY_MATCH := "not_in_any_match"
const ALREADY_IN_QUEUE := "already_in_queue"
const MATCH_ENDED_DISCONNECT := "match_ended_disconnect"
const QUICK_MATCH_CANCELLED := "quick_match_cancelled"
const MATCH_CANCELLED := "match_cancelled"
const QUICK_MATCH_CREATION_FAILED := "quick_match_creation_failed"
const ILLEGAL := "illegal"
const OUT_OF_TURN := "out_of_turn"
const DUPLICATE := "duplicate"
const OUT_OF_ORDER := "out_of_order"
const QUEUE_JOIN_FAILED := "queue_join_failed"
const QUEUE_MATCH_FAILED := "queue_match_failed"
const CONFIG_LOAD_FAILED := "config_load_failed"
const WEBSOCKET_CREATE_FAILED := "websocket_create_failed"
const SERVER_CONNECT_FAILED := "server_connect_failed"
const AUTH_FAILED := "auth_failed"
const AUTH_REQUIRED := "auth_required"
const SIGNUP_FAILED := "signup_failed"
const TOKEN_REFRESH_FAILED := "token_refresh_failed"
const TOKEN_INVALID := "token_invalid"
const PROFILE_FETCH_FAILED := "profile_fetch_failed"
const PROFILE_UPDATE_FAILED := "profile_update_failed"
const CARD_PLAY_FAILED := "card_play_failed"
const UNIT_CREATE_FAILED := "unit_create_failed"
const NAV_SCENE_FAILED := "nav_scene_failed"
const NOT_AUTHENTICATED := "not_authenticated"
const MATCH_JOIN_FAILED := "match_join_failed"
const MATCH_LEAVE_FAILED := "match_leave_failed"
const CARD_NOT_IN_HAND := "card_not_in_hand"
const TARGET_UNIT_NOT_FOUND := "target_unit_not_found"
const TARGET_NOT_FOUND := "target_not_found"
const NOT_YOUR_UNIT := "not_your_unit"
const INVALID_DESTINATION := "invalid_destination"
const ATTACKER_NOT_FOUND := "attacker_not_found"
const CANNOT_ATTACK_OWN_UNIT := "cannot_attack_own_unit"
const NO_CARD_ID := "no_card_id"
const NO_TARGET_UNIT_FOR_SPELL := "no_target_unit_for_spell"
const INVALID_TARGET_POSITION := "invalid_target_position"
const NO_CHAMPION_ID := "no_champion_id"
const INVALID_SPAWN_POSITION := "invalid_spawn_position"
const MATCH_NOT_INITIALIZED := "match_not_initialized"
const UNSUPPORTED_CARD_TYPE := "unsupported_card_type"
const UNKNOWN_ACTION_TYPE := "unknown_action_type"
const INVALID_TILE_COLOR := "invalid_tile_color"
const TAUNT_REQUIRED := "taunt_required"
const INVALID_UNITS := "invalid_units"
const TARGET_OUT_OF_RANGE := "target_out_of_range"
const INVALID_BOARD_POSITION := "invalid_board_position"
const CANNOT_CONTROL_UNIT := "cannot_control_unit"
const NO_ACTIVE_MATCH := "no_active_match"
const MISSING_ACTOR_ID := "missing_actor_id"
const POSITION_IS_NULL := "position_is_null"
const POSITION_MISSING_COORDS := "position_missing_coords"
const POSITION_ALREADY_OCCUPIED := "position_already_occupied"
const INVALID_SPAWN_ZONE := "invalid_spawn_zone"
const PORT_REQUIRED := "port_required"
const UNAUTHORIZED_ACCESS := "unauthorized_access"

static func _entry(message: String, delay: float = 0.0, severity: int = 1) -> Dictionary:
	return {
		"message": message,
		"retry_delay_s": delay,
		"severity": severity
	}

static var _MAP: Dictionary = {
	AUTHENTICATION_FAILED: _entry("Please sign in again", 0.0, 2),
	AUTHENTICATION_REQUIRED: _entry("You must be authenticated", 0.0, 2),
	MATCH_NOT_FOUND: _entry("Match not found", 0.0, 2),
	MATCH_FULL: _entry("This match is full", 0.0, 1),
	ALREADY_IN_MATCH: _entry("You are already in a match", 0.0, 1),
	NETWORK_TIMEOUT: _entry("Request timed out", 2.0, 2),
	NETWORK_ERROR: _entry("Connection error, please try again", 1.0, 2),
	SERVER_ERROR: _entry("Server error, please try again", 2.0, 2),
	RATE_LIMITED: _entry("Too many requests, please slow down", 3.0, 1),
	HTTP_4XX: _entry("Invalid request", 0.0, 2),
	HTTP_5XX: _entry("Server error, please try again", 2.0, 2),
	PARSE_ERROR: _entry("Invalid response format", 0.0, 2),
	REQUEST_FAILED: _entry("Request failed, please try again", 1.0, 2),
	EMPTY_RESPONSE: _entry("No response from server", 1.0, 2),
	NOT_YOUR_TURN: _entry("Please wait for your turn", 0.0, 1),
	UNIT_NOT_FOUND: _entry("Invalid action", 0.0, 1),
	INVALID_MOVE: _entry("That move is not allowed", 0.0, 1),
	PLAYER_NOT_IN_MATCH: _entry("You are not in this match", 0.0, 2),
	INVALID_UNIT: _entry("Invalid unit selected", 0.0, 1),
	UNIT_ALREADY_MOVED: _entry("This unit has already moved", 0.0, 1),
	UNIT_ALREADY_ATTACKED: _entry("This unit has already attacked this turn", 0.0, 1),
	PATH_BLOCKED: _entry("Path is blocked", 0.0, 1),
	OUT_OF_MOVEMENT: _entry("Not enough movement points", 0.0, 1),
	INVALID_POSITION: _entry("Invalid position", 0.0, 1),
	GAME_ALREADY_ENDED: _entry("The game has already ended", 0.0, 1),
	INVALID_ACTION: _entry("Invalid action", 0.0, 1),
	PROTOCOL_VERSION_MISMATCH: _entry("Protocol version mismatch", 0.0, 2),
	MISSING_ACCESS_TOKEN: _entry("Missing access token", 0.0, 2),
	SESSION_CREATION_FAILED: _entry("Session creation failed", 0.0, 2),
	WEBSOCKET_START_FAILED: _entry("Failed to start WebSocket server", 0.0, 2),
	MATCH_NOT_STARTED: _entry("Match has not started yet", 0.0, 1),
	MATCH_STATE_NOT_FOUND: _entry("Match state not found", 0.0, 2),
	MATCH_START_FAILED: _entry("Failed to start match - server error", 0.0, 2),
	JOIN_MATCH_FAILED: _entry("Failed to join match: Invalid match ID or match is full", 0.0, 2),
	HOST_ONLY_START: _entry("Only the host can start the match", 0.0, 1),
	NOT_IN_MATCH: _entry("You are not in this match", 0.0, 1),
	NOT_IN_ANY_MATCH: _entry("You are not in any match", 0.0, 1),
	ALREADY_IN_QUEUE: _entry("You are already in the quick match queue", 0.0, 1),
	MATCH_ENDED_DISCONNECT: _entry("Match ended - other player disconnected", 0.0, 1),
	QUICK_MATCH_CANCELLED: _entry("Quick match cancelled - other player left", 0.0, 1),
	MATCH_CANCELLED: _entry("Match cancelled - other player left", 0.0, 1),
	QUICK_MATCH_CREATION_FAILED: _entry("Failed to create quick match", 0.0, 2),
	ILLEGAL: _entry("Illegal action", 0.0, 1),
	OUT_OF_TURN: _entry("Out of turn", 0.0, 1),
	DUPLICATE: _entry("Duplicate action", 0.0, 1),
	OUT_OF_ORDER: _entry("Out of order", 0.0, 1),
	QUEUE_JOIN_FAILED: _entry("Failed to join queue", 0.0, 2),
	QUEUE_MATCH_FAILED: _entry("Failed to get match details", 0.0, 2),
	CONFIG_LOAD_FAILED: _entry("Failed to load config from server", 0.0, 2),
	WEBSOCKET_CREATE_FAILED: _entry("Failed to create WebSocket", 0.0, 2),
	SERVER_CONNECT_FAILED: _entry("Failed to connect to server", 0.0, 2),
	AUTH_FAILED: _entry("Authentication failed", 0.0, 2),
	AUTH_REQUIRED: _entry("Authentication required", 0.0, 2),
	SIGNUP_FAILED: _entry("Sign up failed", 0.0, 2),
	TOKEN_REFRESH_FAILED: _entry("Failed to refresh token", 0.0, 2),
	TOKEN_INVALID: _entry("Invalid or expired token", 0.0, 2),
	PROFILE_FETCH_FAILED: _entry("Failed to fetch user profile", 0.0, 2),
	PROFILE_UPDATE_FAILED: _entry("Failed to update profile", 0.0, 2),
	CARD_PLAY_FAILED: _entry("Failed to play card", 0.0, 1),
	UNIT_CREATE_FAILED: _entry("Failed to create unit instance!", 0.0, 2),
	NAV_SCENE_FAILED: _entry("Failed to change scene", 0.0, 2),
	NOT_AUTHENTICATED: _entry("You must be authenticated", 0.0, 2),
	MATCH_JOIN_FAILED: _entry("Failed to join match", 0.0, 2),
	MATCH_LEAVE_FAILED: _entry("Failed to leave match", 0.0, 2),
	CARD_NOT_IN_HAND: _entry("Card not found in hand", 0.0, 1),
	TARGET_UNIT_NOT_FOUND: _entry("Target unit not found", 0.0, 1),
	TARGET_NOT_FOUND: _entry("Target not found", 0.0, 1),
	NOT_YOUR_UNIT: _entry("Not your unit", 0.0, 1),
	INVALID_DESTINATION: _entry("Invalid destination format", 0.0, 1),
	ATTACKER_NOT_FOUND: _entry("Attacker not found", 0.0, 1),
	CANNOT_ATTACK_OWN_UNIT: _entry("Cannot attack your own unit", 0.0, 1),
	NO_CARD_ID: _entry("No card ID specified", 0.0, 1),
	NO_TARGET_UNIT_FOR_SPELL: _entry("No target unit specified for spell", 0.0, 1),
	INVALID_TARGET_POSITION: _entry("Invalid target position", 0.0, 1),
	NO_CHAMPION_ID: _entry("No champion ID specified", 0.0, 1),
	INVALID_SPAWN_POSITION: _entry("Invalid spawn position", 0.0, 1),
	MATCH_NOT_INITIALIZED: _entry("Match not initialized", 0.0, 2),
	UNSUPPORTED_CARD_TYPE: _entry("Unsupported card type", 0.0, 1),
	UNKNOWN_ACTION_TYPE: _entry("Unknown action type", 0.0, 1),
	INVALID_TILE_COLOR: _entry("Unit must be on a matching tile", 0.0, 1),
	TAUNT_REQUIRED: _entry("Cannot attack this target - taunt units must be attacked first", 0.0, 1),
	INVALID_UNITS: _entry("Invalid units", 0.0, 1),
	TARGET_OUT_OF_RANGE: _entry("Target not in range", 0.0, 1),
	INVALID_BOARD_POSITION: _entry("Invalid board position", 0.0, 1),
	CANNOT_CONTROL_UNIT: _entry("Cannot control this unit", 0.0, 1),
	NO_ACTIVE_MATCH: _entry("No active match", 0.0, 1),
	MISSING_ACTOR_ID: _entry("Missing actor_id in action", 0.0, 1),
	POSITION_IS_NULL: _entry("Position is null", 0.0, 1),
	POSITION_MISSING_COORDS: _entry("Position dictionary missing x or y", 0.0, 1),
	POSITION_ALREADY_OCCUPIED: _entry("Position already occupied", 0.0, 1),
	INVALID_SPAWN_ZONE: _entry("Invalid spawn zone for this player", 0.0, 1),
	PORT_REQUIRED: _entry("PORT environment variable is required! Please set PORT in your .env file", 0.0, 2),
	UNAUTHORIZED_ACCESS: _entry("Unauthorized: You must be authenticated to access this endpoint.", 0.0, 2),
}

static func resolve_message(code_or_message: String) -> String:
	if _MAP.has(code_or_message):
		return get_safe_message(code_or_message)
	return code_or_message

static func get_safe_message(key: String) -> String:
	var entry: Dictionary = _MAP.get(key, {})
	if not entry.is_empty():
		return str(entry.get("message", "An error occurred"))
	return "An error occurred"

static func get_retry_delay_s(key: String, attempt: int = 1) -> float:
	var entry: Dictionary = _MAP.get(key, {})
	if not entry.is_empty():
		var base_delay: float = float(entry.get("retry_delay_s", 0.0))
		if base_delay > 0.0 and key == RATE_LIMITED:
			return pow(2, attempt) * base_delay
		return base_delay
	return 1.0

static func get_severity(key: String) -> int:
	var entry: Dictionary = _MAP.get(key, {})
	if not entry.is_empty():
		return int(entry.get("severity", 1))
	return 1

static func map_http_error(error_message: String) -> String:
	if error_message.begins_with("http_4"):
		return HTTP_4XX
	elif error_message.begins_with("http_5"):
		return HTTP_5XX
	elif error_message.begins_with("request_failed:"):
		return REQUEST_FAILED
	elif error_message == "parse_error":
		return PARSE_ERROR
	elif error_message == "empty_response":
		return EMPTY_RESPONSE
	elif error_message.begins_with("request_error:"):
		return REQUEST_FAILED
	else:
		return SERVER_ERROR
