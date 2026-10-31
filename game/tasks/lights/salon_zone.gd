class_name SalonZone
extends Node2D
## One light left on in the salon, as a warm additive glow over the night tint.

const WARM := Color(1.0, 0.8, 0.52)
const GLOW_ALPHA := 0.34
const LAMP_ALPHA := 0.5
const DIM_SECONDS := 0.55
const SOFT_CIRCLE_SIZE := 256
## Fixed per-vertex offsets, so the crayon wobble never changes between runs.
const WOBBLE := [0.0, 1.6, -1.2, 0.8, -1.5, 1.1, -0.7, 1.3, -1.0, 0.6, -1.4, 0.9]

var glow_size: Vector2
var is_lamp := false

var _glow: Sprite2D
var _tween: Tween


func setup(center: Vector2, size: Vector2, lamp: bool) -> void:
	position = center
	glow_size = size
	is_lamp = lamp


func _ready() -> void:
	_glow = Sprite2D.new()
	_glow.texture = _soft_circle()
	_glow.scale = glow_size / SOFT_CIRCLE_SIZE
	_glow.modulate = Color(WARM, LAMP_ALPHA if is_lamp else GLOW_ALPHA)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = additive
	add_child(_glow)


## One tween for the whole dim, so the property is never tweened twice.
func dim() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_glow, "modulate:a", 0.0, DIM_SECONDS)


func _soft_circle() -> GradientTexture2D:
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var circle := GradientTexture2D.new()
	circle.gradient = fade
	circle.width = SOFT_CIRCLE_SIZE
	circle.height = SOFT_CIRCLE_SIZE
	circle.fill = GradientTexture2D.FILL_RADIAL
	circle.fill_from = Vector2(0.5, 0.5)
	circle.fill_to = Vector2(1.0, 0.5)
	return circle


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
