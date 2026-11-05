extends RefCounted
## Lab adapter. This slice navigates to the protected point; it does not peek/fire.

const Selector := preload("res://enemies/cover_selector.gd")
var selector := Selector.new()
var debug_by_enemy: Dictionary = {}
var selected_by_enemy: Dictionary = {}

func choose_destination(enemy: CharacterBody3D, player: CharacterBody3D, arena: Node3D) -> Vector3:
	var result: Dictionary = selector.select(enemy, player.global_position, arena.get_world_3d(), arena.region.get_navigation_map(), arena.cover_boxes)
	debug_by_enemy[enemy.get_instance_id()] = selector.candidates.duplicate(true)
	selected_by_enemy[enemy.get_instance_id()] = result.duplicate(true)
	if result.is_empty():
		return enemy.global_position
	return result.hide

func check_cover(enemy: CharacterBody3D, player: CharacterBody3D, arena: Node3D) -> Dictionary:
	var selected: Dictionary = selected_by_enemy.get(enemy.get_instance_id(), {})
	if selected.is_empty():
		return {"protected": false, "peek_clear": false, "shot_clear": false}
	var world: World3D = arena.get_world_3d()
	var threat: Vector3 = player.global_position + Vector3.UP * 1.5
	var peek: Vector3 = selected.peek
	# Deliberately query physics here rather than using the selector's predicates:
	# this tests the actual endpoint, not just the chosen candidate.
	var space := world.direct_space_state
	var torso := PhysicsRayQueryParameters3D.create(threat, enemy.global_position + Vector3.UP * 0.9, 1)
	var head := PhysicsRayQueryParameters3D.create(threat, enemy.global_position + Vector3.UP * 1.5, 1)
	var shot := PhysicsRayQueryParameters3D.create(peek + Vector3.UP * 1.5, threat, 1)
	var capsule := CapsuleShape3D.new()
	capsule.radius = enemy.RADIUS
	capsule.height = enemy.HEIGHT
	var shape := PhysicsShapeQueryParameters3D.new()
	shape.shape = capsule
	shape.transform = Transform3D(Basis.IDENTITY, enemy.global_position + Vector3.UP * (enemy.HEIGHT * 0.5 + 0.02))
	shape.collision_mask = 1
	var start_clear := space.intersect_shape(shape, 1).is_empty()
	shape.motion = peek - enemy.global_position
	var sweep := space.cast_motion(shape)
	return {
		"protected": not space.intersect_ray(torso).is_empty() and not space.intersect_ray(head).is_empty(),
		"peek_clear": start_clear and sweep[0] >= 0.999,
		"shot_clear": space.intersect_ray(shot).is_empty(),
	}
