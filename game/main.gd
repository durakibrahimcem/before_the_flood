class_name Main
extends Node2D
## Runs the game: rooms, the calendar, tasks, the final walk and the ending.

const ROOMS := {
	"bedroom": preload("res://rooms/bedroom/bedroom.tscn"),
	"aylin": preload("res://rooms/aylin/aylin.tscn"),
	"salon": preload("res://rooms/salon/salon.tscn"),
	"street": preload("res://rooms/street/street.tscn"),
	"shore": preload("res://rooms/shore/shore.tscn"),
}
const TASKS := {
	"sort": { "scene": "res://tasks/sort/sort.tscn", "room": "street" },
	"grass": { "scene": "res://tasks/seagrass/seagrass.tscn", "room": "shore" },
	"dune": { "scene": "res://tasks/dunes/dunes_task.tscn", "room": "shore" },
	"light": { "scene": "res://tasks/lights/lights.tscn", "room": "salon" },
	"meet": { "scene": "res://tasks/meeting/meeting.tscn", "room": "street" },
	"wall": { "scene": "res://tasks/seawall/seawall.tscn", "room": "shore" },
}
const FRIDGE := Vector2(1700, 720)
const FRIDGE_REACH := 260.0
const FRIDGE_PROMPT := "Press E for the calendar"
const FRIDGE_PROMPT_SPOT := Vector2(1480, 340)
const PLANT_PROMPT := "Press E to plant a tree"
const PLANT_PROMPT_LIFT := Vector2(-150, -130)
const PLANT_REACH := 125.0
const PLANT_LINE := "A small tree. It will take years to grow."
const BOWLS_SPOT := Vector2(90, 585)
const BOWLS_REACH := 170.0
const BOWLS_PROMPT := "Press E to feed Brian"
const BOWLS_LINE := "Brian's bowls are full."
const BOWLS_PROMPT_SPOT := Vector2(30, 322)
const ASIDE_SECONDS := 2.5
const PROMPT_FADE_PER_SECOND := 6.0
## A judge may only have minutes, so skipping opens up early.
const SKIP_AFTER_ACTIONS := 2
const HINT_ROOM_NAMES := { "street": "the street", "shore": "the shore", "salon": "the salon" }
## Long enough to see the water before the paper covers it.
const PAPER_DELAY := 2.0
const HINT_FONT := 40
const SHAKE_PIXELS := 18.0
const SHAKE_STEPS := 8
const SHAKE_STEP_SECONDS := 0.05

## Tasks finish at once at normal strength. Used by demos and fast replays.
@export var auto_tasks: bool = false

## Demos set this to zero to keep their pace.
var paper_delay := PAPER_DELAY
var room: Room
var pending_action: String = ""
var task: Task
var final_walk: bool = false
var _seen_papers: Dictionary = {}
var _wall_state: int = WorldState.Wall.NONE
var _skipping := false
var _verdict: TaskVerdict
var _prompt: Label
var _prompt_offered := false

@onready var arda: Arda = $Arda
@onready var time: TimeControl = $TimeControl
@onready var calendar: Calendar = $Ui/Calendar
@onready var hint: Label = $Ui/Hint
@onready var newspaper: NewspaperOverlay = $Newspaper
@onready var ending: EndSequence = $Ending
@onready var controls: ControlsScreen = $Controls


func _ready() -> void:
	calendar.action_chosen.connect(_on_action_chosen)
	calendar.closed.connect(_on_calendar_closed)
	# This script owns the paper, so seen pages stay seen and it never pops up twice.
	newspaper.auto_popup = false
	newspaper.dismissed.connect(_on_paper_dismissed)
	ending.retry_requested.connect(new_run)
	ending.code_loaded.connect(_on_code_loaded)
	controls.started.connect(_on_controls_started)
	$Pause.opening.connect(time.stop_scrub)
	WorldClock.jumped.connect(_on_jumped)
	Run.plan_complete.connect(_on_plan_complete)
	WorldClock.year_changed.connect(_on_year_changed)
	ending.hide()
	_verdict = TaskVerdict.new()
	add_child(_verdict)
	_build_prompt()
	Settings.size_text(hint, HINT_FONT)
	enter_room("bedroom", Vector2.INF)
	time.enabled = false
	controls.open()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and can_open_calendar():
		get_viewport().set_input_as_handled()
		open_calendar()
	elif event.is_action_pressed("interact") and bowls_in_reach():
		get_viewport().set_input_as_handled()
		feed_brian()
	elif event.is_action_pressed("interact") and planter_in_reach() >= 0:
		get_viewport().set_input_as_handled()
		plant_tree(planter_in_reach())
	elif event.is_action_pressed("skip") and task != null and can_skip():
		get_viewport().set_input_as_handled()
		_skipping = true
		task.complete(0.0)


## Past attempts unlock skipping, so a new plan can be tested in under 2 minutes.
func is_replay() -> bool:
	return not Run.ghosts.is_empty()


func can_skip() -> bool:
	return is_replay() or Run.plan.total() >= SKIP_AFTER_ACTIONS


func _process(delta: float) -> void:
	var at_fridge := can_open_calendar()
	var at_planter := not at_fridge and planter_in_reach() >= 0
	var at_bowls := bowls_in_reach()
	if at_bowls:
		_prompt.text = BOWLS_PROMPT
		_prompt.position = BOWLS_PROMPT_SPOT
	elif at_fridge:
		_prompt.text = FRIDGE_PROMPT
		_prompt.position = FRIDGE_PROMPT_SPOT
	elif at_planter:
		_prompt.text = PLANT_PROMPT
		_prompt.position = arda.position + PLANT_PROMPT_LIFT
	var goal := 1.0 if at_fridge or at_planter or at_bowls or _prompt_offered else 0.0
	_prompt_offered = false
	_prompt.modulate.a = move_toward(_prompt.modulate.a, goal, PROMPT_FADE_PER_SECOND * delta)


## Lets the opening use the same prompt as the fridge. Call it each frame the prompt applies.
func offer_prompt(text: String, spot: Vector2) -> void:
	_prompt.text = text
	_prompt.position = spot
	_prompt_offered = true


func prompt_text() -> String:
	return _prompt.text if _prompt.modulate.a > 0.0 else ""


func _build_prompt() -> void:
	_prompt = Label.new()
	_prompt.modulate.a = 0.0
	Settings.size_text(_prompt, 36)
	_prompt.add_theme_color_override("font_color", Door.INK)
	_prompt.add_theme_color_override("font_outline_color", Door.OUTLINE)
	_prompt.add_theme_constant_override("outline_size", 10)
	$Ui.add_child(_prompt)


## Today's empty bowls, within reach. By the years they stay empty, there is no one to feed.
func bowls_in_reach() -> bool:
	return room.room_name == "salon" and task == null and not final_walk and not Run.fed_today() \
		and is_equal_approx(WorldClock.year, WorldClock.ERAS[0]) and arda.position.distance_to(BOWLS_SPOT) <= BOWLS_REACH


func feed_brian() -> void:
	Run.feed_brian()
	Sfx.play("drop")
	WorldClock.refresh()
	_aside(BOWLS_LINE)


## A short remark on the hint line, which then hands the line back to the objective.
func _aside(line: String) -> void:
	var objective := hint.text
	hint.text = line
	await get_tree().create_timer(ASIDE_SECONDS).timeout
	if hint.text == line:
		hint.text = objective


## The empty planter Arda can reach today, or -1.
func planter_in_reach() -> int:
	if room.room_name != "street" or task != null or final_walk or not is_equal_approx(WorldClock.year, WorldClock.ERAS[0]):
		return -1
	var spots := WorldProps.SAPLING_SPOTS
	for index: int in spots.size():
		if not index in Run.planted and arda.position.distance_to(spots[index]) <= PLANT_REACH:
			return index
	return -1


func plant_tree(index: int) -> void:
	Run.planted.append(index)
	Sfx.play("plant")
	WorldClock.refresh()
	_aside(PLANT_LINE)


func can_open_calendar() -> bool:
	return room.room_name == "salon" and not calendar.visible and task == null and pending_action == "" and not final_walk \
		and is_equal_approx(WorldClock.year, WorldClock.ERAS[0]) and Run.plan.total() < Plan.SLOTS \
		and arda.position.distance_to(FRIDGE) <= FRIDGE_REACH


func open_calendar() -> void:
	hint.text = ""
	time.enabled = false
	arda.frozen = true
	calendar.open()


func _on_calendar_closed() -> void:
	time.enabled = true
	arda.frozen = false


func enter_room(room_name: String, arrive_at: Vector2) -> void:
	if room != null:
		room.remove_child(arda)
		# Leave the tree now, so the old room's doors can't see Arda arrive and fire again.
		remove_child(room)
		room.queue_free()
	else:
		remove_child(arda)
	room = ROOMS[room_name].instantiate()
	room.door_used.connect(_on_door_used, CONNECT_DEFERRED)
	add_child(room)
	move_child(room, 0)
	arda.position = room.spawn if arrive_at == Vector2.INF else arrive_at
	room.add_child(arda)
	arda.room = room
	$Storm.outdoors = room_name in Room.OUTDOOR_ROOMS
	WorldClock.refresh()
	_start_pending_task()


## Doors stay shut during a task, so Arda can't walk out of it.
func _on_door_used(target_room: String, arrive_at: Vector2) -> void:
	if task == null:
		Sfx.play("door")
		arda.latch_up()
		enter_room(target_room, arrive_at)


func new_run() -> void:
	ending.hide()
	final_walk = false
	_seen_papers.clear()
	Run.new_run()
	enter_room("salon", FRIDGE)
	time.enabled = true
	hint.text = "Open the calendar on the fridge."


func _on_controls_started() -> void:
	if auto_tasks:
		time.enabled = true
		hint.text = "Go to the salon, and open the calendar on the fridge."
		return
	var opening := Opening.new()
	opening.main = self
	add_child(opening)
	opening.finished.connect(opening.queue_free)
	opening.play()


func _on_action_chosen(action: String) -> void:
	pending_action = action
	time.enabled = true
	arda.frozen = false
	var place: String = TASKS[action]["room"]
	hint.text = "Go to %s." % HINT_ROOM_NAMES[place]
	_start_pending_task()


func _start_pending_task() -> void:
	if pending_action == "" or task != null or not is_node_ready():
		return
	var spec: Dictionary = TASKS[pending_action]
	if room.room_name != spec["room"]:
		return
	if not is_equal_approx(WorldClock.year, WorldClock.ERAS[0]):
		hint.text = "Tap T to come back to today."
		return
	hint.text = "Press Tab to skip." if can_skip() else ""
	time.enabled = false
	room.hold_view = true
	task = (load(spec["scene"]) as PackedScene).instantiate()
	task.finished.connect(_on_task_finished)
	add_child(task)
	task.start(int(Run.plan.counts[pending_action]), auto_tasks)


func _on_task_finished(performance: float) -> void:
	var action := pending_action
	if not _skipping and not auto_tasks:
		_verdict.show_result(performance, task.result_text())
	_skipping = false
	hint.text = ""
	pending_action = ""
	task.queue_free.call_deferred()
	task = null
	time.enabled = true
	enter_room.call_deferred("salon", FRIDGE)
	Run.record(action, performance)
	if Run.plan.total() < Plan.SLOTS:
		hint.text = "Day %d. Open the calendar, or press T to see what changed." % Run.day


func _on_plan_complete() -> void:
	final_walk = true
	hint.text = ""
	time.enabled = false
	_show_era.call_deferred(WorldClock.ERAS[1])


func _show_era(era: int) -> void:
	WorldClock.jump(era)
	if final_walk:
		_open_paper(era)


func _on_jumped(era: int) -> void:
	if era == WorldClock.ERAS[0]:
		_start_pending_task.call_deferred()
	if not final_walk and era != WorldClock.ERAS[0] and not _seen_papers.has("%s/%d" % [Run.plan.cache_key(), era]):
		_open_paper.call_deferred(era)


func _open_paper(era: int) -> void:
	_seen_papers["%s/%d" % [Run.plan.cache_key(), era]] = true
	time.enabled = false
	if paper_delay > 0.0:
		arda.frozen = true
		await get_tree().create_timer(paper_delay, false).timeout
	newspaper.show_for(Run.plan, era)


func _on_paper_dismissed() -> void:
	arda.frozen = false
	if not final_walk:
		time.enabled = true
	elif WorldClock.nearest_era() == WorldClock.ERAS[1]:
		_show_era(WorldClock.ERAS[2])
	else:
		_finish_run()


func _on_year_changed(state: WorldState) -> void:
	if _wall_state == WorldState.Wall.CRACKED and state.wall_state == WorldState.Wall.BREACHED:
		Sfx.play("block")
		Sfx.play("wave_crash")
		room.start_surge()
		_shake()
	_wall_state = state.wall_state


func _shake() -> void:
	if Settings.calm_storm:
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for step: int in SHAKE_STEPS:
		var size := SHAKE_PIXELS * (1.0 - float(step) / SHAKE_STEPS)
		tween.tween_property(self, "position", Vector2(size if step % 2 == 0 else -size, 0.0), SHAKE_STEP_SECONDS)
	tween.tween_property(self, "position", Vector2.ZERO, SHAKE_STEP_SECONDS)


func _finish_run() -> void:
	Run.end_run()
	ending.show()
	ending.play(Sim.outcome(Run.plan))


func _on_code_loaded(code: String) -> void:
	ending.hide()
	_seen_papers.clear()
	Run.load_code(code)
