extends Node
## Gate 3: plays a whole run with a scripted bot, from the calendar to the ending, then retries.

const MAIN := preload("res://main.tscn")
const CHOICES: Array[String] = ["grass", "grass", "dune", "light", "meet", "meet"]


func _ready() -> void:
	var main: Main = MAIN.instantiate()
	main.auto_tasks = true
	add_child(main)
	await _frames(3)
	main.controls.started.emit()
	main.controls.hide()
	main.enter_room("salon", Main.FRIDGE)
	await _frames(2)

	for index: int in CHOICES.size():
		var action: String = CHOICES[index]
		assert(main.can_open_calendar(), "the calendar opens before action %d" % index)
		main.open_calendar()
		main.calendar.action_chosen.emit(action)
		main.calendar.close()
		await _frames(1)
		var place: String = Main.TASKS[action]["room"]
		if main.room.room_name != place:
			assert(main.task == null, "the task waits for its room")
			main.enter_room(place, Vector2(960, 800))
		await _frames(6)
		assert(Run.plan.total() == index + 1, "action %d was recorded, total %d" % [index, Run.plan.total()])
		if index < CHOICES.size() - 1:
			assert(main.room.room_name == "salon", "tasks return home")
			assert(main.task == null, "the task is gone")

	await _frames(3)
	assert(main.final_walk, "six actions start the final walk")
	assert(is_equal_approx(WorldClock.year, 2050.0), "the walk starts in 2050")
	assert(main.newspaper.visible, "the 2050 paper pops up")
	main.newspaper._close()
	await _frames(2)
	assert(is_equal_approx(WorldClock.year, 2080.0), "then 2080")
	assert(main.newspaper.visible, "the 2080 paper pops up")
	main.newspaper._close()
	assert(not main.newspaper.visible, "the paper closes")
	await _frames(3)
	assert(main.ending.visible, "the ending plays")
	assert(Run.ghosts.size() > 0, "the attempt is saved")
	assert(Sim.outcome(Run.plan)["homes"] == 3, "this plan saves all three homes")

	main.ending.retry_requested.emit()
	await _frames(3)
	assert(Run.plan.total() == 0, "retry clears the plan")
	assert(is_equal_approx(WorldClock.year, 2026.0), "retry returns to 2026")
	assert(not main.ending.visible and main.room.room_name == "salon", "retry returns home")
	print("DEMO PASS")
	get_tree().quit()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
