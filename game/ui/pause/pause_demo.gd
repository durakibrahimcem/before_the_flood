extends Node
## Gate demo for the pause menu: a bot pauses, flips options and resumes.

const MENU := preload("res://ui/pause/pause_menu.tscn")

var resumed_count: int = 0


class Counter:
	extends Node
	## A stand-in for the world: it must freeze while paused.
	var tick: float = 0.0

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE

	func _process(delta: float) -> void:
		tick += delta


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var calm_before := Settings.calm_storm
	var large_before := Settings.large_text
	Settings.set_options(false, false)
	var counter := Counter.new()
	add_child(counter)
	await _beat()
	assert(counter.tick > 0.0, "the world runs")
	var menu: PauseMenu = MENU.instantiate()
	add_child(menu)
	menu.resumed.connect(_on_resumed)
	await _beat()
	assert(not menu.visible, "the menu starts hidden")

	var probe := Button.new()
	add_child(probe)
	probe.grab_focus()
	await _beat()
	assert(probe.has_focus(), "a probe holds focus")
	_esc(true)
	await _beat()
	_esc(false)
	await _beat()
	assert(menu.visible, "Esc opens the menu")
	_esc(true)
	await _beat()
	_esc(false)
	await _beat()
	assert(probe.has_focus(), "focus returns where it was")
	probe.free()

	_esc(true)
	await _beat()
	_esc(false)
	await _beat()
	assert(menu.visible, "Esc opens the menu")
	assert(get_tree().paused, "the world is paused")
	var frozen := counter.tick
	await get_tree().create_timer(0.15, true).timeout
	assert(is_equal_approx(counter.tick, frozen), "the world stays frozen")
	assert(menu.squiggle_phase > 0.0, "the menu animates while paused")
	assert(menu.resume_button.has_focus(), "Resume holds focus")

	_press(KEY_DOWN)
	await _beat()
	assert(menu.calm_box.has_focus(), "down reaches calm storm")
	_press(KEY_ENTER)
	await _beat()
	assert(menu.calm_box.button_pressed, "Enter ticks calm storm")
	assert(Settings.calm_storm, "the box reaches Settings")
	var small_size := menu.resume_button.get_theme_font_size("font_size")
	_press(KEY_DOWN)
	await _beat()
	assert(menu.large_box.has_focus(), "down reaches larger text")
	_press(KEY_ENTER)
	await _beat()
	assert(Settings.large_text, "larger text is on")
	assert(menu.resume_button.get_theme_font_size("font_size") > small_size, "larger text grows the menu")
	assert(menu.calm_box.get_theme_icon("checked").get_width() > 32, "the tick grows with the text")

	_esc(true)
	await _beat()
	_esc(false)
	await _beat()
	assert(not get_tree().paused, "Esc resumes the world")
	assert(not menu.visible, "the menu hides")
	assert(resumed_count == 2, "resumed fired twice")
	var before := counter.tick
	await _beat()
	assert(counter.tick > before, "the world runs again")

	_esc(true)
	await _beat()
	_esc(false)
	await _beat()
	assert(menu.visible, "Esc reopens the menu")
	assert(menu.calm_box.button_pressed and menu.large_box.button_pressed, "boxes still mirror Settings")

	Settings.set_options(false, false)
	await _beat()
	assert(not menu.calm_box.button_pressed, "external changes sync calm storm")
	assert(not menu.large_box.button_pressed, "external changes sync larger text")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(Settings.SAVE_PATH))
	assert(saved is Dictionary, "settings persist as json")
	var saved_dict: Dictionary = saved
	assert(saved_dict.get("calm_storm") == false, "calm storm saved")
	assert(saved_dict.get("large_text") == false, "large text saved")

	_esc(true)
	await _beat()
	_esc(false)
	await _beat()
	assert(not menu.visible, "the menu steps aside")
	assert(not get_tree().paused, "the menu's own pause ends with it")
	get_tree().paused = true
	_esc(true)
	await _beat()
	_esc(false)
	await _beat()
	assert(menu.visible, "Esc peeks over a foreign pause")
	assert(get_tree().paused, "the foreign pause holds")
	_esc(true)
	await _beat()
	_esc(false)
	await _beat()
	assert(not menu.visible, "Esc closes the peek")
	assert(get_tree().paused, "the menu does not steal the pause")
	get_tree().paused = false
	await _beat()
	assert(not get_tree().paused, "the foreign pause is released")

	Settings.set_options(calm_before, large_before)
	_esc(true)
	await _beat()
	_esc(false)
	await _beat()
	assert(menu.visible, "Esc opens the menu one last time")
	_esc(true)
	await _beat()
	_esc(false)
	await _beat()
	assert(resumed_count == 5, "resumed fired five times")
	assert(not menu.visible, "the menu is hidden at the end")
	assert(not get_tree().paused, "the world runs at the end")
	print("DEMO PASS")
	get_tree().quit()


func _on_resumed() -> void:
	resumed_count += 1


func _esc(pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	key.pressed = pressed
	Input.parse_input_event(key)


func _press(code: int) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventKey.new()
	up.keycode = code
	Input.parse_input_event(up)


func _beat() -> void:
	await get_tree().create_timer(0.05, true).timeout
