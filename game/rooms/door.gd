extends Area2D
## Sends the walker to another room when touched.

## Arda's physics body reaches its new spot a step after a room change. Until then it still
## sits at the old room's coordinates, where it could touch a door here by accident.
const SETTLE_STEPS := 2

@export var target_room: String = ""
@export var arrive_at: Vector2 = Vector2.ZERO

var _settling := SETTLE_STEPS


func _ready() -> void:
	monitoring = false
	body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	_settling -= 1
	if _settling == 0:
		monitoring = true
		set_physics_process(false)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("walker"):
		(get_parent() as Room).door_used.emit(target_room, arrive_at)
