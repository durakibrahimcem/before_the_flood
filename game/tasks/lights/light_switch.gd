class_name LightSwitch
extends Node2D
## One salon light switch, with a soft ring while the walker can reach it.

const PLATE_COLOR := Color(0.95, 0.93, 0.88)
const PLATE_EDGE := Color(0.55, 0.52, 0.48)
const NUB_COLOR := Color(0.78, 0.75, 0.7)
const RING_COLOR := Color(1.0, 0.92, 0.72, 0.75)

var zone_index: int = -1
var switch_texture: Texture2D
var flipped := false
var in_reach := false

var _sprite: Sprite2D


func setup(index: int, texture: Texture2D) -> void:
	zone_index = index
	switch_texture = texture


func _ready() -> void:
	if switch_texture == null:
		queue_redraw()
		return
	_sprite = Sprite2D.new()
	_sprite.texture = switch_texture
	add_child(_sprite)


## The ring only redraws when the state actually changes.
func set_in_reach(reach: bool) -> void:
	if in_reach == reach:
		return
	in_reach = reach
	queue_redraw()


func flip() -> void:
	flipped = true
	in_reach = false
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.07)
	tween.tween_property(self, "scale", Vector2.ONE, 0.14)


func _draw() -> void:
	if _sprite == null:
		var plate := Rect2(-16.0, -22.0, 32.0, 44.0)
		draw_rect(plate, PLATE_COLOR)
		draw_rect(plate, PLATE_EDGE, false, 2.0)
		var nub := Rect2(-6.0, -12.0, 12.0, 8.0)
		if flipped:
			nub = Rect2(-6.0, 4.0, 12.0, 8.0)
		draw_rect(nub, NUB_COLOR)
	if in_reach:
		draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 28, RING_COLOR, 3.0)
