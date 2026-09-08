@tool
extends Button

var section := ""

func _pressed() -> void:
	Settings.reload(section)

func _get_property_list() -> Array:
	return [{
		"name": "section",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(PackedStringArray([""]) + Settings.all_sections())
	}]
