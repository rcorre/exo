extends CharacterBody3D

@export var max_health: int = 100

const VISION_RANGE := 15.0
const VISION_HALF_ANGLE_DEG := 50.0
const AGGRO_GAIN_TIME := 0.5
const AGGRO_DECAY_TIME := 10.0
const CHASE_SPEED := 3.0
const MIN_CHASE_DISTANCE := 5.0

const HEARING_RANGE := 12.0
const AUDIO_AGGRO_TIME := 3.0

const DECISION_INTERVAL := 1.5
const STOP_DECISION_MIN_DIST := MIN_CHASE_DISTANCE
const STOP_DECISION_MAX_DIST := 10.0

const FIRE_RANGE := 20.0
const FIRE_DAMAGE := 10
const FIRE_COOLDOWN := 1.2
const BASE_SPREAD_DEG := 6.0
const MAX_SPREAD_DEG := 16.0
const FIRE_BLOOM_DEG := 4.0
const BLOOM_DECAY_DEG := 8.0

const HIT_STATES := [&"HitChest", &"HitHead"]
const HIT_CLIPS := {&"HitChest": &"Hit_Chest", &"HitHead": &"Hit_Head"}

var health: int
var aggro: float = 0.0
var is_chasing: bool = false
var is_stopped: bool = false
var is_dead: bool = false
var is_playing_reaction: bool = false
var decision_timer: float = 0.0
var fire_cooldown_remaining: float = 0.0
var recoil_bloom_deg: float = 0.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var debug_label: Label3D = $DebugLabel
@onready var animation_player: AnimationPlayer = $Model/AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var playback: AnimationNodeStateMachinePlayback = animation_tree["parameters/playback"]

func _ready() -> void:
	health = max_health
	playback.start(&"Idle")

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
		_update_combat_decision(player, can_see, delta)
		if is_stopped and can_see:
			velocity.x = 0.0
			velocity.z = 0.0
			_aim_at(player)
			_update_fire(player, delta)
		else:
			_chase(player)
	else:
		is_stopped = false
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()

	_update_debug_label()
	_update_locomotion_animation(can_see)

# Crouch state exists in the AnimationTree state machine but nothing travels
# to it yet, since enemies have no crouch/take-cover behavior (matches the
# player, which also has no crouch behavior yet per player.gd).
func _update_locomotion_animation(can_see: bool) -> void:
	if is_playing_reaction:
		return
	if not is_chasing:
		playback.travel(&"Idle")
	elif is_stopped and can_see:
		playback.travel(&"Aim")
	else:
		playback.travel(&"Move")

# AnimationNodeStateMachineTransition's "Auto" advance mode fires as soon as
# a transition becomes current, not when the source clip finishes playing -
# so one-shot reactions (shoot, hit) travel back to their base state from
# here, timed off the real clip length, instead of relying on the graph.
func _play_reaction(state: StringName, clip: StringName, return_state: StringName) -> void:
	is_playing_reaction = true
	playback.travel(state)
	await get_tree().create_timer(animation_player.get_animation(clip).length).timeout
	is_playing_reaction = false
	if not is_dead:
		playback.travel(return_state)

func _update_combat_decision(player: Node3D, can_see: bool, delta: float) -> void:
	decision_timer -= delta
	if decision_timer > 0.0:
		return
	decision_timer = DECISION_INTERVAL

	if not can_see:
		is_stopped = false
		return

	var distance := global_position.distance_to(player.global_position)
	var stop_chance: float = clamp(
		1.0 - (distance - STOP_DECISION_MIN_DIST) / (STOP_DECISION_MAX_DIST - STOP_DECISION_MIN_DIST),
		0.0, 1.0
	)
	is_stopped = randf() < stop_chance

func _update_fire(player: Node3D, delta: float) -> void:
	recoil_bloom_deg = move_toward(recoil_bloom_deg, 0.0, BLOOM_DECAY_DEG * delta)
	fire_cooldown_remaining = max(fire_cooldown_remaining - delta, 0.0)
	if fire_cooldown_remaining <= 0.0:
		_fire(player)
		fire_cooldown_remaining = FIRE_COOLDOWN

func _aim_at(player: Node3D) -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > 0.01:
		look_at(global_position + to_player.normalized(), Vector3.UP)

func _fire(player: Node3D) -> void:
	_play_reaction(&"Shoot", &"Pistol_Shoot", &"Aim")

	var eye_pos := global_position + Vector3.UP * 1.5
	var target_pos := player.global_position + Vector3.UP * 0.9
	var forward := (target_pos - eye_pos).normalized()

	var right := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	var up := right.cross(forward).normalized()

	var spread_rad := deg_to_rad(_current_spread_deg())
	var angle := randf() * TAU
	var radius := sqrt(randf()) * tan(spread_rad)
	var direction := (forward + right * radius * cos(angle) + up * radius * sin(angle)).normalized()

	recoil_bloom_deg = min(recoil_bloom_deg + FIRE_BLOOM_DEG, MAX_SPREAD_DEG)

	var to := eye_pos + direction * FIRE_RANGE
	var query := PhysicsRayQueryParameters3D.create(eye_pos, to)
	query.exclude = [self]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result and result.collider.has_method("take_damage"):
		result.collider.take_damage(FIRE_DAMAGE)

func _current_spread_deg() -> float:
	return clamp(BASE_SPREAD_DEG + recoil_bloom_deg, 0.0, MAX_SPREAD_DEG)

func _update_debug_label() -> void:
	var has_something_to_show := health < max_health or aggro > 0.0
	debug_label.visible = DebugFlags.enabled and has_something_to_show
	if debug_label.visible:
		var state := "STOPPED" if is_stopped else "CHASING" if is_chasing else "IDLE"
		debug_label.text = "HP %d/%d\nAggro %d%%\n%s" % [health, max_health, roundi(aggro * 100), state]

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
	var distance := to_player.length()
	if distance > 0.01:
		var direction := to_player.normalized()
		look_at(global_position + direction, Vector3.UP)
		if distance > MIN_CHASE_DISTANCE:
			velocity.x = direction.x * CHASE_SPEED
			velocity.z = direction.z * CHASE_SPEED
		else:
			velocity.x = 0.0
			velocity.z = 0.0

func take_damage(amount: int) -> void:
	if is_dead:
		return
	health -= amount
	if health <= 0:
		die()
	else:
		var hit_state: StringName = HIT_STATES.pick_random()
		_play_reaction(hit_state, HIT_CLIPS[hit_state], &"Idle")

func die() -> void:
	is_dead = true
	set_physics_process(false)
	playback.travel(&"Death")
	await get_tree().create_timer(animation_player.get_animation(&"Death01").length).timeout
	queue_free()
