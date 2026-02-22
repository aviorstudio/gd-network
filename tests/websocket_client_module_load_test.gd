extends SceneTree

func _initialize() -> void:
	var websocket_client_module := load("res://src/websocket_client_module.gd")
	if websocket_client_module == null:
		push_error("Failed to load res://src/websocket_client_module.gd")
		quit(1)
		return

	var instance: Node = websocket_client_module.new()
	if instance == null:
		push_error("Failed to instantiate websocket client module")
		quit(1)
		return
	instance.free()

	print("PASS gd-network websocket_client_module_load_test")
	quit(0)
