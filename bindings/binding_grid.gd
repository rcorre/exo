@tool
extends GridContainer
class_name BindingGrid

func _ready() -> void:
	columns = 2

	for p in ProjectSettings.get_property_list():
		var prop_name: String = p.name
		if prop_name.find("input/") != 0 or prop_name.find("input/ui_") == 0:
			# default ui bindings in all godot projects
			continue

		var action_name: String = prop_name.trim_prefix("input/")

		var label := Label.new()
		label.text = action_name.capitalize()
		add_child(label)

		var button := BindingButton.new()
		button.action = action_name
		add_child(button)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
