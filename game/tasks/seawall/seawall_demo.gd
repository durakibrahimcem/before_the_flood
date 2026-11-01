extends Node2D
## Self-driving seawall demo: a bot plays a perfect, a crooked and a poor run,
## and the real results are checked. Prints DEMO PASS or DEMO FAIL lines, then quits.

const SEAWALL := preload("res://tasks/seawall/seawall.tscn")
const BLOCK := preload("res://tasks/seawall/wall_block.gd")

const TIGHT_WINDOW := 26.0
const MISS_LINE := 170.0
const CROOKED_LINE := 80.0
const WATCHDOG_SECONDS := 40.0  # game time

var failures := 0
var passed := 0
var _game_seconds := 0.0
var _task: Seawall = null
var _bot_active := false
var _bot_mode := 0  # 0 tight, 1 two tight then wide right, 2 two tight then crooked band
var _bot_pressed := false
var _bot_presses := 0
var _release_at := 0
var _finished := false
var _perf := -1.0
var _aligned_events: Array[bool] = []
var _max_shake := 0.0
var _probe_mode := 0
var _probe_child: ProbeChild = null


func _ready() -> void:
	Engine.time_scale = 2.0
	await _probe_input()
	await _scenario_contract()
	await _scenario_auto_finish()
	await _scenario_perfect()
	await _scenario_poor()
	await _scenario_repeat()
	_finish()


func _physics_process(delta: float) -> void:
	_game_seconds += delta
	if _release_at != 0 and Engine.get_physics_frames() >= _release_at:
		Input.action_release("interact")
		_release_at = 0
	if _probe_mode == 1:
		Input.action_press("interact")
		_probe_mode = 2
		return
	if _probe_mode == 2:
		Input.action_release("interact")
		_probe_mode = 3
		return
	if not _bot_active or _task == null:
		return
	_max_shake = maxf(_max_shake, _task.stage_offset().length())
	if not _task.can_drop():
		_bot_pressed = false
		return
	if _bot_pressed:
		return
	var x := _task.slider_x()
	var press := absf(x - 960.0) <= TIGHT_WINDOW
	if _bot_mode == 1 and _bot_presses >= 2:
		press = x - 960.0 >= MISS_LINE
	elif _bot_mode == 2 and _bot_presses >= 2:
		press = absf(x - 960.0) >= CROOKED_LINE
	if press:
		Input.action_press("interact")
		_bot_pressed = true
		_bot_presses += 1
		_release_at = Engine.get_physics_frames() + 1


## A child node reads the press the same way the task will, proving the bot path.
func _probe_input() -> void:
	print("scenario 0: input probe")
	_probe_child = ProbeChild.new()
	add_child(_probe_child)
	_probe_mode = 1
	await _wait_frames(4)
	_probe_mode = 0
	Input.action_release("interact")
	_check(_probe_child.saw_count == 1, "bot press is seen by a child exactly once")
	_probe_child.queue_free()
	_probe_child = null


func _scenario_contract() -> void:
	print("scenario 1: contract")
	var task := SEAWALL.instantiate() as Seawall
	add_child(task)
	_check(task.action == "wall", "action is wall (got %s)" % task.action)
	task.start(1, false)
	_check(task.goal == 8, "repeat 1 sets goal 8 (got %d)" % task.goal)
	task.queue_free()
	await _wait_frames(3)
	var again := SEAWALL.instantiate() as Seawall
	add_child(again)
	again.start(2, false)
	_check(again.goal == 9, "repeat 2 sets goal 9 (got %d)" % again.goal)
	again.queue_free()
	await _wait_frames(3)
	await _scenario_stone_skin()


## Every block carries a code-drawn stone skin, so the stack reads as stone.
func _scenario_stone_skin() -> void:
	print("scenario 1b: stone skin")
	var block: Node2D = BLOCK.new()
	add_child(block)
	var skin: Node2D = block.get_node_or_null("Stones")
	_check(skin != null, "a block carries its stone joints")
	_check(block.texture != null, "a block without art falls back to a placeholder")
	_check(skin != null and skin.skin >= 0 and skin.skin < 997, "each block lays its joints a little differently")
	var second: Node2D = BLOCK.new()
	add_child(second)
	var second_skin: Node2D = second.get_node_or_null("Stones")
	_check(second_skin != null and second_skin.skin >= 0 and second_skin.skin < 997, "a second block finds its own placing")
	block.queue_free()
	second.queue_free()
	await _wait_frames(3)


func _scenario_auto_finish() -> void:
	print("scenario 2: auto finish")
	_reset_signals()
	var task := SEAWALL.instantiate() as Seawall
	_task = task
	add_child(task)
	task.finished.connect(_on_finished)
	task.block_landed.connect(_on_landed)
	task.start(0, true)
	var start := _game_seconds
	while not _finished:
		await get_tree().physics_frame
		if _game_seconds - start > 1.0:
			_check(false, "auto finish did not emit within 1 s")
			break
	_check(_finished, "auto finish emits finished")
	_check(absf(_perf) <= 0.001, "auto finish performance is 0.0 (got %.3f)" % _perf)
	_check(_aligned_events.is_empty(), "auto finish never lands blocks")
	_task = null
	task.queue_free()
	await _wait_frames(3)


func _scenario_perfect() -> void:
	print("scenario 3: perfect run")
	Settings.calm_storm = false
	_reset_signals()
	var task := SEAWALL.instantiate() as Seawall
	_task = task
	add_child(task)
	task.finished.connect(_on_finished)
	task.block_landed.connect(_on_landed)
	_bot_mode = 0
	_bot_active = true
	var start := _game_seconds
	task.start(0, false)
	var ok := await _wait_for_finished("perfect run")
	var duration := _game_seconds - start
	print("perfect run: %.2f game s" % duration)
	_bot_active = false
	if ok:
		_check(duration >= 15.0 and duration <= 35.0, "perfect run lasts about 25 s (got %.1f)" % duration)
		_check(absf(_perf - 1.0) <= 0.001, "perfect performance is 1.0 (got %.3f)" % _perf)
		_check(task.aligned_blocks == 6, "perfect run aligns 6 blocks (got %d)" % task.aligned_blocks)
		_check(task.blocks_landed == 6, "perfect run lands 6 blocks (got %d)" % task.blocks_landed)
		_check(_aligned_events.size() == 6, "block_landed fired 6 times (got %d)" % _aligned_events.size())
		var all_aligned := true
		for event: bool in _aligned_events:
			all_aligned = all_aligned and event
		_check(all_aligned, "every perfect landing is aligned")
		_check(_max_shake > 0.0, "landings shake the stage (max offset %.2f)" % _max_shake)
	_task = null
	task.queue_free()
	await _wait_frames(3)


func _scenario_poor() -> void:
	print("scenario 4: poor run, calm storm")
	Settings.calm_storm = true
	_reset_signals()
	var task := SEAWALL.instantiate() as Seawall
	_task = task
	add_child(task)
	task.finished.connect(_on_finished)
	task.block_landed.connect(_on_landed)
	_bot_mode = 1
	_bot_active = true
	var start := _game_seconds
	task.start(0, false)
	var ok := await _wait_for_finished("poor run")
	var duration := _game_seconds - start
	print("poor run: %.2f game s" % duration)
	_bot_active = false
	Settings.calm_storm = false
	if ok:
		_check(duration >= 15.0 and duration <= 35.0, "poor run lasts about 25 s (got %.1f)" % duration)
		_check(absf(_perf - 2.0 / 6.0) <= 0.001, "poor performance is 2/6 (got %.3f)" % _perf)
		_check(task.aligned_blocks == 2, "poor run aligns 2 blocks (got %d)" % task.aligned_blocks)
		_check(task.blocks_landed == 6, "poor run lands 6 blocks (got %d)" % task.blocks_landed)
		_check(_aligned_events.size() == 6, "block_landed fired 6 times (got %d)" % _aligned_events.size())
		var aligned_count := 0
		for event: bool in _aligned_events:
			if event:
				aligned_count += 1
		_check(aligned_count == 2, "exactly 2 landings are aligned (got %d)" % aligned_count)
		_check(_max_shake == 0.0, "calm storm keeps the stage still (max offset %.2f)" % _max_shake)
	_task = null
	task.queue_free()
	await _wait_frames(3)


## A repeat at goal 8 with blocks 3-8 pressed into the crooked band, so the
## shrinking block geometry and the crooked path are both really played.
func _scenario_repeat() -> void:
	print("scenario 5: crooked run, repeat 1")
	Settings.calm_storm = false
	_reset_signals()
	var task := SEAWALL.instantiate() as Seawall
	_task = task
	add_child(task)
	task.finished.connect(_on_finished)
	task.block_landed.connect(_on_landed)
	_bot_mode = 2
	_bot_active = true
	task.start(1, false)
	_check(task.goal == 8, "repeat 1 sets goal 8 (got %d)" % task.goal)
	var start := _game_seconds
	var ok := await _wait_for_finished("crooked run")
	var duration := _game_seconds - start
	print("crooked run: %.2f game s" % duration)
	_bot_active = false
	if ok:
		_check(duration >= 15.0 and duration <= 35.0, "crooked run lasts about 25 s (got %.1f)" % duration)
		_check(absf(_perf - 2.0 / 8.0) <= 0.001, "crooked performance is 2/8 (got %.3f)" % _perf)
		_check(task.aligned_blocks == 2, "crooked run aligns 2 blocks (got %d)" % task.aligned_blocks)
		_check(task.blocks_landed == 8, "crooked run lands 8 blocks (got %d)" % task.blocks_landed)
		_check(_aligned_events.size() == 8, "block_landed fired 8 times (got %d)" % _aligned_events.size())
		var aligned_count := 0
		for event: bool in _aligned_events:
			if event:
				aligned_count += 1
		_check(aligned_count == 2, "exactly 2 crooked-run landings are aligned (got %d)" % aligned_count)
	_task = null
	task.queue_free()
	await _wait_frames(3)


func _wait_frames(frames: int) -> void:
	var end := Engine.get_physics_frames() + frames
	while Engine.get_physics_frames() < end:
		await get_tree().physics_frame


func _wait_for_finished(label: String) -> bool:
	var start := _game_seconds
	while not _finished:
		await get_tree().physics_frame
		if _game_seconds - start > WATCHDOG_SECONDS:
			_check(false, label + " hit the 40 s watchdog")
			return false
	return true


func _reset_signals() -> void:
	_finished = false
	_perf = -1.0
	_aligned_events.clear()
	_max_shake = 0.0
	_bot_pressed = false
	_bot_presses = 0


func _on_finished(performance: float) -> void:
	_finished = true
	_perf = performance


func _on_landed(aligned: bool, _at: Vector2) -> void:
	_aligned_events.append(aligned)


func _check(ok: bool, what: String) -> void:
	if ok:
		passed += 1
		print("ok  " + what)
	else:
		failures += 1
		print("DEMO FAIL: " + what)


func _finish() -> void:
	_bot_active = false
	Input.action_release("interact")
	if _task != null:
		_task.queue_free()
		_task = null
	Engine.time_scale = 1.0
	Settings.calm_storm = false
	print("checks: %d passed, %d failed" % [passed, failures])
	if failures > 0:
		print("DEMO FAIL: %d check(s) failed" % failures)
		get_tree().quit(1)
	else:
		print("DEMO PASS")
		get_tree().quit()


class ProbeChild extends Node2D:
	var saw_count := 0

	func _physics_process(_delta: float) -> void:
		if Input.is_action_just_pressed("interact"):
			saw_count += 1
