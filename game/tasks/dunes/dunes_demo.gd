extends Node
## Demo bot for the dunes task: a perfect run, a poor run, and the replay skip.

const DUNES_SCENE := preload("res://tasks/dunes/dunes_task.tscn")
const ALL_ACTIONS: Array[String] = ["move_up", "move_down", "move_left", "move_right", "interact"]

var failures := 0

class RunLog:
	## Counts finished() emissions and keeps the last performance.
	var emissions := 0
	var performance := -1.0

	func record(value: float) -> void:
		emissions += 1
		performance = value


func _ready() -> void:
	_probe_checks()
	await _perfect_run()
	await _poor_run()
	await _auto_finish_check()
	if failures > 0:
		print("DEMO FAIL")
		get_tree().quit(1)
	else:
		print("DEMO PASS")
		get_tree().quit(0)


func _expect(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAILED: ", label)


func _probe_checks() -> void:
	var probe := DuneTask.new()
	_expect(probe.action == "dune", "action is dune")
	probe.repeat_index = 1
	_expect(probe.target_count(5) == 7, "target count grows to 7 at repeat 1, got %d" % probe.target_count(5))
	probe.free()


func _perfect_run() -> void:
	var task := DUNES_SCENE.instantiate() as DuneTask
	var log := RunLog.new()
	task.finished.connect(log.record)
	add_child(task)
	_expect(task.walker == null, "no walker before the task begins")
	task.start(0, false)
	var spawned := task.walker as TaskWalker
	_expect(spawned != null, "the task spawns a TaskWalker")
	if spawned != null:
		_expect(spawned.get_parent() == task, "the spawned walker belongs to the task")
	var steps := 0
	while task.planted_count < task.spots.size() and log.emissions == 0 and steps < 60:
		steps += 1
		if task.walker == null or not is_instance_valid(task.walker):
			_expect(false, "the task keeps a walker to drive")
			break
		var spot := _nearest_unplanted(task)
		if spot == null:
			_expect(false, "an unplanted spot exists to walk to")
			break
		if not await _walk_to(task, spot.global_position):
			_expect(false, "the bot reached the spot at " + str(spot.position))
			break
		await _tap_interact()
	await _physics(3)
	print("perfect run: performance ", log.performance)
	_expect(log.emissions == 1, "finished emitted once for the perfect run")
	_expect(is_equal_approx(log.performance, 1.0), "perfect run performance is 1.0, got %f" % log.performance)
	var all_planted := true
	for spot: DuneSpot in task.spots:
		all_planted = all_planted and spot.is_planted
	_expect(all_planted, "every spot is planted")
	task.queue_free()
	await _frames(3)
	_expect(get_tree().get_first_node_in_group("walker") == null, "the spawned walker dies with the task")


func _poor_run() -> void:
	var walker := TaskWalker.new()
	add_child(walker)
	await _frames(1)
	walker.global_position = Vector2(960, 950)
	var task := DUNES_SCENE.instantiate() as DuneTask
	var log := RunLog.new()
	task.finished.connect(log.record)
	add_child(task)
	task.time_limit = 2.0
	task.start(0, false)
	_expect(task.walker == walker, "the task reuses the walker already in the tree")
	var steps := 0
	while task.planted_count < 2 and log.emissions == 0 and steps < 60:
		steps += 1
		if task.walker == null or not is_instance_valid(task.walker):
			_expect(false, "the poor run task keeps a walker to drive")
			break
		var spot := _nearest_unplanted(task)
		if spot == null:
			_expect(false, "an unplanted spot exists for the poor run")
			break
		if not await _walk_to(task, spot.global_position):
			_expect(false, "the poor run bot reached a spot")
			break
		await _tap_interact()
	_release_all()
	var waited := 0
	while log.emissions == 0 and waited < 3000:
		await get_tree().physics_frame
		waited += 1
	print("poor run: performance ", log.performance)
	_expect(log.emissions == 1, "the poor run finished exactly once")
	_expect(is_equal_approx(log.performance, 0.4), "poor run performance is 0.4, got %f" % log.performance)
	_expect(task.planted_count == 2, "two spots planted in the poor run, got %d" % task.planted_count)
	task.queue_free()
	walker.queue_free()
	await _frames(3)


func _auto_finish_check() -> void:
	var task := DUNES_SCENE.instantiate() as DuneTask
	var log := RunLog.new()
	task.finished.connect(log.record)
	add_child(task)
	task.start(0, true)
	var waited := 0
	while log.emissions == 0 and waited < 300:
		await get_tree().process_frame
		waited += 1
	print("auto-finish: performance ", log.performance)
	_expect(log.emissions == 1, "auto finish emits finished exactly once")
	_expect(log.performance == 0.0, "auto finish performance is 0.0, got %f" % log.performance)
	task.queue_free()
	await _frames(2)


func _nearest_unplanted(task: DuneTask) -> DuneSpot:
	var nearest: DuneSpot = null
	if task.walker == null or not is_instance_valid(task.walker):
		return nearest
	var best := INF
	for spot: DuneSpot in task.spots:
		if spot.is_planted:
			continue
		var distance := task.walker.global_position.distance_to(spot.global_position)
		if distance < best:
			best = distance
			nearest = spot
	return nearest


## Bang-bang walk with a deadband; arrives well inside the plant radius.
func _walk_to(task: DuneTask, target: Vector2) -> bool:
	var frames := 0
	while frames < 2500:
		var gap := target - task.walker.global_position
		if gap.length() < 12.0:
			_release_moves()
			return true
		_hold("move_right", gap.x > 6.0)
		_hold("move_left", gap.x < -6.0)
		_hold("move_down", gap.y > 6.0)
		_hold("move_up", gap.y < -6.0)
		await get_tree().physics_frame
		frames += 1
	_release_moves()
	return false


func _tap_interact() -> void:
	Input.action_press("interact")
	await _physics(2)
	Input.action_release("interact")


func _hold(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _release_moves() -> void:
	for action: String in ["move_up", "move_down", "move_left", "move_right"]:
		Input.action_release(action)


func _release_all() -> void:
	for action: String in ALL_ACTIONS:
		Input.action_release(action)


func _physics(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
