class_name TimeControl
extends CanvasLayer
## Tap T to jump between eras. Hold T to pause the world and scrub the years.

const HOLD_SECONDS := 0.22
const SCRIBBLE_SECONDS := 0.3

@onready var bar: Control = $Bar
@onready var slider: HSlider = $Bar/Slider
@onready var year_label: Label = $Bar/Year
@onready var scribble: ColorRect = $Scribble

var scrubbing: bool = false
var _held: float = 0.0
var _pressed: bool = false
var _moved: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bar.hide()
	scribble.hide()
	slider.min_value = WorldClock.ERAS[0]
	slider.max_value = WorldClock.ERAS[-1]
	slider.value_changed.connect(_on_slider_changed)
	WorldClock.jumped.connect(_on_jumped)


func _process(delta: float) -> void:
	if Input.is_action_pressed("time"):
		_pressed = true
		_held += delta
		if not scrubbing and _held >= HOLD_SECONDS:
			begin_scrub()
	elif _pressed:
		_pressed = false
		_held = 0.0
		if scrubbing:
			end_scrub()
		else:
			tap()


func tap() -> void:
	WorldClock.jump(WorldClock.next_era())


func begin_scrub() -> void:
	scrubbing = true
	_moved = false
	get_tree().paused = true
	slider.set_value_no_signal(WorldClock.year)
	year_label.text = str(roundi(WorldClock.year))
	bar.show()


func end_scrub() -> void:
	scrubbing = false
	bar.hide()
	get_tree().paused = false
	if _moved:
		WorldClock.jump(WorldClock.nearest_era())
	else:
		tap()


func _on_slider_changed(value: float) -> void:
	_moved = true
	year_label.text = str(roundi(value))
	WorldClock.scrub(value)


func _on_jumped(_to_year: int) -> void:
	scribble.show()
	scribble.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(scribble, "modulate:a", 0.0, SCRIBBLE_SECONDS)
	tween.tween_callback(scribble.hide)
