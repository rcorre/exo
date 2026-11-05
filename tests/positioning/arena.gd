extends Node3D
## Shared deterministic fixture world. All simulation uses actual physics ticks.

signal stepped

const Scenario := preload("res://tests/positioning/scenario.gd")
const Actor := preload("res://tests/positioning/actor.gd")

var data: Dictionary
var player: CharacterBody3D
var enemies: Array[CharacterBody3D] = []
var region: NavigationRegion3D
var policy: RefCounted
var cover_boxes: Array[CollisionShape3D] = []
var ticks := 0
var running := false
var next_player_move := 0
var initialized := false

func setup(scenario: Dictionary, interactive: bool = false) -> bool:
	data = scenario.duplicate(true)
	process_physics_priority = 100 # Record/check after the actors have moved.
	seed(1)
	var script: Script = load(data.get("policy", Scenario.DEFAULT_POLICY))
	if not script.can_instantiate():
		push_error("Cannot instantiate positioning policy")
		return false
	policy = script.new()
	if policy == null or not policy.has_method("choose_destination"):
		push_error("Positioning policy needs choose_destination(enemy, player, arena)")
		return false
	region = NavigationRegion3D.new()
	var navmesh := NavigationMesh.new()
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.agent_radius = 0.5
	navmesh.agent_height = ceilf(Actor.HEIGHT / 0.25) * 0.25
	navmesh.agent_max_climb = 0.25
	navmesh.cell_size = 0.25
	navmesh.cell_height = 0.25
	region.navigation_mesh = navmesh
	add_child(region)
	_add_box(Vector3(0, -0.5, 0), Vector3(Scenario.ARENA_SIZE.x, 1, Scenario.ARENA_SIZE.y), 0.0, Color("303b49"))
	for obstacle: Dictionary in data.get("obstacles", []):
		var size := Vector3(obstacle.size[0], obstacle.size[1], obstacle.size[2])
		cover_boxes.append(_add_box(Scenario.point(obstacle.center) + Vector3.UP * size.y * 0.5, size, deg_to_rad(float(obstacle.get("yaw_degrees", 0.0))), Color("8c8273")))
	# Walls keep interactive movement within the same bounds as navigation.
	for side in [-1.0, 1.0]:
		_add_box(Vector3(side * 12.25, 0.5, 0), Vector3(0.5, 1, 21), 0.0, Color("617087"))
		_add_box(Vector3(0, 0.5, side * 10.25), Vector3(24, 1, 0.5), 0.0, Color("617087"))
	region.bake_navigation_mesh(false)
	player = _add_actor("player", Scenario.point(data.player), true)
	player.controlled = interactive
	for spec: Dictionary in data.enemies:
		enemies.append(_add_actor(spec.id, Scenario.point(spec.start), false))
	# Baking and server synchronization are separate. Allow removal of the old
	# region and registration of this one, including during interactive resets.
	await get_tree().physics_frame
	await get_tree().physics_frame
	for frame in 120:
		await get_tree().physics_frame
		await get_tree().process_frame
		# A nonzero map iteration can still describe the previous fixture (or a
		# map with no polygons yet). Wait for THIS region to be queryable.
		var owner := NavigationServer3D.map_get_closest_point_owner(region.get_navigation_map(), player.global_position)
		if owner == region.get_rid() and navmesh.get_polygon_count() > 0:
			for enemy in enemies:
				var floor_point := NavigationServer3D.map_get_closest_point(region.get_navigation_map(), enemy.global_position)
				enemy.agent.path_height_offset = floor_point.y - enemy.global_position.y
			initialized = true
			return true
	push_error("Navigation map failed to initialize")
	return false

func _add_actor(id: String, at: Vector3, is_player: bool) -> CharacterBody3D:
	var actor := Actor.new()
	actor.actor_id = id
	actor.position = at
	actor.is_player = is_player
	actor.arena = self
	actor.policy = policy
	add_child(actor)
	return actor

func _add_box(at: Vector3, size: Vector3, yaw: float, color: Color) -> CollisionShape3D:
	var body := StaticBody3D.new()
	body.position = at
	body.rotation.y = yaw
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	visual.material_override = material
	body.add_child(visual)
	region.add_child(body)
	return collision

func set_running(value: bool) -> void:
	running = value and initialized
	player.active = running
	for enemy in enemies:
		enemy.active = running

func _physics_process(_delta: float) -> void:
	if not running:
		return
	ticks += 1
	var moves: Array = data.get("player_moves", [])
	while next_player_move < moves.size() and elapsed() >= float(moves[next_player_move].at_seconds):
		player.global_position = Scenario.point(moves[next_player_move].position)
		player.velocity = Vector3.ZERO
		next_player_move += 1
	stepped.emit()

func elapsed() -> float:
	return float(ticks) / Engine.physics_ticks_per_second

func snapshot() -> Dictionary:
	var results: Array[Dictionary] = []
	var passed := true
	for index in enemies.size():
		var enemy := enemies[index]
		var expected: Array = data.enemies[index].expected
		var inside := Scenario.accepts(enemy.global_position, expected)
		var settled := Vector2(enemy.velocity.x, enemy.velocity.z).length() < 0.1
		var grounded := enemy.is_on_floor()
		var ok := inside and settled and grounded
		var separation_ok := true
		for other: CharacterBody3D in enemies:
			if other != enemy:
				var delta := enemy.global_position - other.global_position
				separation_ok = separation_ok and Vector2(delta.x, delta.z).length() >= float(data.get("min_enemy_separation", 0.0))
		ok = ok and separation_ok
		var cover_checks: Dictionary = {}
		if data.get("check_cover", false) and policy.has_method("check_cover"):
			cover_checks = policy.check_cover(enemy, player, self)
			ok = ok and cover_checks.get("protected", false) and cover_checks.get("peek_clear", false) and cover_checks.get("shot_clear", false)
			if data.has("cover_kind"):
				ok = ok and cover_checks.get("kind", "") == data.cover_kind
		elif data.get("check_cover", false):
			ok = false
		passed = passed and ok
		var path: Array = []
		for position: Vector3 in enemy.trace:
			path.append(Scenario.coordinates(position))
		results.append({"id": enemy.actor_id, "position": Scenario.coordinates(enemy.global_position),
			"destination": Scenario.coordinates(enemy.destination), "expected": expected,
			"inside_expected": inside, "settled": settled, "grounded": grounded,
			"passed": ok, "separation_ok": separation_ok, "cover_checks": cover_checks, "trace": path})
	return {"name": data.name, "policy": data.get("policy", Scenario.DEFAULT_POLICY),
		"ticks": ticks, "seconds": elapsed(), "passed": passed,
		"player": Scenario.coordinates(player.global_position), "enemies": results}
