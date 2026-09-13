extends SceneTree

func _initialize() -> void:
	push_error("intentional runtime error negative control")
	quit(0)
