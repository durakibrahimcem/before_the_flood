class_name SortHud
extends Control
## Small top-left readout: the sorted count and a slim crayon time bar.

const BAR_SIZE := Vector2(340.0, 14.0)
const BAR_TOP := 46.0
const BAR_BACK := Color(0.1, 0.1, 0.12, 0.45)
const BAR_FILL := Color(1.0, 0.78, 0.36)
const OUTLINE := Color(0.13, 0.11, 0.09)
const JITTER := 1.6
## Fixed seed so the wobble stays still between frames.
const WOBBLE_SEED := 7

var _fraction := 1.0
var _label: Label
var _edge: PackedVector2Array


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_label()
	_edge = _wobbly_rect(Rect2(Vector2(-3.0, BAR_TOP - 3.0), BAR_SIZE + Vector2(6.0, 6.0)))
	queue_redraw()


func update_state(correct: int, total: int, remaining: float) -> void:
	_fraction = clampf(remaining, 0.0, 1.0)
	_label.text = "Sorted %d / %d" % [correct, total]
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(0.0, BAR_TOP), BAR_SIZE), BAR_BACK)
	draw_rect(Rect2(Vector2(0.0, BAR_TOP), Vector2(BAR_SIZE.x * _fraction, BAR_SIZE.y)), BAR_FILL)
	draw_polyline(_edge, OUTLINE, 3.0)


func _build_label() -> void:
	_label = Label.new()
	_label.text = "Sorted 0 / 0"
	var settings := LabelSettings.new()
	settings.font_size = 26
	settings.font_color = Color.WHITE
	settings.outline_size = 8
	settings.outline_color = Color(0.13, 0.11, 0.09, 0.9)
	_label.label_settings = settings
	add_child(_label)


## A hand-drawn rectangle: a jittered loop around the rect, seeded once.
func _wobbly_rect(rect: Rect2) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = WOBBLE_SEED
	var corners: Array[Vector2] = [
		rect.position,
		Vector2(rect.position.x + rect.size.x, rect.position.y),
		rect.position + rect.size,
		Vector2(rect.position.x, rect.position.y + rect.size.y),
	]
	var points := PackedVector2Array()
	for i: int in corners.size():
		var from: Vector2 = corners[i]
		var to: Vector2 = corners[(i + 1) % corners.size()]
		for step: int in 5:
			var point := from.lerp(to, step / 5.0)
			points.append(point + Vector2(rng.randf_range(-JITTER, JITTER), rng.randf_range(-JITTER, JITTER)))
	points.append(points[0])
	return points
