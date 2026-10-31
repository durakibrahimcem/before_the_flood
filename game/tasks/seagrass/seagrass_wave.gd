class_name SeagrassWave
extends Node2D
## The soft foam line of a washing wave.
## The wiggle is drawn only; the logic edge stays straight.

const FOAM := Color(1.0, 0.98, 0.92, 0.88)
const ECHO := Color(1.0, 0.97, 0.90, 0.25)
const ECHO_FAINT := Color(1.0, 0.96, 0.88, 0.12)
const SEA_FILL := Color(0.40, 0.66, 0.64, 0.10)
const WIDTH := 1920.0

var edge := 300.0

var _time := 0.0


func _ready() -> void:
	z_index = 10


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func set_edge(y: float) -> void:
	edge = y


func edge_y() -> float:
	return edge


func _draw() -> void:
	var line := _wiggled(0.0)
	var fill := PackedVector2Array([Vector2(0.0, 0.0), Vector2(WIDTH, 0.0)])
	for i in range(line.size() - 1, -1, -1):
		fill.append(line[i])
	draw_colored_polygon(fill, SEA_FILL)
	draw_polyline(line, FOAM, 7.0, true)
	draw_polyline(_shifted(_wiggled(0.9), 14.0), ECHO, 5.0, true)
	draw_polyline(_shifted(_wiggled(1.8), 27.0), ECHO_FAINT, 4.0, true)


func _wiggled(phase: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for x in range(0, int(WIDTH) + 1, 24):
		var drift := float(x) + phase * 40.0
		var y := edge + sin(drift * 0.012 + _time * 1.6) * 6.0 + sin(drift * 0.05 - _time * 0.9) * 2.5
		pts.append(Vector2(float(x), y))
	return pts


func _shifted(points: PackedVector2Array, dy: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p: Vector2 in points:
		pts.append(Vector2(p.x, p.y + dy))
	return pts
