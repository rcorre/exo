extends Node

var enabled: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed("toggle_debug"):
		enabled = not enabled
