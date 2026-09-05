extends Control

const LINE_LENGTH := 8.0
const LINE_THICKNESS := 2.0
const BASE_GAP := 4.0
const MAX_GAP := 26.0
const COLOR := Color(1, 1, 1, 0.85)

var spread_ratio: float = 0.0:
	set(value):
		spread_ratio = clamp(value, 0.0, 1.0)
		queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var gap: float = lerp(BASE_GAP, MAX_GAP, spread_ratio)

	draw_rect(Rect2(center.x - LINE_THICKNESS * 0.5, center.y - gap - LINE_LENGTH, LINE_THICKNESS, LINE_LENGTH), COLOR)
	draw_rect(Rect2(center.x - LINE_THICKNESS * 0.5, center.y + gap, LINE_THICKNESS, LINE_LENGTH), COLOR)
	draw_rect(Rect2(center.x - gap - LINE_LENGTH, center.y - LINE_THICKNESS * 0.5, LINE_LENGTH, LINE_THICKNESS), COLOR)
	draw_rect(Rect2(center.x + gap, center.y - LINE_THICKNESS * 0.5, LINE_LENGTH, LINE_THICKNESS), COLOR)
