class_name CrayonArt
extends Control
## A code-drawn house by the sea. Real art drops straight into the export.

const DESIGN := Vector2(420, 360)

@export var art: Texture2D


func _draw() -> void:
	var area := size
	if art != null:
		draw_texture_rect(art, Rect2(Vector2.ZERO, area), true)
		return
	var zoom := minf(area.x / DESIGN.x, area.y / DESIGN.y)
	var origin := (area - DESIGN * zoom) * 0.5
	_house(origin, zoom)
	_sun(origin, zoom)
	_water(origin, zoom)


func _house(origin: Vector2, zoom: float) -> void:
	_line(origin, zoom, Vector2(90, 160), Vector2(90, 260), CrayonUI.INK, 4.0, 11)
	_line(origin, zoom, Vector2(250, 160), Vector2(250, 260), CrayonUI.INK, 4.0, 12)
	_line(origin, zoom, Vector2(84, 158), Vector2(170, 88), CrayonUI.INK, 4.0, 13)
	_line(origin, zoom, Vector2(170, 88), Vector2(256, 158), CrayonUI.INK, 4.0, 14)
	_line(origin, zoom, Vector2(150, 260), Vector2(150, 210), CrayonUI.INK, 3.0, 15)
	_line(origin, zoom, Vector2(150, 210), Vector2(182, 210), CrayonUI.INK, 3.0, 16)
	_line(origin, zoom, Vector2(182, 210), Vector2(182, 260), CrayonUI.INK, 3.0, 17)
	_line(origin, zoom, Vector2(205, 185), Vector2(235, 185), CrayonUI.INK, 3.0, 18)
	_line(origin, zoom, Vector2(235, 185), Vector2(235, 210), CrayonUI.INK, 3.0, 19)
	_line(origin, zoom, Vector2(235, 210), Vector2(205, 210), CrayonUI.INK, 3.0, 20)
	_line(origin, zoom, Vector2(205, 210), Vector2(205, 185), CrayonUI.INK, 3.0, 21)


func _sun(origin: Vector2, zoom: float) -> void:
	draw_circle(origin + Vector2(330, 70) * zoom, 24.0 * zoom, Color(CrayonUI.CRAYON.r, CrayonUI.CRAYON.g, CrayonUI.CRAYON.b, 0.85))
	for i: int in 8:
		var angle := TAU * i / 8.0
		var direction := Vector2(cos(angle), sin(angle))
		_line(origin, zoom, Vector2(330, 70) + direction * 34.0, Vector2(330, 70) + direction * 52.0, CrayonUI.CRAYON, 4.0, 40 + i)


func _water(origin: Vector2, zoom: float) -> void:
	_line(origin, zoom, Vector2(40, 295), Vector2(380, 295), CrayonUI.SEA, 5.0, 60)
	_line(origin, zoom, Vector2(60, 325), Vector2(360, 325), CrayonUI.SEA, 5.0, 61)


func _line(origin: Vector2, zoom: float, from: Vector2, to: Vector2, color: Color, width: float, stroke_seed: int) -> void:
	CrayonUI.draw_crayon_line(self, origin + from * zoom, origin + to * zoom, color, width * zoom, stroke_seed)
