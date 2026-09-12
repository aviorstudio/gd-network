extends SceneTree

func _initialize() -> void:
	push_error("intentional assertion-style failure before overwritten exit")
	quit(1)
	quit(0)
