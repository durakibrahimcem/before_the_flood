extends Node
## Gate for the newspaper: reads a page, closes it every way, follows the clock.

const OVERLAY := preload("res://ui/newspaper/newspaper.tscn")

var dismissals := 0


func _ready() -> void:
	Settings.set_options(false, false)
	var spy := Spy.new()
	add_child(spy)
	var overlay: NewspaperOverlay = OVERLAY.instantiate()
	add_child(overlay)
	overlay.dismissed.connect(_on_dismissed)
	await _frames(2)

	var plan := Plan.new()
	plan.add("grass", 0.8)
	plan.add("dune", 0.6)
	overlay.show_for(plan, 2050)
	await _frames(1)
	var page := Newspapers.pick(plan, 2050)
	assert(overlay.visible, "the paper is up")
	assert(_label(overlay, "Masthead").text == "The Bay Herald", "the masthead reads The Bay Herald")
	assert(_label(overlay, "Year").text == "2050", "the year label shows the era")
	assert(_label(overlay, "Headline").text == str(page.get("headline", "")), "the headline matches the page")
	assert(_label(overlay, "Story").text == str(page.get("story", "")), "the story matches the page")
	var picture: CrayonPicture = overlay.get_node("Center/Sheet/Margins/Column/Picture")
	assert(picture.key == str(page.get("picture", "")), "the picture key follows the page")
	assert(picture.art == null, "without art the crayon placeholder draws")

	# Ebru's art drops in by key without code changes.
	var art := ImageTexture.create_from_image(Image.create_empty(8, 8, false, Image.FORMAT_RGB8))
	overlay.pictures["calm"] = art
	overlay.show_for(plan, 2050)
	await _frames(1)
	assert(picture.art == art, "exported art drops into the picture slot")
	overlay.pictures.erase("calm")

	var interact := InputEventKey.new()
	interact.physical_keycode = KEY_E
	interact.pressed = true
	await _close_with(overlay, interact, "the interact key")
	assert(dismissals == 1, "closing the page emits dismissed once")

	# Dismiss input is ignored while the page is hidden.
	await _try_input(overlay, interact)
	assert(not overlay.visible and dismissals == 1, "dismiss input is ignored while hidden")
	spy.seen = 0

	overlay.show_for(plan, 2050)
	await _frames(1)
	await _close_with(overlay, interact, "the interact key")
	assert(dismissals == 2, "the interact key closes the page")

	overlay.show_for(plan, 2050)
	await _frames(1)
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	await _close_with(overlay, enter, "enter")
	assert(dismissals == 3, "enter closes the page")

	overlay.show_for(plan, 2050)
	await _frames(1)
	var keypad := InputEventKey.new()
	keypad.keycode = KEY_KP_ENTER
	keypad.pressed = true
	await _close_with(overlay, keypad, "keypad enter")
	assert(dismissals == 4, "keypad enter closes the page")

	overlay.show_for(plan, 2050)
	await _frames(1)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = get_viewport().size * 0.5
	await _close_with(overlay, click, "a click")
	assert(dismissals == 5, "a click closes the page")
	assert(spy.seen == 0, "dismiss events stay with the paper, not the world")

	assert(overlay.auto_popup, "the paper pops up on arrival by default")
	WorldClock.jump(2050)
	await _frames(1)
	assert(overlay.visible, "arriving in 2050 pops the paper")
	assert(_label(overlay, "Year").text == "2050", "the 2050 page shows the era")
	WorldClock.jump(2080)
	await _frames(1)
	assert(overlay.visible, "the 2080 page is up")
	assert(_label(overlay, "Year").text == "2080", "the year follows the era, not the stored paper")
	assert(dismissals == 5, "replacing the page does not emit dismissed")
	WorldClock.jump(2026)
	await _frames(1)
	assert(not overlay.visible, "jumping home closes the page")
	assert(dismissals == 6, "the jump close emits dismissed once")

	var masthead := _label(overlay, "Masthead")
	var normal := masthead.get_theme_font_size("font_size")
	Settings.set_options(false, true)
	assert(masthead.get_theme_font_size("font_size") > normal, "large text grows the type")
	Settings.set_options(false, false)
	assert(masthead.get_theme_font_size("font_size") == normal, "the type returns to normal")

	print("DEMO PASS")
	get_tree().quit()


func _close_with(overlay: NewspaperOverlay, event: InputEvent, via: String) -> void:
	await _try_input(overlay, event)
	assert(not overlay.visible, "the page closes on %s" % via)


func _try_input(overlay: NewspaperOverlay, event: InputEvent) -> void:
	# Real events through the full pipeline (push_unhandled_input is
	# deprecated in 4.7). Headless runs sometimes drop pushed input, so fall
	# back to calling the handler directly, the house pattern of
	# door._on_body_entered in main_demo.gd.
	get_viewport().push_input(event)
	await _frames(2)
	if overlay.visible:
		overlay._unhandled_input(event)


func _on_dismissed() -> void:
	dismissals += 1


func _label(overlay: NewspaperOverlay, label_name: String) -> Label:
	return overlay.get_node("Center/Sheet/Margins/Column/" + label_name) as Label


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


## Counts anything that slips past the paper to the world behind it.
class Spy extends Node:
	var seen := 0

	func _unhandled_input(_event: InputEvent) -> void:
		seen += 1
