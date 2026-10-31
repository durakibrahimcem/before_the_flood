class_name SortItem
extends Area2D
## A piece of Ebru's waste to carry. A dumb node: it only reports walker touches.

signal touched(body: Node2D)

const ART_SCALE := 0.7

## One of plastic, paper, glass, metal.
@export var kind: String = "plastic"
@export var art: Texture2D

var flipped := false


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	var sprite := Sprite2D.new()
	sprite.texture = art
	sprite.scale = Vector2.ONE * ART_SCALE
	sprite.flip_h = flipped
	add_child(sprite)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("walker"):
		touched.emit(body)
