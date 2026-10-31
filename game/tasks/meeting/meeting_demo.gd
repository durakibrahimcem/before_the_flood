extends Node
## Gate demo for the meeting task: a scripted bot walks, knocks and answers
## through every path a player can take, and asserts the results. Each run
## returns false when an assert aborts it, so a failure can never reach the
## DEMO PASS line.

const MEETING := preload("res://tasks/meeting/meeting.tscn")
const WORRIES_PATH := "res://tasks/meeting/worries.json"
const EXPECTED_TOPICS := ["cost", "one-street", "age", "distance", "disruption", "distrust"]
const WALK_STOP := 90.0
const PHYSICS_GUARD := 600
const CARDS_GUARD := 120
const RUN_SECONDS := 30.0

var _topics: Array[String] = []
## Card slots the true answer landed on, across all runs; a healthy shuffle
## must not leave it glued to one card.
var _right_slots := {}


func _ready() -> void:
	await _frames(2)
	if not _check_pool():
		_fail("the worry pool is broken")
		return
	if not await _run_auto_finish():
		_fail("run 1 auto_finish did not finish")
		return
	if not await _run_perfect():
		_fail("run 2 perfect did not finish")
		return
	var topics2 := _topics.duplicate()
	if not await _run_poor():
		_fail("run 3 poor did not finish")
		return
	var topics3 := _topics.duplicate()
	if not await _run_timeout():
		_fail("run 4 timeout did not finish")
		return
	var topics4 := _topics.duplicate()
	if not await _run_repeat(topics4, topics3, topics2):
		_fail("run 5 repeat did not finish")
		return
	assert(_right_slots.size() >= 2, "the true answer must move between cards, saw only %d slot(s)" % _right_slots.size())
	print("DEMO PASS")
	get_tree().quit()


func _check_pool() -> bool:
	var meeting := MEETING.instantiate() as Meeting
	assert(meeting != null, "meeting.tscn must instantiate a Meeting")
	assert(meeting.action == "meet", "the meeting task must use action meet, got %s" % meeting.action)
	meeting.free()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(WORRIES_PATH))
	assert(parsed is Dictionary, "worries.json must parse into an object")
	var worries: Array = (parsed as Dictionary)["worries"]
	assert(worries.size() == 6, "the pool must hold exactly 6 worries, got %d" % worries.size())
	var topics: Array[String] = []
	for worry: Dictionary in worries:
		assert(worry.has_all(["topic", "worry", "answers", "right_reply", "wrong_reply"]), "a worry misses a required key")
		assert(str(worry["worry"]).length() > 0, "a worry line is empty")
		assert(str(worry["right_reply"]).length() > 0, "a right reply is empty")
		assert(str(worry["wrong_reply"]).length() > 0, "a wrong reply is empty")
		var answers: Array = worry["answers"]
		assert(answers.size() == 3, "a worry needs exactly 3 answers")
		for answer: Variant in answers:
			assert(str(answer).length() > 0, "an answer is empty")
		topics.append(str(worry["topic"]))
	for topic: String in EXPECTED_TOPICS:
		assert(topics.has(topic), "the pool must cover the topic %s" % topic)
	print("pool ok")
	return true


func _run_auto_finish() -> bool:
	assert(_walker_group().is_empty(), "run 1 expects an empty walker group")
	var meeting: Meeting = await _fresh_meeting()
	var perfs := _record(meeting)
	meeting.start(0, true)
	await _frames(3)
	assert(perfs.size() == 1, "auto_finish must finish exactly once, got %d" % perfs.size())
	assert(is_equal_approx(float(perfs[0]), 0.0), "auto_finish must record zero")
	assert(meeting.state == Meeting.State.IDLE, "auto_finish must leave the meeting idle")
	assert(_walker_group().is_empty(), "auto_finish must not spawn a walker")
	await _free_meeting(meeting)
	print("run 1 auto_finish ok")
	return true


func _run_perfect() -> bool:
	assert(_walker_group().is_empty(), "run 2 expects an empty walker group")
	var meeting: Meeting = await _fresh_meeting()
	var perfs := _record(meeting)
	meeting.start(0, false)
	await _bot_play(meeting, "keys")
	await _wait_finished(perfs, "run 2")
	assert(is_equal_approx(float(perfs[0]), 1.0), "a perfect run must record 1.0, got %s" % str(perfs[0]))
	assert(meeting.worries_asked == 2, "run 2 must ask both worries, got %d" % meeting.worries_asked)
	assert(meeting.elapsed < meeting.time_limit, "run 2 must end by answering, not by timeout")
	assert(_walker_group().size() == 1, "run 2 must leave exactly one walker, got %d" % _walker_group().size())
	_topics = meeting.run_topics.duplicate()
	await _free_meeting(meeting)
	print("run 2 perfect ok")
	return true


func _run_poor() -> bool:
	assert(_walker_group().is_empty(), "run 3 expects an empty walker group")
	var meeting: Meeting = await _fresh_meeting()
	var perfs := _record(meeting)
	meeting.start(0, false)
	await _bot_play(meeting, "cards")
	await _wait_finished(perfs, "run 3")
	assert(is_equal_approx(float(perfs[0]), 0.0), "a poor run must record 0.0, got %s" % str(perfs[0]))
	assert(meeting.right_answers == 0, "run 3 must not count right answers")
	_topics = meeting.run_topics.duplicate()
	await _free_meeting(meeting)
	print("run 3 poor ok")
	return true


func _run_timeout() -> bool:
	assert(_walker_group().is_empty(), "run 4 expects an empty walker group")
	var planted := TaskWalker.new()
	planted.position = Vector2(960.0, 880.0)
	add_child(planted)
	await _frames(2)
	assert(_walker_group().size() == 1, "the planted walker must join the group")
	var meeting: Meeting = await _fresh_meeting()
	var perfs := _record(meeting)
	meeting.time_limit = 1.5
	meeting.start(0, false)
	await _wait_finished(perfs, "run 4")
	assert(is_equal_approx(float(perfs[0]), 0.0), "an idle run must record 0.0, got %s" % str(perfs[0]))
	assert(meeting.walker == planted, "the meeting must reuse the walker from the group")
	assert(_walker_group().size() == 1, "the meeting must not spawn a second walker")
	_topics = meeting.run_topics.duplicate()
	await _free_meeting(meeting)
	planted.queue_free()
	await _frames(2)
	assert(_walker_group().is_empty(), "freeing the planted walker must clear the group")
	print("run 4 timeout ok")
	return true


func _run_repeat(topics4: Array[String], topics3: Array[String], topics2: Array[String]) -> bool:
	assert(_walker_group().is_empty(), "run 5 expects an empty walker group")
	var meeting: Meeting = await _fresh_meeting()
	var perfs := _record(meeting)
	meeting.start(1, false)
	assert(meeting.goal == 3, "repeat 1 must raise the goal to 3, got %d" % meeting.goal)
	await _bot_play(meeting, "mixed")
	await _wait_finished(perfs, "run 5")
	assert(is_equal_approx(float(perfs[0]), 2.0 / 3.0), "run 5 must record two of three, got %s" % str(perfs[0]))
	assert(meeting.worries_asked == 3, "run 5 must ask three worries, got %d" % meeting.worries_asked)
	_topics = meeting.run_topics.duplicate()
	for topic: String in _topics:
		assert(_topics.count(topic) == 1, "run 5 must not repeat a worry within the run")
	_assert_disjoint(_topics, topics4, "run 5 must use new worries, not run 4's")
	_assert_disjoint(topics4, topics3, "run 4 must use new worries, not run 3's")
	_assert_disjoint(topics3, topics2, "run 3 must use new worries, not run 2's")
	await _free_meeting(meeting)
	print("run 5 repeat ok")
	return true


## Walks, knocks and answers through the same paths a player uses, until the
## meeting is done or its clock runs out. keys: all right by number key,
## cards: all wrong by card press, mixed: two right then one wrong.
func _bot_play(meeting: Meeting, mode: String) -> void:
	var worries_seen := 0
	while meeting.state != Meeting.State.DONE and meeting.elapsed < meeting.time_limit:
		if meeting.state == Meeting.State.AWAIT_KNOCK:
			await _bot_walk_and_knock(meeting)
			assert(meeting.state != Meeting.State.AWAIT_KNOCK, "a knock must open a worry")
		elif meeting.state == Meeting.State.WORRY:
			await _wait_cards(meeting)
			assert(meeting.state == Meeting.State.WORRY, "the worry must still be on show")
			var right := meeting.bot_right_card()
			_right_slots[right] = true
			if mode == "cards" or (mode == "mixed" and worries_seen >= 2):
				meeting.bot_press_card((right + 1) % 3)
			else:
				meeting.bot_send_key(right)
			assert(meeting.state == Meeting.State.REPLY, "an answer must lead to a reply")
			worries_seen += 1
		else:
			await _frames(1)


## Waits until the argument cards are on show, like a player reading them first.
func _wait_cards(meeting: Meeting) -> void:
	var guard := 0
	while not meeting.bot_cards_ready() and guard < CARDS_GUARD:
		await _frames(1)
		guard += 1
	assert(guard < CARDS_GUARD, "the argument cards must come on show")


func _bot_walk_and_knock(meeting: Meeting) -> void:
	var mat: Vector2 = meeting.active_mat()
	var move := "move_left" if mat.x < meeting.walker.global_position.x else "move_right"
	Input.action_press(move)
	var guard := 0
	while meeting.walker.global_position.distance_to(mat) > WALK_STOP and guard < PHYSICS_GUARD:
		await _physics(1)
		guard += 1
	Input.action_release(move)
	assert(meeting.walker.global_position.distance_to(mat) <= WALK_STOP, "the walker must reach the doormat, so check move_and_slide")
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")


func _fresh_meeting() -> Meeting:
	var meeting := MEETING.instantiate() as Meeting
	assert(meeting != null, "meeting.tscn must instantiate a Meeting")
	add_child(meeting)
	await _frames(2)
	return meeting


func _record(meeting: Meeting) -> Array:
	var perfs: Array = []
	meeting.finished.connect(func(performance: float) -> void: perfs.append(performance))
	return perfs


func _wait_finished(perfs: Array, label: String) -> void:
	var deadline := Time.get_ticks_msec() + int(RUN_SECONDS * 1000.0)
	while perfs.is_empty():
		await _frames(1)
		assert(Time.get_ticks_msec() < deadline, "%s must finish within %d seconds" % [label, RUN_SECONDS])
	assert(perfs.size() == 1, "%s must finish exactly once, got %d" % [label, perfs.size()])


func _assert_disjoint(first: Array[String], second: Array[String], label: String) -> void:
	for topic: String in first:
		assert(not second.has(topic), "%s (repeated topic %s)" % [label, topic])


func _fail(why: String) -> void:
	printerr("DEMO FAIL: " + why)
	get_tree().quit(1)


func _free_meeting(meeting: Meeting) -> void:
	meeting.queue_free()
	await _frames(2)


func _walker_group() -> Array[Node]:
	return get_tree().get_nodes_in_group("walker")


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _physics(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
