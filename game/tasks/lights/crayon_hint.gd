class_name CrayonHint
extends Node2D
## A short hint in warm crayon: centred text with a hand-drawn underline.

const FONT_SIZE := 34
const TEXT_COLOR := Color(1.0, 0.92, 0.72)
const OUTLINE_COLOR := Color(0.1, 0.1, 0.1, 1)
const OUTLINE_WIDTH := 10
const SQUIGGLE_COLOR := Color(1.0, 0.92, 0.72, 0.9)

var text: String = ""
## Seconds before the hint fades itself out. Zero keeps it until fade_out is called.
var auto_fade_after: float = 3.5

var _width := 260.0
var _label: Label
var _fade: Tween


func _ready() -> void:
	_label = Label.new()
	_label.text = text
	_label.add_theme_font_size_override("font_size", Settings.sized(FONT_SIZE))
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	_label.add_theme_constant_override("outline_size", OUTLINE_WIDTH)
	add_child(_label)
	var bounds := _label.get_minimum_size()
	if bounds.x < 1.0:
		bounds = Vector2(320, 44)
	_width = bounds.x
	_label.position = -bounds / 2.0
	queue_redraw()
	if auto_fade_after > 0.0:
		var tween := create_tween()
		tween.tween_interval(auto_fade_after)
		tween.tween_callback(fade_out.bind(0.6))


func fade_out(duration: float) -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 0.0, duration)
	_fade.tween_callback(hide)


func _draw() -> void:
	var points := PackedVector2Array()
	var steps := 14
	for i: int in steps + 1:
		var t := float(i) / float(steps)
		var x := lerpf(-_width / 2.0 - 18.0, _width / 2.0 + 18.0, t)
		var y := 14.0 + sin(t * 17.0) * 3.0 + sin(t * 6.0) * 2.0
		points.append(Vector2(x, y))
	draw_polyline(points, SQUIGGLE_COLOR, 3.0)
