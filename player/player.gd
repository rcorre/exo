extends CharacterBody3D

@export var max_health: int = 100

const SPEED := 6.0
const ACCEL := 20.0
const DECEL := 35.0
const MOUSE_SENSITIVITY := 0.003
const PITCH_LIMIT := deg_to_rad(89.0)
const CROUCH_HEIGHT_MULT := 0.5
const CROUCH_SPEED_MULT := 0.5
const CROUCH_TRANSITION_SPEED := 8.0
const AIM_SPEED_MULT := 0.5
const AIM_SPREAD_MULT := 0.4
const AIM_ZOOM_MULT := 1.25
const AIM_TRANSITION_SPEED := 5.0
const SPRINT_SPEED_MULT := 2.0
const SPRINT_RAMP_SPEED := 1.5
const SPRINT_LOCKOUT_TIME := 0.4
const SPRINT_BOB_FREQUENCY := 14.0
const SPRINT_BOB_AMPLITUDE := 0.05
const RETICLE_FADE_SPEED := 4.0
const FIRE_RANGE := 100.0
const FIRE_DAMAGE := 25

const BASE_SPREAD_DEG := 3.0
const MAX_SPREAD_DEG := 8.0
const MOVE_BLOOM_DEG := 4.0
const FIRE_BLOOM_DEG := 3.0
const BLOOM_DECAY_DEG := 6.0

const BULLET_TRAIL_SCENE := preload("res://weapons/bullet_trail.tscn")

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var reticle: Control = $HUD/Reticle
@onready var health_label: Label = $HUD/HealthLabel

var health: int
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var recoil_bloom_deg: float = 0.0
var is_crouched: bool = false
var is_aiming: bool = false
var aim_progress: float = 0.0
var is_sprinting: bool = false
var sprint_progress: float = 0.0
var sprint_lockout_remaining: float = 0.0
var is_dead: bool = false

var _stand_head_y: float
var _base_fov: float
var _reticle_alpha: float = 1.0
var _bob_phase: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_stand_head_y = head.position.y
	_base_fov = camera.fov
	health = max_health
	_update_health_label()

func take_damage(amount: int) -> void:
	if is_dead:
		return
	health = max(health - amount, 0)
	_update_health_label()
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_health_label()

func _update_health_label() -> void:
	health_label.text = "HP %d/%d" % [health, max_health] if not is_dead else "YOU DIED"

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("crouch"):
		is_crouched = not is_crouched
	elif event.is_action_pressed("sprint"):
		is_sprinting = not is_sprinting
		if is_sprinting:
			is_aiming = false
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.is_action_pressed("fire"):
			if _can_aim_or_fire():
				_fire()
		elif event.is_action_pressed("aim"):
			if _can_aim_or_fire():
				is_aiming = not is_aiming

func _can_aim_or_fire() -> bool:
	return not is_sprinting and sprint_lockout_remaining <= 0.0

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
	var spread_deg := BASE_SPREAD_DEG + move_bloom + recoil_bloom_deg
	spread_deg *= lerp(1.0, AIM_SPREAD_MULT, aim_progress)
	return clamp(spread_deg, 0.0, MAX_SPREAD_DEG)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var speed := SPEED
	if is_crouched:
		speed *= CROUCH_SPEED_MULT
	if is_aiming:
		speed *= AIM_SPEED_MULT
	speed *= lerp(1.0, SPRINT_SPEED_MULT, sprint_progress)
	var target_velocity := direction * speed
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var accel_rate := ACCEL if direction.length_squared() > 0.0 else DECEL
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, accel_rate * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	move_and_slide()

	var target_head_y := _stand_head_y * CROUCH_HEIGHT_MULT if is_crouched else _stand_head_y
	head.position.y = move_toward(head.position.y, target_head_y, CROUCH_TRANSITION_SPEED * delta)

	aim_progress = move_toward(aim_progress, 1.0 if is_aiming else 0.0, AIM_TRANSITION_SPEED * delta)
	camera.fov = lerp(_base_fov, _base_fov / AIM_ZOOM_MULT, aim_progress)

	sprint_progress = move_toward(sprint_progress, 1.0 if is_sprinting else 0.0, SPRINT_RAMP_SPEED * delta)
	sprint_lockout_remaining = SPRINT_LOCKOUT_TIME if is_sprinting else max(sprint_lockout_remaining - delta, 0.0)

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > 0.01:
		_bob_phase += SPRINT_BOB_FREQUENCY * delta
	else:
		_bob_phase = 0.0
	camera.position.y = sin(_bob_phase) * SPRINT_BOB_AMPLITUDE * sprint_progress

	var reticle_target_alpha := 0.0 if not _can_aim_or_fire() else 1.0
	_reticle_alpha = move_toward(_reticle_alpha, reticle_target_alpha, RETICLE_FADE_SPEED * delta)
	reticle.modulate.a = _reticle_alpha

	recoil_bloom_deg = move_toward(recoil_bloom_deg, 0.0, BLOOM_DECAY_DEG * delta)
	reticle.spread_ratio = _current_spread_deg() / MAX_SPREAD_DEG
