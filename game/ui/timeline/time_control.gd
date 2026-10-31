class_name TimeControl
extends CanvasLayer
## Tap T to jump between eras. Hold T to pause the world and scrub the years.

const HOLD_SECONDS := 0.22
const SCRIBBLE_SECONDS := 0.34
## While T is held, the mouse or the walking keys scrub, with no need to grab the slider.
const YEARS_PER_PIXEL := 54.0 / 1620.0
const YEARS_PER_SECOND := 30.0
const ERA_CRAYONS := {
	2026: Color(0.96, 0.75, 0.32),
	2050: Color(0.27, 0.56, 0.6),
	2080: Color(0.15, 0.3, 0.42),
}

@onready var bar: Control = $Bar
@onready var slider: HSlider = $Bar/Slider
@onready var year_label: Label = $Bar/Year
@onready var scribble: ColorRect = $Scribble

## Off while a task or screen has the player's attention.
var enabled: bool = true
var scrubbing: bool = false
var _held: float = 0.0
var _pressed: bool = false
var _scribble_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bar.hide()
	scribble.hide()
	slider.min_value = WorldClock.ERAS[0]
	slider.max_value = WorldClock.ERAS[-1]
	slider.value_changed.connect(_on_slider_changed)
	WorldClock.jumped.connect(_on_jumped)


func _process(delta: float) -> void:
	# Debug Web builds report state in the tab title, so browser tests can read it without touching the page.
	if OS.is_debug_build() and OS.has_feature("web"):
		var main := get_parent() as Main
		var where := "%s %d %d" % [main.room.room_name, main.arda.position.x, main.arda.position.y] if main.room != null else "none 0 0"
		var task := main.task.action + " " + main.task.debug_note() if main.task != null else "none"
		JavaScriptBridge.eval("document.title = 'YEAR %.1f SCRUB %s ROOM %s TASK %s'" % [WorldClock.year, scrubbing, where, task])
	if not enabled or (get_tree().paused and not scrubbing):
		_pressed = false
		_held = 0.0
		return
	if Input.is_action_pressed("time"):
		_pressed = true
		_held += delta
		if not scrubbing and _held >= HOLD_SECONDS:
			begin_scrub()
		if scrubbing:
			_scrub_by(Input.get_axis("move_left", "move_right") * YEARS_PER_SECOND * delta)
	elif _pressed:
		_pressed = false
		_held = 0.0
		if scrubbing:
			end_scrub()
		else:
			tap()


func _input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if scrubbing and motion != null and motion.button_mask == 0:
		_scrub_by(motion.relative.x * YEARS_PER_PIXEL)


func _scrub_by(years: float) -> void:
	if years != 0.0:
		slider.value = clampf(WorldClock.year + years, slider.min_value, slider.max_value)


func tap() -> void:
	WorldClock.jump(WorldClock.next_era())


func begin_scrub() -> void:
	scrubbing = true
	get_tree().paused = true
	slider.set_value_no_signal(WorldClock.year)
	year_label.text = str(roundi(WorldClock.year))
	bar.show()


func end_scrub() -> void:
	scrubbing = false
	bar.hide()
	get_tree().paused = false
	WorldClock.jump(WorldClock.nearest_era())


func _on_slider_changed(value: float) -> void:
	year_label.text = str(roundi(value))
	WorldClock.scrub(value)


func _on_jumped(to_year: int) -> void:
	Sfx.play("scribble")
	var strokes := scribble.material as ShaderMaterial
	strokes.set_shader_parameter("crayon", ERA_CRAYONS[to_year])
	strokes.set_shader_parameter("progress", 0.0)
	scribble.show()
	if _scribble_tween != null and _scribble_tween.is_valid():
		_scribble_tween.kill()
	_scribble_tween = create_tween()
	_scribble_tween.tween_property(strokes, "shader_parameter/progress", 1.0, SCRIBBLE_SECONDS)
	_scribble_tween.tween_callback(scribble.hide)
