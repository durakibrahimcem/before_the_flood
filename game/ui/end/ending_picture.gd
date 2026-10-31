class_name EndingPicture
extends Control
## Code-drawn placeholder ending art. Ebru's textures drop in through the slots.

@export var art_three: Texture2D
@export var art_partial: Texture2D
@export var art_none: Texture2D

var variant: String = ""

const SKY := Color(0.99, 0.96, 0.88)
const SEA := Color(0.24, 0.5, 0.5, 0.45)
const MEADOW := Color(0.56, 0.68, 0.46)
const SHOOT := Color(0.42, 0.58, 0.36)


func show_outcome(homes: int) -> void:
	if homes >= 3:
		variant = "three"
	elif homes >= 1:
		variant = "partial"
	else:
		variant = "none"
	queue_redraw()


func _draw() -> void:
	var card := Rect2(Vector2.ZERO, size)
	draw_rect(card, EndPalette.CARD)
	draw_rect(card, EndPalette.INK, false, 2.0)
	var art := _art()
	if art != null:
		_draw_texture(art)
		return
	match variant:
		"three":
			_draw_three()
		"partial":
			_draw_partial()
		"none":
			_draw_none()


func _art() -> Texture2D:
	match variant:
		"three":
			return art_three
		"partial":
			return art_partial
	return art_none


func _draw_texture(art: Texture2D) -> void:
	var texture_size := art.get_size()
	if texture_size.x < 1.0 or texture_size.y < 1.0:
		return
	var fit := minf(size.x / texture_size.x, size.y / texture_size.y)
	var drawn := texture_size * fit
	draw_texture_rect(art, Rect2((size - drawn) * 0.5, drawn), false)


func _draw_three() -> void:
	var meadow_top := size.y * 0.66
	draw_rect(Rect2(2.0, 2.0, size.x - 4.0, meadow_top - 2.0), SKY)
	draw_rect(Rect2(2.0, meadow_top, size.x - 4.0, size.y * 0.16), SEA)
	draw_colored_polygon(PackedVector2Array([
		Vector2(2.0, size.y - 2.0 - size.y * 0.20),
		Vector2(size.x - 2.0, size.y - 2.0 - size.y * 0.26),
		Vector2(size.x - 2.0, size.y - 2.0),
		Vector2(2.0, size.y - 2.0),
	]), MEADOW)
	var arda := Vector2(size.x * 0.42, meadow_top + 30.0)
	draw_circle(arda + Vector2(-34.0, -52.0), 15.0, EndPalette.INK)
	draw_line(arda + Vector2(-34.0, -40.0), arda + Vector2(8.0, -12.0), EndPalette.INK, 9.0)
	draw_line(arda + Vector2(8.0, -12.0), arda + Vector2(24.0, 8.0), EndPalette.INK, 8.0)
	draw_line(arda + Vector2(0.0, -30.0), arda + Vector2(-52.0, 2.0), EndPalette.INK, 6.0)
	draw_line(arda + Vector2(-58.0, 0.0), arda + Vector2(-58.0, -26.0), SHOOT, 4.0)
	var child := Vector2(size.x * 0.56, meadow_top + 34.0)
	draw_arc(child + Vector2(0.0, -46.0), 12.0, 0.0, TAU, 24, EndPalette.CRAYON, 3.0)
	draw_line(child + Vector2(0.0, -34.0), child + Vector2(-4.0, 6.0), EndPalette.CRAYON, 4.0)
	draw_line(child + Vector2(-4.0, 6.0), child + Vector2(-14.0, 34.0), EndPalette.CRAYON, 4.0)
	draw_line(child + Vector2(-4.0, 6.0), child + Vector2(10.0, 32.0), EndPalette.CRAYON, 4.0)
	draw_line(child + Vector2(-2.0, -24.0), child + Vector2(26.0, -4.0), EndPalette.CRAYON, 4.0)
	draw_line(child + Vector2(32.0, 2.0), child + Vector2(32.0, -24.0), SHOOT, 4.0)


func _draw_partial() -> void:
	var ground := size.y * 0.80
	draw_line(Vector2(size.x * 0.05, ground), Vector2(size.x * 0.95, ground), EndPalette.INK, 3.0)
	_home(Vector2(size.x * 0.14, ground), 0.55, true)
	_home(Vector2(size.x * 0.72, ground), 0.7, true)
	_home(Vector2(size.x * 0.40, ground), 1.0, false)
	var seat := Vector2(size.x * 0.40 + 304.0, ground - 20.0)
	draw_circle(seat + Vector2(0.0, -34.0), 13.0, EndPalette.INK)
	draw_line(seat + Vector2(0.0, -22.0), seat + Vector2(-8.0, 4.0), EndPalette.INK, 8.0)
	draw_line(seat + Vector2(-8.0, 4.0), seat + Vector2(10.0, 8.0), EndPalette.INK, 7.0)


func _home(base: Vector2, scale: float, faded: bool) -> void:
	var width := 260.0 * scale
	var height := 170.0 * scale
	var color := EndPalette.FADED if faded else EndPalette.INK
	var wall := Rect2(base.x, base.y - height, width, height)
	var roof := PackedVector2Array([
		Vector2(base.x - 24.0 * scale, base.y - height),
		Vector2(base.x + width * 0.5, base.y - height - 90.0 * scale),
		Vector2(base.x + width + 24.0 * scale, base.y - height),
	])
	if faded:
		_dashed_rect(wall, color, 2.0)
		_dashed_polyline(roof, color, 2.0)
		return
	draw_rect(wall, color, false, 4.0)
	draw_polyline(roof, color, 4.0)
	draw_rect(Rect2(base.x + width * 0.40, base.y - 78.0, 40.0, 78.0), color, false, 3.0)
	draw_rect(Rect2(base.x + width * 0.40 + 40.0, base.y - 16.0, 54.0, 16.0), color, false, 3.0)


func _draw_none() -> void:
	var floor_y := size.y * 0.82
	var frame_left := Vector2(size.x * 0.42, size.y * 0.22)
	var frame_right := Vector2(size.x * 0.62, size.y * 0.22)
	draw_line(frame_left, Vector2(frame_left.x, floor_y), EndPalette.INK, 5.0)
	draw_line(frame_right, Vector2(frame_right.x, floor_y), EndPalette.INK, 5.0)
	draw_line(frame_left, frame_right, EndPalette.INK, 5.0)
	draw_polyline(PackedVector2Array([
		frame_right,
		Vector2(frame_right.x - 46.0, frame_right.y + 14.0),
		Vector2(frame_right.x - 46.0, floor_y - 12.0),
		Vector2(frame_right.x, floor_y),
	]), EndPalette.FADED, 3.0)
	var box := Rect2(size.x * 0.20, floor_y - 74.0, 96.0, 74.0)
	draw_rect(box, EndPalette.INK, false, 3.0)
	draw_line(box.position, box.position + Vector2(-18.0, -22.0), EndPalette.INK, 2.0)
	draw_line(box.position + Vector2(box.size.x, 0.0), box.position + Vector2(box.size.x + 18.0, -22.0), EndPalette.INK, 2.0)
	var head := box.position + Vector2(48.0, -6.0)
	draw_circle(head, 15.0, EndPalette.INK)
	draw_circle(head + Vector2(-11.0, -13.0), 5.0, EndPalette.INK)
	draw_circle(head + Vector2(11.0, -13.0), 5.0, EndPalette.INK)
	var walker := Vector2(size.x * 0.80, floor_y - 60.0)
	draw_circle(walker + Vector2(0.0, -40.0), 13.0, EndPalette.INK)
	draw_line(walker + Vector2(0.0, -28.0), walker + Vector2(-4.0, 18.0), EndPalette.INK, 7.0)
	draw_line(walker + Vector2(-4.0, 18.0), walker + Vector2(-18.0, 60.0), EndPalette.INK, 6.0)
	draw_line(walker + Vector2(-4.0, 18.0), walker + Vector2(12.0, 58.0), EndPalette.INK, 6.0)
	draw_line(walker + Vector2(0.0, -20.0), walker + Vector2(24.0, -4.0), EndPalette.INK, 5.0)
	draw_arc(walker + Vector2(34.0, 6.0), 15.0, 0.0, TAU, 20, EndPalette.INK, 3.0)


func _dashed_rect(rect: Rect2, color: Color, width: float) -> void:
	_dashed_polyline(PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
		rect.position,
	]), color, width)


func _dashed_polyline(points: PackedVector2Array, color: Color, width: float) -> void:
	for i: int in points.size() - 1:
		_dashed_line(points[i], points[i + 1], color, width)


func _dashed_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var delta := to - from
	var length := delta.length()
	if length < 0.01:
		return
	var direction := delta / length
	var travelled := 0.0
	while travelled < length:
		var dash := minf(10.0, length - travelled)
		draw_line(from + direction * travelled, from + direction * (travelled + dash), color, width)
		travelled += dash + 8.0
