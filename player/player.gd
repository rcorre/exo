extends CharacterBody3D

const SPEED := 6.0
const ACCEL := 20.0
const DECEL := 35.0
const MOUSE_SENSITIVITY := 0.003
const PITCH_LIMIT := deg_to_rad(89.0)
const CROUCH_HEIGHT_MULT := 0.5
const CROUCH_SPEED_MULT := 0.5
const CROUCH_TRANSITION_SPEED := 8.0
const FIRE_RANGE := 100.0
const FIRE_DAMAGE := 25

const BASE_SPREAD_DEG := 0.5
const MAX_SPREAD_DEG := 8.0
const MOVE_BLOOM_DEG := 4.0
const FIRE_BLOOM_DEG := 3.0
const BLOOM_DECAY_DEG := 6.0

const BULLET_TRAIL_SCENE := preload("res://weapons/bullet_trail.tscn")

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var reticle: Control = $HUD/Reticle

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var recoil_bloom_deg: float = 0.0
var is_crouched: bool = false

var _stand_head_y: float

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_stand_head_y = head.position.y

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("crouch"):
		is_crouched = not is_crouched
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.is_action_pressed("fire"):
			_fire()

func _fire() -> void:
	var basis := camera.global_transform.basis
	var forward := -basis.z

	var spread_rad := deg_to_rad(_current_spread_deg())
	var angle := randf() * TAU
	var radius := sqrt(randf()) * tan(spread_rad)
	var direction := (forward + basis.x * radius * cos(angle) + basis.y * radius * sin(angle)).normalized()

	recoil_bloom_deg = min(recoil_bloom_deg + FIRE_BLOOM_DEG, MAX_SPREAD_DEG)

	var from := camera.global_transform.origin
	var to := from + direction * FIRE_RANGE

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var hit_point := to
	if result:
		hit_point = result.position
		if result.collider.has_method("take_damage"):
			result.collider.take_damage(FIRE_DAMAGE)

	_spawn_trail(from, hit_point)

func _spawn_trail(from: Vector3, to: Vector3) -> void:
	var trail := BULLET_TRAIL_SCENE.instantiate()
	get_tree().current_scene.add_child(trail)
	trail.setup(from, to)

func _current_spread_deg() -> float:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var move_bloom: float = MOVE_BLOOM_DEG * clamp(horizontal_speed / SPEED, 0.0, 1.0)
	return clamp(BASE_SPREAD_DEG + move_bloom + recoil_bloom_deg, BASE_SPREAD_DEG, MAX_SPREAD_DEG)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var speed := SPEED * CROUCH_SPEED_MULT if is_crouched else SPEED
	var target_velocity := direction * speed
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var accel_rate := ACCEL if direction.length_squared() > 0.0 else DECEL
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, accel_rate * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	move_and_slide()

	var target_head_y := _stand_head_y * CROUCH_HEIGHT_MULT if is_crouched else _stand_head_y
	head.position.y = move_toward(head.position.y, target_head_y, CROUCH_TRANSITION_SPEED * delta)

	recoil_bloom_deg = move_toward(recoil_bloom_deg, 0.0, BLOOM_DECAY_DEG * delta)
	reticle.spread_ratio = (_current_spread_deg() - BASE_SPREAD_DEG) / (MAX_SPREAD_DEG - BASE_SPREAD_DEG)
