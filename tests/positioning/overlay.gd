extends Control
## Screen-space overlays remain legible above world geometry.

const Scenario := preload("res://tests/positioning/scenario.gd")
const GREEN := Color("7aee9a")
const ORANGE := Color("ff9360")
const YELLOW := Color("ffdf70")

var arena: Node3D
var camera: Camera3D

func _process(_delta: float) -> void:
	queue_redraw()

func screen(point: Vector3) -> Vector2:
	return camera.unproject_position(point + Vector3.UP * 0.1)

func ring(at: Vector3, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for step in 49:
		var angle := TAU * step / 48.0
		points.append(screen(at + Vector3(cos(angle), 0, sin(angle)) * radius))
	draw_polyline(points, color, 2.0, true)

func _draw() -> void:
	if not is_instance_valid(arena) or not arena.initialized:
		return
	for index in arena.enemies.size():
		var enemy: CharacterBody3D = arena.enemies[index]
		for expected: Dictionary in arena.data.enemies[index].expected:
			var center := Scenario.point(expected.center)
			ring(center, expected.radius, GREEN)
			draw_string(ThemeDB.fallback_font, screen(center + Vector3(0, 0, expected.radius)) + Vector2(-24, 15), enemy.actor_id + " expected", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GREEN)
		ring(enemy.start_position, 0.4, Color(ORANGE, 0.5))
		var points := PackedVector2Array()
		for position: Vector3 in enemy.trace:
			points.append(screen(position))
		if points.size() > 1:
			draw_polyline(points, Color(ORANGE, 0.7), 2.0, true)
		if "debug_by_enemy" in arena.policy:
			var candidates: Array = arena.policy.debug_by_enemy.get(enemy.get_instance_id(), [])
			for candidate: Dictionary in candidates:
				var color := Color("70e6ff") if candidate.reason == "valid" else Color("e66b75", 0.65)
				draw_circle(screen(candidate.hide), 3.0, color)
				if candidate.reason == "valid":
					draw_line(screen(candidate.hide), screen(candidate.peek), color, 1.5)
					draw_circle(screen(candidate.peek), 3.0, color)
		var target := screen(enemy.destination)
		draw_line(target - Vector2(6, 0), target + Vector2(6, 0), YELLOW, 2.0)
		draw_line(target - Vector2(0, 6), target + Vector2(0, 6), YELLOW, 2.0)
		draw_dashed_line(screen(enemy.global_position), target, Color(YELLOW, 0.4), 1.0, 5.0)
