extends RefCounted
## Harness positive control ONLY, not cover AI. Hold a fixed distance from the
## player, on the bearing from the player to the enemy's original spawn.
## Stable bearings let navigation detour without changing the destination.

const STANDOFF_DISTANCE := 5.0

func choose_destination(enemy: CharacterBody3D, player: CharacterBody3D, _arena: Node3D) -> Vector3:
	var bearing: Vector3 = enemy.start_position - player.global_position
	bearing.y = 0.0
	if bearing.length_squared() < 0.001:
		bearing = Vector3.RIGHT
	return player.global_position + bearing.normalized() * STANDOFF_DISTANCE
