extends RefCounted
## Portable visual artifacts from actual trajectories; no renderer required.

const Scenario := preload("res://tests/positioning/scenario.gd")
const SCALE := 28.0
const ORIGIN := Vector2(380, 365)

static func save(directory: String, stem: String, data: Dictionary, result: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("Cannot create report directory: " + directory)
		return false
	var json := FileAccess.open(directory.path_join(stem + ".json"), FileAccess.WRITE)
	var svg := FileAccess.open(directory.path_join(stem + ".svg"), FileAccess.WRITE)
	if json == null or svg == null:
		push_error("Cannot write positioning reports to " + directory)
		return false
	json.store_string(JSON.stringify(result, "\t") + "\n")
	svg.store_string(render_svg(data, result))
	return true

static func project(point: Array) -> Vector2:
	return ORIGIN + Vector2(point[0], point[1]) * SCALE

static func circle(at: Array, radius: float, color: String, fill: String = "none") -> String:
	var p := project(at)
	return '<circle cx="%.2f" cy="%.2f" r="%.2f" stroke="%s" fill="%s" stroke-width="2"/>' % [p.x, p.y, radius * SCALE, color, fill]

static func text(at: Vector2, value: String, color: String = "white") -> String:
	return '<text x="%.2f" y="%.2f" fill="%s" font-family="sans-serif" font-size="15">%s</text>' % [at.x, at.y, color, value.xml_escape()]

static func render_svg(data: Dictionary, result: Dictionary) -> String:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="760" height="700" viewBox="0 0 760 700">'
	svg += '<rect width="760" height="700" fill="#202934"/>'
	svg += text(Vector2(20, 27), ("PASS: " if result.passed else "FAIL: ") + str(data.name))
	svg += text(Vector2(20, 51), "Cyan: player | Orange: actual paths/endpoints | Green rings: expected")
	svg += text(Vector2(20, 73), "Hollow orange: starts | Yellow: chosen targets | +X right, +Z down")
	var corner := project([-12, -10])
	svg += '<rect x="%f" y="%f" width="672" height="560" fill="#303b49" stroke="#617087"/>' % [corner.x, corner.y]
	for x in range(-12, 13, 2):
		var a := project([x, -10])
		var b := project([x, 10])
		svg += '<path d="M %f %f L %f %f" stroke="#3d4856"/>' % [a.x, a.y, b.x, b.y]
	for z in range(-10, 11, 2):
		var a := project([-12, z])
		var b := project([12, z])
		svg += '<path d="M %f %f L %f %f" stroke="#3d4856"/>' % [a.x, a.y, b.x, b.y]
	for obstacle: Dictionary in data.get("obstacles", []):
		var p := project(obstacle.center)
		var w := float(obstacle.size[0]) * SCALE
		var h := float(obstacle.size[2]) * SCALE
		svg += '<rect x="%f" y="%f" width="%f" height="%f" fill="#8c8273" transform="rotate(%f %f %f)"/>' % [p.x - w / 2, p.y - h / 2, w, h, -float(obstacle.get("yaw_degrees", 0)), p.x, p.y]
	for index in result.enemies.size():
		var enemy: Dictionary = result.enemies[index]
		for region: Dictionary in enemy.expected:
			svg += circle(region.center, region.radius, "#7aee9a")
		var points := ""
		for at: Array in enemy.trace:
			var p := project(at)
			points += "%f,%f " % [p.x, p.y]
		svg += '<polyline points="%s" fill="none" stroke="#ff9360" stroke-width="2"/>' % points
		svg += circle(data.enemies[index].start, 0.4, "#ff9360")
		svg += circle(enemy.destination, 0.23, "#ffdf70")
		svg += circle(enemy.position, 0.35, "#ff9360", "#ff9360")
		svg += text(project(enemy.position) + Vector2(12, -12), str(enemy.id) + (" PASS" if enemy.passed else " FAIL"))
	svg += circle(data.player, 0.4, "#54c8ef")
	svg += circle(result.player, 0.4, "#54c8ef", "#54c8ef")
	svg += text(Vector2(20, 680), "%.2fs / %d physics ticks — %s" % [result.seconds, result.ticks, result.policy])
	return svg + "</svg>\n"
