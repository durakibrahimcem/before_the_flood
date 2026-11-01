class_name Meeting
extends Task
## The neighbourhood meeting. The family next door state their worries as quiet
## lines; the player walks to their doormat, knocks with E and picks 1 of 3
## arguments with the mouse or keys 1 to 3. No named neighbours, no audio.

enum State { IDLE, AWAIT_KNOCK, WORRY, REPLY, DONE }

const BASE_GOAL := 2
const KNOCK_RADIUS := 110.0
const WORRIES_PATH := "res://tasks/meeting/worries.json"
const SEED_BASE := 20261031
const WORRY_CARDS_DELAY := 0.4
const REPLY_TIME := 1.5
const NEXT_WORRY_BEAT := 0.8
const CLOSE_TIME := 1.2
const HINT_FADE_AT := 4.0
## UI sits above the y-sorted street, so the walker never draws over it.
const UI_Z := 10
const CRAYON := Color("d98a3f")
const AMBER := Color("e0a44e")
const LAMPS_LINE := "The lamps come on down the street."
const EVENING_LINE := "The evening closes. Another day, then."

@export var time_limit: float = 45.0
@export var hint_text: String = "Walk to the neighbours' door and press E to knock."
## The foot of the door Ebru painted on the house next door.
@export var door_pos: Vector2 = Vector2(1581.0, 381.0)
@export var spawn_pos: Vector2 = Vector2(1000.0, 450.0)

var state: State = State.IDLE
var walker: CharacterBody2D = null
var goal: int = 0
var worries_asked: int = 0
var right_answers: int = 0
var elapsed: float = 0.0
## Topics of this run's worries, in the order the doors ask them.
var run_topics: Array[String] = []

static var _pool: Array = []
static var _pool_offset := 0

var _door: MeetingDoor
var _door_worries: Array = []
var _worry_cursor := 0
var _run_worry_index := 0
var _worry: Dictionary = {}
var _card_texts: Array[String] = []
var _right_card := 0
var _cards_shown := false
var _cards: MeetingCards
var _hint: Label
var _close_label: Label
var _closing := false
var _hint_tween: Tween


func _init() -> void:
	action = "meet"


func _begin() -> void:
	goal = target_count(BASE_GOAL)
	time_limit = target_time(time_limit)
	right_answers = 0
	worries_asked = 0
	elapsed = 0.0
	_closing = false
	_cards_shown = false
	y_sort_enabled = true
	var worries := _pick_worries(goal)
	run_topics.clear()
	for worry: Dictionary in worries:
		run_topics.append(worry["topic"])
	_build_scene()
	_door_worries = worries
	_worry_cursor = 0
	_run_worry_index = 0
	state = State.AWAIT_KNOCK
	_door.set_active(true)
	_show_hint()


func _process(delta: float) -> void:
	if state == State.IDLE or state == State.DONE:
		return
	elapsed += delta
	queue_redraw()
	if _closing:
		return
	if elapsed >= time_limit:
		_begin_close(EVENING_LINE)
		return
	if state == State.AWAIT_KNOCK and Input.is_action_pressed("interact") and _in_knock_range():
		_on_knock()


## The single guarded path for answering; card clicks and number keys land here.
## Answers only count once the cards are on show, so mouse and keys agree.
func choose(index: int) -> void:
	if _done or _closing or state != State.WORRY or not _cards_shown:
		return
	_cards_shown = false
	state = State.REPLY
	_cards.hide_cards()
	if index == _right_card:
		right_answers += 1
		_door.light_up()
		_door.reply(_worry["right_reply"])
	else:
		_door.reply(_worry["wrong_reply"])
	_after(REPLY_TIME, _after_reply)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		var index: int = key.keycode - KEY_1
		if index >= 0 and index <= 2:
			choose(index)


## World position of the mat the player should walk to next.
func active_mat() -> Vector2:
	return _door.mat_position()


## For scripted demos: the card index holding answers[0], the true answer.
## Call while the state is WORRY.
func bot_right_card() -> int:
	assert(state == State.WORRY, "bot_right_card() needs the WORRY state")
	return _right_card


## For scripted demos: the exact path a mouse click on a card takes.
func bot_press_card(index: int) -> void:
	_cards.press(index)


## For scripted demos: the exact path a number key takes.
func bot_send_key(index: int) -> void:
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = [KEY_1, KEY_2, KEY_3][index]
	_unhandled_key_input(key)


## For scripted demos: true once the argument cards are on show.
func bot_cards_ready() -> bool:
	return _cards_shown


func result_text() -> String:
	return "%d of %d worries answered" % [right_answers, goal]


func instruction() -> CanvasItem:
	return _hint


func debug_note() -> String:
	return "%d %d %d %d" % [right_answers, worries_asked, state, _right_card if _cards_shown else -1]


func _on_knock() -> void:
	Sfx.play("knock")
	_hide_hint()
	state = State.WORRY
	worries_asked += 1
	_present_worry()


func _present_worry() -> void:
	_worry = _door_worries[_worry_cursor]
	_door.say(_worry["worry"])
	_deal_answers()
	_run_worry_index += 1
	_after(WORRY_CARDS_DELAY, _show_cards)


func _show_cards() -> void:
	if _done or _closing or state != State.WORRY:
		return
	_cards.show_answers(_card_texts)
	_cards_shown = true


## Seeded Fisher-Yates over the three answers, so the true one moves around.
func _deal_answers() -> void:
	var order: Array[int] = [0, 1, 2]
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_BASE + repeat_index * 97 + _run_worry_index * 7
	for i: int in range(order.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: int = order[i]
		order[i] = order[j]
		order[j] = swap
	_right_card = order.find(0)
	_card_texts.clear()
	for slot: int in 3:
		_card_texts.append(_worry["answers"][order[slot]])


func _after_reply() -> void:
	if _done or _closing or state != State.REPLY:
		return
	_worry_cursor += 1
	if _worry_cursor < _door_worries.size():
		_after(NEXT_WORRY_BEAT, _present_next_worry)
		return
	_door.set_active(false)
	_door.hide_speech()
	_begin_close(LAMPS_LINE)


func _present_next_worry() -> void:
	if _done or _closing or state != State.REPLY:
		return
	state = State.WORRY
	worries_asked += 1
	_present_worry()


func _begin_close(line: String) -> void:
	_closing = true
	_cards_shown = false
	state = State.REPLY
	_cards.hide_cards()
	_close_label.text = line
	_close_label.visible = true
	_close_label.modulate.a = 0.0
	var tween := create_tween().bind_node(self)
	tween.tween_property(_close_label, "modulate:a", 1.0, 0.3)
	_after(CLOSE_TIME, _finish)


func _finish() -> void:
	if _done:
		return
	complete(right_answers / float(goal))
	state = State.DONE


## Runs callback after seconds; the tween dies with this node, so a freed
## meeting never resumes a pending beat.
func _after(seconds: float, callback: Callable) -> void:
	var timer := create_tween().bind_node(self)
	timer.tween_interval(seconds)
	timer.tween_callback(callback)


func _in_knock_range() -> bool:
	return walker != null and walker.global_position.distance_to(active_mat()) <= KNOCK_RADIUS


func _build_scene() -> void:
	_door = MeetingDoor.new()
	_door.position = door_pos
	add_child(_door)
	_cards = MeetingCards.new()
	_cards.z_index = UI_Z
	add_child(_cards)
	_cards.card_chosen.connect(choose)
	_hint = Label.new()
	_hint.z_index = UI_Z
	_hint.text = hint_text
	_hint.position = Vector2(510.0, 690.0)
	_hint.size = Vector2(900.0, 44.0)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.rotation = deg_to_rad(-2.0)
	_hint.modulate.a = 0.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override("font_size", 34)
	_hint.add_theme_color_override("font_color", CRAYON)
	add_child(_hint)
	_close_label = Label.new()
	_close_label.z_index = UI_Z
	_close_label.position = Vector2(510.0, 826.0)
	_close_label.size = Vector2(900.0, 50.0)
	_close_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_close_label.visible = false
	_close_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_close_label.add_theme_font_size_override("font_size", 34)
	_close_label.add_theme_color_override("font_color", AMBER)
	add_child(_close_label)
	_claim_walker()


## The shape-less TaskWalker still moves with move_and_slide, so no collision
## shape is added here.
func _claim_walker() -> void:
	var walkers: Array[Node] = get_tree().get_nodes_in_group("walker")
	if walkers.is_empty():
		var spawned := TaskWalker.new()
		spawned.position = spawn_pos
		add_child(spawned)
		walker = spawned
	else:
		walker = walkers[0] as CharacterBody2D


func _show_hint() -> void:
	_hint.modulate.a = 0.0
	_hint_tween = create_tween().bind_node(self)
	_hint_tween.tween_property(_hint, "modulate:a", 1.0, 0.4)
	_hint_tween.tween_interval(HINT_FADE_AT - 0.4)
	_hint_tween.tween_property(_hint, "modulate:a", Task.REMINDER_ALPHA, 0.8)


func _hide_hint() -> void:
	if _hint.modulate.a <= 0.0:
		return
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_tween = create_tween().bind_node(self)
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 0.25)


func _draw() -> void:
	_draw_hint_underline()
	_draw_timer()


func _draw_hint_underline() -> void:
	if _hint == null or _hint.modulate.a <= 0.03:
		return
	var points := PackedVector2Array()
	for i: int in 21:
		var t := i / 20.0
		points.append(Vector2(650.0 + t * 620.0, 748.0 + sin(t * 9.0) * 3.0))
	draw_polyline(points, Color(CRAYON, _hint.modulate.a * 0.7), 3.0)


func _draw_timer() -> void:
	if _closing or state == State.IDLE or state == State.DONE or time_limit <= 0.0:
		return
	var left := 1.0 - clampf(elapsed / time_limit, 0.0, 1.0)
	if left <= 0.0:
		return
	var width := 210.0 * left
	draw_line(Vector2(960.0 - width, 1055.0), Vector2(960.0 + width, 1055.0), Color(AMBER, 0.75), 4.0)


func _pick_worries(count: int) -> Array:
	var pool := _load_pool()
	# Consecutive worries wrap the pool, so a run's worries stay distinct:
	# the game's repeats cap goal at 5, within the 6-worry pool.
	var picked: Array = []
	for i: int in count:
		picked.append(pool[(_pool_offset + i) % pool.size()])
	_pool_offset = (_pool_offset + count) % pool.size()
	return picked


## Loads and validates the pool once per game run. Convention inside each
## worry: answers[0] truly answers the worry, answers[1] is true but beside
## the point, answers[2] blames or preaches.
static func _load_pool() -> Array:
	if not _pool.is_empty():
		return _pool
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(WORRIES_PATH))
	assert(parsed is Dictionary, "worries.json must parse into an object")
	var worries: Array = (parsed as Dictionary)["worries"]
	assert(worries.size() == 6, "the worry pool must hold exactly 6 worries, got %d" % worries.size())
	for worry: Dictionary in worries:
		assert(worry.has_all(["topic", "worry", "answers", "right_reply", "wrong_reply"]), "a worry misses a required key")
		assert(str(worry["worry"]).length() > 0, "a worry line is empty")
		assert(str(worry["right_reply"]).length() > 0, "a right reply is empty")
		assert(str(worry["wrong_reply"]).length() > 0, "a wrong reply is empty")
		var answers: Array = worry["answers"]
		assert(answers.size() == 3, "a worry needs exactly 3 answers")
		for answer: Variant in answers:
			assert(str(answer).length() > 0, "an answer is empty")
	_pool = worries
	return worries
