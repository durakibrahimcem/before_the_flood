extends Node
## Gate demo for the controls screen: a bot reads the keys and starts the game.

const SCREEN := preload("res://ui/controls/controls_screen.tscn")

var started_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var calm_before := Settings.calm_storm
	var large_before := Settings.large_text
	Settings.set_options(false, false)
	var screen: ControlsScreen = SCREEN.instantiate()
	add_child(screen)
	await _frames(2)
	assert(screen.visible, "the screen starts visible")
	assert(screen.title_label.text == "Before the Flood", "the title is right")
	assert(screen.hint_walk.text == "walk, or use the arrow keys", "walk hint")
	assert(screen.hint_use.text == "use", "use hint")
	assert(screen.hint_time.text == "tap to jump through time", "time hint")
	assert(screen.hint_scrub.text == "hold to scrub the years", "scrub hint")
	assert(screen.hint_pause.text == "pause", "pause hint")
	var keycaps: Array[Label] = screen.keycap_labels
	assert(keycaps[0].text == "W" and keycaps[1].text == "A", "W and A keycaps")
	assert(keycaps[2].text == "S" and keycaps[3].text == "D", "S and D keycaps")
	assert(keycaps[4].text == "E", "E keycap")
	assert(keycaps[5].text == "T", "T keycap")
	assert(keycaps[7].text == "Esc", "Esc keycap")
	screen.started.connect(_on_started)
	assert(started_count == 0, "nothing has started yet")
	assert(screen.begin_button.has_focus(), "Begin holds focus")
	var small_size := screen.title_label.get_theme_font_size("font_size")

	_press(KEY_ENTER)
	await _frames(2)
	assert(started_count == 1, "Enter starts the game")
	assert(not screen.visible, "starting hides the screen")

	screen.open()
	assert(screen.visible, "open shows the screen again")
	assert(screen.begin_button.has_focus(), "open focuses Begin")

	_click(screen.begin_button)
	await _frames(2)
	assert(started_count == 2, "a click starts the game too")
	assert(not screen.visible, "the screen hides again")

	screen.open()
	Settings.set_options(false, true)
	await _frames(2)
	var large_size := screen.title_label.get_theme_font_size("font_size")
	assert(absf(large_size - small_size * 1.4) <= 1.0, "large text grows by 1.4")
	Settings.set_options(false, false)
	await _frames(2)
	assert(screen.title_label.get_theme_font_size("font_size") == small_size, "sizes shrink back")

	Settings.set_options(calm_before, large_before)
	print("DEMO PASS")
	get_tree().quit()


func _on_started() -> void:
	started_count += 1


func _press(code: int) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventKey.new()
	up.keycode = code
	Input.parse_input_event(up)


func _click(button: Button) -> void:
	var center := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	get_viewport().push_input(motion, true)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	get_viewport().push_input(down, true)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = center
	get_viewport().push_input(up, true)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
