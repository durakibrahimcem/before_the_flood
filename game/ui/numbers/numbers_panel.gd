class_name NumbersPanel
extends Control
## A pinned scrap of paper with the numbers that matter, tracking the clock.

const WIDTH := 340.0
const BASE_HEIGHT := 190.0
const ROW_HEIGHT := 30.0
const LARGE_SCALE := 1.35
const DRY_BELOW_M := 0.05
const PULSE_SECONDS := 0.22
const RED_X := 40.0
const INK := Color(0.15, 0.125, 0.10)
const FADED := Color(0.15, 0.125, 0.10, 0.62)
const WARM_PAPER := Color(0.969, 0.937, 0.863)
const RULE_BLUE := Color(0.44, 0.56, 0.76, 0.75)
const MARGIN_RED := Color(0.79, 0.26, 0.22, 0.85)
const PIN_RED := Color(0.80, 0.22, 0.18)

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

var _hand := SystemFont.new()
var _scrap := StyleBoxFlat.new()
var _pulses: Dictionary = {}
var _pulse_next := false


func _ready() -> void:
	_hand.font_names = PackedStringArray(["Comic Sans MS", "Segoe Print", "Bradley Hand", "Comic Neue", "cursive"])
	_scrap.bg_color = WARM_PAPER
	_scrap.border_color = Color(INK, 0.35)
	_scrap.set_border_width_all(1)
	_scrap.set_corner_radius_all(3)
	_scrap.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	_scrap.shadow_size = 5
	_style_text()
	_apply_text_sizes()
	for box: Control in row_boxes:
		box.resized.connect(queue_redraw)
	dateline.resized.connect(queue_redraw)
	_fill(Sim.at(Run.plan, WorldClock.year))
	WorldClock.year_changed.connect(_on_year_changed)
	WorldClock.jumped.connect(_on_jumped)
	Settings.changed.connect(_apply_text_sizes)


func _draw() -> void:
	draw_style_box(_scrap, Rect2(Vector2.ZERO, size))
	var pin := Vector2(size.x * 0.5, 9.0)
	draw_circle(pin + Vector2(1.5, 2.5), 6.5, Color(0.0, 0.0, 0.0, 0.18))
	draw_circle(pin, 5.5, PIN_RED)
	draw_circle(pin - Vector2(1.5, 1.5), 1.8, Color(1.0, 0.9, 0.85, 0.6))
	draw_line(Vector2(RED_X, 8.0), Vector2(RED_X, size.y - 10.0), MARGIN_RED, 1.2)
	for box: Control in row_boxes:
		var y := box.global_position.y - global_position.y + box.size.y - 2.0
		draw_line(Vector2(RED_X + 10.0, y), Vector2(size.x - 8.0, y), RULE_BLUE, 1.0)


func _on_year_changed(state: WorldState) -> void:
	_fill(state)


## Arriving at an era pulses the ink; plain updates and scrub ticks stay quiet.
func _on_jumped(_to_year: int) -> void:
	_pulse_next = true


func _fill(state: WorldState) -> void:
	_set_value(dateline, str(roundi(state.year)))
	_set_value(homes, "%d of 3" % state.homes)
	_set_value(flood, _flood_text(float(state.flood_m.get("salon", 0.0))))
	_set_value(neighbours, "%d of 2" % state.neighbours)
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
	dateline.add_theme_font_size_override("font_size", roundi(14.0 * factor))
	homes.add_theme_font_size_override("font_size", roundi(17.0 * factor))
	flood.add_theme_font_size_override("font_size", roundi(17.0 * factor))
	neighbours.add_theme_font_size_override("font_size", roundi(17.0 * factor))
	for caption: Label in captions:
		caption.add_theme_font_size_override("font_size", roundi(16.0 * factor))
	for box: Control in row_boxes:
		box.custom_minimum_size = Vector2(0.0, roundi(ROW_HEIGHT * factor))
	custom_minimum_size = Vector2(WIDTH, roundi(BASE_HEIGHT * factor))
