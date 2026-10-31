class_name WalkerBody
extends Node2D
## Placeholder crayon figure for a task-spawned walker. Arda brings her own art.

const OUTLINE := Color(0.13, 0.11, 0.09)
const SKIN := Color(1.0, 0.85, 0.7)
const SHIRT := Color(0.85, 0.48, 0.3)
const LEGS := Color(0.2, 0.16, 0.12)


func _draw() -> void:
	draw_line(Vector2(-5.0, 12.0), Vector2(-5.0, 27.0), LEGS, 5.0)
	draw_line(Vector2(5.0, 12.0), Vector2(5.0, 27.0), LEGS, 5.0)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-10, -12), Vector2(10, -12), Vector2(10, 14), Vector2(-10, 14),
		]), SHIRT)
	draw_polyline(
		PackedVector2Array([
			Vector2(-10, -12), Vector2(10, -12), Vector2(10, 14), Vector2(-10, 14),
			Vector2(-10, -12),
		]), OUTLINE, 2.5)
	draw_circle(Vector2(0.0, -22.0), 10.0, SKIN)
	draw_arc(Vector2(0.0, -22.0), 10.0, 0.0, TAU, 24, OUTLINE, 2.5)
