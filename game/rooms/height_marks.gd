class_name HeightMarks
extends Node2D
## Crayon lines on the bedroom height chart, showing how high the water reached in earlier runs.

const LEFT := 830.0
const RIGHT := 892.0
const MARKS_SHOWN := 8
const CRAYON := Color(0.78, 0.18, 0.2)
const LINE_WIDTH := 5.0
const NUMBER_SIZE := 28
const NUMBER_STEP := 22.0
const CROWDED_PX := 24.0
const HAND: Font = preload("res://ui/fonts/Caveat.ttf")

var room: Room


func _ready() -> void:
	z_index = -1


## The same line the water reaches on this wall at that depth.
func mark_y(depth_m: float) -> float:
	return (room.floor_line - depth_m / room.wall_m_per_uv) * Room.ROOM_SIZE.y


func _draw() -> void:
	var recent := Run.ghosts.slice(-MARKS_SHOWN)
	var first_run := Run.ghosts.size() - recent.size() + 1
	for index: int in recent.size():
		var y := mark_y(recent[index])
		var tilt := 3.0 if index % 2 == 0 else -3.0
		draw_line(Vector2(LEFT, y - tilt), Vector2(RIGHT, y + tilt), CRAYON, LINE_WIDTH, true)
		var crowd := 0
		for earlier: int in index:
			if absf(mark_y(recent[earlier]) - y) < CROWDED_PX:
				crowd += 1
		draw_string(HAND, Vector2(LEFT - 26.0 - crowd * NUMBER_STEP, y + 8.0), str(first_run + index), HORIZONTAL_ALIGNMENT_LEFT, -1, NUMBER_SIZE, CRAYON)
