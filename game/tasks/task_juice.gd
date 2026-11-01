class_name TaskJuice
extends RefCounted
## One shared feel for the six tasks: a small paper pop and a few settling
## sparks. Under Calm Storm the pop stays.

const POP_OVERSHOOT := 1.10
const POP_SECONDS := 0.18
const SPARK_COUNT := 7
const SPARK_LIFETIME := 0.35
const SPARK_MIN_SPEED := 40.0
const SPARK_MAX_SPEED := 90.0
const SPARK_GRAVITY := Vector2(0.0, 120.0)
const SPARK_MIN_SCALE := 2.0
const SPARK_MAX_SCALE := 4.0
## Sparks sit above the task's own art, so planting is answered in sight.
const SPARK_Z := 2

const _POP_TWEEN := "task_juice_pop_tween"
const _POP_REST := "task_juice_pop_rest"

static var _spark_ramp: Gradient


## A small pop with a back ease: ten percent up, then settled, in 180 ms.
## A pop cut short by a newer one still settles at the node's resting scale.
static func pop(node: CanvasItem) -> void:
	if node == null or not is_instance_valid(node):
		return
	# has_meta guards each read: a missing key must stay silent, or every
	# first pop would log an error.
	var rest: Vector2 = node.scale
	if node.has_meta(_POP_REST):
		rest = node.get_meta(_POP_REST)
	if node.has_meta(_POP_TWEEN):
		var old := node.get_meta(_POP_TWEEN) as Tween
		if old != null and old.is_valid():
			old.kill()
	node.scale = rest
	node.set_meta(_POP_REST, rest)
	var tween := node.create_tween()
	tween.bind_node(node)
	node.set_meta(_POP_TWEEN, tween)
	var half := POP_SECONDS * 0.5
	tween.tween_property(node, "scale", rest * POP_OVERSHOOT, half) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", rest, half) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A few quiet sparks that rise and settle like paper. Skipped under Calm
## Storm; the emitter frees itself once every spark has landed.
static func sparks(parent: Node, at: Vector2, tint: Color) -> void:
	if Settings.calm_storm:
		return
	if parent == null or not is_instance_valid(parent):
		return
	var burst := CPUParticles2D.new()
	burst.position = at
	burst.z_index = SPARK_Z
	burst.one_shot = true
	burst.emitting = false
	burst.amount = SPARK_COUNT
	burst.lifetime = SPARK_LIFETIME
	burst.explosiveness = 1.0
	burst.direction = Vector2(0.0, -1.0)
	burst.spread = 180.0
	burst.initial_velocity_min = SPARK_MIN_SPEED
	burst.initial_velocity_max = SPARK_MAX_SPEED
	burst.gravity = SPARK_GRAVITY
	burst.scale_amount_min = SPARK_MIN_SCALE
	burst.scale_amount_max = SPARK_MAX_SCALE
	burst.color = tint
	burst.color_ramp = _fade_ramp()
	parent.add_child(burst)
	burst.finished.connect(burst.queue_free)
	burst.restart()
	burst.emitting = true


## Sparks fade out instead of vanishing at the end of their short life.
static func _fade_ramp() -> Gradient:
	if _spark_ramp == null:
		_spark_ramp = Gradient.new()
		_spark_ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		_spark_ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	return _spark_ramp
