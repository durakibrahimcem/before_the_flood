extends Node
## The current playthrough: the plan so far, the day, and past attempts.

signal plan_changed
signal day_changed(day: int)
signal plan_complete
signal run_ended(outcome: Dictionary)

const DAYS := 3
const SLOTS_PER_DAY := 2
const SAVE_PATH := "user://save.json"

var plan: Plan = Plan.new()
var day: int = 1
var slots_left: int = SLOTS_PER_DAY
var ghosts: Array[float] = []


func _ready() -> void:
	_load()


func new_run() -> void:
	plan = Plan.new()
	day = 1
	slots_left = SLOTS_PER_DAY
	plan_changed.emit()
	day_changed.emit(day)
	WorldClock.scrub(WorldClock.ERAS[0])


func record(action: String, performance: float) -> void:
	if plan.total() >= Plan.SLOTS or not action in Plan.ACTIONS:
		push_error("Ignored action: %s" % action)
		return
	plan.add(action, performance)
	slots_left -= 1
	if slots_left == 0 and day < DAYS:
		day += 1
		slots_left = SLOTS_PER_DAY
		day_changed.emit(day)
	plan_changed.emit()
	WorldClock.refresh()
	if plan.total() == Plan.SLOTS:
		plan_complete.emit()


func load_code(code: String) -> bool:
	var loaded := Plan.from_code(code)
	if loaded == null:
		return false
	plan = loaded
	day = DAYS
	slots_left = 0
	plan_changed.emit()
	day_changed.emit(day)
	WorldClock.refresh()
	plan_complete.emit()
	return true


func end_run() -> void:
	if plan.total() != Plan.SLOTS:
		push_error("A run ended with an unfinished plan")
		return
	var outcome := Sim.outcome(plan)
	ghosts.append(outcome["depth_2080"])
	_save()
	run_ended.emit(outcome)


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({ "ghosts": ghosts }))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is Dictionary and parsed.get("ghosts") is Array:
		ghosts.clear()
		for value: Variant in parsed["ghosts"]:
			if value is float:
				ghosts.append(value)
