extends RefCounted
## Single experimental peek cycle. The caller owns selection, movement and firing.
## A changed or invalid selection immediately cancels the old cycle.

const ARRIVAL_DISTANCE := 0.32
const HOLD_SECONDS := 0.6

enum State { IDLE, APPROACH, HOLD, PEEK, RETURN, COMPLETE }
var state := State.IDLE
var selection: Dictionary = {}
var hold_remaining := 0.0
var fire_requested := false

func step(choice: Dictionary, position: Vector3, delta: float) -> Vector3:
	fire_requested = false
	if choice.is_empty():
		selection = {}
		state = State.IDLE
		return position
	if selection.is_empty() or not _same_choice(choice, selection):
		selection = choice.duplicate(true)
		state = State.APPROACH
		hold_remaining = HOLD_SECONDS
	if state == State.APPROACH and _arrived(position, selection.hide):
		if selection.kind == "partial":
			state = State.COMPLETE
		else:
			state = State.HOLD
	if state == State.HOLD:
		hold_remaining -= delta
		if hold_remaining <= 0.0:
			state = State.PEEK
	if state == State.PEEK and _arrived(position, selection.peek):
		fire_requested = true
		state = State.RETURN
	if state == State.RETURN and _arrived(position, selection.hide):
		state = State.COMPLETE
	return selection.peek if state == State.PEEK else selection.hide

func _arrived(position: Vector3, target: Vector3) -> bool:
	return Vector2(position.x - target.x, position.z - target.z).length() <= ARRIVAL_DISTANCE

func _same_choice(a: Dictionary, b: Dictionary) -> bool:
	return a.kind == b.kind and a.hide.distance_to(b.hide) < 0.01 and a.peek.distance_to(b.peek) < 0.01
