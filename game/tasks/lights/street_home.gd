class_name StreetHome
extends Node2D
## The lit windows of one home on Ebru's night street. They can go dark.

const WINDOW_LIT := Color(1.0, 0.86, 0.6, 0.95)
const GLOW := Color(1.0, 0.8, 0.5, 0.2)
const GLOW_GROW := 18.0
## Multiplies the lit colour down to night. Tweening a polygon's own colour rebuilds its buffers
## every frame, which floods WebGL with errors.
const WINDOW_DARK := Color(0.1, 0.14, 0.33)
const GLOW_OFF := Color(1.0, 1.0, 1.0, 0.0)
const DARK_SECONDS := 0.7

var window_rects: Array[Rect2] = []

var _windows: Array[Polygon2D] = []
var _glows: Array[Polygon2D] = []
var _tween: Tween


func _ready() -> void:
	for rect: Rect2 in window_rects:
		var glow := _polygon(SalonZone.wobbly_rect(rect.grow(GLOW_GROW), 34.0), GLOW)
		_glows.append(glow)
		add_child(glow)
		var window := _polygon(SalonZone.wobbly_rect(rect, 26.0), WINDOW_LIT)
		_windows.append(window)
		add_child(window)


## The windows cool to night. Kill before recreate.
func go_dark() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	for window: Polygon2D in _windows:
		_tween.tween_property(window, "modulate", WINDOW_DARK, DARK_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	for glow: Polygon2D in _glows:
		_tween.tween_property(glow, "modulate", GLOW_OFF, DARK_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _polygon(points: PackedVector2Array, color: Color) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.polygon = points
	polygon.color = color
	return polygon
