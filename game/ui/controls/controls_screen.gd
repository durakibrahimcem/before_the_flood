class_name ControlsScreen
extends CanvasLayer
## The before-play screen: the keys, then Begin. Sits above the timeline HUD.

signal started

const LARGE_SCALE := 1.4
const KEYCAP_SIZE := Vector2(58, 58)
const KEYCAP_BASE := 20
const KEYCAP_TILT: Array[float] = [-2.5, 1.5, -1.0, 2.0, -1.5, 1.0, -2.0, 2.5]
const WALK_KEYS: Array[String] = ["W", "A", "S", "D"]
const USE_KEYS: Array[String] = ["E"]
const TIME_KEYS: Array[String] = ["T"]
const SCRUB_KEYS: Array[String] = ["T"]
const PAUSE_KEYS: Array[String] = ["Esc"]

@onready var _sheet: Control = $Sheet
@onready var paper: TextureRect = $Sheet/Paper
@onready var title_label: Label = $Sheet/Center/Column/Title
@onready var subtitle_label: Label = $Sheet/Center/Column/Subtitle
@onready var begin_button: Button = $Sheet/Center/Column/Begin
@onready var hint_walk: Label = $Sheet/Center/Column/Rows/WalkRow/hint_walk
@onready var hint_use: Label = $Sheet/Center/Column/Rows/UseRow/hint_use
@onready var hint_time: Label = $Sheet/Center/Column/Rows/TimeRow/hint_time
@onready var hint_scrub: Label = $Sheet/Center/Column/Rows/ScrubRow/hint_scrub
@onready var hint_pause: Label = $Sheet/Center/Column/Rows/PauseRow/hint_pause
@onready var _walk_keys: HBoxContainer = $Sheet/Center/Column/Rows/WalkRow/WalkKeys
@onready var _use_keys: HBoxContainer = $Sheet/Center/Column/Rows/UseRow/UseKeys
@onready var _time_keys: HBoxContainer = $Sheet/Center/Column/Rows/TimeRow/TimeKeys
@onready var _scrub_keys: HBoxContainer = $Sheet/Center/Column/Rows/ScrubRow/ScrubKeys
@onready var _pause_keys: HBoxContainer = $Sheet/Center/Column/Rows/PauseRow/PauseKeys

## Keycap letters in order: W A S D, E, T, T, Esc.
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
	_fill_keys(_scrub_keys, SCRUB_KEYS)
	_fill_keys(_pause_keys, PAUSE_KEYS)
	_track(title_label, 64)
	_track(subtitle_label, 24)
	_track(hint_walk, 26)
	_track(hint_use, 26)
	_track(hint_time, 26)
	_track(hint_scrub, 26)
	_track(hint_pause, 26)
	_track(begin_button, 30)
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


func _track(control: Control, base_size: int) -> void:
	_sized.append(control)
	_bases.append(base_size)
