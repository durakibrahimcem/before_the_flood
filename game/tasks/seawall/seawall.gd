class_name Seawall
extends Task
## Stack heavy concrete blocks into a seawall with one timed press per block.

signal block_landed(aligned: bool, at: Vector2)

const WALL_X := 960.0
const GROUND_Y := 880.0
const CARRIAGE_MIN_X := 170.0
const CARRIAGE_MAX_X := 1750.0
const CARRIAGE_TRAVEL := CARRIAGE_MAX_X - CARRIAGE_MIN_X
const BLOCK_HALF_W := 110.0
const BLOCK_H_MAX := 96.0
const STACK_USABLE := 560.0
const ALIGNED_OFFSET := 64.0
const CROOKED_OFFSET := BLOCK_HALF_W
const MISS_CLEAR_X := 230.0
const MISS_SLOT_STEP := 230.0
const MISS_SPAN := 115.0
const MISS_LEAN := 0.10
const FALL_START_VY := 150.0
const FALL_GRAVITY := 3400.0
const FREEZE_ALIGNED := 0.10
const FREEZE_CROOKED := 0.06
const FREEZE_MISSED := 0.04
const SETTLE_GAP := 0.35
const SHAKE_STRENGTH := 14.0
const SHAKE_TIME := 0.35
const CAP_SECONDS := 60.0

enum State { IDLE, SLIDING, FALLING, FROZEN, SETTLING }

const Gantry := preload("res://tasks/seawall/gantry.gd")
const WallGuide := preload("res://tasks/seawall/wall_guide.gd")
const WallBlock := preload("res://tasks/seawall/wall_block.gd")
const DustBurst := preload("res://tasks/seawall/dust_burst.gd")
const SeawallHint := preload("res://tasks/seawall/crayon_hint.gd")

@export var block_texture: Texture2D = preload("res://tasks/seawall/block.png")

var goal: int = 0
var blocks_landed: int = 0
var aligned_blocks: int = 0

var _state: State = State.IDLE
var _carriage_x := 0.0
var _carriage_dir := 1.0
var _slide_speed := 0.0
var _fall_vy := 0.0
var _freeze_t := 0.0
var _settle_t := 0.0
var _shake_t := 0.0
var _elapsed := 0.0
var _stack := 0
var _burst_index := 0
var _block_h := BLOCK_H_MAX
var _misses: Array[float] = []
var _hanging: WallBlock = null
var _falling_block: WallBlock = null
var _landed_block: WallBlock = null
var _land_kind := 0
var _land_point := Vector2.ZERO
var _bursts: Array[DustBurst] = []

@onready var _stage: Node2D = $Stage
@onready var _gantry: Gantry = $Stage/Gantry
@onready var _guide: WallGuide = $Stage/Guide
@onready var _blocks: Node2D = $Stage/Blocks
@onready var _hint: SeawallHint = $Stage/Hint
@onready var _dust_a: DustBurst = $Stage/Dust/DustA
@onready var _dust_b: DustBurst = $Stage/Dust/DustB


func _init() -> void:
	action = "wall"


func _ready() -> void:
	_bursts.append(_dust_a)
	_bursts.append(_dust_b)


func _begin() -> void:
	goal = target_count(6)
	blocks_landed = 0
	aligned_blocks = 0
	_stack = 0
	_burst_index = 0
	_misses.clear()
	_elapsed = 0.0
	_shake_t = 0.0
	_stage.position = Vector2.ZERO
	_landed_block = null
	for child: Node in _blocks.get_children():
		_blocks.remove_child(child)
		child.queue_free()
	_hanging = null
	_falling_block = null
	# Repeats need more blocks under the same crane, so the blocks shrink.
	_block_h = minf(BLOCK_H_MAX, STACK_USABLE / goal)
	_slide_speed = CARRIAGE_TRAVEL / maxf(0.8, 30.0 / goal - 0.9)
	_carriage_x = CARRIAGE_MIN_X
	_carriage_dir = 1.0
	_gantry.set_carriage_x(_carriage_x)
	_guide.setup(goal, _block_h, BLOCK_HALF_W, _gantry.rail_bottom_y() + 30.0)
	_hint.show_hint()
	_spawn_hanging()
	_state = State.SLIDING


func _physics_process(delta: float) -> void:
	if _state == State.IDLE:
		return
	_elapsed += delta
	if _elapsed >= target_time(CAP_SECONDS) and not _done:
		if _falling_block != null:
			_land_on(_surface_for(_falling_block.position.x))
		_stop()
		complete(aligned_blocks / float(goal))
		return
	match _state:
		State.SLIDING:
			_slide(delta)
		State.FALLING:
			_fall(delta)
		State.FROZEN:
			_freeze(delta)
		State.SETTLING:
			_settle(delta)
	_update_shake(delta)


func result_text() -> String:
	return "%d of %d blocks straight" % [aligned_blocks, goal]


func debug_note() -> String:
	return "%d %d %d %d %d" % [aligned_blocks, blocks_landed, goal, _carriage_x, 1 if can_drop() else 0]


func can_drop() -> bool:
	return _state == State.SLIDING and _hanging != null


func slider_x() -> float:
	return _carriage_x


func stage_offset() -> Vector2:
	return _stage.position


func is_shaking() -> bool:
	return _shake_t > 0.0


func _slide(delta: float) -> void:
	_carriage_x += _slide_speed * _carriage_dir * delta
	if _carriage_x >= CARRIAGE_MAX_X:
		_carriage_x = CARRIAGE_MAX_X
		_carriage_dir = -1.0
	elif _carriage_x <= CARRIAGE_MIN_X:
		_carriage_x = CARRIAGE_MIN_X
		_carriage_dir = 1.0
	_gantry.set_carriage_x(_carriage_x)
	if _hanging == null:
		# The empty carriage fetches the next block at the rail ends, so a drop
		# over the wall can never be chained into an instant second drop.
		if blocks_landed < goal and (_carriage_x == CARRIAGE_MIN_X or _carriage_x == CARRIAGE_MAX_X):
			_spawn_hanging()
		return
	_hanging.position = Vector2(_carriage_x, _gantry.hang_top_y() + _block_h * 0.5)
	if Input.is_action_just_pressed("interact"):
		_drop()


func _drop() -> void:
	_falling_block = _hanging
	_hanging = null
	_fall_vy = FALL_START_VY
	_state = State.FALLING


func _fall(delta: float) -> void:
	_fall_vy += FALL_GRAVITY * delta
	_falling_block.position.y += _fall_vy * delta
	var surface := _surface_for(_falling_block.position.x)
	if _falling_block.position.y + _block_h * 0.5 >= surface:
		_land_on(surface)


func _surface_for(x: float) -> float:
	if absf(x - WALL_X) <= CROOKED_OFFSET:
		return GROUND_Y - _stack * _block_h
	for slot_x: float in _misses:
		if absf(slot_x - x) <= MISS_SPAN:
			return GROUND_Y - _block_h
	return GROUND_Y


func _land_on(surface: float) -> void:
	Sfx.play("block")
	var block := _falling_block
	_falling_block = null
	var offset := block.position.x - WALL_X
	var kind := 0
	var land_x := block.position.x
	if absf(offset) <= ALIGNED_OFFSET:
		land_x = WALL_X
		aligned_blocks += 1
		_stack += 1
	elif absf(offset) <= CROOKED_OFFSET:
		kind = 1
		_stack += 1
	else:
		kind = 2
	blocks_landed += 1
	block.position = Vector2(land_x, surface - _block_h * 0.5)
	block.impact()
	if kind == 1:
		block.prepare(clampf(offset * 0.0016, -0.10, 0.10))
	elif kind == 2:
		block.prepare_slide(_miss_rest(offset), signf(offset) * MISS_LEAN)
	_land_kind = kind
	_land_point = Vector2(land_x, surface)
	_landed_block = block
	_freeze_t = [FREEZE_ALIGNED, FREEZE_CROOKED, FREEZE_MISSED][kind]
	_state = State.FROZEN
	block_landed.emit(kind == 0, to_global(_land_point))
	if blocks_landed == goal:
		complete(aligned_blocks / float(goal))


## Missed blocks rest in a flat lane beside the wall, one slot per block, so
## they never clip the wall or each other.
func _miss_rest(offset: float) -> Vector2:
	var side := signf(offset)
	var slot := 0
	for slot_x: float in _misses:
		if signf(slot_x - WALL_X) == side:
			slot += 1
	var rest_x := WALL_X + side * (MISS_CLEAR_X + slot * MISS_SLOT_STEP)
	var half_h := _block_h * 0.5 * cos(MISS_LEAN) + BLOCK_HALF_W * sin(MISS_LEAN)
	_misses.append(rest_x)
	return Vector2(rest_x, GROUND_Y - half_h)


func _dust_strength(kind: int) -> float:
	if kind == 0:
		return 1.0
	return 0.6 if kind == 1 else 0.35


func _freeze(delta: float) -> void:
	_freeze_t -= delta
	if _freeze_t <= 0.0:
		_release_impact()
		_settle_t = SETTLE_GAP
		_state = State.SETTLING


## The freeze is a held beat of stillness; the weight lands after it.
func _release_impact() -> void:
	if not Settings.calm_storm:
		_shake_t = SHAKE_TIME
	_bursts[_burst_index].burst(_land_point, _dust_strength(_land_kind))
	_burst_index = 1 - _burst_index
	if _landed_block != null:
		_landed_block.release()
		_landed_block = null


func _settle(delta: float) -> void:
	_settle_t -= delta
	if _settle_t <= 0.0:
		if blocks_landed >= goal:
			_stop()
			return
		_state = State.SLIDING


func _update_shake(delta: float) -> void:
	if _shake_t <= 0.0:
		return
	_shake_t = maxf(0.0, _shake_t - delta)
	if _shake_t <= 0.0:
		_stage.position = Vector2.ZERO
		return
	var strength := SHAKE_STRENGTH * (_shake_t / SHAKE_TIME)
	_stage.position = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))


func _spawn_hanging() -> void:
	var block: WallBlock = WallBlock.new()
	block.block_texture = block_texture
	block.setup_height(_block_h)
	_blocks.add_child(block)
	block.position = Vector2(_carriage_x, _gantry.hang_top_y() + _block_h * 0.5)
	block.appear()
	_hanging = block


func _stop() -> void:
	_state = State.IDLE
	_shake_t = 0.0
	_stage.position = Vector2.ZERO
