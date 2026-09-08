@tool
extends OptionButton
class_name SettingDropdown

var setting_name: String : set = set_setting_name
var setting: Settings.Text : set = set_setting

func _ready() -> void:
	connect("item_selected", _on_item_selected)
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _on_item_selected(idx: int) -> void:
	if setting:
		setting.value = get_item_text(idx)

func set_setting_name(p_name: String) -> void:
	setting_name = p_name

	for s in Settings.all_settings():
		if s.full_name() == setting_name:
			set_setting(s as Settings.Text)
			return

func set_setting(s: Settings.Text) -> void:
	setting = s
	clear()
	for i in range(s.choices.size()):
		add_item(s.choices[i])
		if s.choices[i] == setting.value:
			select(i)

func _get_property_list() -> Array:
	var settings := []
	for s in Settings.all_settings():
		var t := s as Settings.Text
		if (not t) or t.choices.is_empty():
			continue
		settings.push_back(t.full_name())

	return [{
		"name": "setting_name",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(settings)
	}]
