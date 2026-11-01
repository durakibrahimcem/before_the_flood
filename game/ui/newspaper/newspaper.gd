class_name NewspaperOverlay
extends CanvasLayer
## The front page for an era. It pops up, gets read, and goes away quietly.

signal dismissed

const HINT := "Press E, Enter or click to continue"
const POPUP_YEARS: Array[int] = [2050, 2080]
const SHOW_SECONDS := 0.15
const SETTLE_SECONDS := 0.3
const SHADE_ALPHA := 0.45
## Ebru's page leaves one band for text, so large text grows less here than elsewhere.
const LARGE_SCALE := 1.2
const BAND_HEIGHT := 212.0
const BAND_WIDTH := 1360.0
## Room left on each line, because a balanced break rarely falls exactly in the middle.
const LINE_SLACK := 0.96
const SHEET_SPOT := Vector2(140, 110)
const DROP_FROM := Vector2(0, -36)
const DROP_TURN := -0.02
const INK := Color(0.15, 0.125, 0.10)
const MUTED := Color(0.45, 0.40, 0.34)
const HINT_INK := Color(0.96, 0.93, 0.85)
const HINT_OUTLINE := Color(0.15, 0.125, 0.10)

@export var auto_popup := true

@onready var shade: ColorRect = $Shade
@onready var sheet: Control = $Sheet
@onready var year: Label = $Sheet/Band/Year
@onready var headline: Label = $Sheet/Band/Headline
@onready var story: Label = $Sheet/Band/Story
@onready var hint: Label = $Hint

var _serif: Font = preload("res://ui/fonts/PlayfairDisplay.ttf")
var _tween: Tween


func _ready() -> void:
	_style_text()
	_apply_text_sizes()
	visible = false
	WorldClock.jumped.connect(_on_jumped)
	Settings.changed.connect(_apply_text_sizes)


## Puts the front page for an era on screen, replacing any page already up.
func show_for(plan: Plan, era: int) -> void:
	show_page(Newspapers.pick(plan, era), era)


func show_page(page: Dictionary, era: int) -> void:
	assert(is_node_ready(), "Add the overlay to the tree before showing a page")
	Sfx.play("paper")
	year.text = str(era)
	headline.text = str(page.get("headline", ""))
	story.text = balanced(str(page.get("story", "")))
	visible = true
	_play_show()


## Breaks a story into even lines, so no word is left alone on the last one.
func balanced(text: String) -> String:
	var wide := _serif.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, story.get_theme_font_size("font_size")).x
	var lines := ceili(wide / (BAND_WIDTH * LINE_SLACK))
	if lines < 2:
		return text
	var result := text
	for line: int in range(1, lines):
		var goal := roundi(float(text.length()) * line / lines)
		var space := _nearest_space(text, goal)
		result[space] = "\n"
	return result


func _nearest_space(text: String, goal: int) -> int:
	for reach: int in text.length():
		if goal + reach < text.length() and text[goal + reach] == " ":
			return goal + reach
		if goal - reach >= 0 and text[goal - reach] == " ":
			return goal - reach
	return goal


func _close() -> void:
	if _tween != null:
		_tween.kill()
	visible = false
	dismissed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _is_dismiss(event):
		return
	_close()
	get_viewport().set_input_as_handled()


func _is_dismiss(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER):
		return true
	var click := event as InputEventMouseButton
	return click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT


func _play_show() -> void:
	if _tween != null:
		_tween.kill()
	var calm := Settings.calm_storm
	shade.color.a = 0.0
	sheet.modulate.a = 0.0
	sheet.position = SHEET_SPOT + (Vector2.ZERO if calm else DROP_FROM)
	sheet.rotation = 0.0 if calm else DROP_TURN
	_tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT)
	_tween.tween_property(shade, "color:a", SHADE_ALPHA, SHOW_SECONDS)
	_tween.tween_property(sheet, "modulate:a", 1.0, SHOW_SECONDS)
	_tween.tween_property(sheet, "position", SHEET_SPOT, SETTLE_SECONDS).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(sheet, "rotation", 0.0, SETTLE_SECONDS).set_trans(Tween.TRANS_BACK)


func _on_jumped(to_year: int) -> void:
	if not auto_popup:
		return
	if to_year in POPUP_YEARS:
		show_for(Run.plan, to_year)
	elif visible:
		_close()


func _style_text() -> void:
	for label: Label in [year, headline, story, hint]:
		label.add_theme_font_override("font", _serif)
	for label: Label in [headline, story]:
		label.add_theme_color_override("font_color", INK)
	year.add_theme_color_override("font_color", MUTED)
	hint.add_theme_color_override("font_color", HINT_INK)
	hint.add_theme_color_override("font_outline_color", HINT_OUTLINE)
	hint.add_theme_constant_override("outline_size", 6)
	hint.text = HINT


func _apply_text_sizes() -> void:
	var factor := LARGE_SCALE if Settings.large_text else 1.0
	year.add_theme_font_size_override("font_size", roundi(24.0 * factor))
	headline.add_theme_font_size_override("font_size", roundi(44.0 * factor))
	story.add_theme_font_size_override("font_size", roundi(26.0 * factor))
	hint.add_theme_font_size_override("font_size", roundi(24.0 * factor))
