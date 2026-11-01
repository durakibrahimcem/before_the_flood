class_name FloodArrival
extends Node
## The water arrives instead of teleporting. An era jump (or a step into a flooded room)
## raises the waterline to its new level over a beat, with a heave on the big ones, so the
## flood comes at the player. A held scrub still moves the water directly.

## The tap lands, a breath, then the flood answers.
const HOLD_SECONDS := 0.22
const RISE_SECONDS := 1.15
## Walking into a flooded room settles a touch quicker.
const ENTRY_SECONDS := 0.85
## Steps smaller than this just are.
const MIN_RISE_M := 0.06
## A rise this big heaves and sounds like a wave.
const HEAVE_M := 0.4
## Godot's TRANS_BACK constant: a single pop a shade under the 10% overshoot the art allows.
const BACK_S := 1.70158

var room: Room
var _materials: Array[ShaderMaterial] = []
var _from_m := 0.0
var _to_m := 0.0
var _seconds := 0.0
var _hold := 0.0
var _rise := 0.0
var _rising := false
var _heave := false
var _jump_wait := false
var _first_state := true
## The level this node is drawing, which lags the room's own value while a rise runs.
var _shown_m := 0.0
## For the demo: how many heaves this room has given.
var surges := 0


func _ready() -> void:
	room = get_parent() as Room
	# Late in the frame, after the timeline has tapped, so the eased line always wins the draw.
	process_priority = 500
	WorldClock.jumped.connect(_on_jumped)
	WorldClock.year_changed.connect(_on_year_changed)


## The level on screen right now, which during a rise is the eased one.
func displayed_m() -> float:
	return _shown_m


## The level the painting's own material is drawing. Read by the demo.
func shader_flood_m() -> float:
	if _materials.is_empty():
		return -1.0
	return float(_materials[0].get_shader_parameter("flood_m"))


## How many water materials this room draws. Read by the demo.
func material_count() -> int:
	return _materials.size()


func is_rising() -> bool:
	return _rising


func _on_jumped(_to_year: int) -> void:
	_jump_wait = true


## Runs before the room's own handler, so the level it reads is the one on screen.
func _on_year_changed(state: WorldState) -> void:
	_collect_materials()
	if _materials.is_empty():
		return
	var target := float(state.flood_m.get(room.room_name, 0.0))
	var entering := _first_state
	_first_state = false
	if _jump_wait:
		_jump_wait = false
		_begin(target, true)
	elif entering:
		_begin(target, false)
	elif _rising and not is_equal_approx(target, _to_m):
		# A live scrub moves the water itself, so the rise gives way at once.
		_finish(target)
	elif not _rising:
		_apply(target)


func _begin(target: float, from_jump: bool) -> void:
	# Resume from the level on screen: the true level is already at the target,
	# so a second tap mid-rise must not snap the rest of the climb into one frame.
	var from := _shown_m
	if target <= from + MIN_RISE_M:
		# Falls snap, and a snap ends whatever rise was still running toward
		# the old target, so the line can never keep climbing on its own.
		_rising = false
		_apply(target)
		return
	_from_m = from
	_to_m = target
	_seconds = RISE_SECONDS if from_jump else ENTRY_SECONDS
	_hold = HOLD_SECONDS if from_jump else 0.0
	_rise = 0.0
	_heave = target - from >= HEAVE_M
	_rising = true
	_apply(from)
	if _heave and not Settings.calm_storm:
		Sfx.play("wave_crash")


func _process(delta: float) -> void:
	if not _rising:
		return
	if _hold > 0.0:
		_hold -= delta
		# The room's own handler has already written the new level, so hold the old line.
		_apply(_from_m)
		if _hold <= 0.0 and _heave:
			# The heave is strong motion, so calm storm keeps the water plain.
			if not Settings.calm_storm:
				room.start_surge()
				surges += 1
		return
	_rise = minf(_rise + delta, _seconds)
	_apply(lerpf(_from_m, _to_m, _ease(_rise / _seconds)))
	if _rise >= _seconds:
		_finish(_to_m)


## Ease-out with Godot's back pop, unless the player asked for calm.
func _ease(t: float) -> float:
	if Settings.calm_storm:
		return 1.0 - pow(1.0 - t, 4.0)
	var x := t - 1.0
	return 1.0 + (BACK_S + 1.0) * x * x * x + BACK_S * x * x


## Only the drawn waterline eases; room.flood_m stays the true level at once,
## so wading, ripples and keepsakes never wait for the picture.
func _apply(level: float) -> void:
	_shown_m = level
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("flood_m", level)


func _finish(level: float) -> void:
	_rising = false
	_apply(level)


## Every material that draws this room's water: the painting, its cut-outs, the wall.
func _collect_materials() -> void:
	if not _materials.is_empty():
		return
	_gather(room)


func _gather(node: Node) -> void:
	var canvas := node as CanvasItem
	if canvas != null and canvas.material is ShaderMaterial and (canvas.material as ShaderMaterial).shader == Room.SHADER:
		_materials.append(canvas.material)
	for child: Node in node.get_children():
		_gather(child)
