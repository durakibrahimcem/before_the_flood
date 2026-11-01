class_name GhostChart
extends Control
## Past attempts as waterlines on a height chart by the door.

const MAX_M := 2.0
const PAD_LEFT := 64.0
const PAD_RIGHT := 30.0
const PAD_TOP := 26.0
const PAD_BOTTOM := 46.0
const TICK_LABELS := ["0", "0.5", "1", "1.5", "2 m"]
const CHILD_MARKS := [[0.95, "3"], [1.30, "8"]]
const WAVE_AMPLITUDE := 2.5
const WAVE_STEP := 12.0
## One mark's own arrival, and the quiet gap before the next one.
const MARK_SECONDS := 0.3
const MARK_STAGGER := 0.08

var depths: Array[float] = []

var _reveal := 0.0
var _card: StyleBoxFlat
var _entrance: Tween


func _init() -> void:
	_card = StyleBoxFlat.new()
	_card.bg_color = EndPalette.CARD
	_card.border_color = EndPalette.INK
	_card.set_border_width_all(2)
	_card.set_corner_radius_all(12)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_depths(values: Array[float]) -> void:
	depths.assign(values)
	_reveal = float(depths.size())
	queue_redraw()


## Every mark back at once, so a skip or a calm storm leaves nothing half drawn.
func rest_marks() -> void:
	_reveal = float(depths.size())
	queue_redraw()


func marks_fully_shown() -> bool:
	return _reveal >= float(depths.size())


## The marks arrive one by one, oldest first, the bright newest one last.
func reveal_marks(delay := 0.0) -> Tween:
	if _entrance != null and _entrance.is_valid():
		_entrance.kill()
	_reveal = 0.0
	queue_redraw()
	var count := float(depths.size())
	_entrance = create_tween()
	_entrance.tween_method(_set_reveal, 0.0, count, MARK_SECONDS + MARK_STAGGER * maxf(count - 1.0, 0.0)) \
		.set_delay(delay)
	return _entrance


func _set_reveal(value: float) -> void:
	_reveal = value
	queue_redraw()


func newest_index() -> int:
	return depths.size() - 1


func _draw() -> void:
	draw_style_box(_card, Rect2(Vector2.ZERO, size))
	var axis_x := PAD_LEFT + 8.0
	var floor_y := size.y - PAD_BOTTOM
	draw_line(Vector2(axis_x, PAD_TOP), Vector2(axis_x, floor_y), EndPalette.INK, 2.0)
	draw_line(Vector2(axis_x, floor_y), Vector2(size.x - PAD_RIGHT, floor_y), EndPalette.INK, 2.0)
	var font := ThemeDB.fallback_font
	for i: int in TICK_LABELS.size():
		var tick_y := _y(float(i) * 0.5)
		draw_line(Vector2(axis_x - 6.0, tick_y), Vector2(axis_x + 6.0, tick_y), EndPalette.INK, 1.5)
		draw_string(font, Vector2(10.0, tick_y + 5.0), String(TICK_LABELS[i]), HORIZONTAL_ALIGNMENT_RIGHT, 44.0, 20, EndPalette.FADED)
	for mark: Array in CHILD_MARKS:
		var mark_y := _y(float(mark[0]))
		draw_line(Vector2(axis_x + 6.0, mark_y), Vector2(axis_x + 16.0, mark_y), EndPalette.FADED, 2.0)
		draw_string(font, Vector2(axis_x + 20.0, mark_y + 5.0), String(mark[1]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, EndPalette.FADED)
	var newest := newest_index()
	for i: int in depths.size():
		var arrival := smoothstep(0.0, 1.0, clampf(_reveal - float(i), 0.0, 1.0))
		if arrival <= 0.0:
			continue
		var line := _wave(_y(depths[i]))
		if i == newest:
			draw_polyline(line, Color(EndPalette.CRAYON, arrival), 4.0)
			draw_string(font, Vector2(size.x - PAD_RIGHT - 84.0, _y(depths[i]) - 10.0), "%.2f m" % depths[i], HORIZONTAL_ALIGNMENT_RIGHT, 80.0, 20, Color(EndPalette.CRAYON, arrival))
		else:
			draw_polyline(line, Color(EndPalette.TEAL_OLD, arrival), 2.0)


func _y(metres: float) -> float:
	var plot_height := size.y - PAD_TOP - PAD_BOTTOM
	return PAD_TOP + (1.0 - clampf(metres, 0.0, MAX_M) / MAX_M) * plot_height


func _wave(y: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var x := PAD_LEFT + 18.0
	while x <= size.x - PAD_RIGHT:
		points.append(Vector2(x, y + sin(x * 0.09) * WAVE_AMPLITUDE))
		x += WAVE_STEP
	return points
