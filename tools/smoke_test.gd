extends SceneTree
# Loads and instantiates every .tscn in the project to catch scene corruption
# (bad ext_resource/sub_resource ids, missing scripts, etc.) that only shows
# up when Godot actually parses the file. Run via: tools/check.sh tools/smoke_test.gd

const SKIP_DIRS := [".godot", ".git", "addons"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var ok := true
	for path in _find_scenes("res://"):
		var res: Resource = load(path)
		if res == null:
			printerr("FAILED TO LOAD: ", path)
			ok = false
			continue
		var inst: Node = res.instantiate()
		if inst == null:
			printerr("FAILED TO INSTANTIATE: ", path)
			ok = false
			continue
		inst.free()
		print("ok: ", path)
	quit(0 if ok else 1)

func _find_scenes(dir_path: String) -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return results
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			if not SKIP_DIRS.has(name):
				results.append_array(_find_scenes(full))
		elif name.ends_with(".tscn"):
			results.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return results
