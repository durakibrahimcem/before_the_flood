class_name ControlsScreen
extends CanvasLayer
## The before-play screen: the keys, then Begin. Sits above the timeline HUD.

signal started

const LARGE_SCALE := 1.4
const KEYCAP_SIZE := Vector2(74, 74)
const KEYCAP_BASE := 30
const KEYCAP_TILT: Array[float] = [-2.5, 1.5, -1.0, 2.0, -1.5, 1.0, -2.0, 2.5]
const WALK_KEYS: Array[String] = ["W", "A", "S", "D"]
const USE_KEYS: Array[String] = ["E"]
const TIME_KEYS: Array[String] = ["T"]
const PAUSE_KEYS: Array[String] = ["Esc"]
## The share of the sheet the text takes, leaving the rest to Ebru's logo.
const TEXT_SHARE := 0.54

@onready var _sheet: Control = $Sheet
@onready var paper: TextureRect = $Sheet/Paper
@onready var _logo_frame: Control = $Sheet/Frame
@onready var _center: Control = $Sheet/Center
@onready var title_label: Label = $Sheet/Center/Column/Title
@onready var subtitle_label: Label = $Sheet/Center/Column/Subtitle
@onready var begin_button: Button = $Sheet/Center/Column/Begin
@onready var hint_walk: Label = $Sheet/Center/Column/Rows/WalkRow/hint_walk
@onready var hint_use: Label = $Sheet/Center/Column/Rows/UseRow/hint_use
@onready var hint_time: Label = $Sheet/Center/Column/Rows/TimeRow/hint_time
@onready var hint_pause: Label = $Sheet/Center/Column/Rows/PauseRow/hint_pause
@onready var _walk_keys: HBoxContainer = $Sheet/Center/Column/Rows/WalkRow/WalkKeys
@onready var _use_keys: HBoxContainer = $Sheet/Center/Column/Rows/UseRow/UseKeys
@onready var _time_keys: HBoxContainer = $Sheet/Center/Column/Rows/TimeRow/TimeKeys
@onready var _pause_keys: HBoxContainer = $Sheet/Center/Column/Rows/PauseRow/PauseKeys

## Keycap letters in order: W A S D, E, T, Esc.
var keycap_labels: Array[Label] = []
var _armed: bool = true
var _sized: Array[Control] = []
var _bases: Array[int] = []


func _ready() -> void:
	_sheet.theme = CrayonUI.build_theme()
	paper.texture = CrayonUI.paper_texture()
	title_label.rotation_degrees = -1.5
	_fill_keys(_walk_keys, WALK_KEYS)
	_fill_keys(_use_keys, USE_KEYS)
	_fill_keys(_time_keys, TIME_KEYS)
	_fill_keys(_pause_keys, PAUSE_KEYS)
	_track(title_label, 84)
	_track(subtitle_label, 32)
	_track(hint_walk, 38)
	_track(hint_use, 38)
	_track(hint_time, 38)
	_track(hint_pause, 38)
	_track(begin_button, 38)
	Settings.changed.connect(_apply_text_sizes)
	begin_button.pressed.connect(_on_begin_pressed)
	_apply_text_sizes()
	begin_button.grab_focus()


func open() -> void:
	## Show the screen again after a start, with focus back on Begin.
	visible = true
	_armed = true
	_apply_text_sizes()
	begin_button.grab_focus()


func _fill_keys(row: HBoxContainer, keys: Array[String]) -> void:
	for key: String in keys:
		var tilt := KEYCAP_TILT[keycap_labels.size() % KEYCAP_TILT.size()]
		row.add_child(_make_keycap(key, tilt))


func _make_keycap(text: String, tilt_degrees: float) -> Panel:
	var cap := Panel.new()
	cap.custom_minimum_size = KEYCAP_SIZE
	cap.rotation_degrees = tilt_degrees
	var letter := Label.new()
	letter.text = text
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.set_anchors_preset(Control.PRESET_FULL_RECT)
	cap.add_child(letter)
	keycap_labels.append(letter)
	_track(letter, KEYCAP_BASE)
	return cap


func _on_begin_pressed() -> void:
	if not _armed:
		return
	_armed = false
	visible = false
	started.emit()


func _apply_text_sizes() -> void:
	var factor := LARGE_SCALE if Settings.large_text else 1.0
	for i: int in _sized.size():
		_sized[i].add_theme_font_size_override("font_size", int(round(_bases[i] * factor)))
	# Larger text needs the whole sheet, so the logo steps aside.
	_logo_frame.visible = not Settings.large_text
	_center.anchor_right = 1.0 if Settings.large_text else TEXT_SHARE


func _track(control: Control, base_size: int) -> void:
	_sized.append(control)
	_bases.append(base_size)
