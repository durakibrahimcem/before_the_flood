class_name NumbersPanel
extends Control
## Ebru's notebook with the numbers that matter, tracking the clock.

const NOTEBOOK := preload("res://ui/numbers/notebook.png")
## Big enough to read, and small enough to sit on the wall like a note in every room.
const PAGE_SIZE := Vector2(352, 220)
## Where the writing goes on her page, under the rings.
const ROWS_SPOT := Vector2(20, 24)
const ROWS_SIZE := Vector2(316, 186)
## The year sits right after the "Date:" she drew.
const DATE_INDENT := 74.0
const ROW_HEIGHT := 36.0
const LARGE_SCALE := 1.3
const DRY_BELOW_M := 0.05
const PULSE_SECONDS := 0.22
const INK := Color(0.15, 0.125, 0.10)
const FADED := Color(0.15, 0.125, 0.10, 0.72)

@onready var rows: VBoxContainer = $Rows
@onready var dateline: Label = $Rows/Dateline
@onready var homes: Label = $Rows/Homes/Value
@onready var flood: Label = $Rows/Flood/Value
@onready var neighbours: Label = $Rows/Neighbours/Value
@onready var captions: Array[Label] = [
	$Rows/Homes/Caption as Label,
	$Rows/Flood/Caption as Label,
	$Rows/Neighbours/Caption as Label,
]
@onready var row_boxes: Array[Control] = [
	$Rows/Homes as Control,
	$Rows/Flood as Control,
	$Rows/Neighbours as Control,
]

var _hand: Font = preload("res://ui/fonts/Caveat.ttf")
var _date_gap := StyleBoxEmpty.new()
var _pulses: Dictionary = {}
var _pulse_next := false


func _ready() -> void:
	dateline.add_theme_stylebox_override("normal", _date_gap)
	_style_text()
	_apply_text_sizes()
	_fill(Sim.at(Run.plan, WorldClock.year))
	WorldClock.year_changed.connect(_on_year_changed)
	WorldClock.jumped.connect(_on_jumped)
	Settings.changed.connect(_apply_text_sizes)


func _draw() -> void:
	draw_texture_rect(NOTEBOOK, Rect2(Vector2.ZERO, size), false)


func _on_year_changed(state: WorldState) -> void:
	_fill(state)


## Arriving at an era pulses the ink; plain updates and scrub ticks stay quiet.
func _on_jumped(_to_year: int) -> void:
	_pulse_next = true


func _fill(state: WorldState) -> void:
	_set_value(dateline, str(roundi(state.year)))
	_set_value(homes, "%d of %d" % [state.homes, Sim.ALL_HOMES])
	_set_value(flood, _flood_text(float(state.flood_m.get("salon", 0.0))))
	_set_value(neighbours, "yes" if state.neighbours > 0 else "no")
	_pulse_next = false


func _flood_text(depth_m: float) -> String:
	return "dry" if depth_m < DRY_BELOW_M else "%.1f m" % depth_m


func _set_value(label: Label, text: String) -> void:
	if label.text == text:
		return
	label.text = text
	if _pulses.has(label):
		(_pulses[label] as Tween).kill()
		_pulses.erase(label)
	if not _pulse_next:
		label.modulate.a = 1.0
		return
	label.modulate.a = 0.45
	var pulse := create_tween()
	pulse.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	pulse.tween_property(label, "modulate:a", 1.0, PULSE_SECONDS)
	_pulses[label] = pulse


func _style_text() -> void:
	for label: Label in [dateline, homes, flood, neighbours]:
		label.add_theme_font_override("font", _hand)
	dateline.add_theme_color_override("font_color", FADED)
	homes.add_theme_color_override("font_color", INK)
	flood.add_theme_color_override("font_color", INK)
	neighbours.add_theme_color_override("font_color", INK)
	for caption: Label in captions:
		caption.add_theme_font_override("font", _hand)
		caption.add_theme_color_override("font_color", FADED)


func _apply_text_sizes() -> void:
	var factor := LARGE_SCALE if Settings.large_text else 1.0
	dateline.add_theme_font_size_override("font_size", roundi(30.0 * factor))
	homes.add_theme_font_size_override("font_size", roundi(31.0 * factor))
	flood.add_theme_font_size_override("font_size", roundi(31.0 * factor))
	neighbours.add_theme_font_size_override("font_size", roundi(31.0 * factor))
	for caption: Label in captions:
		caption.add_theme_font_size_override("font_size", roundi(29.0 * factor))
	for box: Control in row_boxes:
		box.custom_minimum_size = Vector2(0.0, roundi(ROW_HEIGHT * factor))
	_date_gap.content_margin_left = DATE_INDENT * factor
	custom_minimum_size = PAGE_SIZE * factor
	size = custom_minimum_size
	rows.position = ROWS_SPOT * factor
	rows.size = ROWS_SIZE * factor
