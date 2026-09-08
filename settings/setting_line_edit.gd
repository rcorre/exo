@tool
extends LineEdit
class_name SettingLineEdit

var setting_name: String : set = set_setting_name
var setting: Settings.Text : set = set_setting

func _ready() -> void:
	connect("text_submitted", _on_text_entered)

func _on_text_entered(val: String) -> void:
	if setting:
		setting.value = val

func set_setting_name(p_name: String) -> void:
	setting_name = p_name

	for s in Settings.all_settings():
		if s.full_name() == name:
			set_setting(s as Settings.Text)
			return

func set_setting(s: Settings.Text) -> void:
	setting = s
	text = s.value
	s.changed.connect(set_text)

func _get_property_list() -> Array:
	var settings := []
	for s in Settings.all_settings():
		if s is Settings.Text:
			settings.push_back(s.full_name())

	return [{
		"name": "setting_name",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(settings)
	}]
