extends Node
## Gate demo for the lights task: a bot plays a perfect run, a poor run, and an auto-finish run.

const LIGHTS := preload("res://tasks/lights/lights.tscn")
const DEADZONE := 14.0
const FLIP_DIST := 70.0
const INTERACT_HOLD := 3
const NEIGHBOUR_GAP_MS := 800

var failures := 0
var task: LightsTask = null
var run_active := false
var perfect := true
var targets: Array[LightSwitch] = []
var interact_hold := 0
var finished_count := 0
var performance := -1.0
var home_order: Array[int] = []
var home_times: Array[int] = []


func _ready() -> void:
	await _run_perfect()
	await _run_poor()
	await _run_auto()
	if failures == 0:
		print("DEMO PASS")
		get_tree().quit(0)
	else:
		get_tree().quit(1)


## The bot drives the real input actions. The interact pulse spans several physics
## ticks, so it lands whatever order the bot and the task run in.
func _physics_process(_delta: float) -> void:
	if not run_active or task == null or not is_instance_valid(task) or targets.is_empty():
		return
	if task.phase != 1:
		_release_all()
		return
	if not perfect and task.switches_done >= 1:
		_release_all()
		return
	var walker := task.walker
	if walker == null or not is_instance_valid(walker):
		return
	var target := _pick_target(walker)
	if target == null:
		_release_all()
		return
	_axis("move_left", "move_right", target.stand.x - walker.position.x)
	_axis("move_up", "move_down", target.stand.y - walker.position.y)
	if walker.position.distance_to(target.stand) <= FLIP_DIST:
		_pulse_interact()
	else:
		interact_hold = 0
		Input.action_release("interact")


func _pick_target(walker: CharacterBody2D) -> LightSwitch:
	if not perfect:
		var first: LightSwitch = targets[0]
		return null if first.flipped else first
	var best: LightSwitch = null
	var best_distance := INF
	for light: LightSwitch in targets:
		if light.flipped or not is_instance_valid(light):
			continue
		var distance := walker.position.distance_to(light.stand)
		if distance < best_distance:
			best = light
			best_distance = distance
	return best


func _axis(negative: String, positive: String, offset: float) -> void:
	if absf(offset) <= DEADZONE:
		Input.action_release(negative)
		Input.action_release(positive)
	elif offset > 0.0:
		Input.action_press(positive)
		Input.action_release(negative)
	else:
		Input.action_press(negative)
		Input.action_release(positive)


## Press, hold a few ticks, release, and press again until the switch flips.
func _pulse_interact() -> void:
	if interact_hold <= 0:
		Input.action_press("interact")
		interact_hold = INTERACT_HOLD
	else:
		interact_hold -= 1
		if interact_hold == 0:
			Input.action_release("interact")


func _release_all() -> void:
	interact_hold = 0
	Input.action_release("interact")
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")


func _run_perfect() -> void:
	print("run 1: perfect")
	task = LIGHTS.instantiate()
	add_child(task)
	_watch()
	task.start(0, false)
	perfect = true
	targets = _switches_of(task)
	run_active = true
	await task.finished
	run_active = false
	_release_all()
	_check(finished_count == 1, "perfect: finished emitted exactly once, got %d" % finished_count)
	_check(is_equal_approx(performance, 1.0), "perfect: performance is 1.0, got %f" % performance)
	_check(task.switches_done == 3, "perfect: all 3 switches flipped, got %d" % task.switches_done)
	_check(task.phase == 2, "perfect: the task ends in phase 2, got %d" % task.phase)
	_check(task.action == "light", "perfect: the action is light, got %s" % task.action)
	_check(task.walker != null and task.walker.is_in_group("walker"), "perfect: the task spawned a walker")
	_check_homes()
	_check_containment()
	task.queue_free()
	await _frames(2)


func _run_poor() -> void:
	print("run 2: poor")
	var walker := TaskWalker.new()
	walker.position = Vector2(960, 940)
	add_child(walker)
	task = LIGHTS.instantiate()
	add_child(task)
	_watch()
	task.start(0, false)
	perfect = false
	targets = _switches_of(task)
	run_active = true
	await task.finished
	run_active = false
	_release_all()
	_check(finished_count == 1, "poor: finished emitted exactly once, got %d" % finished_count)
	_check(absf(performance - 1.0 / 3.0) <= 0.001, "poor: performance is one third, got %f" % performance)
	_check(task.switches_done == 1, "poor: exactly 1 switch flipped, got %d" % task.switches_done)
	_check(task.phase == 2, "poor: the task ends in phase 2, got %d" % task.phase)
	_check_homes()
	_check(task.walker == walker, "poor: the task used the walker it found")
	task.queue_free()
	await _frames(2)
	walker.queue_free()
	await _frames(2)


func _run_auto() -> void:
	print("run 3: auto finish")
	task = LIGHTS.instantiate()
	add_child(task)
	_watch()
	task.start(0, true)
	await task.finished
	_check(finished_count == 1, "auto: finished emitted exactly once, got %d" % finished_count)
	_check(is_equal_approx(performance, 0.0), "auto: performance is 0.0, got %f" % performance)
	task.queue_free()
	await _frames(2)


func _watch() -> void:
	finished_count = 0
	performance = -1.0
	home_order.clear()
	home_times.clear()
	task.finished.connect(_on_finished)
	task.home_dark.connect(_on_home_dark)


func _on_finished(value: float) -> void:
	finished_count += 1
	performance = value


func _on_home_dark(home_index: int) -> void:
	home_order.append(home_index)
	home_times.append(Time.get_ticks_msec())


func _check_homes() -> void:
	_check(home_order.size() == 2 and home_order[0] == 0 and home_order[1] == 1,
		"the family goes dark first, then the neighbours, got %s" % str(home_order))
	for i: int in range(1, home_times.size()):
		_check(home_times[i] - home_times[i - 1] >= NEIGHBOUR_GAP_MS,
			"home %d follows after a quiet beat, got %d ms" % [i, home_times[i] - home_times[i - 1]])


## The tint must live inside the task's own layer, so it can only touch this scene.
func _check_containment() -> void:
	var night: CanvasLayer = null
	var tints: Array[CanvasModulate] = []
	for node: Node in _descendants(task):
		if node is CanvasLayer and (node as CanvasLayer).layer == 5:
			night = node
		if node is CanvasModulate:
			tints.append(node)
	_check(night != null, "the task keeps its glows inside a layer 5 CanvasLayer")
	_check(tints.size() == 1 and night != null and not night.is_ancestor_of(tints[0]),
		"the one CanvasModulate darkens the room's own canvas")


func _switches_of(root: Node) -> Array[LightSwitch]:
	var found: Array[LightSwitch] = []
	for node: Node in _descendants(root):
		if node is LightSwitch:
			found.append(node)
	return found


func _descendants(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	_walk(node, found)
	return found


func _walk(node: Node, found: Array[Node]) -> void:
	for child: Node in node.get_children():
		found.append(child)
		_walk(child, found)


func _check(ok: bool, label: String) -> void:
	if ok:
		return
	failures += 1
	print("DEMO FAIL: ", label)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
