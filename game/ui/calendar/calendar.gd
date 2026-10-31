class_name Calendar
extends Control
## Arda's week as a crayon drawing. The caller opens it, listens for
## action_chosen, runs the task, and records. This screen never records.

signal action_chosen(action: String)

const NAMES := {
	"grass": "Seagrass",
	"dune": "Dunes",
	"sort": "Sort waste",
	"light": "Lights",
	"meet": "Meeting",
	"wall": "Seawall",
}
const TIPS := {
	"grass": "Plant seagrass in the shallows.",
	"dune": "Plant the thin spots on the dunes.",
	"sort": "Carry each item to its bin.",
	"light": "Switch off the lights.",
	"meet": "Talk with the neighbours.",
	"wall": "Stack the big blocks.",
}
const BASE_TITLE_FONT := 46
const BASE_HINT_FONT := 24
const BASE_DAY_FONT := 24
const BASE_CAPTION_FONT := 20
const BASE_BADGE_FONT := 15
## Presses that travel further than this count as drags, not clicks.
const CLICK_SLOP := 12.0

@export var paper: Texture2D
## Ebru's art, one per action, in Plan.ACTIONS order. Editing the
## scene is enough: empty entries fall back to the code glyphs.
@export var arts: Array[Texture2D] = []

var dragging: bool = false
var drag_action: String = ""
var title_label: Label = null
var hint_label: Label = null
var ghost: DragGhost = null

var _slots: Array[DaySlot] = []
var _day_labels: Array[Label] = []
var _drawings: Dictionary = {}
var _history: Array[String] = []
var _open_slot: DaySlot = null
var _drag_drawing: ActionDrawing = null
var _press_position := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	Settings.changed.connect(_on_settings_changed)
	Run.plan_changed.connect(_on_plan_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_end_drag()


func _process(_delta: float) -> void:
	## Self-heal a drag whose release never arrived, as can happen on the web.
	if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_end_drag()


func open() -> void:
	_refresh()
	_apply_text_size()
	show()


func close() -> void:
	_end_drag()
	hide()


## Day and index are 1-based, like the labels: slot(2, 1) is day 2, slot 1.
func slot(day: int, index: int) -> DaySlot:
	if day < 1 or day > Run.DAYS or index < 1 or index > Run.SLOTS_PER_DAY:
		return null
	return _slots[(day - 1) * Run.SLOTS_PER_DAY + index - 1]


func drawing(action: String) -> ActionDrawing:
	return _drawings.get(action) as ActionDrawing


func open_slot() -> DaySlot:
	return _open_slot


func _build() -> void:
	var column := VBoxContainer.new()
	column.name = "Column"
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 60.0
	column.offset_top = 36.0
	column.offset_right = -60.0
	column.offset_bottom = -28.0
	add_child(column)

	title_label = _make_label("Title")
	title_label.text = "Arda's week"
	column.add_child(title_label)
	hint_label = _make_label("Hint")
	column.add_child(hint_label)

	var days := HBoxContainer.new()
	days.name = "Days"
	days.size_flags_vertical = Control.SIZE_EXPAND_FILL
	days.add_theme_constant_override("separation", 56)
	column.add_child(days)
	for day: int in Run.DAYS:
		var day_column := VBoxContainer.new()
		day_column.name = "Day%d" % (day + 1)
		day_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		day_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		days.add_child(day_column)
		var day_label := _make_label("DayLabel%d" % (day + 1))
		day_label.text = "Day %d" % (day + 1)
		day_column.add_child(day_label)
		_day_labels.append(day_label)
		for index: int in Run.SLOTS_PER_DAY:
			var day_slot := DaySlot.new()
			day_slot.name = "Slot%d" % (day * Run.SLOTS_PER_DAY + index + 1)
			day_slot.setup(day * Run.SLOTS_PER_DAY + index + 1)
			day_slot.custom_minimum_size = Vector2(0.0, 210.0)
			day_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			day_column.add_child(day_slot)
			_slots.append(day_slot)

	var tray := HBoxContainer.new()
	tray.name = "Tray"
	tray.add_theme_constant_override("separation", 24)
	column.add_child(tray)
	for action: String in Plan.ACTIONS:
		var card := ActionDrawing.new()
		card.name = "Drawing%s" % action.capitalize()
		card.custom_minimum_size = Vector2(0.0, 216.0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tray.add_child(card)
		card.setup(action, _art_for(action), NAMES[action], TIPS[action])
		card.gui_input.connect(_on_drawing_input.bind(card))
		_drawings[action] = card

	ghost = DragGhost.new()
	ghost.name = "Ghost"
	add_child(ghost)
	_apply_text_size()


func _make_label(node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Crayon.INK)
	return label


## Slot actions in order: our own history while it still matches the plan,
## otherwise Plan.ACTIONS order (a plan loaded from a code has no history).
## The fallback also re-baselines the history, so one stale view is the worst
## that a desync can do. Core keeps counts only, not the pick order.
func _assigned_actions() -> Array[String]:
	if _matches_plan(_history):
		return _history.duplicate()
	var assigned: Array[String] = []
	for action: String in Plan.ACTIONS:
		for n: int in int(Run.plan.counts.get(action, 0)):
			assigned.append(action)
	_history = assigned
	return _history.duplicate()


func _matches_plan(actions: Array[String]) -> bool:
	if actions.size() != Run.plan.total():
		return false
	var seen: Dictionary = {}
	for action: String in actions:
		seen[action] = int(seen.get(action, 0)) + 1
	for action: String in Plan.ACTIONS:
		if int(seen.get(action, 0)) != int(Run.plan.counts.get(action, 0)):
			return false
	return true


func _on_plan_changed() -> void:
	if Run.plan.total() == 0:
		_history.clear()


func _refresh() -> void:
	var total := Run.plan.total()
	var assigned := _assigned_actions()
	var open_position := -1
	if total < Plan.SLOTS and Run.day >= 1 and Run.day <= Run.DAYS:
		var index := Run.SLOTS_PER_DAY - Run.slots_left
		if index >= 0 and index < Run.SLOTS_PER_DAY:
			open_position = (Run.day - 1) * Run.SLOTS_PER_DAY + index

	_open_slot = null
	var seen: Dictionary = {}
	for i: int in _slots.size():
		var day_slot := _slots[i]
		if i < total and i < assigned.size():
			var action: String = assigned[i]
			seen[action] = int(seen.get(action, 0)) + 1
			day_slot.action = action
			day_slot.occurrence = int(seen[action])
			day_slot.art = _art_for(action)
			day_slot.tooltip_text = NAMES[action]
		else:
			day_slot.action = ""
			day_slot.occurrence = 0
			day_slot.art = null
			day_slot.tooltip_text = ""
		day_slot.drag_over = false
		day_slot.open = i == open_position
		day_slot.future = open_position >= 0 and i > open_position
		if i == open_position:
			_open_slot = day_slot

	for action: String in Plan.ACTIONS:
		var card := _drawings.get(action) as ActionDrawing
		if card != null:
			card.count = int(Run.plan.counts.get(action, 0))

	hint_label.text = "Pick a drawing for today." if open_position >= 0 else "The week is full."


func _art_for(action: String) -> Texture2D:
	var index := Plan.ACTIONS.find(action)
	if index < 0 or index >= arts.size():
		return null
	return arts[index]


func _apply_text_size() -> void:
	var large := Settings.large_text
	title_label.add_theme_font_size_override("font_size", Crayon.font_size(BASE_TITLE_FONT, large))
	hint_label.add_theme_font_size_override("font_size", Crayon.font_size(BASE_HINT_FONT, large))
	for day_label: Label in _day_labels:
		day_label.add_theme_font_size_override("font_size", Crayon.font_size(BASE_DAY_FONT, large))
	for day_slot: DaySlot in _slots:
		day_slot.set_font_size(Crayon.font_size(BASE_BADGE_FONT, large))
	for action: String in Plan.ACTIONS:
		var card := _drawings.get(action) as ActionDrawing
		if card != null:
			card.set_font_size(Crayon.font_size(BASE_CAPTION_FONT, large), Crayon.font_size(BASE_BADGE_FONT, large))


func _on_settings_changed() -> void:
	_apply_text_size()


## Central input: every tray card forwards its gui_input here.
func _on_drawing_input(event: InputEvent, card: ActionDrawing) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_press(card)
		else:
			_release(card)
		return
	var motion := event as InputEventMouseMotion
	if motion != null and dragging and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_drag_move()


func _press(card: ActionDrawing) -> void:
	if Run.plan.total() >= Plan.SLOTS:
		return
	_drag_drawing = card
	drag_action = card.action
	_press_position = get_global_mouse_position()
	dragging = true
	ghost.action = drag_action
	ghost.art = _art_for(drag_action)
	_drag_move()


func _drag_move() -> void:
	var mouse := get_global_mouse_position()
	ghost.global_position = mouse - ghost.size * 0.5
	ghost.show()
	var over := _open_slot != null and _open_slot.get_global_rect().has_point(mouse)
	if _open_slot != null:
		_open_slot.drag_over = over


func _release(card: ActionDrawing) -> void:
	if not dragging or _drag_drawing != card:
		return
	var mouse := get_global_mouse_position()
	var dropped := _open_slot != null and _open_slot.get_global_rect().has_point(mouse)
	var clicked := _press_position.distance_to(mouse) <= CLICK_SLOP and card.get_global_rect().has_point(mouse)
	if dropped or clicked:
		_choose(drag_action)
	else:
		_end_drag()


func _choose(action: String) -> void:
	_end_drag()
	_history.append(action)
	action_chosen.emit(action)
	close()


func _end_drag() -> void:
	dragging = false
	drag_action = ""
	_drag_drawing = null
	if ghost != null:
		ghost.action = ""
		ghost.hide()
	if _open_slot != null:
		_open_slot.drag_over = false


func _draw() -> void:
	var sheet := Rect2(Vector2.ZERO, size)
	if paper != null:
		draw_texture_rect(paper, sheet, false)
	else:
		draw_rect(sheet, Crayon.PAPER)
