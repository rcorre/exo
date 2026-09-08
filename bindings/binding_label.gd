@tool
extends Label
class_name BindingLabel

@export var index := 0

var action: String

func _ready() -> void:
	var binds := InputMap.action_get_events(action)

	if binds.size() <= index:
		return

	var ev := binds[index]
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
