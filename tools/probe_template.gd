extends SceneTree
# Starter for one-off gameplay probes: loads a scene, drives it with real
# physics frames and real input actions, and prints state for inspection.
# Copy this file (don't edit in place) when writing a new probe, e.g.:
#   cp tools/probe_template.gd /tmp/probe_foo.gd && tools/check.sh /tmp/probe_foo.gd
#
# Gotchas learned the hard way:
# - Node3D.look_at(target, up) points -Z at target. Do NOT pass a third
#   `use_model_front=true` arg unless you mean +Z forward (it flips the
#   result 180 degrees and produces a confident, wrong observation).
# - When a probe claims something is "broken", add a positive control
#   (a case expected to succeed with obviously-correct setup) in the same
#   run. A probe that never demonstrates the passing case can't be trusted
#   to have exercised the failing one correctly either.
# - Godot exits 0 on most runtime script errors. Always run probes through
#   tools/check.sh, not `godot --headless --script` directly, so an engine
#   error in the probe itself doesn't get read as "no output == fine".

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var arena: Node = load("res://world/test_arena.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await physics_frame

	var player: CharacterBody3D = arena.get_node("Player")
	var enemy: StaticBody3D = arena.get_node("Enemy")
	var camera: Camera3D = player.get_node("Head/Camera3D")

	# Positive control: aim directly at the enemy with the correct forward
	# axis and confirm a hit lands before testing anything else.
	camera.look_at(enemy.global_position, Vector3.UP)
	seed(1)
	player._fire()
	await physics_frame
	print("control shot (aimed): enemy health = ", enemy.health, " (expect 75)")

	# --- add probe-specific steps below ---

	quit(0)
