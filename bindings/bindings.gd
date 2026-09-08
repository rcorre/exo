extends Node

const CONFIG_PATH := "user://input.cfg"

signal reset()

var config := ConfigFile.new()

func _ready() -> void:
	config.load(CONFIG_PATH)
	for action in config.get_sections():
		if not InputMap.has_action(action):
			push_warning("%s is not an action" % action)
			continue

		InputMap.action_erase_events(action)

		var key = config.get_value(action, "key", -1)
		if key >= 0 and key is int:
			var event := InputEventKey.new()
			event.keycode = key
			InputMap.action_add_event(action, event)
			print("Loaded key binding %s for %s" % [key, action])
		elif key >= 0:
			push_warning("Invalid input setting %s for %s" % [key, action])

		var mouse = config.get_value(action, "mouse", -1)
		if mouse >= 0 and mouse is int:
			var event := InputEventMouseButton.new()
			event.button_index = mouse
			InputMap.action_add_event(action, event)
			print("Loaded mouse binding %s for %s" % [mouse, action])
		elif mouse >= 0:
			push_warning("Invalid input setting %s for %s" % [mouse, action])

func bind(action: String, event: InputEvent) -> void:
	if event is InputEventKey:
		config.set_value(action, "key", (event as InputEventKey).keycode)
	elif event is InputEventMouseButton:
		config.set_value(action, "mouse", (event as InputEventMouseButton).button_index)
	else:
		push_warning("Cannot serialize input event %s" % event)
		return

	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)

	config.save(CONFIG_PATH)
	print("Saved binding %s for %s" % [event.as_text(), action])

func reset_to_default() -> void:
	InputMap.load_from_project_settings()
	var err := DirAccess.remove_absolute(CONFIG_PATH)
	if err:
		push_error("Failed to remove persisted input settings. Error=%d" % err)
	else:
		print("Reset bindings to default")
		reset.emit()
