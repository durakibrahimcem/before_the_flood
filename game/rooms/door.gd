extends Area2D
## Sends the walker to another room when touched.

@export var target_room: String = ""
@export var arrive_at: Vector2 = Vector2.ZERO


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("walker"):
		(get_parent() as Room).door_used.emit.call_deferred(target_room, arrive_at)
