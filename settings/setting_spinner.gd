@tool
extends SpinBox
class_name SettingSpinner

var setting_name: String : set = set_setting_name
var setting: Settings.Integer : set = set_setting

func _value_changed(new_value: float) -> void:
	if setting:
		setting.value = floor(new_value)

func set_setting_name(p_name: String) -> void:
	setting_name = p_name

	for s in Settings.all_settings():
		if s.full_name() == name:
			set_setting(s as Settings.Integer)
			return

func set_setting(s: Settings.Integer) -> void:
	setting = s
	value = s.value
	min_value = s.lower
	max_value = s.upper
	s.changed.connect(set_value_no_signal)

func _get_property_list() -> Array:
	var settings := []
	for s in Settings.all_settings():
		if s is Settings.Integer:
			settings.push_back(s.full_name())

	return [{
		"name": "setting_name",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(settings)
	}]
