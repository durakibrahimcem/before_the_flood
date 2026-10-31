extends Node2D
## The crane: rail, support ties, trolley and chains. The task drives the carriage x.

const RAIL_LEFT := 120.0
const RAIL_RIGHT := 1800.0
const RAIL_Y := 150.0
const HANG_TOP_Y := RAIL_Y + 55.0
const STEEL := Color(0.36, 0.34, 0.32)
const STEEL_DARK := Color(0.26, 0.25, 0.24)
const CHAIN := Color(0.30, 0.29, 0.27)

@export var rail_texture: Texture2D
@export var trolley_texture: Texture2D

var _carriage_x := 170.0


func set_carriage_x(x: float) -> void:
	_carriage_x = x
	queue_redraw()


## Where a hanging block's top edge hangs from, whatever its height.
func hang_top_y() -> float:
	return HANG_TOP_Y


## The rail beam's lower edge, in scene coordinates.
func rail_bottom_y() -> float:
	return RAIL_Y + 8.0


func _draw() -> void:
	_draw_rail()
	_draw_trolley()


func _draw_rail() -> void:
	if rail_texture != null:
		draw_texture(rail_texture, Vector2(RAIL_LEFT, RAIL_Y - rail_texture.get_height() * 0.5))
		return
	draw_rect(Rect2(RAIL_LEFT, RAIL_Y - 8.0, RAIL_RIGHT - RAIL_LEFT, 16.0), STEEL)
	var x := RAIL_LEFT + 60.0
	while x < RAIL_RIGHT:
		draw_line(Vector2(x, RAIL_Y - 8.0), Vector2(x + 12.0, -6.0), STEEL, 5.0)
		x += 240.0


func _draw_trolley() -> void:
	var cx := _carriage_x
	if trolley_texture != null:
		draw_texture(trolley_texture, Vector2(cx - trolley_texture.get_width() * 0.5, RAIL_Y + 26.0 - trolley_texture.get_height() * 0.5))
		return
	draw_rect(Rect2(cx - 44.0, 160.0, 88.0, 34.0), STEEL_DARK)
	draw_circle(Vector2(cx - 22.0, 158.0), 6.0, STEEL)
	draw_circle(Vector2(cx + 22.0, 158.0), 6.0, STEEL)
	draw_line(Vector2(cx - 26.0, 194.0), Vector2(cx - 32.0, HANG_TOP_Y), CHAIN, 3.0)
	draw_line(Vector2(cx + 26.0, 194.0), Vector2(cx + 32.0, HANG_TOP_Y), CHAIN, 3.0)
