class_name Opening
extends Node
## The first minute: a happy morning, Arda's drawing, the flood, and the way back.

signal finished

const DRAW_SPOT := Vector2(722, 560)
const DRAW_REACH := 240.0
const DRAW_PROMPT := "Press E to draw"
const DRAW_PROMPT_SPOT := Vector2(600, 270)
const GREETING_SECONDS := 2.5
const CAPTION_SECONDS := 2.7
## Ebru's drawing drops in here. Until then the crayon house from the start screen stands in.
const DRAWING_PATH := "res://ui/my_house.png"
const DRAWING_SIZE := Vector2(760, 640)
const DRAWING_FADE_SECONDS := 0.3
const SKIP_NOTE := "Press Tab to skip this."
const TODAY_LINE := "Go to the salon, and open the calendar on the fridge."

var main: Main
var _can_draw: bool = false
var _drew: bool = false


func play() -> void:
	main.time.enabled = false
	_say("Morning, Arda! Brian the dog is waiting for breakfast.")
	await get_tree().create_timer(GREETING_SECONDS).timeout
	_say("Walk to the crayon sun, and press E to draw.")
	_can_draw = true
	while not _drew:
		await get_tree().process_frame
	_can_draw = false
	main.hint.text = "\"My house when I'm big.\""
	main.arda.frozen = true
	var drawing := _show_drawing()
	await get_tree().create_timer(CAPTION_SECONDS).timeout
	drawing.queue_free()
	main.arda.frozen = false
	main.hint.text = ""
	main.time.enabled = true
	WorldClock.jump(WorldClock.ERAS[2])
	await main.newspaper.dismissed
	main.hint.text = "This is what happens if nothing changes. Hold T, and move the mouse left, back to today."
	while not is_equal_approx(WorldClock.year, WorldClock.ERAS[0]) or main.time.scrubbing:
		await get_tree().process_frame
	main.hint.text = "It isn't too late. %s" % TODAY_LINE
	finished.emit()


## Someone back for another go shouldn't have to sit through the morning again.
func _say(line: String) -> void:
	main.hint.text = "%s %s" % [line, SKIP_NOTE] if main.is_replay() else line


func skip() -> void:
	main.hint.text = TODAY_LINE
	main.time.enabled = true
	finished.emit()


func _process(_delta: float) -> void:
	if _can_draw and _in_reach():
		main.offer_prompt(DRAW_PROMPT, DRAW_PROMPT_SPOT)


func _in_reach() -> bool:
	return main.arda.position.distance_to(DRAW_SPOT) <= DRAW_REACH


func _show_drawing() -> Control:
	var card := PanelContainer.new()
	card.name = "Drawing"
	card.add_theme_stylebox_override("panel", CrayonUI.style_panel())
	card.size = DRAWING_SIZE
	card.position = Vector2((Room.ROOM_SIZE.x - DRAWING_SIZE.x) * 0.5, 170.0)
	card.rotation_degrees = -1.5
	var art := CrayonArt.new()
	if ResourceLoader.exists(DRAWING_PATH):
		art.art = load(DRAWING_PATH)
	card.add_child(art)
	var layer := main.get_node("Ui")
	layer.add_child(card)
	layer.move_child(card, 0)
	card.modulate.a = 0.0
	card.create_tween().tween_property(card, "modulate:a", 1.0, DRAWING_FADE_SECONDS)
	return card


func draw_now() -> void:
	Sfx.play("scribble")
	_drew = true


func _unhandled_input(event: InputEvent) -> void:
	if not _drew and event.is_action_pressed("skip") and main.is_replay():
		get_viewport().set_input_as_handled()
		skip()
	elif _can_draw and event.is_action_pressed("interact") and _in_reach():
		get_viewport().set_input_as_handled()
		draw_now()
