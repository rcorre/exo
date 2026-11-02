extends CharacterBody3D
## Real physics/navigation actor shared by the runner and interactive lab.
## Deliberately omits combat/perception/animation: this isolates positioning.

const SPEED := 3.0
const PLAYER_SPEED := 6.0
const RADIUS := 0.4
const HEIGHT := 1.8
const ARRIVAL_DISTANCE := 0.15
const REPLAN_INTERVAL := 0.25

var actor_id := ""
var start_position := Vector3.ZERO
var destination := Vector3.ZERO
var active := false
var controlled := false
var is_player := false
var policy: RefCounted
var arena: Node3D
var replan_remaining := 0.0
var agent: NavigationAgent3D
var trace: Array[Vector3] = []

func _ready() -> void:
	collision_layer = 2
	collision_mask = 3
	var shape := CapsuleShape3D.new()
	shape.radius = RADIUS
	shape.height = HEIGHT
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = HEIGHT * 0.5
	add_child(collision)
	var mesh := CapsuleMesh.new()
	mesh.radius = RADIUS
	mesh.height = HEIGHT
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position.y = HEIGHT * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("54c8ef") if is_player else Color("ff9360")
	visual.material_override = material
	add_child(visual)
	var label := Label3D.new()
	label.text = "PLAYER" if is_player else actor_id
	label.position = Vector3(0, 2.5, -0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 48
	label.pixel_size = 0.015
	add_child(label)
	if not is_player:
		agent = NavigationAgent3D.new()
		agent.path_desired_distance = 0.25
		agent.target_desired_distance = ARRIVAL_DISTANCE
		add_child(agent)
	start_position = position
	destination = position
	trace.append(position)

func _physics_process(delta: float) -> void:
	if not active:
		return
	var direction := Vector3.ZERO
	if is_player:
		if controlled:
			var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
			direction = Vector3(input.x, 0.0, input.y)
	else:
		replan_remaining -= delta
		if replan_remaining <= 0.0:
			replan_remaining = REPLAN_INTERVAL
			var desired: Vector3 = policy.choose_destination(self, arena.player, arena)
			if not desired.is_finite():
				push_error("Policy returned a non-finite destination for " + actor_id)
				active = false
				return
			desired = NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), desired)
			if desired.distance_to(destination) > 0.05 or agent.target_position != destination:
				destination = desired
				agent.target_position = destination
		# Baked surfaces sit slightly above the physics floor. Arrival is measured
		# on XZ in this flat fixture, not against that voxel-height offset.
		var distance := Vector2(destination.x - global_position.x, destination.z - global_position.z).length()
		if distance > ARRIVAL_DISTANCE and not agent.is_navigation_finished():
			direction = agent.get_next_path_position() - global_position
			direction.y = 0.0
			direction = direction.normalized()
	var speed := PLAYER_SPEED if is_player else SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	if global_position.distance_to(trace[-1]) >= 0.2:
		trace.append(global_position)
		if trace.size() > 4096:
			trace.pop_front()
