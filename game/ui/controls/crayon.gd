class_name CrayonUI
extends RefCounted
## The shared crayon-on-paper look: palette, theme and hand-drawn strokes.

const PAPER := Color(0.96, 0.93, 0.85)
const PAPER_WARM := Color(0.98, 0.95, 0.87)
const INK := Color(0.3, 0.24, 0.19)
const SEA := Color(0.36, 0.51, 0.6)
const CRAYON := Color(0.96, 0.8, 0.32)
const CRAYON_RED := Color(0.87, 0.42, 0.3)
const FONT_PATH := "res://ui/handwriting.tres"

static var _theme: Theme
static var _paper: ImageTexture
static var _icons: Dictionary = {}


static func build_theme() -> Theme:
	## Hand-made theme: paper fills, uneven ink borders, a crayon focus ring.
	if _theme != null:
		return _theme
	var theme := Theme.new()
	if ResourceLoader.exists(FONT_PATH):
		var font := load(FONT_PATH) as Font
		if font != null:
			theme.default_font = font
	theme.default_font_size = 28
	var normal := _paper_box(PAPER, INK, 26.0, 16.0)
	var hover := _paper_box(PAPER_WARM, INK, 26.0, 16.0)
	var pressed := _paper_box(CRAYON, INK, 26.0, 16.0)
	for type: String in ["Button", "CheckBox"]:
		theme.set_stylebox("normal", type, normal)
		theme.set_stylebox("hover", type, hover)
		theme.set_stylebox("pressed", type, pressed)
		theme.set_stylebox("hover_pressed", type, pressed)
		theme.set_stylebox("focus", type, _focus_box())
		theme.set_color("font_color", type, INK)
		theme.set_color("font_hover_color", type, INK)
		theme.set_color("font_pressed_color", type, INK)
		theme.set_color("font_hover_pressed_color", type, INK)
		theme.set_color("font_focus_color", type, INK)
	theme.set_color("font_color", "Label", INK)
	var panel := _paper_box(PAPER, INK, 10.0, 8.0)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)
	_theme = theme
	return theme


static func style_panel() -> StyleBoxFlat:
	## A sheet of paper with room to sit a menu on.
	return _paper_box(PAPER, INK, 34.0, 24.0)


static func paper_texture() -> ImageTexture:
	## Cream paper with seeded grain, so the speckle is the same every run.
	if _paper != null:
		return _paper
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260207
	var size := 256
	var bytes := PackedByteArray()
	bytes.resize(size * size * 4)
	var i := 0
	for _y: int in size:
		for _x: int in size:
			var shade := rng.randf_range(-0.03, 0.03)
			bytes[i] = _byte(PAPER.r + shade)
			bytes[i + 1] = _byte(PAPER.g + shade)
			bytes[i + 2] = _byte(PAPER.b + shade)
			bytes[i + 3] = 255
			i += 4
	for _speck: int in 90:
		var at := (rng.randi_range(0, size - 1) * size + rng.randi_range(0, size - 1)) * 4
		bytes[at] = _byte(PAPER.r * 0.82)
		bytes[at + 1] = _byte(PAPER.g * 0.8)
		bytes[at + 2] = _byte(PAPER.b * 0.78)
	var image := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, bytes)
	_paper = ImageTexture.create_from_image(image)
	return _paper


static func squiggle_points(from: Vector2, to: Vector2, waves: int, amp: float, phase: float) -> PackedVector2Array:
	## A line with a sine wobble perpendicular to it, tapered at both ends.
	var points := PackedVector2Array()
	var length := from.distance_to(to)
	if length < 0.001:
		points.append(from)
		return points
	var direction := (to - from) / length
	var normal := Vector2(-direction.y, direction.x)
	for i: int in 25:
		var t := i / 24.0
		var wobble := sin(t * TAU * waves + phase) * amp * sin(t * PI)
		points.append(from + direction * length * t + normal * wobble)
	return points


static func jitter(points: PackedVector2Array, amount: float, seed: int) -> PackedVector2Array:
	## Deterministic per-point wobble; the ends stay anchored.
	if points.size() < 2:
		return points
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var moved := PackedVector2Array()
	for i: int in points.size():
		if i == 0 or i == points.size() - 1:
			moved.append(points[i])
		else:
			moved.append(points[i] + Vector2(rng.randf_range(-amount, amount), rng.randf_range(-amount, amount)))
	return moved


static func draw_crayon_line(item: CanvasItem, from: Vector2, to: Vector2, color: Color, width: float, seed: int) -> void:
	var wobble := squiggle_points(from, to, 3, maxf(1.0, width * 0.3), float(seed % 628) * 0.01)
	draw_crayon_polyline(item, wobble, color, width, seed)


static func draw_crayon_polyline(item: CanvasItem, points: PackedVector2Array, color: Color, width: float, seed: int) -> void:
	## A few slightly moved passes, so a stroke reads as wax, not vector.
	if points.size() < 2:
		return
	var wax := Color(color.r, color.g, color.b, 0.8)
	for i: int in 3:
		var stroke := jitter(points, maxf(0.6, width * 0.25), seed + i * 131)
		item.draw_polyline(stroke, wax, maxf(1.5, width * (1.0 - 0.2 * i)))


static func box_icon(checked: bool, size: int = 32) -> ImageTexture:
	## The checkbox itself: a wobbly ink box with a crayon tick when on.
	var key := "%d-%d" % [int(checked), size]
	if _icons.has(key):
		return _icons[key]
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var unit := size / 32.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 if checked else 3
	var corner := Vector2(5, 5)
	var corners: Array[Vector2] = []
	for _i: int in 4:
		corners.append(Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5)))
	var a := (corner + corners[0]) * unit
	var b := (corner + Vector2(22, 0) + corners[1]) * unit
	var c := (corner + Vector2(22, 22) + corners[2]) * unit
	var d := (corner + Vector2(0, 22) + corners[3]) * unit
	_paint_line(image, a, b, INK, 2.0 * unit)
	_paint_line(image, b, c, INK, 2.0 * unit)
	_paint_line(image, c, d, INK, 2.0 * unit)
	_paint_line(image, d, a, INK, 2.0 * unit)
	if checked:
		_paint_line(image, Vector2(9, 16) * unit, Vector2(13, 21) * unit, CRAYON_RED, 3.0 * unit)
		_paint_line(image, Vector2(13, 21) * unit, Vector2(22, 8) * unit, CRAYON_RED, 3.0 * unit)
	var texture := ImageTexture.create_from_image(image)
	_icons[key] = texture
	return texture


static func _paper_box(fill: Color, border: Color, wide: float, tall: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(3)
	box.corner_radius_top_left = 10
	box.corner_radius_top_right = 14
	box.corner_radius_bottom_right = 8
	box.corner_radius_bottom_left = 12
	box.content_margin_left = wide
	box.content_margin_right = wide
	box.content_margin_top = tall
	box.content_margin_bottom = tall
	return box


static func _focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = INK
	box.border_width_left = 4
	box.border_width_top = 3
	box.border_width_right = 5
	box.border_width_bottom = 3
	box.corner_radius_top_left = 13
	box.corner_radius_top_right = 17
	box.corner_radius_bottom_right = 11
	box.corner_radius_bottom_left = 15
	box.set_expand_margin_all(4.0)
	return box


static func _paint_line(image: Image, from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var steps := maxf(2.0, ceilf(from.distance_to(to) * 2.0))
	var half := maxf(0.5, width * 0.5)
	for i: int in int(steps) + 1:
		var at := from.lerp(to, i / steps)
		for px: int in range(int(at.x - half), int(at.x + half) + 1):
			for py: int in range(int(at.y - half), int(at.y + half) + 1):
				if px >= 0 and py >= 0 and px < image.get_width() and py < image.get_height():
					image.set_pixel(px, py, color)


static func _byte(value: float) -> int:
	return int(clampf(value, 0.0, 1.0) * 255.0)
