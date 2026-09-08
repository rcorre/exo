@tool
extends GridContainer
class_name SettingsGrid

var section: String : set = set_section

# Automatically creates a grid with controls to tweak settings

func set_section(sec: String) -> void:
	section = sec
	columns = 2

	for c in get_children():
		c.queue_free()

	for opt in Settings.all_settings():
		if section.length() > 0 and opt._section != section:
			continue

		var control

		if opt is Settings.Integer:
			control = SettingSpinner.new()
		elif opt is Settings.Real:
			control = SettingSlider.new()
		elif opt is Settings.Text:
			var t: Settings.Text = opt
			if t.choices.is_empty():
				control = SettingLineEdit.new()
			else:
				control = SettingDropdown.new()
		elif opt is Settings.Boolean:
			control = SettingToggle.new()
		else:
			push_warning("No control can handle setting: %s" % opt)
			continue

		var label := Label.new()
		label.text = opt.name().capitalize()
		add_child(label)

		control.setting = opt
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(control as Control)

func _get_property_list() -> Array:
	return [{
		"name": "section",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(Settings.all_sections())
	}]
