class_name WorldProps
extends Node2D
## Things outdoors that change with the years. Drawn in code until Ebru's art arrives.

const MEADOW_SPOTS: Array[Vector2] = [Vector2(320, 420), Vector2(760, 380), Vector2(1180, 430), Vector2(1560, 390)]
const WALL_RECT := Rect2(0, 500, 1920, 64)
const BREACH_RECT := Rect2(840, 494, 300, 76)
const HOME_RECTS := { "near": Rect2(760, 170, 430, 260), "far": Rect2(1380, 170, 430, 260) }
const TREE_SPOTS: Array[Vector2] = [Vector2(640, 470), Vector2(1270, 470)]

@export var outdoor_room: String = "shore"

var state: WorldState


func _ready() -> void:
	z_index = -1
	WorldClock.year_changed.connect(_on_year_changed)
	WorldClock.refresh()


func _on_year_changed(new_state: WorldState) -> void:
	state = new_state
	queue_redraw()


func _draw() -> void:
	if state == null:
		return
	if outdoor_room == "shore":
		_draw_shore()
	else:
		_draw_street()


func _draw_shore() -> void:
	for spot: Vector2 in MEADOW_SPOTS:
		draw_circle(spot, 40.0 + 110.0 * state.meadow, Color(0.2, 0.42, 0.34, 0.45 * state.meadow))
	var dune_top := 560.0 - 150.0 * state.dune
	draw_colored_polygon(PackedVector2Array([Vector2(1300, 620), Vector2(1600, dune_top), Vector2(1920, 620)]), Color(0.83, 0.74, 0.52))
	if state.wall_state == WorldState.Wall.NONE:
		return
	var stone := Color(0.56, 0.55, 0.53)
	draw_rect(WALL_RECT, stone)
	if state.wall_state == WorldState.Wall.CRACKED:
		draw_polyline(PackedVector2Array([Vector2(900, 500), Vector2(960, 530), Vector2(930, 564)]), Color(0.2, 0.2, 0.2), 5.0)
	elif state.wall_state == WorldState.Wall.BREACHED:
		draw_rect(BREACH_RECT, Color(0.36, 0.56, 0.6))


func _draw_street() -> void:
	for spot: Vector2 in TREE_SPOTS:
		var size := 20.0 + 90.0 * state.dune
		draw_rect(Rect2(spot.x - 8.0, spot.y - size, 16.0, size), Color(0.42, 0.3, 0.2))
		draw_circle(Vector2(spot.x, spot.y - size), size * 0.7, Color(0.36, 0.52, 0.32))
	for home: String in HOME_RECTS:
		if not state.home_alive.get(home, true):
			var rect: Rect2 = HOME_RECTS[home]
			draw_rect(rect, Color(0.1, 0.1, 0.1, 0.4))
			draw_line(rect.position, rect.end, Color(0.32, 0.22, 0.16), 14.0)
			draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), Color(0.32, 0.22, 0.16), 14.0)
