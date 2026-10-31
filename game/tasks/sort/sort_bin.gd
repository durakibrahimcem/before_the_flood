class_name SortBin
extends Area2D
## The touch area of one of Ebru's painted bins. It reports walker touches, the task keeps the rules.

signal touched(body: Node2D)

const GROUP := "sort_bin"

## One of plastic, paper, glass, metal.
@export var kind: String = "plastic"


func _ready() -> void:
	monitoring = true
	add_to_group(GROUP)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("walker"):
		touched.emit(body)
