extends Node
## The first minute, played by a bot: draw, flood, scrub back to today.

const MAIN := preload("res://main.tscn")


func _ready() -> void:
	Run.ghosts.clear()
	var main: Main = MAIN.instantiate()
	add_child(main)
	await _frames(3)
	main.controls.started.emit()
	main.controls.hide()
	await _frames(2)
	var opening: Opening = main.get_node_or_null("Opening")
	assert(opening == null or opening is Opening)
	for child: Node in main.get_children():
		if child is Opening:
			opening = child
	assert(opening != null, "the opening plays on a first run")
	assert(not main.time.enabled, "time is locked during the greeting")
	opening.draw_now()
	await get_tree().create_timer(Opening.GREETING_SECONDS + Opening.CAPTION_SECONDS + 0.3).timeout
	await _frames(3)
	assert(is_equal_approx(WorldClock.year, 2080.0), "the drawing opens 2080")
	assert(main.newspaper.visible, "the paper pops up")
	assert(main.room.flood_m > 1.0, "the bedroom is flooded")
	main.newspaper._close()
	await _frames(2)
	assert(main.hint.text.begins_with("This is what happens"), "the hint teaches the way back")
	main.time.begin_scrub()
	main.time.slider.value = 2030.0
	await _frames(1)
	main.time.end_scrub()
	await _frames(3)
	assert(is_equal_approx(WorldClock.year, 2026.0), "back to today")
	assert(main.hint.text.contains("fridge"), "the hint points at the fridge")
	Run.ghosts.append(1.0)
	assert(main.is_replay(), "a past attempt makes it a replay")
	print("DEMO PASS")
	get_tree().quit()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
