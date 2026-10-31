class_name WorldProps
extends Node2D
## Things outdoors that change with the years, drawn over Ebru's paintings.

const INK := Color("4a4a4a")
const SAPLING := preload("res://rooms/street/sapling.png")
const SAPLING_SPOTS: Array[Vector2] = [Vector2(168, 226), Vector2(374, 232), Vector2(90, 299), Vector2(256, 300), Vector2(442, 303)]
## Ebru's own size. Saplings start here, and the years and the dunes' care raise them.
const SAPLING_SIZE_MIN := 28.0
const SAPLING_SIZE_MAX := 100.0
const SAPLING_FULL_SHARE := 0.6
const SAPLING_BARE_GROWTH := 0.4
const SAPLING_DROWNS_M := 1.3
## Sorts with the houses, so boards sit on the walls and Arda still walks in front of them.
const STREET_SORT_Y := 395.0
const HOME_OPENINGS := {
	"own": [Rect2(664, 250, 76, 130), Rect2(866, 302, 74, 92), Rect2(1042, 305, 66, 85)],
	"near": [Rect2(1540, 250, 80, 130), Rect2(1736, 302, 74, 92)],
}
const WINDOW_DARK := Color(0.16, 0.17, 0.2, 0.6)
const BOARD := Color("9b6a43")
const BOARD_WIDTH := 11.0
const MEADOW_TUFTS := 44
const MEADOW_AREA := Rect2(30, 290, 1860, 170)
const MEADOW_BLADE := Color(0.3, 0.5, 0.4, 0.6)
const DUNE_FOOT_Y := 1020.0
const DUNE_FULL_PX := 210.0
const DUNE_STEP_PX := 120
const DUNE_FILL := Color("eadba9")
const DUNE_MARK := Color("dcc896")
const DUNE_GRASS := Color("8fa97a")
## How near the front the boarded houses and the dune sit, to slide with the room's objects.
const HOUSE_NEARNESS := 381.0 / 1080.0
const DUNE_NEARNESS := 0.85
const REDRAW_PX := 0.25

@export var outdoor_room: String = "shore"

var state: WorldState
var room: Room
var _drawn_slide := 0.0


func _ready() -> void:
	if outdoor_room == "shore":
		z_index = -1
	else:
		position.y = STREET_SORT_Y
	WorldClock.year_changed.connect(_on_year_changed)
	WorldClock.refresh()


func _on_year_changed(new_state: WorldState) -> void:
	state = new_state
	queue_redraw()


func _process(_delta: float) -> void:
	var slide := room.slide_at(1.0)
	if absf(slide - _drawn_slide) >= REDRAW_PX:
		_drawn_slide = slide
		queue_redraw()


func _draw() -> void:
	if state == null:
		return
	if outdoor_room == "shore":
		_draw_meadow()
		draw_set_transform(Vector2(_drawn_slide * DUNE_NEARNESS, 0.0))
		_draw_dune()
	else:
		draw_set_transform(Vector2(0.0, -STREET_SORT_Y))
		_draw_saplings()
		draw_set_transform(Vector2(_drawn_slide * HOUSE_NEARNESS, -STREET_SORT_Y))
		for home: String in HOME_OPENINGS:
			if not state.home_alive.get(home, true):
				_draw_boards(HOME_OPENINGS[home])


func _draw_meadow() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for tuft: int in MEADOW_TUFTS:
		var spot := MEADOW_AREA.position + Vector2(rng.randf(), rng.randf()) * MEADOW_AREA.size
		var tall := rng.randf_range(16.0, 30.0)
		if tuft < state.meadow * MEADOW_TUFTS:
			for blade: float in [-0.7, 0.0, 0.7]:
				draw_line(spot, spot + Vector2(blade * tall * 0.6, -tall), MEADOW_BLADE, 3.0)


func _draw_dune() -> void:
	var tall := DUNE_FULL_PX * state.dune
	if tall < 3.0:
		return
	var crest := PackedVector2Array()
	for x: int in range(-DUNE_STEP_PX, 1920 + 2 * DUNE_STEP_PX, DUNE_STEP_PX):
		var swell := 0.72 + 0.28 * sin(x * 0.0071) * sin(x * 0.0023 + 1.0)
		crest.append(Vector2(x, DUNE_FOOT_Y - tall * swell))
	var body := crest.duplicate()
	body.append(Vector2(1920 + 2 * DUNE_STEP_PX, 1080))
	body.append(Vector2(-DUNE_STEP_PX, 1080))
	draw_colored_polygon(body, DUNE_FILL)
	draw_polyline(crest, INK, 3.0)
	for index: int in range(1, crest.size() - 1):
		var spot := crest[index]
		draw_line(spot + Vector2(-34, 34), spot + Vector2(30, 40), DUNE_MARK, 5.0)
		for blade: float in [-0.5, 0.1, 0.6]:
			draw_line(spot, spot + Vector2(blade * 26.0, -30.0 - 40.0 * state.dune), DUNE_GRASS, 4.0)


func _draw_saplings() -> void:
	if float(state.flood_m.get("street", 0.0)) >= SAPLING_DROWNS_M:
		return
	var age := inverse_lerp(Sim.FIRST_YEAR, Sim.LAST_YEAR, state.year)
	var care := clampf(state.dune / SAPLING_FULL_SHARE, 0.0, 1.0)
	var size := lerpf(SAPLING_SIZE_MIN, SAPLING_SIZE_MAX, age * lerpf(SAPLING_BARE_GROWTH, 1.0, care))
	for index: int in mini(state.saplings, SAPLING_SPOTS.size()):
		var spot := SAPLING_SPOTS[index]
		draw_texture_rect(SAPLING, Rect2(spot.x - size * 0.5, spot.y - size, size, size), false)


func _draw_boards(openings: Array) -> void:
	for opening: Rect2 in openings:
		draw_rect(opening, WINDOW_DARK)
		_draw_board(opening.position, opening.end)
		_draw_board(Vector2(opening.end.x, opening.position.y), Vector2(opening.position.x, opening.end.y))


func _draw_board(from: Vector2, to: Vector2) -> void:
	draw_line(from, to, INK, BOARD_WIDTH + 4.0)
	draw_line(from, to, BOARD, BOARD_WIDTH)
