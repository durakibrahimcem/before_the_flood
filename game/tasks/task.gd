class_name Task
extends Node2D
## Base class for the six hands-on actions.

signal finished(performance: float)

const REPEAT_GROWTH := 0.25
## How strongly a task's instruction stays on screen once it has been read.
const REMINDER_ALPHA := 0.7

@export var action: String = ""

var repeat_index: int = 0
var _done: bool = false


## auto_finish skips the task at normal strength, for fast replays.
func start(repeat: int, auto_finish: bool) -> void:
	repeat_index = repeat
	if auto_finish:
		complete.call_deferred(0.0)
	else:
		_begin()


## Each repeat raises the target count by 25 percent.
func target_count(base: int) -> int:
	return ceili(base * (1.0 + REPEAT_GROWTH * repeat_index))


## More to do on a repeat means more time, at the same rate as the target count.
func target_time(base_seconds: float) -> float:
	return base_seconds * (1.0 + REPEAT_GROWTH * repeat_index)


func complete(performance: float) -> void:
	if _done:
		return
	_done = true
	Sfx.play("chime")
	finished.emit(clampf(performance, 0.0, 1.0))


## Override this to start the task.
func _begin() -> void:
	pass


## The score in words, for the verdict card, such as "6 of 8 sorted".
func result_text() -> String:
	return ""


## The instruction on screen. It stays readable for the whole task.
func instruction() -> CanvasItem:
	return null


## Progress for browser tests, reported in debug Web builds only.
func debug_note() -> String:
	return ""
