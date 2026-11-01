class_name TimeControl
extends CanvasLayer
## Tap T to jump between eras. Hold T to pause the world and scrub the years.

const HOLD_SECONDS := 0.22
const SCRIBBLE_SECONDS := 0.34
## While T is held, the mouse or the walking keys scrub, with no need to grab the slider.
const YEARS_PER_PIXEL := 54.0 / 1620.0
const YEARS_PER_SECOND := 30.0
## The year lands big after a jump, in that era's crayon.
const STAMP_SPOT := Vector2(0, 20)
const STAMP_SIZE := Vector2(1920, 240)
const STAMP_FONT := preload("res://ui/fonts/Caveat.ttf")
const STAMP_LAND_SECONDS := 0.3
const STAMP_HOLD_SECONDS := 0.65
const STAMP_FADE_SECONDS := 0.45
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
var stamp: Label
var _stamp_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bar.hide()
	scribble.hide()
	slider.min_value = WorldClock.ERAS[0]
	slider.max_value = WorldClock.ERAS[-1]
	slider.value_changed.connect(_on_slider_changed)
	_build_stamp()
	WorldClock.jumped.connect(_on_jumped)


func _process(delta: float) -> void:
	# Debug Web builds report state in the tab title, so browser tests can read it without touching the page.
	if OS.is_debug_build() and OS.has_feature("web"):
		JavaScriptBridge.eval("document.title = '%s'" % _debug_title())
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


## The tab title is the debug protocol for browser tests: one line with the visible
## screens, the plan, the settings and whatever sits under the mouse. Debug Web only.
func _debug_title() -> String:
	var main := get_parent() as Main
	var where := "none 0 0"
	var task := "none"
	var pause := false
	var pause_menu := main.get_node_or_null("Pause")
	if pause_menu != null:
		pause = pause_menu.visible
	if main.room != null:
		where = "%s %d %d" % [main.room.room_name, main.arda.position.x, main.arda.position.y]
	if main.task != null:
		task = "%s %s" % [main.task.action, main.task.debug_note()]
	var counts: PackedStringArray = []
	for action: String in Plan.ACTIONS:
		counts.append(str(Run.plan.counts[action]))
	var hover := "none"
	var rect := "0,0,0,0"
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null:
		hover = hovered.name
		var box := hovered.get_global_rect()
		rect = "%d,%d,%d,%d" % [box.position.x, box.position.y, box.size.x, box.size.y]
	var focus := "none"
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focus = focused.name
	return format_title({
		"year": WorldClock.year, "scrub": scrubbing, "where": where, "task": task,
		"cal": main.calendar.visible, "news": main.newspaper.visible, "pause": pause,
		"ctrl": main.controls.visible, "end": main.ending.visible,
		"step": main.ending.step_index(), "verdict": main._verdict.word() != "",
		"day": Run.day, "plan": ",".join(counts), "ghosts": Run.ghosts.size(),
		"fed": Run.fed_today(), "final": main.final_walk, "frozen": main.arda.frozen,
		"calm": Settings.calm_storm, "large": Settings.large_text, "vol": Settings.volume,
		"hover": hover, "rect": rect, "focus": focus,
	})


## The one format every browser test parses. Bool values must be cast to int,
## because GDScript's %d rejects a bool and the whole title would go out raw.
static func format_title(v: Dictionary) -> String:
	return "YEAR %.1f SCRUB %d ROOM %s TASK %s | CAL %d NEWS %d PAUSE %d CTRL %d END %d STEP %d VERDICT %d DAY %d PLAN %s GHOSTS %d FED %d FINAL %d FROZEN %d CALM %d LARGE %d VOL %.2f HOVER %s RECT %s FOCUS %s" % [
		v["year"],
		int(v["scrub"]),
		v["where"],
		v["task"],
		int(v["cal"]),
		int(v["news"]),
		int(v["pause"]),
		int(v["ctrl"]),
		int(v["end"]),
		v["step"],
		int(v["verdict"]),
		v["day"],
		v["plan"],
		v["ghosts"],
		int(v["fed"]),
		int(v["final"]),
		int(v["frozen"]),
		int(v["calm"]),
		int(v["large"]),
		v["vol"],
		v["hover"],
		v["rect"],
		v["focus"],
	]


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
	_hold_stamp()


func end_scrub() -> void:
	scrubbing = false
	bar.hide()
	get_tree().paused = false
	_kill_stamp()
	_stamp_tween = create_tween()
	_stamp_tween.tween_property(stamp, "modulate:a", 0.0, STAMP_FADE_SECONDS)
	WorldClock.jump(WorldClock.nearest_era())


## Esc during a scrub lands on the nearest era first, so releasing T can't close the pause menu.
func stop_scrub() -> void:
	if scrubbing:
		end_scrub()


func _on_slider_changed(value: float) -> void:
	year_label.text = str(roundi(value))
	WorldClock.scrub(value)
	if scrubbing:
		_write_stamp(value)


func _on_jumped(to_year: int) -> void:
	Sfx.play("scribble")
	_stamp_year(to_year)
	var strokes := scribble.material as ShaderMaterial
	strokes.set_shader_parameter("crayon", ERA_CRAYONS[to_year])
	strokes.set_shader_parameter("progress", 0.0)
	scribble.show()
	if _scribble_tween != null and _scribble_tween.is_valid():
		_scribble_tween.kill()
	_scribble_tween = create_tween()
	_scribble_tween.tween_property(strokes, "shader_parameter/progress", 1.0, SCRIBBLE_SECONDS)
	_scribble_tween.tween_callback(scribble.hide)


func _build_stamp() -> void:
	stamp = Label.new()
	stamp.name = "Stamp"
	stamp.position = STAMP_SPOT
	stamp.size = STAMP_SIZE
	stamp.pivot_offset = STAMP_SIZE * 0.5
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.add_theme_font_override("font", STAMP_FONT)
	stamp.add_theme_font_size_override("font_size", 190)
	stamp.add_theme_color_override("font_outline_color", Color(0.98, 0.95, 0.88))
	stamp.add_theme_constant_override("outline_size", 22)
	stamp.modulate.a = 0.0
	add_child(stamp)


func _kill_stamp() -> void:
	if _stamp_tween != null and _stamp_tween.is_valid():
		_stamp_tween.kill()


func _hold_stamp() -> void:
	_kill_stamp()
	stamp.scale = Vector2.ONE
	stamp.modulate.a = 1.0
	_write_stamp(WorldClock.year)


func _write_stamp(year: float) -> void:
	stamp.text = str(roundi(year))
	stamp.add_theme_color_override("font_color", _crayon_at(year))


func _crayon_at(year: float) -> Color:
	var eras: Array = WorldClock.ERAS
	var later := 1 if year <= eras[1] else 2
	var share := inverse_lerp(float(eras[later - 1]), float(eras[later]), year)
	return ERA_CRAYONS[eras[later - 1]].lerp(ERA_CRAYONS[eras[later]], share)


func _stamp_year(to_year: int) -> void:
	_kill_stamp()
	_write_stamp(to_year)
	stamp.modulate.a = 0.0
	stamp.scale = Vector2(1.3, 1.3)
	_stamp_tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT)
	_stamp_tween.tween_property(stamp, "modulate:a", 1.0, STAMP_LAND_SECONDS * 0.5)
	_stamp_tween.tween_property(stamp, "scale", Vector2.ONE, STAMP_LAND_SECONDS).set_trans(Tween.TRANS_BACK)
	_stamp_tween.chain().tween_interval(STAMP_HOLD_SECONDS)
	_stamp_tween.chain().tween_property(stamp, "modulate:a", 0.0, STAMP_FADE_SECONDS)
