class_name ShareCard
extends Control
## Your plan code and a friend's code to load.

signal loaded(code: String)

const SHARE_LINE := "Share it, and a friend can walk your future."
const NO_CODE_LINE := "Finish all six choices to get a code of your own."
const BAD_CODE_MESSAGE := "That code doesn't match a plan. Check the three letters."
const LOADED_MESSAGE := "Loaded. Their future is ready."
const FADE_SECONDS := 0.35
## The code settles like the rank does; the rest follows it a breath later.
const ARRIVE_SECONDS := 0.32
const CODE_SETTLE_FROM := 0.98
const CODE_SETTLE_SECONDS := 0.45
const FOLLOW_STAGGER := 0.08

var _code: Label
var _line: Label
var _message: Label
var _edit: LineEdit
var _fade: Tween
var _enter_order: Array[Control] = []
var _entrance: Tween
# Plan.from_code is slow, so the codes are warmed one per frame and every
# answer is cached. Uncached text still validates through Plan.from_code.
var _cache: Dictionary = {}
var _warm_plans: Array[Plan] = []
var _warm_index := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := _wide_label("Title", "Your plan code", EndPalette.TITLE_SIZE, EndPalette.INK, 150, 226)
	add_child(title)
	_code = _wide_label("Code", "-", EndPalette.CODE_SIZE, EndPalette.INK, 258, 392)
	_line = _wide_label("Line", SHARE_LINE, 28, EndPalette.INK, 420, 470)
	Settings.size_text(_line, 34)
	add_child(_code)
	add_child(_line)
	_enter_order = [title, _code, _line]
	var band := CenterContainer.new()
	band.name = "RowCenter"
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.offset_top = 560.0
	band.offset_bottom = 720.0
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var friend := _label("FriendLabel", "A friend's code", EndPalette.BODY_SIZE, EndPalette.INK)
	Settings.size_text(friend, EndPalette.BODY_SIZE)
	_edit = LineEdit.new()
	_edit.name = "Edit"
	_edit.placeholder_text = "code"
	_edit.max_length = 6
	_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edit.custom_minimum_size = Vector2(240, 56)
	_edit.text_submitted.connect(_on_submit)
	var load_button := Button.new()
	load_button.name = "Load"
	load_button.text = "Load"
	load_button.focus_mode = Control.FOCUS_NONE
	load_button.custom_minimum_size = Vector2(150, 56)
	load_button.pressed.connect(_on_load_pressed)
	row.add_child(friend)
	row.add_child(_edit)
	row.add_child(load_button)
	band.add_child(row)
	add_child(band)
	_enter_order.append(band)
	_message = _wide_label("Message", "", EndPalette.BODY_SIZE, EndPalette.INK, 740, 806)
	_message.visible = false
	Settings.size_text(_message, EndPalette.BODY_SIZE)
	add_child(_message)


## Back to rest, so a quick skip leaves the card whole.
func rest_entrance() -> void:
	for node: Control in _enter_order:
		node.modulate.a = 1.0
	_code.scale = Vector2.ONE


## The title opens, the code settles, then the line and the friend's box follow.
func play_entrance() -> Tween:
	if _entrance != null and _entrance.is_valid():
		_entrance.kill()
	for node: Control in _enter_order:
		node.modulate.a = 0.0
	_code.pivot_offset = _code.size * 0.5
	_code.scale = Vector2.ONE * CODE_SETTLE_FROM
	_entrance = create_tween()
	_entrance.set_parallel(true)
	_entrance.tween_property(_enter_order[0], "modulate:a", 1.0, ARRIVE_SECONDS) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_entrance.tween_property(_code, "modulate:a", 1.0, ARRIVE_SECONDS).set_delay(FOLLOW_STAGGER) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_entrance.tween_property(_code, "scale", Vector2.ONE, CODE_SETTLE_SECONDS).set_delay(FOLLOW_STAGGER) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_entrance.tween_property(_line, "modulate:a", 1.0, ARRIVE_SECONDS).set_delay(FOLLOW_STAGGER * 2.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_entrance.tween_property(_enter_order[3], "modulate:a", 1.0, ARRIVE_SECONDS).set_delay(FOLLOW_STAGGER * 3.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	return _entrance


func set_code(code: String) -> void:
	_edit.text = ""
	_message.visible = false
	if code.is_empty():
		_code.text = "-"
		_line.text = NO_CODE_LINE
	else:
		_code.text = code
		_line.text = SHARE_LINE


func warm_ready() -> bool:
	return _warm_index >= _warm_plans.size() and not _warm_plans.is_empty()


func _process(_delta: float) -> void:
	if _warm_plans.is_empty():
		_warm_plans = Plan.all_plans()
		return
	if _warm_index >= _warm_plans.size():
		set_process(false)
		return
	var plan: Plan = _warm_plans[_warm_index]
	_cache[plan.code()] = plan
	_warm_index += 1


func _on_load_pressed() -> void:
	_on_submit(_edit.text)


func _on_submit(text: String) -> void:
	var wanted := text.strip_edges().to_upper()
	var plan: Plan = null
	if _cache.has(wanted):
		plan = _cache[wanted]
	else:
		plan = Plan.from_code(wanted)
		_cache[wanted] = plan
	if plan == null:
		_show_message(BAD_CODE_MESSAGE)
		return
	loaded.emit(wanted)
	_show_message(LOADED_MESSAGE)


func _show_message(text: String) -> void:
	_message.text = text
	_message.modulate.a = 0.0
	_message.visible = true
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_message, "modulate:a", 1.0, FADE_SECONDS)


func _label(label_name: String, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _wide_label(label_name: String, text: String, font_size: int, color: Color, top: int, bottom: int) -> Label:
	var label := _label(label_name, text, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.offset_top = top
	label.offset_bottom = bottom
	return label
