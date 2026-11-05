extends RefCounted
## JSON fixtures use [x, z] coordinates in meters. Expectations are acceptable
## destination regions, never inputs to the positioning policy.

const DEFAULT_POLICY := "res://tests/positioning/navigation_baseline.gd"
const ARENA_SIZE := Vector2(24.0, 20.0)

static func load_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot read scenario: " + path)
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		push_error("Invalid scenario JSON: " + path)
		return {}
	var data: Dictionary = json.data
	var error := validate(data)
	if not error.is_empty():
		push_error(path + ": " + error)
		return {}
	return data

static func validate(data: Dictionary) -> String:
	if not data.get("name") is String or not point_valid(data.get("player")):
		return "name and player [x, z] are required"
	if not positive(data.get("duration_seconds")) or float(data.duration_seconds) > 120.0:
		return "duration_seconds must be positive and at most 120"
	if not data.get("enemies") is Array or data.enemies.is_empty():
		return "enemies must be a nonempty array"
	var ids: Array[String] = []
	for enemy: Variant in data.enemies:
		if not enemy is Dictionary or not enemy.get("id") is String or not point_valid(enemy.get("start")):
			return "each enemy needs an id and start [x, z]"
		if enemy.id.is_empty() or enemy.id in ids:
			return "enemy ids must be nonempty and unique"
		ids.append(enemy.id)
		if not enemy.get("expected") is Array or enemy.expected.is_empty():
			return "each enemy needs at least one expected region"
		for region: Variant in enemy.expected:
			if not region is Dictionary or not point_valid(region.get("center")) or not positive(region.get("radius")):
				return "expected regions need center [x, z] and positive radius"
	if not data.get("obstacles", []) is Array or not data.get("player_moves", []) is Array:
		return "obstacles and player_moves must be arrays"
	for obstacle: Variant in data.get("obstacles", []):
		if not obstacle is Dictionary or not point_valid(obstacle.get("center")):
			return "obstacles need center [x, z]"
		var size: Variant = obstacle.get("size")
		if not size is Array or size.size() != 3:
			return "obstacle size must be [width, height, depth]"
		for value: Variant in size:
			if not positive(value):
				return "obstacle dimensions must be positive"
		if not number_valid(obstacle.get("yaw_degrees", 0.0)):
			return "obstacle yaw_degrees must be a finite number"
	var previous_time := -1.0
	for move: Variant in data.get("player_moves", []):
		if not move is Dictionary or not number_valid(move.get("at_seconds")) or not point_valid(move.get("position")):
			return "player_moves need at_seconds and position [x, z]"
		var time := float(move.at_seconds)
		if time < 0.0 or time <= previous_time or time >= float(data.duration_seconds):
			return "player_moves must be ordered, unique, and within the scenario duration"
		previous_time = time
	if data.has("exercise_peek") and not data.exercise_peek is bool:
		return "exercise_peek must be a boolean"
	if data.has("min_enemy_separation") and not positive(data.min_enemy_separation):
		return "min_enemy_separation must be positive"
	if data.has("check_cover") and not data.check_cover is bool:
		return "check_cover must be a boolean"
	if data.has("cover_kind") and (not data.get("check_cover", false) or data.cover_kind not in ["partial", "side_peek"]):
		return "cover_kind requires check_cover and must be partial or side_peek"
	var policy: Variant = data.get("policy", DEFAULT_POLICY)
	if not policy is String or not ResourceLoader.exists(policy, "Script"):
		return "policy must name an existing script"
	return ""

static func number_valid(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func positive(value: Variant) -> bool:
	return number_valid(value) and float(value) > 0.0

static func point_valid(value: Variant) -> bool:
	return value is Array and value.size() == 2 and number_valid(value[0]) and number_valid(value[1])

static func point(value: Array) -> Vector3:
	return Vector3(float(value[0]), 0.0, float(value[1]))

static func coordinates(value: Vector3) -> Array:
	return [value.x, value.z]

static func paths() -> Array[String]:
	var result: Array[String] = []
	for file in DirAccess.get_files_at("res://tests/positioning/cases"):
		if file.ends_with(".json"):
			result.append("res://tests/positioning/cases/" + file)
	result.sort()
	return result

static func accepts(position: Vector3, regions: Array) -> bool:
	for region: Dictionary in regions:
		if Vector2(position.x, position.z).distance_to(Vector2(region.center[0], region.center[1])) <= float(region.radius):
			return true
	return false
