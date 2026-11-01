extends Node
## Gate demo: a scripted bot plays the sort task end to end and checks the rules.
## The bot only drives Input actions, exactly like a player; it never touches velocity.

const SORT: PackedScene = preload("res://tasks/sort/sort.tscn")
const KINDS: Array[String] = SortTask.KINDS
const STOP := 14.0
const APPROACH_Y := 560.0
const PLAY_BUDGET := 1800
const IDLE_BUDGET := 300
const CORRECT_FIRST := 3

var _performance := -1.0
var _frames := 0
var _budget := 0
var _runs_done := 0


func _ready() -> void:
	await _run_sanity()
	assert(_runs_done == 1, "run 0 (auto-finish) did not complete")
	await _run_perfect()
	assert(_runs_done == 2, "run A (perfect) did not complete")
	await _run_poor()
	assert(_runs_done == 3, "run B (poor) did not complete")
	await _run_timeout()
	assert(_runs_done == 4, "run C (timeout) did not complete")
	await _run_growth()
	assert(_runs_done == 5, "run D (growth) did not complete")
	print("DEMO PASS")
	get_tree().quit()


func _run_sanity() -> void:
	var task := _fresh_task()
	_performance = -1.0
	task.finished.connect(_capture)
	task.start(0, true)
	await _idle(3)
	assert(_performance == 0.0, "auto-finish reports zero, got %f" % _performance)
	await _free_task(task)
	_runs_done += 1


func _run_perfect() -> void:
	var task := _fresh_task()
	assert(task.seconds == 40.0, "the task lasts 40 seconds by default, got %f" % task.seconds)
	task.layout_seed = 7
	_performance = -1.0
	task.finished.connect(_capture)
	task.start(0, false)
	await _idle(1)
	assert(task.total_items == task.target_count(8), "target_count(8) sizes the run")
	assert(task.total_items == 8, "the first run sorts 8 items, got %d" % task.total_items)
	assert(get_tree().get_nodes_in_group("walker").size() == 1, "exactly one walker during the run")
	assert(task.hint.visible, "the hint shows at start")
	Input.action_press("interact")
	await _idle(2)
	Input.action_release("interact")
	await _idle(20)
	assert(not task.hint.visible, "interact hides the hint early")

	_frames = 0
	_budget = PLAY_BUDGET
	var walker := _walker_of()
	var order := _plan_errands(walker, _tour_target_a)
	var probed := false
	var aligned := false
	var routed := false
	while _performance < 0.0:
		var carried := String(walker.get("carried"))
		if carried == "":
			aligned = false
			routed = false
			var item := _next_errand(order)
			_drive(walker, item.position if item != null else walker.position)
		else:
			if not probed:
				probed = true
				await _probe_carry(task, walker, carried)
			var bin := _bin_with_kind(carried)
			if not routed:
				routed = true
				aligned = _path_clear(walker.position, bin.position, bin)
			elif not aligned and _aligned_with(walker, bin):
				aligned = true
			_drive(walker, bin.position if aligned else Vector2(bin.position.x, APPROACH_Y))
		await _tick()
	assert(is_equal_approx(_performance, 1.0), "a perfect run scores 1.0, got %f" % _performance)
	assert(get_tree().get_nodes_in_group("sort_item").is_empty(), "every item was handled")
	await _free_task(task)
	_runs_done += 1


func _run_poor() -> void:
	var task := _fresh_task()
	task.layout_seed = 11
	_performance = -1.0
	task.finished.connect(_capture)
	task.start(0, false)
	await _idle(1)
	var walker := _walker_of()
	var order := _plan_errands(walker, _tour_target_b)
	var handled := 0
	var wrong_checked := false
	var aligned := false
	var routed := false
	_frames = 0
	_budget = PLAY_BUDGET
	while _performance < 0.0:
		var carried := String(walker.get("carried"))
		if carried == "":
			aligned = false
			routed = false
			var item := _next_errand(order)
			_drive(walker, item.position if item != null else walker.position)
		else:
			var bin := _poor_bin(carried, handled)
			if not routed:
				routed = true
				aligned = _path_clear(walker.position, bin.position, bin)
			elif not aligned and _aligned_with(walker, bin):
				aligned = true
			_drive(walker, bin.position if aligned else Vector2(bin.position.x, APPROACH_Y))
		await _tick()
		var now := String(walker.get("carried"))
		if carried != "" and now == "":
			handled += 1
			if handled == CORRECT_FIRST + 1 and not wrong_checked:
				wrong_checked = true
				await _idle(3)
				assert(String(walker.get("carried")) == "", "a wrong bin empties the hands")
				assert(task.sorted_correct == CORRECT_FIRST,
					"a wrong deposit keeps the score at %d, got %d" % [CORRECT_FIRST, task.sorted_correct])
				assert(get_tree().get_nodes_in_group("sort_item").size() == 5,
					"the item goes back to the field")
				# Going on would only repeat the same mistake until the timer ran out.
				task.time_left = 0.1
	assert(is_equal_approx(_performance, 3.0 / 8.0),
		"a poor run scores 3 of 8, got %f" % _performance)
	await _free_task(task)
	_runs_done += 1


func _run_timeout() -> void:
	var task := _fresh_task()
	task.seconds = 2.0
	task.layout_seed = 3
	_performance = -1.0
	task.finished.connect(_capture)
	task.start(0, false)
	await _idle(1)
	assert(task.total_items == 8, "the timeout run still sorts 8 items")
	_release_axes()
	_frames = 0
	_budget = IDLE_BUDGET
	while _performance < 0.0:
		await _tick()
	assert(_performance == 0.0, "an idle timeout scores 0.0, got %f" % _performance)
	assert(get_tree().get_nodes_in_group("sort_item").size() == 8,
		"the timer ends the run with every item unhandled")
	await _free_task(task)
	_runs_done += 1


func _run_growth() -> void:
	var task := _fresh_task()
	task.seconds = 0.5
	task.layout_seed = 3
	_performance = -1.0
	task.finished.connect(_capture)
	task.start(1, false)
	await _idle(1)
	assert(task.total_items == task.target_count(8), "repeat 1 grows the target")
	assert(task.total_items == 10, "the second pass sorts 10 items, got %d" % task.total_items)
	_frames = 0
	_budget = IDLE_BUDGET
	while _performance < 0.0:
		await _tick()
	assert(_performance == 0.0, "a fast timeout scores 0.0, got %f" % _performance)
	await _free_task(task)
	_runs_done += 1


## While carrying: drive over another item and prove it is not picked up.
## The probe item sits on the cheapest detour along this errand's own walk to the bin.
func _probe_carry(task: SortTask, walker: CharacterBody2D, carried: String) -> void:
	var label := task.get_node("CarriedLabel") as Label
	assert(label != null and label.visible, "the carried label shows the held kind")
	var probe := _best_item(walker, func(_item: SortItem): return _bin_with_kind(carried).position)
	if probe == null:
		return
	await _drive_onto(walker, probe.position)
	await _idle(8)
	assert(String(walker.get("carried")) == carried, "a second touch does not grab while carrying")
	assert(is_instance_valid(probe) and probe.is_inside_tree(), "the touched item stays in place")


func _drive_onto(walker: CharacterBody2D, target: Vector2) -> void:
	while walker.position.distance_to(target) > STOP:
		_drive(walker, target)
		await _tick()
	_release_axes()


## Aligned once the walker is on the bin's column, or at the waypoint below it.
## From there the walk to the bin stays vertical and can never graze a wrong bin.
func _aligned_with(walker: CharacterBody2D, bin: SortBin) -> bool:
	if absf(walker.position.x - bin.position.x) <= STOP:
		return true
	return walker.position.distance_to(Vector2(bin.position.x, APPROACH_Y)) <= STOP


## Can the walker walk straight to the bin without entering any other bin's space?
## Healthy angles walk the exact line; near-axis walks bend at 45 degrees like an L,
## so the L route is checked there. The danger rect covers the bin's shape plus the
## walker's, with a safety margin for the last-frame wobble.
func _path_clear(from: Vector2, to: Vector2, target: SortBin) -> bool:
	var unit := (to - from).normalized()
	if absf(unit.x) < 0.25 or absf(unit.y) < 0.25:
		var short := minf(absf(to.x - from.x), absf(to.y - from.y))
		var corner := Vector2(
			from.x + signf(to.x - from.x) * short,
			from.y + signf(to.y - from.y) * short)
		return _segment_clear(from, corner, target) and _segment_clear(corner, to, target)
	return _segment_clear(from, to, target)


func _segment_clear(from: Vector2, to: Vector2, target: SortBin) -> bool:
	for bin: SortBin in _bins():
		if bin == target:
			continue
		var danger := Rect2(bin.position.x - 92.0, bin.position.y - 129.0, 184.0, 258.0)
		var steps := maxi(ceili(from.distance_to(to) / 8.0), 1)
		for i: int in steps + 1:
			if danger.has_point(from.lerp(to, i / float(steps))):
				return false
	return true


func _drive(walker: CharacterBody2D, target: Vector2) -> void:
	var offset := target - walker.position
	if offset.length() <= STOP:
		_release_axes()
		return
	# Strengths proportional to the direction keep the walk on a straight line.
	var unit := offset.normalized()
	_set_action("move_left", maxf(-unit.x, 0.0))
	_set_action("move_right", maxf(unit.x, 0.0))
	_set_action("move_up", maxf(-unit.y, 0.0))
	_set_action("move_down", maxf(unit.y, 0.0))


func _set_action(action: String, strength: float) -> void:
	if strength <= 0.0:
		if Input.is_action_pressed(action):
			Input.action_release(action)
	else:
		Input.action_press(action, strength)


func _release_axes() -> void:
	for axis: String in ["move_left", "move_right", "move_up", "move_down"]:
		if Input.is_action_pressed(axis):
			Input.action_release(axis)


func _tick() -> void:
	_frames += 1
	assert(_frames <= _budget, "the bot ran past its frame budget of %d" % _budget)
	await get_tree().physics_frame


func _idle(frames: int) -> void:
	for i: int in frames:
		await _tick()


func _capture(performance: float) -> void:
	_performance = performance


func _fresh_task() -> SortTask:
	assert(get_tree().get_nodes_in_group("walker").is_empty(), "no walker leaks between runs")
	assert(get_tree().get_nodes_in_group("sort_item").is_empty(), "no item leaks between runs")
	assert(get_tree().get_nodes_in_group("sort_bin").is_empty(), "no bin leaks between runs")
	var task := SORT.instantiate() as SortTask
	assert(task != null, "sort.tscn instantiates into a SortTask")
	assert(task.action == "sort", "the task reports the sort action")
	add_child(task)
	_frames = 0
	_budget = IDLE_BUDGET
	return task


func _free_task(task: SortTask) -> void:
	_release_axes()
	task.queue_free()
	_frames = 0
	_budget = IDLE_BUDGET
	await _idle(2)


func _walker_of() -> CharacterBody2D:
	var walker := get_tree().get_first_node_in_group("walker") as CharacterBody2D
	assert(walker != null, "the task provides a walker")
	return walker


func _items() -> Array[SortItem]:
	var items: Array[SortItem] = []
	for node: Node in get_tree().get_nodes_in_group("sort_item"):
		var item := node as SortItem
		if item != null and is_instance_valid(item) and item.is_inside_tree() \
				and not item.is_queued_for_deletion():
			items.append(item)
	return items


func _bins() -> Array[SortBin]:
	var bins: Array[SortBin] = []
	for node: Node in get_tree().get_nodes_in_group("sort_bin"):
		var bin := node as SortBin
		if bin != null and is_instance_valid(bin):
			bins.append(bin)
	return bins


func _bin_with_kind(kind: String) -> SortBin:
	for bin: SortBin in _bins():
		if bin.kind == kind:
			return bin
	assert(false, "missing a %s bin" % kind)
	return null


## The wrong bin is a deterministic pick: the first kind that is not the carried one.
func _poor_bin(kind: String, handled: int) -> SortBin:
	if handled < CORRECT_FIRST:
		return _bin_with_kind(kind)
	for kind_choice: String in KINDS:
		if kind_choice != kind:
			return _bin_with_kind(kind_choice)
	return _bin_with_kind(kind)


## Tour targets: where the bot will carry each item, by errand number.
func _tour_target_a(item: SortItem, _index: int) -> Vector2:
	return _bin_with_kind(item.kind).position


func _tour_target_b(item: SortItem, index: int) -> Vector2:
	return _poor_bin(item.kind, index).position


## Pick the item whose whole errand (grab plus its bin) costs the least.
func _best_item(walker: CharacterBody2D, bin_target: Callable) -> SortItem:
	var best: SortItem = null
	var best_cost := INF
	for item: SortItem in _items():
		var target: Vector2 = bin_target.call(item)
		var cost := walker.position.distance_to(item.position) + item.position.distance_to(target)
		if cost < best_cost:
			best_cost = cost
			best = item
	return best


## The next unplanned errand in the tour.
func _next_errand(order: Array[SortItem]) -> SortItem:
	for item: SortItem in order:
		if is_instance_valid(item) and item.is_inside_tree() and not item.is_queued_for_deletion():
			return item
	return null


## Plan the errand order up front: greedy, then pairwise swaps until no swap helps.
## Eight items is small, so this keeps the demo well inside the task's seconds.
func _plan_errands(walker: CharacterBody2D, target_of: Callable) -> Array[SortItem]:
	var order := _greedy_order(walker.position, _items(), target_of)
	var improved := true
	while improved:
		improved = false
		for i: int in order.size():
			for j: int in range(i + 1, order.size()):
				var swapped := order.duplicate()
				var segment := swapped.slice(i, j + 1)
				segment.reverse()
				for k: int in segment.size():
					swapped[i + k] = segment[k]
				var swapped_cost := _tour_cost(walker.position, swapped, target_of)
				if swapped_cost < _tour_cost(walker.position, order, target_of) - 0.01:
					order = swapped
					improved = true
	return order


func _greedy_order(from: Vector2, items: Array[SortItem], target_of: Callable) -> Array[SortItem]:
	var order: Array[SortItem] = []
	var left: Array[SortItem] = items.duplicate()
	var at := from
	while not left.is_empty():
		var pick: SortItem = null
		var pick_cost := INF
		for item: SortItem in left:
			var bin_position: Vector2 = target_of.call(item, order.size())
			var cost := at.distance_to(item.position) + item.position.distance_to(bin_position)
			if cost < pick_cost:
				pick_cost = cost
				pick = item
		left.erase(pick)
		order.append(pick)
		at = target_of.call(pick, order.size() - 1)
	return order


## The full walk: to each item, then to the bin it will be carried to.
func _tour_cost(from: Vector2, order: Array[SortItem], target_of: Callable) -> float:
	var cost := 0.0
	var at := from
	for i: int in order.size():
		var bin_position: Vector2 = target_of.call(order[i], i)
		cost += at.distance_to(order[i].position) + order[i].position.distance_to(bin_position)
		at = bin_position
	return cost
