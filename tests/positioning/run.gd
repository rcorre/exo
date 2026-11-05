extends SceneTree
## tools/check.sh tests/positioning/run.gd --fixed-fps 60 -- [--output DIR] [CASE.json ...]

const Scenario := preload("res://tests/positioning/scenario.gd")
const Report := preload("res://tests/positioning/report.gd")
const Arena := preload("res://tests/positioning/arena.tscn")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var paths: Array[String] = []
	var output := "/tmp/exo-positioning"
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		if args[i] == "--output" and i + 1 < args.size():
			i += 1
			output = args[i]
		elif args[i].begins_with("--"):
			printerr("usage: -- [--output DIR] [CASE.json ...]")
			quit(2)
			return
		else:
			paths.append(args[i])
		i += 1
	if paths.is_empty():
		paths = Scenario.paths()
	if paths.is_empty():
		printerr("No positioning scenarios found")
		quit(1)
		return
	# Guard the oracle itself: displaced positions must not pass, and alternate
	# acceptable regions must work. Do not infer expected positions from policy.
	var regions := [{"center": [2, 3], "radius": 0.5}, {"center": [-2, -3], "radius": 0.5}]
	if Scenario.accepts(Vector3.ZERO, regions) or not Scenario.accepts(Vector3(-2, 0, -3), regions):
		printerr("FAIL: region matcher self-check")
		quit(1)
		return
	var failures := 0
	for path in paths:
		var data := Scenario.load_file(path)
		if data.is_empty():
			failures += 1
			continue
		var arena := Arena.instantiate()
		root.add_child(arena)
		current_scene = arena
		if not await arena.setup(data):
			failures += 1
			arena.queue_free()
			await process_frame
			continue
		arena.set_running(true)
		var limit := ceili(float(data.duration_seconds) * Engine.physics_ticks_per_second)
		while arena.ticks < limit:
			await arena.stepped
		arena.set_running(false)
		var result: Dictionary = arena.snapshot()
		if not result.passed:
			failures += 1
		print("%s: %s (%d ticks)" % ["PASS" if result.passed else "FAIL", data.name, result.ticks])
		for enemy: Dictionary in result.enemies:
			print("  %s actual=%s target=%s in_region=%s settled=%s grounded=%s" % [enemy.id,
				enemy.position, enemy.destination, enemy.inside_expected, enemy.settled, enemy.grounded])
			if not enemy.cover_checks.is_empty():
				print("    cover: %s" % enemy.cover_checks)
			if not enemy.peek_checks.is_empty():
				print("    peek: %s" % enemy.peek_checks)
		result["scenario_path"] = path
		if not Report.save(output, path.get_file().get_basename(), data, result):
			failures += 1
		arena.queue_free()
		await process_frame
		await physics_frame
	print("%d scenarios, %d failures. JSON + SVG reports: %s" % [paths.size(), failures, output])
	quit(0 if failures == 0 else 1)
