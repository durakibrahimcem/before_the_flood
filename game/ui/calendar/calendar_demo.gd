extends Node
## Bot for the crayon calendar: real synthetic mouse input, real asserts.

const CALENDAR := preload("res://ui/calendar/calendar.tscn")

var calendar: Calendar
var chosen: Array[String] = []
var normal_title_size := 0
var normal_hint_size := 0


func _ready() -> void:
	Run.new_run()
	Settings.large_text = false
	calendar = CALENDAR.instantiate()
	calendar.action_chosen.connect(_on_action_chosen)
	add_child(calendar)
	await _frames(2)

	# 1. Hidden until open(); day 1 slot 1 is today's open slot.
	assert(not calendar.is_visible_in_tree(), "starts hidden")
	calendar.open()
	await _frames(2)
	assert(calendar.is_visible_in_tree(), "open() shows the calendar")
	for action: String in Plan.ACTIONS:
		assert(calendar.drawing(action) != null, "the tray has a %s drawing" % action)
	assert(calendar.slot(1, 1).open, "day 1 slot 1 is the open slot")
	assert(not calendar.slot(1, 2).open and not calendar.slot(2, 1).open, "only one open slot")
	for day: int in Run.DAYS:
		for index: int in Run.SLOTS_PER_DAY:
			assert(calendar.slot(day + 1, index + 1).action == "", "slots start empty")
	normal_title_size = calendar.title_label.get_theme_font_size("font_size")
	normal_hint_size = calendar.hint_label.get_theme_font_size("font_size")

	# 2. Hover every tray drawing.
	for action: String in Plan.ACTIONS:
		var card := calendar.drawing(action)
		var target := card.get_global_rect().get_center()
		await _move_mouse(target)
		var landed := get_viewport().get_mouse_position().distance_to(target)
		assert(landed < 0.5, "synthetic motion lands on target for %s" % action)
		assert(card.hovered, "hovering %s highlights it" % action)
		assert(card.tip_text() != "", "%s says what it does" % action)

	# 3. Click Seagrass.
	await _click(calendar.drawing("grass").get_global_rect().get_center())
	assert(chosen == ["grass"], "clicking Seagrass chooses grass, got %s" % str(chosen))
	assert(not calendar.is_visible_in_tree(), "choosing closes the calendar")

	# 4. Drag Dunes onto day 1 slot 2.
	calendar.open()
	await _frames(2)
	assert(calendar.slot(1, 1).action == "grass", "day 1 slot 1 shows grass")
	assert(calendar.slot(1, 1).occurrence == 1, "day 1 slot 1 is the first grass pick")
	assert(calendar.slot(1, 1).tooltip_text == "Seagrass", "filled slots have a tooltip")
	await _drag(calendar.drawing("dune"), calendar.slot(1, 2))
	assert(chosen == ["grass", "dune"], "dropping Dunes on the open slot chooses dune")
	assert(Run.day == 2, "recording both day 1 slots moves to day 2")

	# 5. Click grass again for a repeat.
	calendar.open()
	await _frames(2)
	assert(calendar.slot(1, 1).action == "grass" and calendar.slot(1, 2).action == "dune", "day 1 is full")
	assert(calendar.slot(2, 1).open, "day 2 slot 1 is the open slot")
	await _click(calendar.drawing("grass").get_global_rect().get_center())
	assert(int(Run.plan.counts["grass"]) == 2, "grass chosen twice")
	calendar.open()
	await _frames(2)
	assert(calendar.slot(2, 1).action == "grass", "day 2 slot 1 shows grass")
	assert(calendar.slot(2, 1).occurrence == 2, "a repeat shows its count")

	# 6. Fill the week.
	await _drag(calendar.drawing("sort"), calendar.slot(2, 2))
	calendar.open()
	await _frames(2)
	await _click(calendar.drawing("light").get_global_rect().get_center())
	calendar.open()
	await _frames(2)
	await _drag(calendar.drawing("wall"), calendar.slot(3, 2))
	assert(Run.plan.total() == Plan.SLOTS, "the plan is full")
	calendar.open()
	await _frames(2)
	var week := ["grass", "dune", "grass", "sort", "light", "wall"]
	for i: int in week.size():
		assert(calendar.slot(i / 2 + 1, i % 2 + 1).action == week[i], "slot %d shows %s" % [i + 1, week[i]])
	assert(calendar.open_slot() == null, "no open slot when the week is full")
	assert(calendar.hint_label.text == "The week is full.", "the hint says the week is full")
	for action: String in Plan.ACTIONS:
		assert(calendar.drawing(action).tip_text() == Calendar.TIPS[action], "the card for %s says what it does" % action)
		assert(calendar.drawing(action).key_number == Plan.ACTIONS.find(action) + 1, "the card for %s shows its key" % action)
	assert(calendar.drawing("grass").count == 2, "the tray shows the grass repeat count")

	# 7. A full plan ignores picks.
	await _click(calendar.drawing("grass").get_global_rect().get_center())
	assert(chosen.size() == Plan.SLOTS, "no action_chosen when the plan is full")
	assert(calendar.is_visible_in_tree(), "the calendar stays open when the plan is full")
	calendar.close()
	assert(not calendar.is_visible_in_tree(), "close() hides the calendar")

	# 7b. A week loaded from a code has no history: slots fill in Plan.ACTIONS order.
	var coded := Plan.new()
	coded.counts["wall"] = Plan.SLOTS
	assert(Run.load_code(coded.code()), "the code loads")
	calendar.open()
	await _frames(2)
	assert(calendar.slot(1, 1).action == "wall", "a loaded code fills slots in action order")
	assert(calendar.slot(3, 2).occurrence == Plan.SLOTS, "the last slot counts the repeats")
	assert(calendar.open_slot() == null, "a loaded week has no open slot")
	calendar.close()

	# 8. Large text grows the fonts.
	Settings.large_text = false
	calendar.open()
	await _frames(2)
	var normal_size := calendar.title_label.get_theme_font_size("font_size")
	Settings.large_text = true
	Settings.changed.emit()
	var after_signal := calendar.title_label.get_theme_font_size("font_size")
	assert(after_signal > normal_size, "Settings.changed re-applies large text")
	assert(after_signal > normal_title_size, "large text grows the title")
	assert(calendar.hint_label.get_theme_font_size("font_size") > normal_hint_size, "large text grows the hint")
	calendar.close()
	Settings.large_text = false

	# 9. A reused calendar starts a fresh week, and the pick order survives it.
	Run.new_run()
	calendar.open()
	await _frames(2)
	for day: int in Run.DAYS:
		for index: int in Run.SLOTS_PER_DAY:
			assert(calendar.slot(day + 1, index + 1).action == "", "a new run empties every slot")
	await _press(calendar.drawing("meet").get_global_rect().get_center())
	assert(calendar.dragging, "the drag starts on press")
	calendar.close()
	assert(not calendar.dragging and not calendar.ghost.visible, "close() drops a mid-drag quietly")
	calendar.open()
	await _frames(2)
	await _press(calendar.drawing("meet").get_global_rect().get_center())
	await _move_mouse(calendar.title_label.get_global_rect().get_center(), MOUSE_BUTTON_MASK_LEFT)
	assert(not calendar.open_slot().drag_over, "a drop far from the slot does not highlight it")
	await _release(calendar.title_label.get_global_rect().get_center())
	await _frames(2)
	assert(not calendar.dragging and not calendar.ghost.visible, "a lost release self-heals")
	assert(chosen.size() == Plan.SLOTS, "a cancelled drag chooses nothing")
	assert(calendar.is_visible_in_tree(), "a cancelled drag keeps the calendar open")
	await _click(calendar.drawing("meet").get_global_rect().get_center())
	calendar.open()
	await _frames(2)
	await _drag(calendar.drawing("grass"), calendar.slot(1, 2))
	assert(chosen == ["grass", "dune", "grass", "sort", "light", "wall", "meet", "grass"], "the full pick list")
	calendar.open()
	await _frames(2)
	assert(calendar.slot(1, 1).action == "meet" and calendar.slot(1, 2).action == "grass", "slots keep the real pick order after a new run")

	print("DEMO PASS")
	get_tree().quit()


func _on_action_chosen(action: String) -> void:
	chosen.append(action)
	Run.record(action, 0.5)


## Synthetic input: events go through the real pipeline, in window coordinates.
## get_screen_transform() maps viewport to window coordinates; the engine maps
## the event back, so verify with get_viewport().get_mouse_position().
func _window_pos(viewport_pos: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * viewport_pos


func _inject(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _move_mouse(viewport_pos: Vector2, mask: int = 0) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _window_pos(viewport_pos)
	motion.global_position = motion.position
	motion.button_mask = mask
	await _inject(motion)


func _press(viewport_pos: Vector2) -> void:
	await _button(viewport_pos, true, MOUSE_BUTTON_MASK_LEFT)


func _release(viewport_pos: Vector2) -> void:
	await _button(viewport_pos, false, 0)


func _click(viewport_pos: Vector2) -> void:
	await _press(viewport_pos)
	await _release(viewport_pos)


func _button(viewport_pos: Vector2, pressed: bool, mask: int) -> void:
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	button.position = _window_pos(viewport_pos)
	button.global_position = button.position
	button.button_mask = mask
	await _inject(button)


func _drag(card: ActionDrawing, day_slot: DaySlot) -> void:
	var from := card.get_global_rect().get_center()
	var to := day_slot.get_global_rect().get_center()
	await _press(from)
	await _move_mouse(from.lerp(to, 0.5), MOUSE_BUTTON_MASK_LEFT)
	assert(calendar.dragging, "the drag ghost is active mid-drag")
	await _move_mouse(to, MOUSE_BUTTON_MASK_LEFT)
	assert(day_slot.drag_over, "the target slot highlights mid-drag")
	await _release(to)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
