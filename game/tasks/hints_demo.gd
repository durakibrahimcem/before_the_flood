extends Node
## Gate demo: every task's instruction is still there long after it has settled.

const TASKS: Array[PackedScene] = [
	preload("res://tasks/sort/sort.tscn"),
	preload("res://tasks/seagrass/seagrass.tscn"),
	preload("res://tasks/dunes/dunes_task.tscn"),
	preload("res://tasks/lights/lights.tscn"),
	preload("res://tasks/meeting/meeting.tscn"),
	preload("res://tasks/seawall/seawall.tscn"),
]
const SETTLED_SECONDS := 8.0
const FAST_CLOCK := 5.0


func _ready() -> void:
	Engine.time_scale = FAST_CLOCK
	for scene: PackedScene in TASKS:
		var task: Task = scene.instantiate()
		add_child(task)
		task.start(0, false)
		await get_tree().create_timer(SETTLED_SECONDS).timeout
		var line := task.instruction()
		assert(line != null, "%s has an instruction" % task.action)
		assert(line.is_visible_in_tree(), "the %s instruction is still on screen" % task.action)
		assert(line.modulate.a >= Task.REMINDER_ALPHA - 0.01, "the %s instruction is still readable, alpha %f" % [task.action, line.modulate.a])
		task.queue_free()
		await get_tree().process_frame
	Engine.time_scale = 1.0
	print("DEMO PASS")
	get_tree().quit()
