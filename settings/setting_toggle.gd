@tool
extends CheckBox
class_name SettingToggle

var setting_name: String : set = set_setting_name
var setting: Settings.Boolean : set = set_setting

func _toggled(val: bool) -> void:
	if setting:
		setting.value = val

func set_setting_name(p_name: String) -> void:
	setting_name = p_name

	for s in Settings.all_settings():
		if s.full_name() == name:
			set_setting(s as Settings.Boolean)
			return

func set_setting(s: Settings.Boolean) -> void:
	if setting:
		setting.changed.disconnect(set_pressed_no_signal)
	setting = s
	set_pressed_no_signal(s.value)
	s.changed.connect(set_pressed_no_signal)

func _get_property_list() -> Array:
	var settings := []
	for s in Settings.all_settings():
		var r := s as Settings.Boolean
		if not r:
			continue
		settings.push_back(r.full_name())

	return [{
		"name": "setting_name",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(settings)
	}]
