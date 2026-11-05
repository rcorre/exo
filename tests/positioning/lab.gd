extends Node3D
## Interactive editor/replay for exactly the same fixtures used headlessly.

const Scenario := preload("res://tests/positioning/scenario.gd")
const Arena := preload("res://tests/positioning/arena.tscn")
const Overlay := preload("res://tests/positioning/overlay.gd")
const Report := preload("res://tests/positioning/report.gd")

@onready var camera: Camera3D = $Camera3D

var arena: Node3D
var overlay: Control
var paths: Array[String]
var case_path := ""
var selector: OptionButton
var enemy_selector: OptionButton
var radius: SpinBox
var status: Label
var title: Label
var message: Label
var pause_button: Button
var loading := false
var dirty := false
var step_once := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	paths = Scenario.paths()
	for arg in OS.get_cmdline_user_args():
		if arg.ends_with(".json"):
			if not arg in paths:
				paths.append(arg)
			case_path = arg
	if case_path.is_empty() and not paths.is_empty():
		case_path = paths[0]
	_build_ui()
	if not case_path.is_empty():
		selector.select(paths.find(case_path))
		_load_case(case_path)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	overlay = Overlay.new()
	overlay.camera = camera
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	var panel := PanelContainer.new()
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 12
	panel.offset_top = 12
	panel.offset_right = -12
	var box := VBoxContainer.new()
	panel.add_child(box)
	title = Label.new()
	title.text = "POSITIONING LAB"
	box.add_child(title)
	var controls := HBoxContainer.new()
	box.add_child(controls)
	selector = OptionButton.new()
	for path in paths:
		selector.add_item(path.get_file().get_basename())
	selector.item_selected.connect(_select_case)
	controls.add_child(selector)
	_button(controls, "Reset", _reset)
	pause_button = _button(controls, "Pause", _toggle_pause)
	_button(controls, "Step", _step)
	_button(controls, "Export report", _export)
	_button(controls, "Save setup copy", _save_setup_copy)
	var editor := HBoxContainer.new()
	box.add_child(editor)
	var label := Label.new()
	label.text = "Edit expected:"
	editor.add_child(label)
	enemy_selector = OptionButton.new()
	enemy_selector.item_selected.connect(_select_enemy)
	editor.add_child(enemy_selector)
	radius = SpinBox.new()
	radius.min_value = 0.1
	radius.max_value = 5.0
	radius.step = 0.1
	radius.value = 0.6
	radius.prefix = "radius "
	radius.custom_minimum_size.x = 140
	editor.add_child(radius)
	_button(editor, "Save expectations", _save)
	var help := Label.new()
	help.text = "WASD: move player | Right-click floor: replace selected enemy's expected region\nGreen: expected | Yellow: target | Orange: trail | Cyan: valid cover/peek | Red: rejected"
	box.add_child(help)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.text = "Expectations are independent of the policy; saving never copies actual endpoints."
	box.add_child(message)

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _load_case(path: String) -> void:
	if loading:
		return
	loading = true
	var data := Scenario.load_file(path)
	if data.is_empty():
		message.text = "Failed to load " + path
		loading = false
		return
	if is_instance_valid(arena):
		arena.set_running(false)
		arena.queue_free()
		await get_tree().process_frame
	arena = Arena.instantiate()
	add_child(arena)
	overlay.arena = arena
	if not await arena.setup(data, true):
		message.text = "Arena initialization failed; see errors."
		loading = false
		return
	case_path = path
	title.text = "POSITIONING LAB — " + ("NAVIGATION BASELINE (not cover AI)" if data.get("policy", Scenario.DEFAULT_POLICY) == Scenario.DEFAULT_POLICY else str(data.policy).get_file())
	dirty = false
	step_once = false
	enemy_selector.clear()
	for enemy: Dictionary in data.enemies:
		enemy_selector.add_item(enemy.id)
	_select_enemy(0)
	arena.stepped.connect(_on_step)
	arena.set_running(true)
	pause_button.text = "Pause"
	message.text = data.get("description", "")
	loading = false

func _select_case(index: int) -> void:
	if dirty:
		message.text = "Save expectations before switching. Reset discards edits."
		selector.select(paths.find(case_path))
		return
	_load_case(paths[index])

func _select_enemy(index: int) -> void:
	if is_instance_valid(arena):
		radius.value = arena.data.enemies[index].expected[0].radius

func _reset() -> void:
	_load_case(case_path)

func _toggle_pause() -> void:
	if loading or not is_instance_valid(arena) or not arena.initialized:
		return
	arena.set_running(not arena.running)
	pause_button.text = "Pause" if arena.running else "Resume"

func _step() -> void:
	if loading or not is_instance_valid(arena) or not arena.initialized:
		return
	step_once = true
	arena.set_running(true)

func _on_step() -> void:
	if step_once:
		step_once = false
		arena.set_running(false)
		pause_button.text = "Resume"

func _process(_delta: float) -> void:
	if loading or not is_instance_valid(arena) or not arena.initialized:
		return
	var entries: Array[String] = []
	for index in arena.enemies.size():
		var enemy: CharacterBody3D = arena.enemies[index]
		var inside := Scenario.accepts(enemy.global_position, arena.data.enemies[index].expected)
		entries.append("%s (%.1f, %.1f): %s" % [enemy.actor_id, enemy.position.x, enemy.position.z, "in region" if inside else "outside"])
	status.text = "%.2fs | %s%s" % [arena.elapsed(), " | ".join(entries), " | UNSAVED" if dirty else ""]

func _unhandled_input(event: InputEvent) -> void:
	if loading or not is_instance_valid(arena) or not arena.initialized:
		return
	if event.is_action_pressed("aim"):
		var mouse: Vector2 = event.position if event is InputEventMouseButton else get_viewport().get_mouse_position()
		var hit: Variant = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
		if hit == null or absf(hit.x) > 12.0 or absf(hit.z) > 10.0:
			return
		var point := Vector3(snappedf(hit.x, 0.1), 0, snappedf(hit.z, 0.1))
		arena.data.enemies[enemy_selector.selected].expected = [{"center": Scenario.coordinates(point), "radius": radius.value}]
		dirty = true
		message.text = "Expected %s: (%.1f, %.1f). Save expectations preserves fixture starts; Save setup copy captures live starts." % [enemy_selector.get_item_text(enemy_selector.selected), point.x, point.z]
		get_viewport().set_input_as_handled()

func _save() -> void:
	if loading or not is_instance_valid(arena) or not arena.initialized:
		return
	# Reload to preserve starts and unrelated fields; never bless actual output.
	var original := Scenario.load_file(case_path)
	if original.is_empty():
		return
	for edited: Dictionary in arena.data.enemies:
		for enemy: Dictionary in original.enemies:
			if enemy.id == edited.id:
				enemy.expected = edited.expected.duplicate(true)
	var file := FileAccess.open(case_path, FileAccess.WRITE)
	if file == null:
		message.text = "Cannot write " + case_path
		return
	file.store_string(JSON.stringify(original, "\t") + "\n")
	dirty = false
	message.text = "Saved expectations to " + case_path + ". Reset to replay from fixture starts."

func _save_setup_copy() -> void:
	if loading or not is_instance_valid(arena) or not arena.initialized:
		return
	var copy: Dictionary = arena.data.duplicate(true)
	copy.name = str(copy.name) + " (edited setup)"
	copy.player = Scenario.coordinates(arena.player.global_position)
	copy.erase("player_moves")
	for index in arena.enemies.size():
		copy.enemies[index].start = Scenario.coordinates(arena.enemies[index].global_position)
	# Expectations remain explicitly authored, never replaced with actual output.
	var directory := "user://positioning-cases"
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		message.text = "Cannot create " + directory
		return
	var path := directory.path_join("setup_%d.json" % Time.get_ticks_usec())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		message.text = "Cannot write " + path
		return
	file.store_string(JSON.stringify(copy, "\t") + "\n")
	file.close()
	paths.append(path)
	selector.add_item(path.get_file().get_basename())
	selector.select(paths.size() - 1)
	await _load_case(path)
	message.text = "Saved and replaying " + ProjectSettings.globalize_path(path)

func _export() -> void:
	if loading or not is_instance_valid(arena) or not arena.initialized:
		return
	var output := ProjectSettings.globalize_path("user://positioning-reports")
	var result: Dictionary = arena.snapshot()
	result["interactive"] = true
	if Report.save(output, case_path.get_file().get_basename(), arena.data, result):
		message.text = "JSON + SVG exported to " + output
