extends Node2D
## Bot demo for the seagrass task, all driven through real input:
## a perfect run through a pre-existing Arda, a poor run through a spawned
## TaskWalker, and an auto-finish run. Prints DEMO PASS only if every check holds.

const TASK_SCENE := "res://tasks/seagrass/seagrass.tscn"
const ARDA_SCENE := "res://actors/arda.tscn"
const SEA_TOP := Color(0.47, 0.71, 0.72)
const SAND_WET := Color(0.83, 0.73, 0.58)
const SAND := Color(0.90, 0.81, 0.64)
const DEADZONE := 8.0
const PRESS_TICKS := 3
const BUDGET_MS := 75000
const MARGIN := 0.3

var _failed := false
var _finish_count := 0
var _perf := -1.0
var _cap_elapsed := -1.0
var _cap_rooted := -1
var _watchdog: Timer
var _watchdog_label := ""
var _deadline := 0
var _start_ms := 0


func _ready() -> void:
	_watchdog = Timer.new()
	_watchdog.one_shot = true
	_watchdog.timeout.connect(_on_watchdog)
	add_child(_watchdog)
	_start_ms = Time.get_ticks_msec()
	_deadline = _start_ms + BUDGET_MS
	_run()


func _process(_delta: float) -> void:
	if not _failed and Time.get_ticks_msec() > _deadline:
		_fail("the whole demo passed 75 s")


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, 1920.0, 300.0), SEA_TOP)
	draw_rect(Rect2(0.0, 300.0, 1920.0, 80.0), SAND_WET)
	draw_rect(Rect2(0.0, 380.0, 1920.0, 700.0), SAND)


func _run() -> void:
	await get_tree().process_frame
	print("seagrass demo: three runs, real input")
	_check_repeat_count()
	if _failed:
		return
	await _run_existing_walker()
	if _failed:
		return
	await _run_poor()
	if _failed:
		return
	await _run_auto()
	if _failed:
		return
	print("demo wall time: %.1f s" % ((Time.get_ticks_msec() - _start_ms) / 1000.0))
	print("DEMO PASS")
	get_tree().quit(0)


func _check_repeat_count() -> void:
	var task := _fresh_task()
	task.repeat_index = 1
	var count := task.target_count(6)
	task.free()
	_check(count == 8, "target_count(6) at repeat 1 should be 8, got %d" % count)
	print("repeat growth: target_count(6) at repeat 1 = %d" % count)


## The room integration path: Arda already in the "walker" group, task off-origin.
func _run_existing_walker() -> void:
	var arda := (load(ARDA_SCENE) as PackedScene).instantiate() as CharacterBody2D
	add_child(arda)
	arda.position = Vector2(960.0, 960.0)
	var task := _fresh_task()
	add_child(task)
	task.position = Vector2(120.0, 60.0)
	task.finished.connect(_record_finished.bind(task))
	task.start(0, false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(task.walker == arda, "the task should use the existing walker, not spawn one")
	_check(get_tree().get_nodes_in_group("walker").size() == 1, "the task must not spawn a second walker")
	_check(task.goal == 6, "goal should be 6 at repeat 0, got %d" % task.goal)
	if _failed:
		return
	_arm_watchdog(30.0, "the existing-walker run")
	var planted := 0
	while _finish_count == 0:
		var spot := _nearest_empty(task, arda.global_position)
		if spot == null:
			_fail("existing-walker run: every spot planted but the task did not finish")
			return
		await _walk_to(arda, spot.global_position)
		await _wait_calm_margin(task)
		if _finish_count > 0:
			break
		await _press_interact()
		await _confirm_planted(spot)
		planted += 1
		if planted == 1:
			_check(str(arda.get("carried")) == "shoot", "the walker should carry a shoot while planting")
			if _failed:
				return
		print("existing-walker run: rooted %d of %d" % [task.rooted, task.goal])
	_disarm_watchdog()
	_release_inputs()
	_check(_finish_count == 1, "existing-walker run: finished emitted %d times, expected once" % _finish_count)
	_check(_perf == 1.0, "existing-walker run: performance should be 1.0, got %.3f" % _perf)
	_check(_cap_rooted == 6, "existing-walker run: rooted %d at the end, expected 6" % _cap_rooted)
	_check(_cap_elapsed < 24.5, "existing-walker run: should end by the goal, elapsed %.2f s" % _cap_elapsed)
	print("existing-walker run: performance %.3f" % _perf)
	await _await_task_gone(task, "existing-walker run task")
	if _failed:
		return
	_check(is_instance_valid(arda), "the task must not free a walker it does not own")
	_check(str(arda.get("carried")) == "", "the walker's hands should be empty again")
	arda.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(get_tree().get_first_node_in_group("walker") == null, "the demo frees its own Arda")


func _run_poor() -> void:
	var task := _fresh_task()
	add_child(task)
	task.finished.connect(_record_finished.bind(task))
	task.start(0, false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var walker := get_tree().get_first_node_in_group("walker") as TaskWalker
	_check(walker != null and walker.get_parent() == task, "poor run: the task should spawn a fresh walker")
	if _failed:
		return
	_arm_watchdog(45.0, "the poor run")
	var washed: Array[SeagrassSpot] = []
	for i in range(4):
		var spot := _nearest_empty(task, walker.global_position)
		if spot == null:
			_fail("poor run: no empty spot left for wash plant %d" % (i + 1))
			return
		await _walk_to(walker, spot.global_position)
		await _wait_wash_margin(task)
		await _press_interact()
		await _confirm_planted(spot)
		washed.append(spot)
		print("poor run: wash plant %d of 4" % (i + 1))
	var ticks := 0
	while not _all_empty(washed) and ticks < 420:
		await get_tree().physics_frame
		ticks += 1
	_check(_all_empty(washed), "poor run: shoots planted in the wash should wash away")
	if _failed:
		return
	print("poor run: all four washed spots are empty again")
	for i in range(2):
		var spot := _nearest_empty(task, walker.global_position)
		if spot == null:
			_fail("poor run: no empty spot left for calm plant %d" % (i + 1))
			return
		await _walk_to(walker, spot.global_position)
		await _wait_calm_margin(task)
		await _press_interact()
		await _confirm_planted(spot)
		print("poor run: rooted %d of 2" % (i + 1))
	_release_inputs()
	while _finish_count == 0:
		await get_tree().physics_frame
	_disarm_watchdog()
	_check(_finish_count == 1, "poor run: finished emitted %d times, expected once" % _finish_count)
	_check(is_equal_approx(_perf, 2.0 / 6.0), "poor run: performance should be 2/6, got %.3f" % _perf)
	_check(_cap_rooted == 2, "poor run: rooted %d at the end, expected 2" % _cap_rooted)
	_check(_cap_elapsed >= 24.5, "poor run: should end by the timeout, elapsed %.2f s" % _cap_elapsed)
	print("poor run: performance %.3f" % _perf)
	await _await_task_gone(task, "poor run task")
	if _failed:
		return
	_check(get_tree().get_first_node_in_group("walker") == null, "the spawned walker should free with its task")


func _run_auto() -> void:
	var task := _fresh_task()
	add_child(task)
	task.finished.connect(_record_finished.bind(task))
	_arm_watchdog(3.0, "the auto-finish run")
	task.start(0, true)
	while _finish_count == 0:
		await get_tree().physics_frame
	_disarm_watchdog()
	_release_inputs()
	_check(_finish_count == 1, "auto run: finished emitted %d times, expected once" % _finish_count)
	_check(_perf == 0.0, "auto run: performance should be 0.0, got %.3f" % _perf)
	print("auto run: performance %.3f" % _perf)
	await _await_task_gone(task, "auto run task")


func _fresh_task() -> SeagrassTask:
	_finish_count = 0
	_perf = -1.0
	_cap_elapsed = -1.0
	_cap_rooted = -1
	var packed := load(TASK_SCENE) as PackedScene
	return packed.instantiate() as SeagrassTask


func _record_finished(performance: float, task: SeagrassTask) -> void:
	_finish_count += 1
	_perf = performance
	_cap_elapsed = task.elapsed
	_cap_rooted = task.rooted


func _nearest_empty(task: SeagrassTask, from: Vector2) -> SeagrassSpot:
	var nearest: SeagrassSpot = null
	var best := INF
	for spot: SeagrassSpot in task.spots:
		if spot.state != SeagrassSpot.State.EMPTY:
			continue
		var d := from.distance_to(spot.global_position)
		if d < best:
			best = d
			nearest = spot
	return nearest


func _all_empty(spots: Array[SeagrassSpot]) -> bool:
	for spot: SeagrassSpot in spots:
		if spot.state != SeagrassSpot.State.EMPTY:
			return false
	return true


func _walk_to(walker: CharacterBody2D, target: Vector2) -> void:
	var ticks := 0
	while ticks < 400:
		if _finish_count > 0:
			_release_move()
			return
		var d := target - walker.global_position
		if d.length() <= DEADZONE:
			_release_move()
			return
		_press_direction(d)
		await get_tree().physics_frame
		ticks += 1
	_release_move()
	_fail("the walker could not reach %s" % target)


func _press_direction(d: Vector2) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")
	if d.x < -4.0:
		Input.action_press("move_left")
	elif d.x > 4.0:
		Input.action_press("move_right")
	if d.y < -4.0:
		Input.action_press("move_up")
	elif d.y > 4.0:
		Input.action_press("move_down")


func _wait_calm_margin(task: SeagrassTask) -> void:
	while _finish_count == 0:
		var phase := fposmod(task.elapsed, SeagrassTask.CYCLE)
		if phase >= SeagrassTask.WASH_SECONDS and SeagrassTask.CYCLE - phase >= MARGIN:
			return
		await get_tree().physics_frame


func _wait_wash_margin(task: SeagrassTask) -> void:
	while _finish_count == 0:
		var phase := fposmod(task.elapsed, SeagrassTask.CYCLE)
		if phase < SeagrassTask.WASH_SECONDS and SeagrassTask.WASH_SECONDS - phase >= MARGIN:
			return
		await get_tree().physics_frame


func _press_interact() -> void:
	Input.action_press("interact")
	for _i in range(PRESS_TICKS):
		await get_tree().physics_frame
	Input.action_release("interact")


func _confirm_planted(spot: SeagrassSpot) -> void:
	var ticks := 0
	while spot.state == SeagrassSpot.State.EMPTY and ticks < 30:
		await get_tree().physics_frame
		ticks += 1
	_check(ticks < 30, "interact planted nothing at %s" % spot.global_position)


func _await_task_gone(node: Node, label: String) -> void:
	_arm_watchdog(6.0, "%s to free itself" % label)
	while is_instance_valid(node):
		await get_tree().physics_frame
	_disarm_watchdog()


func _arm_watchdog(seconds: float, label: String) -> void:
	_watchdog_label = label
	_watchdog.wait_time = seconds
	_watchdog.start()


func _disarm_watchdog() -> void:
	_watchdog.stop()


func _on_watchdog() -> void:
	_fail("timed out waiting for %s" % _watchdog_label)


func _release_inputs() -> void:
	_release_move()
	Input.action_release("interact")


func _release_move() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")


func _check(ok: bool, what: String) -> void:
	if ok:
		return
	_fail(what)


func _fail(what: String) -> void:
	if _failed:
		return
	_failed = true
	printerr("DEMO FAIL: " + what)
	get_tree().quit(1)
