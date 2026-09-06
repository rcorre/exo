extends CharacterBody3D

@export var max_health: int = 100

const VISION_RANGE := 15.0
const VISION_HALF_ANGLE_DEG := 50.0
const AGGRO_GAIN_TIME := 0.5
const AGGRO_DECAY_TIME := 10.0
const CHASE_SPEED := 3.0

const HEARING_RANGE := 12.0
const AUDIO_AGGRO_TIME := 3.0

var health: int
var aggro: float = 0.0
var is_chasing: bool = false

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	health = max_health

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	var player := _get_player()
	var can_see := player != null and _can_see_player(player)
	var audio_gain_rate := _audio_gain_rate(player) if player else 0.0

	if can_see:
		aggro = min(aggro + delta / AGGRO_GAIN_TIME, 1.0)
	elif audio_gain_rate > 0.0:
		aggro = min(aggro + audio_gain_rate * delta, 1.0)
	else:
		aggro = max(aggro - delta / AGGRO_DECAY_TIME, 0.0)

	if aggro >= 1.0:
		is_chasing = true
	elif aggro <= 0.0:
		is_chasing = false

	if is_chasing and player:
		_chase(player)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()

func _get_player() -> Node3D:
	return get_tree().get_first_node_in_group("player")

func _can_see_player(player: Node3D) -> bool:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()
	if distance > VISION_RANGE or distance < 0.001:
		return false

	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var angle_deg := rad_to_deg(forward.angle_to(to_player.normalized()))
	if angle_deg > VISION_HALF_ANGLE_DEG:
		return false

	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.9,
		player.global_position + Vector3.UP * 0.9
	)
	query.exclude = [self]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result.is_empty() or result.collider == player

func _audio_gain_rate(player: Node3D) -> float:
	var distance := global_position.distance_to(player.global_position)
	var distance_factor: float = clamp(1.0 - distance / HEARING_RANGE, 0.0, 1.0)

	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	var speed_factor: float = clamp(horizontal_speed / float(player.SPEED), 0.0, 1.0)

	return distance_factor * speed_factor / AUDIO_AGGRO_TIME

func _chase(player: Node3D) -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > 0.01:
		var direction := to_player.normalized()
		velocity.x = direction.x * CHASE_SPEED
		velocity.z = direction.z * CHASE_SPEED
		look_at(global_position + direction, Vector3.UP)

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		die()

func die() -> void:
	queue_free()
