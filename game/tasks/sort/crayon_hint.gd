class_name CrayonHint
extends Control
## One short crayon hint line, shown by the task and faded by hand or by time.

const HOLD_SECONDS := 4.0
const FADE_SECONDS := 0.5
const QUICK_FADE_SECONDS := 0.25
const TILT_DEG := -2.0
const UNDERLINE_SEED := 13

@export var line: String = "Carry each thing to its bin."

var _tween: Tween
var _underline: PackedVector2Array


func _ready() -> void:
	rotation_degrees = TILT_DEG
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_line()
	hide()


func show_hint() -> void:
	_kill_tween()
	modulate.a = 1.0
	show()
	_tween = create_tween()
	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(hide)


func fade_out() -> void:
	if not visible:
		return
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, QUICK_FADE_SECONDS)
	_tween.tween_callback(hide)


func _build_line() -> void:
	var label := Label.new()
	label.text = line
	var settings := LabelSettings.new()
	settings.font_size = 34
	settings.font_color = Color.WHITE
	settings.outline_size = 10
	settings.outline_color = Color(0.13, 0.11, 0.09, 0.9)
	label.label_settings = settings
	add_child(label)
	label.reset_size()
	var width := maxf(label.size.x, 220.0)
	label.position = Vector2(-width / 2.0, -44.0)
	_underline = _wobbly_line(Vector2(-width / 2.0, 14.0), Vector2(width / 2.0, 14.0))


func _draw() -> void:
	draw_polyline(_underline, Color(1.0, 1.0, 1.0, 0.85), 3.0)


## A hand-drawn underline: jittered once, then it never flickers.
func _wobbly_line(from: Vector2, to: Vector2) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = UNDERLINE_SEED
	var points := PackedVector2Array()
	for step: int in 12:
		var point := from.lerp(to, step / 12.0)
		point.y += rng.randf_range(-2.5, 2.5)
		point.x += rng.randf_range(-1.2, 1.2)
		points.append(point)
	return points


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
