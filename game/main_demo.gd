extends Node
## Gate 2: walks through the rooms and time controls with a scripted bot.

const MAIN := preload("res://main.tscn")


func _ready() -> void:
	var main: Main = MAIN.instantiate()
	main.auto_tasks = true
	add_child(main)
	await _frames(3)
	var time: TimeControl = main.get_node("TimeControl")
	main.controls.started.emit()
	main.controls.hide()
	assert(main.room.room_name == "bedroom", "starts in the bedroom")
	assert(is_equal_approx(WorldClock.year, 2026.0), "starts in 2026")
	assert(main.room.flood_m == 0.0, "dry in 2026")
	var marks: HeightMarks = main.room.get_node("HeightMarks")
	var waterline: float = (main.room.floor_line - 1.0 / main.room.wall_m_per_uv) * Room.ROOM_SIZE.y
	assert(is_equal_approx(marks.mark_y(1.0), waterline), "a chart mark sits where that depth of water reaches the wall")

	time.tap()
	await _frames(2)
	assert(is_equal_approx(WorldClock.year, 2050.0), "tap jumps to 2050")
	assert(main.room.flood_m > 0.0, "doing nothing floods the room by 2050")
	time.tap()
	await _frames(2)
	assert(is_equal_approx(WorldClock.year, 2080.0), "tap jumps to 2080")
	var deep := main.room.flood_m
	assert(is_equal_approx(snappedf(deep, 0.001), 1.261), "room depth matches the simulation, got %f" % deep)

	var start: Vector2 = main.arda.position
	Input.action_press("move_left")
	await _physics(30)
	Input.action_release("move_left")
	var waded: float = start.distance_to(main.arda.position)
	assert(waded > 0.0, "Arda wades")
	assert(main.arda.wade_factor(deep) < 1.0, "water slows Arda")
	assert(main.room.ripple_count() > 0, "wading leaves rings on the water")

	time.begin_scrub()
	assert(get_tree().paused, "scrubbing pauses the world")
	time.slider.value = 2040.0
	await _frames(2)
	assert(is_equal_approx(WorldClock.year, 2040.0), "the slider moves the clock")
	var at_2040: float = main.room.flood_m
	assert(at_2040 < deep, "the water falls when scrubbing back")
	time.end_scrub()
	assert(not get_tree().paused, "releasing resumes the world")
	assert(is_equal_approx(WorldClock.year, 2050.0), "release lands on the nearest era")

	time.begin_scrub()
	time.end_scrub()
	await _frames(2)
	assert(is_equal_approx(WorldClock.year, 2080.0), "a hold with no drag acts like a tap")
	time.tap()
	await _frames(2)
	assert(is_equal_approx(WorldClock.year, 2026.0), "tap wraps to 2026")
	var door: Area2D = main.room.get_node("ToSalon")
	door._on_body_entered(main.arda)
	await _frames(3)
	assert(main.room.room_name == "salon", "the door leads to the salon")
	assert(main.arda.get_parent() == main.room, "Arda moved rooms")
	var dry_x: float = main.arda.position.x
	assert(main.room.get_node("BowlsFull").visible and not main.room.get_node("BowlsEmpty").visible, "Brian's bowls are full in 2026")
	assert(main.room.get_node("LampOn").visible, "the lamp is on while the home stands")
	WorldClock.scrub(2050.0)
	await _frames(1)
	assert(main.room.get_node("BowlsEmpty").visible and not main.room.get_node("BowlsFull").visible, "the bowls sit empty in 2050")
	WorldClock.scrub(2080.0)
	await _frames(1)
	assert(main.room.get_node("LampOff").visible and not main.room.get_node("LampOn").visible, "the lamp is off once the home is lost")
	WorldClock.scrub(2026.0)
	await _frames(1)
	assert(dry_x > 0.0 and main.room.has_node("Sofa"), "salon has furniture")
	main.room.get_node("ToStreet")._on_body_entered(main.arda)
	await _frames(3)
	assert(main.room.room_name == "street", "the salon leads to the street")
	assert(main.room.flood_m == 0.0, "the street is dry in 2026")
	main.room.get_node("ToShore")._on_body_entered(main.arda)
	await _frames(3)
	assert(main.room.room_name == "shore", "the street leads to the shore")
	assert(main.room.flood_m > 0.0, "the sea is at the shore")
	assert(main.room.depth_at(Vector2(960, 300)) > main.room.depth_at(Vector2(960, 1000)), "the sea is deeper than the beach")
	await _walk_every_door(main)
	print("DEMO PASS")
	get_tree().quit()


## Touches each door through real physics, as a player does, and checks Arda stays where they land.
func _walk_every_door(main: Main) -> void:
	WorldClock.scrub(2026.0)
	var route: Array[Array] = [
		["shore", "ToStreet", "street"], ["street", "ToSalon", "salon"], ["salon", "ToBedroom", "bedroom"],
		["bedroom", "ToSalon", "salon"], ["salon", "ToAylin", "aylin"], ["aylin", "ToSalon", "salon"],
		["salon", "ToStreet", "street"], ["street", "ToShore", "shore"],
	]
	for leg: Array in route:
		assert(main.room.room_name == leg[0], "the walk reached %s, got %s" % [leg[0], main.room.room_name])
		var door: Area2D = main.room.get_node(leg[1])
		var target: String = leg[2]
		main.arda.position = door.position
		await _physics(4)
		assert(main.room.room_name == target, "%s leads to %s, got %s" % [leg[1], target, main.room.room_name])
		await _physics(30)
		assert(main.room.room_name == target, "Arda stays in %s after arriving, got %s" % [target, main.room.room_name])
	main.task = Task.new()
	main.room.get_node("ToStreet")._on_body_entered(main.arda)
	await _frames(3)
	assert(main.room.room_name == "shore", "doors stay shut during a task")
	main.task.free()
	main.task = null
	main.enter_room("salon", Vector2(1760, 700))
	Input.action_press("move_right")
	await _physics(40)
	Input.action_release("move_right")
	assert(main.arda.position.x < 1830.0, "the fridge stops Arda, got x %f" % main.arda.position.x)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _physics(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
