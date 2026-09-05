extends CharacterBody3D

const SPEED := 6.0
const ACCEL := 20.0
const DECEL := 35.0
const MOUSE_SENSITIVITY := 0.003
const PITCH_LIMIT := deg_to_rad(89.0)
const FIRE_RANGE := 100.0
const FIRE_DAMAGE := 25

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.is_action_pressed("fire"):
			_fire()

func _fire() -> void:
	var from := camera.global_transform.origin
	var to := from + camera.global_transform.basis * Vector3(0.0, 0.0, -FIRE_RANGE)

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result and result.collider.has_method("take_damage"):
		result.collider.take_damage(FIRE_DAMAGE)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var target_velocity := direction * SPEED
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var accel_rate := ACCEL if direction.length_squared() > 0.0 else DECEL
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, accel_rate * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	move_and_slide()
