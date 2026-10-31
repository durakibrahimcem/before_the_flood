class_name SalonZone
extends Node2D
## One lit corner of the salon: a warm window, a soft floor glow, and the dim that lands when it is switched off.

const WINDOW_COLOR := Color(1.0, 0.82, 0.5, 0.9)
const GLOW_COLOR := Color(1.0, 0.82, 0.5, 0.16)
const DIM_COLOR := Color(0.04, 0.05, 0.12, 0.72)
const DIM_SECONDS := 0.55
## Fixed per-vertex offsets, so the crayon wobble never changes between runs.
const WOBBLE := [0.0, 1.6, -1.2, 0.8, -1.5, 1.1, -0.7, 1.3, -1.0, 0.6, -1.4, 0.9]

var zone: Rect2
var window_rect: Rect2

var _glow: Polygon2D
var _window: Polygon2D
var _dim: Polygon2D
var _tween: Tween


func setup(zone_rect: Rect2, lit_window: Rect2) -> void:
	zone = zone_rect
	window_rect = lit_window


func _ready() -> void:
	_glow = Polygon2D.new()
	_glow.polygon = wobbly_rect(window_rect.grow_individual(70, 40, 70, 150), 44.0)
	_glow.color = GLOW_COLOR
	add_child(_glow)
	_window = Polygon2D.new()
	_window.polygon = wobbly_rect(window_rect, 36.0)
	_window.color = WINDOW_COLOR
	add_child(_window)
	_dim = Polygon2D.new()
	_dim.polygon = wobbly_rect(zone, 64.0)
	_dim.color = Color(DIM_COLOR.r, DIM_COLOR.g, DIM_COLOR.b, 0.0)
	add_child(_dim)


## One tween for the whole dim, so the property is never tweened twice.
func dim() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_window, "color:a", 0.0, DIM_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_glow, "color:a", 0.0, DIM_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_dim, "color:a", DIM_COLOR.a, DIM_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


## A rectangle with slightly wobbly edges, as one closed loop of points.
static func wobbly_rect(rect: Rect2, step: float) -> PackedVector2Array:
	var corners: Array[Vector2] = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	var points := PackedVector2Array()
	for side: int in corners.size():
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % corners.size()]
		var segments := maxi(2, int(a.distance_to(b) / step))
		var normal := (b - a).normalized().orthogonal()
		for s: int in segments:
			var wobble: float = WOBBLE[(side * 5 + s) % WOBBLE.size()]
			points.append(a.lerp(b, float(s) / float(segments)) + normal * wobble)
	return points
