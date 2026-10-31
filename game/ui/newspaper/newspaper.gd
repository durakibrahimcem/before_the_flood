class_name NewspaperOverlay
extends CanvasLayer
## The front page for an era. It pops up, gets read, and goes away quietly.

signal dismissed

const MASTHEAD := "The Bay Herald"
const HINT := "Press E, Enter or click to continue"
const POPUP_YEARS: Array[int] = [2050, 2080]
const SHOW_SECONDS := 0.15
const SHADE_ALPHA := 0.45
const LARGE_SCALE := 1.35
const INK := Color(0.15, 0.125, 0.10)
const PAPER := Color(0.949, 0.918, 0.855)
const MUTED := Color(0.45, 0.40, 0.34)

@export var auto_popup := true
## Ebru's art drops in here by the picture key from the data files.
@export var pictures: Dictionary[String, Texture2D] = {}

@onready var shade: ColorRect = $Shade
@onready var sheet: PanelContainer = $Center/Sheet
@onready var masthead: Label = $Center/Sheet/Margins/Column/Masthead
@onready var year: Label = $Center/Sheet/Margins/Column/Year
@onready var headline: Label = $Center/Sheet/Margins/Column/Headline
@onready var story: Label = $Center/Sheet/Margins/Column/Story
@onready var hint: Label = $Center/Sheet/Margins/Column/Hint
@onready var picture: CrayonPicture = $Center/Sheet/Margins/Column/Picture

var _serif: Font = preload("res://ui/fonts/PlayfairDisplay.ttf")
var _tween: Tween


func _ready() -> void:
	_style_sheet()
	_style_text()
	_apply_text_sizes()
	visible = false
	WorldClock.jumped.connect(_on_jumped)
	Settings.changed.connect(_apply_text_sizes)


## Puts the front page for an era on screen, replacing any page already up.
func show_for(plan: Plan, era: int) -> void:
	assert(is_node_ready(), "Add the overlay to the tree before showing a page")
	Sfx.play("paper")
	var page := Newspapers.pick(plan, era)
	masthead.text = MASTHEAD
	year.text = str(era)
	headline.text = str(page.get("headline", ""))
	story.text = str(page.get("story", ""))
	var picture_key := str(page.get("picture", ""))
	picture.key = picture_key
	picture.art = pictures.get(picture_key) as Texture2D
	picture.queue_redraw()
	visible = true
	_play_show()


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
	shade.color.a = 0.0
	sheet.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(shade, "color:a", SHADE_ALPHA, SHOW_SECONDS)
	_tween.parallel().tween_property(sheet, "modulate:a", 1.0, SHOW_SECONDS)


func _on_jumped(to_year: int) -> void:
	if not auto_popup:
		return
	if to_year in POPUP_YEARS:
		show_for(Run.plan, to_year)
	elif visible:
		_close()


func _style_sheet() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER
	box.border_color = Color(INK, 0.3)
	box.set_border_width_all(1)
	box.set_corner_radius_all(1)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	box.shadow_size = 10
	sheet.add_theme_stylebox_override("panel", box)


func _style_text() -> void:
	for label: Label in [masthead, year, headline, story, hint]:
		label.add_theme_font_override("font", _serif)
	for label: Label in [masthead, year, headline, story]:
		label.add_theme_color_override("font_color", INK)
	hint.add_theme_color_override("font_color", MUTED)
	hint.text = HINT


func _apply_text_sizes() -> void:
	var factor := LARGE_SCALE if Settings.large_text else 1.0
	masthead.add_theme_font_size_override("font_size", roundi(48.0 * factor))
	year.add_theme_font_size_override("font_size", roundi(32.0 * factor))
	headline.add_theme_font_size_override("font_size", roundi(30.0 * factor))
	story.add_theme_font_size_override("font_size", roundi(22.0 * factor))
	hint.add_theme_font_size_override("font_size", roundi(14.0 * factor))
