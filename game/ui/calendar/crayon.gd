class_name Crayon
extends RefCounted
## Deterministic crayon-style drawing helpers. No runtime randomness.

const PAPER := Color(0.98, 0.94, 0.86)
const INK := Color(0.42, 0.35, 0.28)
const FAINT := Color(0.72, 0.65, 0.55)
const WARM := Color(0.91, 0.55, 0.25)
const BASE_TOOLTIP_FONT := 16
const LARGE_SCALE := 1.4

const COLORS := {
	"grass": Color(0.33, 0.60, 0.38),
	"dune": Color(0.86, 0.66, 0.32),
	"sort": Color(0.42, 0.60, 0.78),
	"light": Color(0.93, 0.75, 0.28),
	"meet": Color(0.76, 0.44, 0.55),
	"wall": Color(0.55, 0.53, 0.50),
}


static func color(action: String) -> Color:
	return COLORS.get(action, INK)


## A stable wobble grain per action, so the same drawing always wobbles the same.
static func grain(action: String) -> int:
	return absi(action.hash()) % 71 + 5


## Font size honouring the large text option.
static func font_size(base: int, large: bool) -> int:
	return roundi(float(base) * (LARGE_SCALE if large else 1.0))


## Deterministic noise in [-1, 1] from an integer: a sin hash, never random.
static func noise(n: int) -> float:
	var x := sin(float(n) * 12.9898 + 78.233) * 43758.5453
	return (x - floorf(x)) * 2.0 - 1.0


## Every point of an open path drifts a little, always the same way.
static func wobble(points: PackedVector2Array, grain: int, amount: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i: int in points.size():
		var drift := Vector2(noise(grain * 131 + i * 17), noise(grain * 57 + i * 29))
		result.append(points[i] + drift * amount)
	return result


## A wobbled loop that ends exactly where it began.
static func loop(points: PackedVector2Array, grain: int, amount: float) -> PackedVector2Array:
	var result := wobble(points, grain, amount)
	result.append(result[0])
	return result


## A hand-drawn rectangle: edges subdivided, then wobbled.
static func rect_path(rect: Rect2, grain: int, step: float = 20.0) -> PackedVector2Array:
	var corners := PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	var path := PackedVector2Array()
	for i: int in corners.size():
		var a := corners[i]
		var b := corners[(i + 1) % corners.size()]
		var steps := maxi(2, roundi(a.distance_to(b) / step))
		for j: int in steps:
			path.append(a.lerp(b, float(j) / float(steps)))
	return loop(path, grain, 1.8)


## A wobbly line from a to b.
static func line_path(a: Vector2, b: Vector2, grain: int, segments: int = 3) -> PackedVector2Array:
	var path := PackedVector2Array()
	for j: int in segments + 1:
		path.append(a.lerp(b, float(j) / float(segments)))
	return wobble(path, grain, 1.4)


## A wobbly circle.
static func circle_path(center: Vector2, radius: float, grain: int, points: int = 18) -> PackedVector2Array:
	var path := PackedVector2Array()
	for i: int in points:
		var angle := TAU * float(i) / float(points)
		path.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return loop(path, grain, 1.2)


## A small count badge: paper circle, crayon outline, centred number.
static func draw_badge(canvas: CanvasItem, font: Font, center: Vector2, value: int, font_size: int) -> void:
	if value < 1:
		return
	var radius := float(font_size) * 1.05
	canvas.draw_circle(center, radius + 1.0, PAPER)
	canvas.draw_polyline(circle_path(center, radius, value * 7 + 3), INK, 3.0)
	var width := radius * 2.4
	var baseline := Vector2(center.x - width * 0.5, center.y + font_size * 0.36)
	canvas.draw_string(font, baseline, str(value), HORIZONTAL_ALIGNMENT_CENTER, width, font_size, INK)


## A tooltip label for _make_custom_tooltip, so tips grow with large text.
static func tooltip_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", INK)
	label.add_theme_font_size_override("font_size", font_size)
	return label


## Draws the placeholder glyph for an action inside rect.
static func draw_glyph(canvas: CanvasItem, action: String, rect: Rect2) -> void:
	var unit := minf(rect.size.x, rect.size.y)
	if unit < 8.0:
		return
	var c := rect.get_center()
	var grain_id := grain(action)
	var ink := color(action)
	match action:
		"grass":
			_grass(canvas, c, unit, ink, grain_id)
		"dune":
			_dune(canvas, c, unit, ink, grain_id)
		"sort":
			_sort(canvas, c, unit, ink, grain_id)
		"light":
			_light(canvas, c, unit, ink, grain_id)
		"meet":
			_meet(canvas, c, unit, ink, grain_id)
		"wall":
			_wall(canvas, c, unit, ink, grain_id)
		_:
			canvas.draw_polyline(rect_path(rect, grain_id), ink, 3.0)


static func _grass(canvas: CanvasItem, c: Vector2, unit: float, ink: Color, grain_id: int) -> void:
	var base_y := c.y + unit * 0.26
	for i: int in 5:
		var k := float(i) - 2.0
		var from := Vector2(c.x + k * unit * 0.13, base_y)
		var to := Vector2(c.x + k * unit * 0.24, base_y - unit * 0.50)
		canvas.draw_polyline(line_path(from, to, grain_id + i * 5, 3), ink, maxf(2.0, unit * 0.035))
	var left := Vector2(c.x - unit * 0.30, base_y + 5.0)
	var right := Vector2(c.x + unit * 0.30, base_y + 5.0)
	canvas.draw_polyline(line_path(left, right, grain_id + 71, 3), ink, maxf(2.0, unit * 0.03))


static func _dune(canvas: CanvasItem, c: Vector2, unit: float, ink: Color, grain_id: int) -> void:
	for h: int in 2:
		var hump := PackedVector2Array()
		var cx := c.x + (float(h) - 0.5) * unit * 0.36
		var radius := unit * (0.32 if h == 0 else 0.24)
		for i: int in 9:
			var t := float(i) / 8.0
			var angle := PI * (1.0 - t)
			hump.append(Vector2(cx + cos(angle) * radius, c.y + unit * 0.24 - sin(angle) * radius))
		canvas.draw_polyline(wobble(hump, grain_id + h * 13, 1.6), ink, maxf(3.0, unit * 0.05))
	var sun := Vector2(c.x + unit * 0.32, c.y - unit * 0.30)
	canvas.draw_polyline(circle_path(sun, unit * 0.09, grain_id + 3), ink, maxf(2.0, unit * 0.03))
	for i: int in 4:
		var angle := TAU * float(i) / 4.0 + 0.4
		var from := sun + Vector2(cos(angle), sin(angle)) * unit * 0.13
		var to := sun + Vector2(cos(angle), sin(angle)) * unit * 0.19
		canvas.draw_polyline(line_path(from, to, grain_id + 40 + i, 2), ink, maxf(2.0, unit * 0.025))


static func _sort(canvas: CanvasItem, c: Vector2, unit: float, ink: Color, grain_id: int) -> void:
	canvas.draw_polyline(circle_path(Vector2(c.x - unit * 0.26, c.y - unit * 0.14), unit * 0.07, grain_id + 5), ink, maxf(2.0, unit * 0.03))
	var toss_from := Vector2(c.x - unit * 0.16, c.y - unit * 0.14)
	var toss_to := Vector2(c.x - unit * 0.05, c.y - unit * 0.02)
	canvas.draw_polyline(line_path(toss_from, toss_to, grain_id + 9, 3), ink, maxf(2.0, unit * 0.025))
	var top := c.y - unit * 0.02
	var bottom := c.y + unit * 0.30
	var bin := PackedVector2Array([
		Vector2(c.x - unit * 0.24, top),
		Vector2(c.x + unit * 0.24, top),
		Vector2(c.x + unit * 0.18, bottom),
		Vector2(c.x - unit * 0.18, bottom),
	])
	canvas.draw_polyline(loop(bin, grain_id + 11, 1.5), ink, maxf(3.0, unit * 0.05))
	var lid_left := Vector2(c.x - unit * 0.29, top)
	var lid_right := Vector2(c.x + unit * 0.29, top)
	canvas.draw_polyline(line_path(lid_left, lid_right, grain_id + 15, 3), ink, maxf(3.0, unit * 0.05))


static func _light(canvas: CanvasItem, c: Vector2, unit: float, ink: Color, grain_id: int) -> void:
	var bulb := Vector2(c.x, c.y - unit * 0.10)
	canvas.draw_polyline(circle_path(bulb, unit * 0.17, grain_id + 2), ink, maxf(3.0, unit * 0.05))
	var base_left := Vector2(c.x - unit * 0.08, c.y + unit * 0.14)
	var base_right := Vector2(c.x + unit * 0.08, c.y + unit * 0.14)
	canvas.draw_polyline(line_path(base_left, base_right, grain_id + 6, 2), ink, maxf(3.0, unit * 0.05))
	var screw_left := Vector2(c.x - unit * 0.06, c.y + unit * 0.21)
	var screw_right := Vector2(c.x + unit * 0.06, c.y + unit * 0.21)
	canvas.draw_polyline(line_path(screw_left, screw_right, grain_id + 8, 2), ink, maxf(3.0, unit * 0.05))
	for i: int in 6:
		var angle := TAU * float(i) / 6.0
		if sin(angle) > 0.5:
			continue
		var from := bulb + Vector2(cos(angle), sin(angle)) * unit * 0.24
		var to := bulb + Vector2(cos(angle), sin(angle)) * unit * 0.34
		canvas.draw_polyline(line_path(from, to, grain_id + 20 + i, 2), ink, maxf(2.0, unit * 0.03))


static func _meet(canvas: CanvasItem, c: Vector2, unit: float, ink: Color, grain_id: int) -> void:
	for f: int in 2:
		var side := -1.0 if f == 0 else 1.0
		var x := c.x + side * unit * 0.21
		var head := Vector2(x, c.y - unit * 0.30)
		var neck := Vector2(x, c.y - unit * 0.17)
		var hip := Vector2(x, c.y + unit * 0.10)
		var shoulder := Vector2(x, c.y - unit * 0.12)
		canvas.draw_polyline(circle_path(head, unit * 0.085, grain_id + f * 3), ink, maxf(2.0, unit * 0.035))
		canvas.draw_polyline(line_path(neck, hip, grain_id + f * 5, 3), ink, maxf(2.0, unit * 0.035))
		var shake := Vector2(c.x, c.y - unit * 0.16)
		canvas.draw_polyline(line_path(shoulder, shake, grain_id + f * 7, 3), ink, maxf(2.0, unit * 0.03))
		var hang := Vector2(x - side * unit * 0.14, c.y + unit * 0.02)
		canvas.draw_polyline(line_path(shoulder, hang, grain_id + f * 11, 3), ink, maxf(2.0, unit * 0.03))
		var foot_left := Vector2(x - unit * 0.13, c.y + unit * 0.30)
		var foot_right := Vector2(x + unit * 0.13, c.y + unit * 0.30)
		canvas.draw_polyline(line_path(hip, foot_left, grain_id + f * 13, 3), ink, maxf(2.0, unit * 0.035))
		canvas.draw_polyline(line_path(hip, foot_right, grain_id + f * 17, 3), ink, maxf(2.0, unit * 0.035))


static func _wall(canvas: CanvasItem, c: Vector2, unit: float, ink: Color, grain_id: int) -> void:
	var block := Vector2(unit * 0.30, unit * 0.20)
	var tops: Array[Vector2] = [
		Vector2(c.x - unit * 0.17, c.y + unit * 0.06),
		Vector2(c.x + unit * 0.17, c.y + unit * 0.06),
		Vector2(c.x, c.y - unit * 0.17),
	]
	for i: int in tops.size():
		var rect := Rect2(tops[i] - block * 0.5, block)
		canvas.draw_polyline(rect_path(rect, grain_id + i * 9, unit * 0.10), ink, maxf(3.0, unit * 0.05))
	var wave := PackedVector2Array()
	for i: int in 9:
		var t := float(i) / 8.0
		wave.append(Vector2(c.x + (t - 0.5) * unit * 0.74, c.y + unit * 0.28 + sin(t * TAU * 1.5) * unit * 0.03))
	canvas.draw_polyline(wobble(wave, grain_id + 41, 1.0), COLORS["grass"], maxf(2.0, unit * 0.03))
