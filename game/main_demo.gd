extends Node
## Gate 2: walks through the rooms and time controls with a scripted bot.

const MAIN := preload("res://main.tscn")
## Every door walked through with W: from, to, and where the door stands.
const UP_DOORS: Array[Array] = [
	["bedroom", "salon", Vector2(1253, 535)],
	["aylin", "salon", Vector2(312, 535)],
	["salon", "bedroom", Vector2(804, 549)],
	["salon", "aylin", Vector2(1152, 549)],
	["salon", "street", Vector2(284, 549)],
	["street", "salon", Vector2(702, 392)],
]


func _ready() -> void:
	var main: Main = MAIN.instantiate()
	main.auto_tasks = true
	main.paper_delay = 0.0
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
	assert(is_equal_approx(snappedf(deep, 0.001), 0.911), "room depth matches the simulation, got %f" % deep)

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
	assert(is_equal_approx(WorldClock.year, 2050.0), "a hold with no drag stays where it was")
	time.begin_scrub()
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(-300, 0)
	time._input(mouse)
	await _frames(1)
	assert(WorldClock.year < 2041.0, "moving the mouse scrubs with no click, got %f" % WorldClock.year)
	var held := WorldClock.year
	Input.action_press("move_right")
	await _frames(4)
	Input.action_release("move_right")
	assert(not time.scrubbing or WorldClock.year >= held, "the walking keys scrub too")
	time.end_scrub()
	await _frames(1)
	WorldClock.scrub(2050.0)
	time.tap()
	await _frames(2)
	assert(is_equal_approx(WorldClock.year, 2080.0), "tap still moves on")
	time.tap()
	await _frames(2)
	assert(is_equal_approx(WorldClock.year, 2026.0), "tap wraps to 2026")
	var door: Area2D = main.room.get_node("ToSalon")
	door._on_body_entered(main.arda)
	await _frames(3)
	assert(main.room.room_name == "salon", "the door leads to the salon")
	assert(main.arda.get_parent() == main.room, "Arda moved rooms")
	var dry_x: float = main.arda.position.x
	assert(main.room.get_node("BowlsEmpty").visible and not main.room.get_node("BowlsFull").visible, "Brian's bowls wait to be filled")
	main.feed_brian()
	assert(main.room.get_node("BowlsFull").visible and not main.room.get_node("BowlsEmpty").visible, "feeding Brian fills his bowls")
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
	_check_verdicts()
	await _check_view(main)
	main.auto_tasks = false
	await _check_characters(main)
	await _check_planting(main)
	await _check_bowls(main)
	await _check_doors(main)
	await _check_paper_delay(main)
	await _check_large_text(main)
	await _check_pause_over_scrub(main)
	await _check_ayla_blocks(main)
	await _check_flow(main)
	await _check_outdoors(main)
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
		assert(door._label.text != "", "%s names the place behind it" % leg[1])
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


func _check_verdicts() -> void:
	assert(TaskVerdict.entry_for(1.0)["word"] == "Awesome!", "a perfect task is awesome")
	assert(TaskVerdict.entry_for(0.8)["word"] == "Great job!", "a strong task is great")
	assert(TaskVerdict.entry_for(0.5)["word"] == "Good work.", "half is good")
	assert(TaskVerdict.entry_for(0.0)["word"] == "That went badly.", "nothing done is bad")


## Larger text reaches the hint line, the prompts, door names and the verdict card.
func _check_large_text(main: Main) -> void:
	main.enter_room("salon", Vector2(900, 700))
	await _frames(1)
	var door: Label = main.room.get_node("ToStreet")._label
	var normal_door := door.get_theme_font_size("font_size")
	Settings.set_options(false, true)
	await _frames(1)
	assert(main.hint.get_theme_font_size("font_size") > Main.HINT_FONT, "the hint line grows")
	assert(door.get_theme_font_size("font_size") > normal_door, "door names grow")
	main._verdict.show_result(0.3, "2 of 8 sorted")
	await _frames(2)
	var card: PanelContainer = main._verdict._card
	assert(card.get_rect().get_center().x > 950.0 and card.get_rect().get_center().x < 970.0, "the verdict card stays centred")
	assert(card.size.x <= Room.ROOM_SIZE.x, "the verdict card fits")
	Settings.set_options(false, false)
	await _frames(1)
	assert(door.get_theme_font_size("font_size") == normal_door, "door names shrink back")


## Esc during a scrub leaves a pause menu that stays open.
func _check_pause_over_scrub(main: Main) -> void:
	var time: TimeControl = main.get_node("TimeControl")
	var menu: PauseMenu = main.get_node("Pause")
	WorldClock.scrub(2026.0)
	main.newspaper.hide()
	time.begin_scrub()
	await _frames(1)
	_key(KEY_ESCAPE)
	await _frames(3)
	assert(menu.visible and not time.scrubbing, "Esc ends the scrub and opens the menu")
	assert(get_tree().paused, "the menu holds the pause")
	await _frames(5)
	assert(menu.visible, "the menu stays open")
	menu.resume()
	await _frames(2)
	assert(not get_tree().paused, "resuming frees the world")
	WorldClock.scrub(2026.0)
	await _frames(1)


## Arda walks around Ayla, not through her, and the way to the fridge stays a straight walk.
func _check_ayla_blocks(main: Main) -> void:
	WorldClock.scrub(2026.0)
	main.newspaper.hide()
	main.enter_room("salon", Ayla.SPOT + Vector2(0, 120))
	await _ticks(4)
	Input.action_press("move_up")
	await _ticks(30)
	Input.action_release("move_up")
	assert(main.arda.position.y > Ayla.SPOT.y + 30.0, "Ayla stops Arda, who reached y %f" % main.arda.position.y)
	await _ticks(2)
	for walk_y: float in [680.0, 700.0, 730.0]:
		main.enter_room("salon", Vector2(1200, walk_y))
		await _ticks(4)
		Input.action_press("move_right")
		await _ticks(40)
		Input.action_release("move_right")
		assert(main.arda.position.x > Ayla.SPOT.x + 60.0, "Arda slides past Ayla at y %f, reaching x %f" % [walk_y, main.arda.position.x])
		await _ticks(2)


## Ebru's poses swap as Arda walks, and Ayla shares the salon's water.
func _check_characters(main: Main) -> void:
	WorldClock.scrub(2026.0)
	main.enter_room("salon", Vector2(900, 700))
	await _frames(2)
	assert(main.arda.body_sprite.texture == Arda.IDLE, "Arda stands in the idle pose")
	var poses := {}
	Input.action_press("move_left")
	for step: int in 40:
		await _physics(1)
		poses[main.arda.body_sprite.texture] = true
	Input.action_release("move_left")
	assert(poses.has(Arda.WALK[0]) and poses.has(Arda.WALK[1]), "the two walk poses swap")
	await _physics(3)
	assert(main.arda.body_sprite.texture == Arda.IDLE, "Arda stops in the idle pose")
	WorldClock.scrub(2050.0)
	await _frames(1)
	assert(main.arda.body_sprite.texture == Arda.ADULT_IDLE, "Arda is grown up in 2050")
	var grown: float = main.arda.body_sprite.scale.y * Arda.ADULT_IDLE.get_height()
	assert(is_equal_approx(grown, 1.75 * main.room.px_per_m), "Arda stands at their grown height, got %f" % grown)
	await _check_grown_walk(main, "move_right", Arda.ADULT_WALK, Arda.ADULT_IDLE, 1.75)
	WorldClock.scrub(2080.0)
	await _frames(1)
	assert(main.arda.body_sprite.texture == Arda.OLD_IDLE, "Arda is old in 2080")
	var old: float = main.arda.body_sprite.scale.y * Arda.OLD_IDLE.get_height()
	assert(is_equal_approx(old, 1.7 * main.room.px_per_m), "Arda stands at their old height, got %f" % old)
	await _check_grown_walk(main, "move_left", Arda.OLD_WALK, Arda.OLD_IDLE, 1.7)
	WorldClock.scrub(2026.0)
	await _physics(2)
	assert(main.arda.body_sprite.texture == Arda.IDLE, "Arda is eight again in 2026")
	var ayla: Ayla = main.room.get_node("Ayla")
	assert(ayla.visible, "Ayla is home in 2026")
	WorldClock.scrub(2050.0)
	await _frames(1)
	WorldClock.scrub(2026.0)
	await _frames(1)
	var feet: ShaderMaterial = ayla.get_child(0).material
	assert(is_equal_approx(feet.get_shader_parameter("waterline"), 1.0), "Ayla stands dry in dry 2026")
	WorldClock.scrub(2080.0)
	await _frames(1)
	assert(not ayla.visible, "Ayla is gone by 2080")
	WorldClock.scrub(2026.0)
	await _frames(1)


## Planting is free: it uses no calendar slot and leaves the water alone.
func _check_planting(main: Main) -> void:
	Run.new_run()
	WorldClock.scrub(2026.0)
	var spot: Vector2 = WorldProps.SAPLING_SPOTS[0]
	main.enter_room("street", spot + Vector2(0, 60))
	await _frames(2)
	assert(main.planter_in_reach() == 0, "a planter is in reach")
	var level := Sim.at(Run.plan, 2080).water_m
	main.hint.text = "Go to the street."
	main.plant_tree(main.planter_in_reach())
	assert(main.hint.text == Main.PLANT_LINE, "planting says so")
	assert(Run.planted == [0] and Run.plan.total() == 0, "planting uses no calendar slot")
	assert(Sim.at(Run.plan, 2080).water_m == level, "planting does not change the water")
	assert(main.planter_in_reach() != 0, "a planted planter is full")
	await get_tree().create_timer(Main.ASIDE_SECONDS + 0.2).timeout
	assert(main.hint.text == "Go to the street.", "the objective comes back after planting")
	WorldClock.scrub(2050.0)
	await _frames(1)
	assert(main.planter_in_reach() == -1, "trees are planted today, not in the future")
	WorldClock.scrub(2026.0)
	await _frames(1)
	Run.new_run()
	assert(Run.planted.is_empty(), "a new run starts with empty planters")


## The flood gets a moment on screen before the newspaper covers it.
func _check_paper_delay(main: Main) -> void:
	Run.new_run()
	WorldClock.scrub(2026.0)
	main.newspaper.hide()
	main.paper_delay = Main.PAPER_DELAY
	main.time.enabled = true
	main._seen_papers.clear()
	WorldClock.jump(2080)
	await get_tree().create_timer(1.0).timeout
	assert(not main.newspaper.visible, "no paper yet at 1 second")
	assert(main.arda.frozen and not main.time.enabled, "Arda and the clock wait for the paper")
	await get_tree().create_timer(Main.PAPER_DELAY - 1.0 + 0.3).timeout
	assert(main.newspaper.visible, "the paper arrives after the delay")
	main.newspaper._close()
	await _frames(2)
	assert(not main.arda.frozen and main.time.enabled, "dismissing frees Arda and the clock")
	main.paper_delay = 0.0
	WorldClock.scrub(2026.0)
	await _frames(1)
	Run.new_run()


## A key still held after a door must not walk Arda back through it, and S must work at once.
func _check_doors(main: Main) -> void:
	Run.new_run()
	WorldClock.scrub(2026.0)
	main.newspaper.hide()
	for door_way: Array in UP_DOORS:
		var from: String = door_way[0]
		var to: String = door_way[1]
		var door: Vector2 = door_way[2]
		main.enter_room(from, door + Vector2(0, 110))
		await _ticks(4)
		Input.action_press("move_up")
		var changes := 0
		var last: String = main.room.room_name
		for tick: int in 60:
			await get_tree().physics_frame
			if main.room.room_name != last:
				last = main.room.room_name
				changes += 1
		assert(changes == 1 and last == to, "W held from %s changed rooms %d times, ending in %s" % [from, changes, last])
		var stopped: float = main.arda.position.y
		await _ticks(10)
		assert(is_equal_approx(main.arda.position.y, stopped), "a held W does nothing after a door")
		Input.action_press("move_down")
		await _ticks(6)
		assert(main.arda.position.y > stopped, "S moves Arda away while W is still held, from %s" % from)
		Input.action_release("move_down")
		Input.action_release("move_up")
		await _ticks(2)
		Input.action_press("move_up")
		for tick: int in 40:
			await get_tree().physics_frame
			if main.room.room_name == from:
				break
		Input.action_release("move_up")
		assert(main.room.room_name == from, "pressing W again goes back through the door to %s" % from)
		await _ticks(2)
	Run.new_run()


## Brian's bowls need filling once a day, and they stay empty in the years he is gone.
func _check_grown_walk(main: Node, action: String, walk: Array[Texture2D], idle: Texture2D, height_m: float) -> void:
	var poses := {}
	Input.action_press(action)
	for step: int in 70:
		await _physics(1)
		poses[main.arda.body_sprite.texture] = true
		var tall: float = main.arda.body_sprite.scale.y * main.arda.body_sprite.texture.get_height()
		assert(is_equal_approx(tall, height_m * main.room.px_per_m), "Arda keeps their height mid-stride, got %f" % tall)
	Input.action_release(action)
	assert(poses.has(walk[0]) and poses.has(walk[1]), "the grown walk poses swap")
	await _physics(3)
	assert(main.arda.body_sprite.texture == idle, "Arda stops in the grown idle pose")


func _check_bowls(main: Main) -> void:
	Run.new_run()
	WorldClock.scrub(2026.0)
	main.enter_room("salon", Main.BOWLS_SPOT + Vector2(90, 40))
	main.newspaper.hide()
	await _frames(2)
	assert(main.bowls_in_reach(), "the bowls are in reach")
	main.hint.text = "Open the calendar on the fridge."
	_key(KEY_E)
	await _frames(2)
	assert(Run.fed_today() and Run.meals == 1, "E feeds Brian")
	assert(main.hint.text == Main.BOWLS_LINE, "feeding says so")
	await get_tree().create_timer(Main.ASIDE_SECONDS + 0.2).timeout
	assert(main.hint.text == "Open the calendar on the fridge.", "the objective comes back")
	assert(not main.bowls_in_reach(), "he has eaten today")
	assert(Run.plan.total() == 0, "feeding uses no calendar slot")
	Run.day = 2
	assert(main.bowls_in_reach(), "a new day means empty bowls")
	WorldClock.scrub(2050.0)
	await _frames(1)
	assert(not main.bowls_in_reach(), "there is no one to feed in 2050")
	assert(main.room.get_node("BowlsEmpty").visible, "the bowls sit empty in 2050")
	WorldClock.scrub(2026.0)
	await _frames(1)
	Run.new_run()


## Keys, the skip rule and a peek at the future must all leave the player able to carry on.
func _check_flow(main: Main) -> void:
	for action: String in ["move_up", "move_down", "move_left", "move_right"]:
		assert(InputMap.action_get_events(action).size() == 2, "%s has WASD and an arrow key" % action)
	Run.new_run()
	WorldClock.scrub(2026.0)
	main.enter_room("salon", Main.FRIDGE)
	await _frames(2)
	assert(main.can_open_calendar(), "the fridge opens the calendar")
	main.open_calendar()
	assert(main.arda.frozen, "Arda waits while the calendar is open")
	_key(KEY_E)
	await _frames(2)
	assert(not main.calendar.visible and not main.arda.frozen, "E puts the calendar away")
	main.open_calendar()
	_key(KEY_2)
	await _frames(2)
	assert(main.pending_action == "dune", "key 2 picks the second drawing, got %s" % main.pending_action)
	assert(not main.calendar.visible and not main.arda.frozen, "picking closes the calendar")
	var past_runs: Array[float] = Run.ghosts.duplicate()
	Run.ghosts.clear()
	assert(not main.can_skip(), "a first run cannot skip its first task")
	Run.ghosts.assign(past_runs)
	WorldClock.jump(2080)
	await _frames(2)
	main.enter_room("shore", Vector2(300, 800))
	await _frames(2)
	assert(main.task == null, "no task starts in the future")
	assert(main.hint.text == "Tap T to come back to today.", "the hint says how to get back, got %s" % main.hint.text)
	WorldClock.jump(2026)
	await _frames(3)
	assert(main.task != null, "coming back to today starts the waiting task")
	main.task.complete(1.0)
	await _frames(3)
	Run.plan.counts["sort"] = 1
	Run.ghosts.clear()
	assert(main.can_skip(), "two actions in, a judge can skip")
	Run.ghosts.assign(past_runs)
	Run.new_run()
	main.pending_action = ""


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)


## Whole objects slide against the walker. The floor, and whatever sits on it, must stay put.
func _check_view(main: Main) -> void:
	var calm := Settings.calm_storm
	Settings.calm_storm = false
	main.enter_room("salon", Vector2(120, 700))
	await _frames(2)
	var sofa: Sprite2D = main.room.get_node("Sofa")
	var painting: Sprite2D = main.room.get_node("Painting")
	var left := sofa.position.x
	assert(left > 0.0, "with Arda on the left, the sofa rests to the right")
	main.arda.position = Vector2(1800, 700)
	await get_tree().create_timer(0.1).timeout
	assert(sofa.position.x < left and sofa.position.x > 0.0, "the sofa eases, it does not jump")
	assert(painting.position == Vector2.ZERO, "the floor never moves")
	await get_tree().create_timer(3.0).timeout
	assert(sofa.position.x < 0.0, "with Arda on the right, the sofa rests to the left")
	assert(absf(sofa.position.x) <= Room.SLIDE_PX, "the slide stays small")
	assert(sofa.position.y == 1006.0, "the view never shifts up or down")
	main.room.hold_view = true
	await get_tree().create_timer(4.0).timeout
	assert(absf(sofa.position.x) < 0.3, "objects settle during a task")
	Settings.calm_storm = true
	main.room.hold_view = false
	await get_tree().create_timer(4.0).timeout
	assert(absf(sofa.position.x) < 0.3, "calm mode stops the slide")
	Settings.calm_storm = calm


## Plays Ebru's street and shore on foot: Arda shrinks to fit them, so every reach is checked with real physics.
func _check_outdoors(main: Main) -> void:
	WorldClock.scrub(2026.0)
	main.enter_room("street", Vector2(702, 460))
	await _frames(2)
	assert(main.arda.height_m * main.arda.pixels_per_metre < 110.0, "Arda fits the painted door")
	assert(main.room.has_node("Home") and main.room.has_node("Neighbour"), "the street has the family's home and one neighbour")
	await get_tree().create_timer(0.3).timeout
	assert(main.room.get_node("ToShore")._label.modulate.a > 0.5, "the way to the shore is named from anywhere on the street")
	Input.action_press("move_up")
	await _physics(30)
	Input.action_release("move_up")
	assert(main.room.room_name == "salon", "the painted door leads home, got %s" % main.room.room_name)

	main.auto_tasks = false
	main.pending_action = "sort"
	main.enter_room("street", Vector2(177, 600))
	await _frames(2)
	var sort := main.task as SortTask
	assert(sort != null, "the sort task starts on the street")
	main.arda.carried = "paper"
	Input.action_press("move_up")
	await _physics(40)
	Input.action_release("move_up")
	assert(sort.sorted_correct == 1, "Arda reaches the painted paper bin, got %d" % sort.sorted_correct)
	sort.running = false
	assert(sort.result_text() == "1 of %d sorted" % sort.total_items, "the score reads as words, got %s" % sort.result_text())
	main.task.complete(0.1)
	await _frames(3)
	assert(main._verdict.word() == "That went badly.", "a poor task says so, got %s" % main._verdict.word())

	main.pending_action = "meet"
	main.enter_room("street", Vector2(1581, 560))
	await _frames(2)
	var meeting := main.task as Meeting
	assert(meeting != null, "the meeting starts on the street")
	Input.action_press("move_up")
	await _physics(40)
	Input.action_release("move_up")
	assert(main.arda.position.distance_to(meeting.active_mat()) <= Meeting.KNOCK_RADIUS, "Arda reaches the neighbours' mat")
	meeting.state = Meeting.State.IDLE
	await _leave_task(main)

	Run.new_run()
	Run.plan.counts["wall"] = 1
	main.enter_room("shore", Vector2(960, 700))
	await _frames(2)
	var wall: ShoreWall = main.room.get_node("ShoreWall")
	assert(wall.visible and wall.texture == ShoreWall.TEXTURES[WorldState.Wall.STANDING], "the wall stands in 2026")
	Input.action_press("move_up")
	await _physics(40)
	Input.action_release("move_up")
	assert(main.arda.position.y > ShoreWall.FOOT_Y, "the wall stops Arda, got y %f" % main.arda.position.y)
	WorldClock.scrub(2080.0)
	await _frames(1)
	assert(wall.texture == ShoreWall.TEXTURES[WorldState.Wall.BREACHED], "the wall is broken by 2080")
	Run.new_run()
	WorldClock.scrub(2026.0)
	await _frames(1)
	assert(not wall.visible, "a plan with no wall shows no wall")


func _leave_task(main: Main) -> void:
	main.task.complete(0.0)
	await _frames(3)


func _ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _physics(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
