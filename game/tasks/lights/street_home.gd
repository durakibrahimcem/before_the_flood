class_name StreetHome
extends Node2D
## One home on the night street, with two warm windows that can go dark.

const BODY_COLOR := Color(0.3, 0.28, 0.34)
const ROOF_COLOR := Color(0.22, 0.2, 0.28)
const DOOR_COLOR := Color(0.15, 0.13, 0.19)
const WINDOW_LIT := Color(1.0, 0.86, 0.6, 0.95)
const WINDOW_DARK := Color(0.1, 0.12, 0.2, 0.95)
const DARK_SECONDS := 0.7
const WINDOW_RECTS: Array[Rect2] = [
	Rect2(-134, -244, 66, 58),
	Rect2(68, -244, 66, 58),
]

@export var home_texture: Texture2D

var _body: Node2D
var _windows: Array[Polygon2D] = []
var _tween: Tween


func _ready() -> void:
	if home_texture != null:
		var sprite := Sprite2D.new()
		sprite.texture = home_texture
		sprite.centered = false
		sprite.offset = -Vector2(float(home_texture.get_width()) / 2.0, float(home_texture.get_height()))
		_body = sprite
		add_child(_body)
	else:
		_body = _polygon(PackedVector2Array([
			Vector2(-172, 0), Vector2(168, -2), Vector2(164, -282), Vector2(-166, -278),
		]), BODY_COLOR)
		add_child(_body)
		add_child(_polygon(PackedVector2Array([
			Vector2(-212, -276), Vector2(208, -278), Vector2(6, -424),
		]), ROOF_COLOR))
		add_child(_polygon(PackedVector2Array([
			Vector2(-28, 0), Vector2(28, 0), Vector2(24, -98), Vector2(-24, -96),
		]), DOOR_COLOR))
	for rect: Rect2 in WINDOW_RECTS:
		var window := _polygon(SalonZone.wobbly_rect(rect, 26.0), WINDOW_LIT)
		_windows.append(window)
		add_child(window)


## The windows cool to night, and the body dims a little. Kill before recreate.
func go_dark() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	for window: Polygon2D in _windows:
		_tween.tween_property(window, "color", WINDOW_DARK, DARK_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_body, "modulate", Color(0.8, 0.8, 0.86), DARK_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _polygon(points: PackedVector2Array, color: Color) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.polygon = points
	polygon.color = color
	return polygon
