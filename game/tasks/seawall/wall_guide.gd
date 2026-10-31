extends Node2D
## Crayon plan on the shore: dashed wall outline, plumb line and a soft shadow.
## The node sits at the wall's base and draws relative to that point.

const CRAYON := Color(0.55, 0.42, 0.28, 0.85)
const SHADOW := Color(0.02, 0.02, 0.05, 0.16)

@export var guide_texture: Texture2D

var _levels := 6
var _block_h := 96.0
var _half_w := 110.0
var _plumb_top := -692.0


func setup(levels: int, block_h: float, half_w: float, plumb_top_y: float) -> void:
	_levels = maxi(1, levels)
	_block_h = block_h
	_half_w = half_w
	_plumb_top = plumb_top_y - position.y
	queue_redraw()


func _draw() -> void:
	var top := -_levels * _block_h
	if guide_texture != null:
		draw_texture(guide_texture, Vector2(-guide_texture.get_width() * 0.5, -guide_texture.get_height()))
		return
	_dashed_line(Vector2(-_half_w, 0.0), Vector2(-_half_w, top))
	_dashed_line(Vector2(_half_w, 0.0), Vector2(_half_w, top))
	_dashed_line(Vector2(-_half_w, top), Vector2(_half_w, top))
	_dashed_line(Vector2(0.0, top - 10.0), Vector2(0.0, _plumb_top))
	_draw_shadow()


func _draw_shadow() -> void:
	draw_set_transform(Vector2(0.0, 8.0), 0.0, Vector2(1.0, 0.20))
	draw_circle(Vector2.ZERO, 150.0, SHADOW)
	draw_circle(Vector2.ZERO, 105.0, SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _dashed_line(from: Vector2, to: Vector2) -> void:
	var total := from.distance_to(to)
	var dir := (to - from).normalized()
	var travelled := 0.0
	while travelled < total:
		var seg := minf(22.0, total - travelled)
		var a := from + dir * travelled
		var wobble := Vector2(sin(travelled * 0.7) * 2.0, cos(travelled * 0.5) * 2.0)
		draw_line(a + wobble, a + dir * seg + wobble * 0.5, CRAYON, 3.0)
		travelled += 34.0
