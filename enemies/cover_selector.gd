extends RefCounted
## Experimental standing partial-cover/side-peek selector; inputs are world objects.
## Boxes are supplied by the caller; only static collision is considered for cover.

const RADIUS := 0.4
const HEIGHT := 1.8
const OFFSET := 0.65
const MAX_PROJECTION := 0.45
const MAX_SEARCH := 20.0
const SWITCH_IMPROVEMENT := 1.0
const OCCUPANCY_DISTANCE := 1.2

var candidates: Array[Dictionary] = []
# Keyed by instance ID, with weak references so freed actors cannot leak slots.
var reservations: Dictionary = {}

func release(enemy: CharacterBody3D) -> void:
	reservations.erase(enemy.get_instance_id())

func _occupied(enemy: CharacterBody3D, hide: Vector3, peek: Vector3) -> bool:
	for id: int in reservations.keys():
		var reservation: Dictionary = reservations[id]
		if not is_instance_valid(reservation.actor.get_ref()):
			reservations.erase(id)
			continue
		if id == enemy.get_instance_id():
			continue
		for ours: Vector3 in [hide, peek]:
			for theirs: Vector3 in [reservation.hide, reservation.peek]:
				if Vector2(ours.x - theirs.x, ours.z - theirs.z).length() < OCCUPANCY_DISTANCE:
					return true
	return false

func select(enemy: CharacterBody3D, threat: Vector3, world: World3D, map: RID, boxes: Array[CollisionShape3D]) -> Dictionary:
	candidates.clear()
	var best: Dictionary = {}
	var best_score := INF
	var previous: Dictionary = reservations.get(enemy.get_instance_id(), {})
	var retained: Dictionary = {}
	for collision: CollisionShape3D in boxes:
		if not collision.shape is BoxShape3D:
			continue
		var size: Vector3 = collision.shape.size
		var transform := collision.global_transform
		for axis in 2:
			var normal := Vector3.RIGHT if axis == 0 else Vector3.BACK
			var tangent := Vector3.BACK if axis == 0 else Vector3.RIGHT
			var half_normal := (size.x if axis == 0 else size.z) * 0.5
			var half_tangent := (size.z if axis == 0 else size.x) * 0.5
			for side in [-1.0, 1.0]:
				for edge in [-1.0, 1.0]:
					# Hide near an edge, peek around that edge on the same face.
					var local_hide: Vector3 = normal * side * (half_normal + OFFSET) + tangent * edge * maxf(0.0, half_tangent - 0.35)
					var local_peek: Vector3 = normal * side * (half_normal + OFFSET) + tangent * edge * (half_tangent + 1.5)
					var hide := transform * local_hide
					var peek := transform * local_peek
					hide.y = enemy.global_position.y
					peek.y = hide.y
					var entry := {"hide": hide, "peek": peek, "kind": "side_peek", "reason": "distance", "score": -1.0}
					candidates.append(entry)
					if hide.distance_to(enemy.global_position) > MAX_SEARCH:
						continue
					entry.reason = "exposed"
					var threat_eye := threat + Vector3.UP * 1.5
					if _ray_clear(world, threat_eye, hide + Vector3.UP * 0.9):
						continue
					# A clear head/shot ray over low cover means the standing position
					# can engage directly while its torso remains protected.
					if _ray_clear(world, threat_eye, hide + Vector3.UP * 1.5):
						peek = hide
						entry.peek = hide
						entry.kind = "partial"
					var projected := NavigationServer3D.map_get_closest_point(map, hide)
					var projected_peek := NavigationServer3D.map_get_closest_point(map, peek)
					entry.reason = "projection"
					if Vector2(projected.x - hide.x, projected.z - hide.z).length() > MAX_PROJECTION or Vector2(projected_peek.x - peek.x, projected_peek.z - peek.z).length() > MAX_PROJECTION:
						continue
					entry.reason = "occupied"
					if _occupied(enemy, hide, peek):
						continue
					entry.reason = "path"
					var path := NavigationServer3D.map_get_path(map, enemy.global_position, projected, true)
					if path.is_empty() or path[-1].distance_to(projected) > 0.2:
						continue
					entry.reason = "clearance"
					if not _clear_move(world, hide, peek, enemy.get_rid()):
						continue
					entry.reason = "no shot"
					if not _ray_clear(world, peek + Vector3.UP * 1.5, threat + Vector3.UP * 1.5):
						continue
					var length := 0.0
					for i in range(1, path.size()):
						length += path[i - 1].distance_to(path[i])
					entry.reason = "valid"
					entry.score = length
					if not previous.is_empty() and hide.distance_to(previous.hide) < 0.01 and peek.distance_to(previous.peek) < 0.01:
						retained = entry
					if length < best_score:
						best_score = length
						best = entry
	if not retained.is_empty() and retained.score <= best_score + SWITCH_IMPROVEMENT:
		best = retained
	if best.is_empty():
		release(enemy)
	else:
		reservations[enemy.get_instance_id()] = {"actor": weakref(enemy), "hide": best.hide, "peek": best.peek}
	return best

func _ray_clear(world: World3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return world.direct_space_state.intersect_ray(query).is_empty()

func _clear_move(world: World3D, from: Vector3, to: Vector3, exclude: RID) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, from + Vector3.UP * (HEIGHT * 0.5 + 0.02))
	query.collision_mask = 1
	query.exclude = [exclude]
	if not world.direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	query.motion = to - from
	var motion := world.direct_space_state.cast_motion(query)
	return motion[0] >= 0.999
