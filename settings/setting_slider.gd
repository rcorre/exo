@tool
extends HBoxContainer
class_name SettingSlider

var setting_name: String : set = set_setting_name
var setting: Settings.Real : set = set_setting

var slider := HSlider.new()
var label := Label.new()

func _init() -> void:
	add_child(slider)
	add_child(label)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_stretch_ratio = 2.0
	slider.step = 0.1
	slider.connect("value_changed", _on_slider_changed)

func _on_slider_changed(val: float) -> void:
	if setting:
		setting.value = val

func _on_setting_changed(val: float) -> void:
	# if we get a signal before _ready, we must wait to be added to the tree
	await get_tree().process_frame
	slider.value = val
	label.text = "%3.1f" % val

func set_setting_name(p_name: String) -> void:
	setting_name = p_name

	for s in Settings.all_settings():
		if s.full_name() == name:
			set_setting(s as Settings.Real)
			return

func set_setting(s: Settings.Real) -> void:
	if setting:
		setting.changed.disconnect(_on_setting_changed)
	setting = s
	slider.min_value = s.lower
	slider.max_value = s.upper
	slider.value = s.value
	label.text = "%3.1f" % s.value
	s.changed.connect(_on_setting_changed)

func _get_property_list() -> Array:
	var settings := []
	for s in Settings.all_settings():
		if s is Settings.Real or s is Settings.Integer:
			settings.push_back(s.full_name())

	return [{
		"name": "setting_name",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(settings)
	}]
