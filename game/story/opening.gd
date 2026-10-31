class_name Opening
extends Node
## The first minute: a happy morning, Arda's drawing, the flood, and the way back.

signal finished

const DRAW_SPOT := Vector2(722, 560)
const DRAW_REACH := 240.0
const GREETING_SECONDS := 2.5
const CAPTION_SECONDS := 1.2

var main: Main
var _can_draw: bool = false
var _drew: bool = false


func play() -> void:
	main.time.enabled = false
	main.hint.text = "Morning, Arda! Brian wants to play."
	await get_tree().create_timer(GREETING_SECONDS).timeout
	main.hint.text = "Walk to the crayon sun, and press E to draw."
	_can_draw = true
	while not _drew:
		await get_tree().process_frame
	_can_draw = false
	main.hint.text = "\"My house when I'm big.\""
	await get_tree().create_timer(CAPTION_SECONDS).timeout
	main.hint.text = ""
	main.time.enabled = true
	WorldClock.jump(WorldClock.ERAS[2])
	await main.newspaper.dismissed
	main.hint.text = "This is what happens if nothing changes. Hold T, and drag back to today."
	while not is_equal_approx(WorldClock.year, WorldClock.ERAS[0]) or main.time.scrubbing:
		await get_tree().process_frame
	main.hint.text = "It isn't too late. Go to the salon, and open the calendar on the fridge."
	finished.emit()


func draw_now() -> void:
	Sfx.play("scribble")
	_drew = true


func _unhandled_input(event: InputEvent) -> void:
	if _can_draw and event.is_action_pressed("interact") and main.arda.position.distance_to(DRAW_SPOT) <= DRAW_REACH:
		get_viewport().set_input_as_handled()
		draw_now()
