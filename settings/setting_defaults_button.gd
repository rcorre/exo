@tool
extends Button

var section := ""

func _pressed() -> void:
	Settings.reset(section)
	if section == "":
		Bindings.reset_to_default()

func _get_property_list() -> Array:
	return [{
		"name": "section",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(PackedStringArray([""]) + Settings.all_sections())
	}]
