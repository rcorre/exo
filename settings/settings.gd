@tool
extends Node

const CONFIG_PATH := "user://settings.cfg"

class Setting:
	extends RefCounted

	signal changed(val)

	var _section: String
	var _key: String
	var _val
	var _default

	func _init(section: String, key: String, default) -> void:
		_section = section
		_key = key
		_val = default
		_default = default

	func _normalize(val):
		return val

	func _read(conf: ConfigFile) -> void:
		_set_value(conf.get_value(_section, _key, _default))

	func _write(conf: ConfigFile) -> void:
		conf.set_value(_section, _key, _val)

	func _set_value(val) -> void:
		_val = _normalize(val)
		changed.emit(_val)
		print("Set %s to %s" % [full_name(), _val])

	func name() -> String:
		return _key

	func full_name() -> String:
		return "%s.%s" % [_section, _key]

class Integer:
	extends Setting

	var lower: int
	var upper: int
	var value: int : get = get_value, set = set_value

	func _init(section: String, key: String, default: int, bounds: PackedInt32Array) -> void:
		super(section, key, default)
		lower = bounds[0]
		upper = bounds[1]

	func _normalize(val):
		if typeof(val) != TYPE_INT:
			push_warning("Invalid type for setting %s: %s" % [full_name(), type_string(typeof(val))])
			return _default

		var res: int = clamp(val, lower, upper)
		if res != val:
			push_warning("Config %s value %s out of range [%d, %d]" % [full_name(), val, lower, upper])

		return res

	func get_value() -> int:
		return _val

	func set_value(val: int) -> void:
		_set_value(val)

class Real:
	extends Setting

	var lower: float
	var upper: float
	var value: float : get = get_value, set = set_value

	func _init(section: String, key: String, default: float, bounds: PackedFloat32Array) -> void:
		super(section, key, default)
		lower = bounds[0]
		upper = bounds[1]

	func _normalize(val):
		if typeof(val) != TYPE_FLOAT:
			push_warning("Invalid type for setting %s" % full_name())
			return _default

		var res: float = clamp(val, lower, upper)
		if res != val:
			push_warning("Config %s value %s out of range [%f, %f]" % [full_name(), val, lower, upper])

		return res

	func get_value() -> float:
		return _val

	func set_value(val: float) -> void:
		_set_value(val)

class Text:
	extends Setting

	var choices: PackedStringArray
	var value: String : get = get_value, set = set_value

	func _init(section: String, key: String, default: String, choice_list: PackedStringArray) -> void:
		super(section, key, default)
		choices = choice_list

	func _normalize(val):
		if typeof(val) != TYPE_STRING:
			push_warning("%s has invalid type for setting %s" % [val, full_name()])
			return _default

		if choices.size() > 0 and not val in choices:
			push_warning("Config %s value %s not in %s" % [full_name(), val, choices])
			return _default

		return val

	func get_value() -> String:
		return _val

	func set_value(val: String) -> void:
		_set_value(val)

class Boolean:
	extends Setting

	var value: bool : get = get_value, set = set_value

	func _init(section: String, key: String, default: bool) -> void:
		super(section, key, default)

	func _normalize(val):
		if typeof(val) != TYPE_BOOL:
			push_warning("%s has invalid type for setting %s" % [val, full_name()])
			return _default

		return val

	func get_value() -> bool:
		return _val

	func set_value(val: bool) -> void:
		_set_value(val)

var _config := ConfigFile.new()
var _settings: Array[Setting]

func integer(section: String, key: String, default: int, bounds: PackedInt32Array) -> Integer:
	var s := Integer.new(section, key, default, bounds)
	_settings.append(s)
	return s

func real(section: String, key: String, default: float, bounds: PackedFloat32Array) -> Real:
	var s := Real.new(section, key, default, bounds)
	_settings.append(s)
	return s

func text(section: String, key: String, default: String = "") -> Text:
	var s := Text.new(section, key, default, PackedStringArray())
	_settings.append(s)
	return s

func choice(section: String, key: String, choices: PackedStringArray) -> Text:
	var s := Text.new(section, key, choices[0], choices)
	_settings.append(s)
	return s

func boolean(section: String, key: String, default: bool = false) -> Boolean:
	var s := Boolean.new(section, key, default)
	_settings.append(s)
	return s

var video_display := choice("video", "display", ["window", "fullscreen", "borderless"])
var video_scale_factor := real("video", "scale", 1.0, [0.1, 1.0])

var audio_master_volume := real("audio", "master_volume", 100.0, [0.0, 100.0])

var mouse_sensitivity := real("input", "mouse_sensitivity", 1.0, [0.1, 5.0])
var mouse_invert_y := boolean("input", "mouse_invert_y")

func _ready() -> void:
	audio_master_volume.changed.connect(_on_master_volume_changed)
	video_display.changed.connect(_on_video_display_changed)
	video_scale_factor.changed.connect(_on_video_scale_factor_changed)
	reload()

# Reset settings to default values
# If section is passed, only reload settings in the given section
func reload(section: String = "") -> void:
	_config.load(CONFIG_PATH)

	for s in _settings:
		if section == "" or s._section == section:
			s._read(_config)

	print("Loaded settings")

# Reset settings to default values
# If section is passed, only reset settings in the given section
func reset(section: String = "") -> void:
	for s in _settings:
		if section == "" or s._section == section:
			s._set_value(s._default)

# Persist settings to disk
# If section is passed, only persist settings in the given section
func save(section: String = "") -> void:
	for s in _settings:
		if section == "" or s._section == section:
			s._write(_config)
	_config.save(CONFIG_PATH)
	print("Saved settings")

func all_settings() -> Array[Setting]:
	return _settings

func all_sections() -> PackedStringArray:
	var ret := PackedStringArray()
	for s in _settings:
		if not s._section in ret:
			ret.push_back(s._section)
	return ret

func _on_master_volume_changed(val: float) -> void:
	var idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(idx, remap(val, 0.0, 100.0, -72.0, 0.0))

func _on_video_display_changed(val: String) -> void:
	match val:
		"window":
			get_window().mode = Window.MODE_WINDOWED
			get_window().borderless = false
		"borderless":
			get_window().mode = Window.MODE_WINDOWED
			get_window().borderless = true
		"fullscreen":
			get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
			get_window().borderless = true

func _on_video_scale_factor_changed(val: float) -> void:
	get_tree().root.scaling_3d_scale = val
