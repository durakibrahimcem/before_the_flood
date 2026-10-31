class_name CrayonPicture
extends Control
## The picture slot on the front page. Ebru's art shows when it exists,
## otherwise a crayon doodle that stays the same for the same picture key.

const PAPER := Color(0.97, 0.95, 0.89)
const SKY := Color(0.86, 0.89, 0.90)
const SEA := Color(0.29, 0.45, 0.53)
const FOAM := Color(0.78, 0.87, 0.90)
const INK := Color(0.15, 0.125, 0.10)
const SUN := Color(0.94, 0.76, 0.36)
const SUN_INK := Color(0.72, 0.52, 0.18)
const WALL := Color(0.90, 0.84, 0.72)
const ROOF := Color(0.62, 0.30, 0.22)

@export var art: Texture2D
@export var key := ""


func _draw() -> void:
	if art != null and art.get_width() > 0:
		# Keep the art's shape and centre it, like a photo pasted on the page.
		draw_rect(Rect2(Vector2.ZERO, size), PAPER, true)
		var fit := minf(size.x / art.get_width(), size.y / art.get_height())
		var fitted := Vector2(art.get_width(), art.get_height()) * fit
		draw_texture_rect(art, Rect2((size - fitted) * 0.5, fitted), false)
		return
	_draw_doodle()


## A hand-wobbly seaside, deterministic from the key so every story keeps its own doodle.
func _draw_doodle() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = key.hash()
	draw_rect(Rect2(Vector2.ZERO, size), PAPER, true)
	var horizon := size.y * (0.52 + rng.randf_range(-0.05, 0.05))
	draw_rect(Rect2(Vector2(0.0, horizon), Vector2(size.x, size.y - horizon)), SEA, true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, horizon)), SKY, true)

	var sun := Vector2(size.x * (0.72 + rng.randf_range(0.0, 0.12)), size.y * 0.19)
	draw_circle(sun, 11.0 + rng.randf() * 3.0, SUN)
	draw_arc(sun, 13.0, 0.0, TAU, 24, SUN_INK, 2.5)
	_wobbly(Vector2(0.0, horizon), Vector2(size.x, horizon), INK, rng, 3.0)

	for index: int in 3:
		var wave_y := horizon + (size.y - horizon) * (0.22 + 0.24 * index) + rng.randf_range(-2.0, 2.0)
		var wave_x := rng.randf_range(0.08, 0.3) * size.x
		var wave_end := minf(wave_x + size.x * rng.randf_range(0.2, 0.38), size.x - 6.0)
		_wobbly(Vector2(wave_x, wave_y), Vector2(wave_end, wave_y), FOAM, rng, 2.5)

	var width := size.x * 0.17
	var house := Rect2(size.x * 0.14, horizon - width * 0.5, width, width * 0.5)
	draw_rect(house, WALL, true)
	draw_rect(house, INK, false, 2.5)
	var roof := PackedVector2Array([
		Vector2(house.position.x - 5.0, house.position.y),
		Vector2(house.position.x + house.size.x * 0.5, house.position.y - width * 0.38),
		Vector2(house.position.x + house.size.x + 5.0, house.position.y),
	])
	draw_colored_polygon(roof, ROOF)
	var outline := roof.duplicate()
	outline.append(roof[0])
	draw_polyline(outline, INK, 2.5)
	var door := Rect2(house.position.x + house.size.x * 0.42, house.position.y + house.size.y * 0.4, width * 0.16, house.size.y * 0.6)
	draw_rect(door, INK, false, 2.0)


func _wobbly(from: Vector2, to: Vector2, color: Color, rng: RandomNumberGenerator, width: float) -> void:
	var points := PackedVector2Array()
	var steps := maxi(2, roundi(from.distance_to(to) / 26.0))
	for index: int in steps + 1:
		var point := from.lerp(to, float(index) / float(steps))
		point.y += rng.randf_range(-2.5, 2.5)
		points.append(point)
	draw_polyline(points, color, width)
