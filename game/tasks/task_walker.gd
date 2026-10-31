class_name TaskWalker
extends CharacterBody2D
## Placeholder walker for task demos. Arda offers the same `carried` field and "walker" group.

@export var speed: float = 420.0

var carried: String = ""


func _ready() -> void:
	add_to_group("walker")


func _physics_process(_delta: float) -> void:
	velocity = Input.get_vector("move_left", "move_right", "move_up", "move_down") * speed
	move_and_slide()
