class_name InkRule
extends Control
## A thin ink rule, like the ones under a broadsheet masthead.

const INK := Color(0.15, 0.125, 0.10)

@export var lines: int = 1
@export var thickness := 2.0
@export var gap := 3.0


func _draw() -> void:
	var total := thickness * float(lines) + gap * float(lines - 1)
	var top := (size.y - total) * 0.5
	for index: int in lines:
		var y := top + thickness * 0.5 + float(index) * (thickness + gap)
		draw_line(Vector2(0.0, y), Vector2(size.x, y), INK, thickness)
