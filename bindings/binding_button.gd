@tool
extends Button
class_name BindingButton

var action: String : set = set_action

func _ready() -> void:
	set_process_input(false)
	update_text()
	Bindings.reset.connect(update_text)
	text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR

func update_text() -> void:
	var binds: Array
	if Engine.is_editor_hint():
		# in the editor, InputMap refers to the editor's own keybinds
		binds = ProjectSettings.get("input/" + action).events
	else:
		binds = InputMap.action_get_events(action)

	if binds.is_empty():
		text = ""
		return

	var ev = binds[0]
	var mb := ev as InputEventMouseButton
	if mb:
		text = "Mouse%d" % mb.button_index
		return

	var key := ev as InputEventKey
	if key:
		text = OS.get_keycode_string(key.keycode if key.keycode else key.physical_keycode)
		return

func _get_property_list() -> Array:
	var hint := ""
	for p in ProjectSettings.get_property_list():
		var prop_name: String = p.name
		if prop_name.find("input/") == 0 and prop_name.find("input/ui_") != 0:
			hint += prop_name.trim_prefix("input/") + ","

	return [{
		"name": "action",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": hint.trim_suffix(","),
	}]

func set_action(val: String) -> void:
	action = val
	update_text()

func _pressed() -> void:
	# process input so we can catch the next event
	set_process_input(true)
	text = "..."

func _input(event: InputEvent) -> void:
	if event.is_pressed() and (event is InputEventMouseButton or event is InputEventKey):
		get_viewport().set_input_as_handled()
		set_process_input(false)
		Bindings.bind(action, event)
		update_text()
