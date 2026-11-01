class_name Arda
extends CharacterBody2D
## The player, at the age the clock says. Offers `carried` and the "walker" group to tasks.

const WADE_FLOOR := 0.4
const WADE_FULL_M := 1.2
const SHOULDER_SHARE := 0.2
const BOB_HEIGHT := 7.0
const IDLE := preload("res://actors/art/arda_idle.png")
const WALK: Array[Texture2D] = [preload("res://actors/art/arda_walk1.png"), preload("res://actors/art/arda_walk2.png")]
const ADULT_IDLE := preload("res://actors/art/arda_adult_idle.png")
const ADULT_WALK: Array[Texture2D] = [preload("res://actors/art/arda_adult_walk1.png"), preload("res://actors/art/arda_adult_walk2.png")]
const OLD_IDLE := preload("res://actors/art/arda_old_idle.png")
const OLD_WALK: Array[Texture2D] = [preload("res://actors/art/arda_old_walk1.png"), preload("res://actors/art/arda_old_walk2.png")]
const IDLES := { 2026: IDLE, 2050: ADULT_IDLE, 2080: OLD_IDLE }
const WALKS := { 2026: WALK, 2050: ADULT_WALK, 2080: OLD_WALK }
const BOB_SPEED := 9.0
const AGE_METRES := { 2026: 1.3, 2050: 1.75, 2080: 1.7 }
const STRIDE := 0.35
const RIPPLE_MIN_DEPTH_M := 0.03
## A small lean into the walk, far less than the real angle, which eases out through a reversal.
const LEAN_RADIANS := 0.045
const LEAN_EASE := 9.0
## Turning round squeezes the sprite for a moment, so the flip isn't a hard cut.
const TURN_SQUEEZE := 0.16
const TURN_RECOVER := 6.0
## Left standing, Arda glances the other way now and then.
const LOOK_AROUND_SECONDS := 4.5
const PUFF_COUNT := 3
const PUFF_LIFETIME := 0.42
const SPLASH_TINT := Color("d7eaee")
const GROUND_TINTS := { "shore": Color("e6d6a2"), "street": Color("efeade") }
## The scale the foot shape was made for.
const FOOT_PX_PER_M := 200.0

@export var speed: float = 460.0

var carried: String = ""
## Keeps Arda still while a full-screen sheet is open over the room.
var frozen := false
## Takes the room's scale with it, so Arda and their foot fit the painting.
var room: Room:
	set(value):
		room = value
		if room != null:
			pixels_per_metre = room.px_per_m
			character_size = room.character_size()
			$Foot.scale = Vector2.ONE * minf(1.0, room.px_per_m / FOOT_PX_PER_M)
var pixels_per_metre: float = 200.0
var character_size: float = 1.0
var height_m: float = 1.3
var _walked: float = 0.0
var _walk_pose := 0
var _stepped_at: float = -STRIDE
var _up_latched := false
var _turn := 0.0
var _next_puff := 0
var stands_for := 0.0
## A few reused bursts, one for each footfall.
var puffs: Array[CPUParticles2D] = []

@onready var body_sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group("walker")
	_build_puffs()
	WorldClock.year_changed.connect(_on_year_changed)
	WorldClock.refresh()


func _physics_process(delta: float) -> void:
	var direction := _walk_direction()
	var depth := room.depth_at(global_position) if room != null else 0.0
	velocity = direction * speed * wade_factor(depth)
	move_and_slide()
	_walked += velocity.length() * delta / speed
	if velocity != Vector2.ZERO and _walked - _stepped_at >= STRIDE:
		_stepped_at = _walked
		_walk_pose = 1 - _walk_pose
		_step(depth)
	_show_pose(_current_pose())
	if direction.x != 0.0:
		var faces_left := direction.x < 0.0
		_turn = 1.0 if faces_left != body_sprite.flip_h else _turn
		body_sprite.flip_h = faces_left
	_look_around(delta)
	_turn = move_toward(_turn, 0.0, TURN_RECOVER * delta)
	body_sprite.rotation = lerpf(body_sprite.rotation, LEAN_RADIANS * velocity.x / speed, 1.0 - exp(-LEAN_EASE * delta))
	body_sprite.position.y = -absf(sin(_walked * BOB_SPEED)) * BOB_HEIGHT * pixels_per_metre / FOOT_PX_PER_M
	_set_waterline(depth)


func _look_around(delta: float) -> void:
	if velocity != Vector2.ZERO:
		stands_for = 0.0
		return
	stands_for += delta
	if stands_for >= LOOK_AROUND_SECONDS:
		stands_for = 0.0
		body_sprite.flip_h = not body_sprite.flip_h
		_turn = 1.0


## Ignores a W still held from the last door, so it can't walk Arda straight back through.
func latch_up() -> void:
	_up_latched = Input.is_action_pressed("move_up")


func _walk_direction() -> Vector2:
	_up_latched = _up_latched and Input.is_action_pressed("move_up")
	if frozen:
		return Vector2.ZERO
	if _up_latched:
		return Vector2(Input.get_axis("move_left", "move_right"), Input.get_action_strength("move_down")).limit_length()
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _step(depth: float) -> void:
	if depth <= RIPPLE_MIN_DEPTH_M:
		Sfx.play("step_dry")
		if room != null and GROUND_TINTS.has(room.room_name):
			_puff(global_position, GROUND_TINTS[room.room_name])
		return
	Sfx.play("step_wet")
	var wet_m := minf(depth, _drawn_height_m() * (1.0 - SHOULDER_SHARE))
	room.add_ripple(position - Vector2(0.0, wet_m * pixels_per_metre))
	_puff(global_position - Vector2(0.0, wet_m * pixels_per_metre), SPLASH_TINT)


func wade_factor(depth: float) -> float:
	return lerpf(1.0, WADE_FLOOR, clampf(depth / WADE_FULL_M, 0.0, 1.0))


func _current_pose() -> Texture2D:
	var era := WorldClock.nearest_era()
	if velocity == Vector2.ZERO:
		return IDLES[era]
	return WALKS[era][_walk_pose]


func _show_pose(pose: Texture2D) -> void:
	body_sprite.texture = pose
	body_sprite.offset = Vector2(-pose.get_width() * 0.5, -pose.get_height())
	body_sprite.scale = Vector2.ONE * _drawn_height_m() * pixels_per_metre / pose.get_height()
	body_sprite.scale.x *= 1.0 - TURN_SQUEEZE * _turn


func _on_year_changed(_state: WorldState) -> void:
	height_m = AGE_METRES[WorldClock.nearest_era()]
	_show_pose(_current_pose())
	if room != null:
		_set_waterline(room.depth_at(global_position))


func _set_waterline(depth: float) -> void:
	var above := maxf(1.0 - depth / _drawn_height_m(), SHOULDER_SHARE)
	(body_sprite.material as ShaderMaterial).set_shader_parameter("waterline", above)


func _build_puffs() -> void:
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var speck := GradientTexture2D.new()
	speck.width = 24
	speck.height = 24
	speck.fill = GradientTexture2D.FILL_RADIAL
	speck.fill_from = Vector2(0.5, 0.5)
	speck.fill_to = Vector2(1.0, 0.5)
	var soft_edge := Gradient.new()
	soft_edge.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	soft_edge.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)])
	speck.gradient = soft_edge
	for i: int in PUFF_COUNT:
		var puff := CPUParticles2D.new()
		puff.one_shot = true
		puff.emitting = false
		puff.local_coords = false
		puff.amount = 9
		puff.lifetime = PUFF_LIFETIME
		puff.explosiveness = 1.0
		puff.direction = Vector2.UP
		puff.spread = 70.0
		puff.initial_velocity_min = 40.0
		puff.initial_velocity_max = 95.0
		puff.gravity = Vector2(0.0, 220.0)
		puff.texture = speck
		puff.scale_amount_min = 0.25
		puff.scale_amount_max = 0.55
		puff.color_ramp = fade
		add_child(puff)
		puffs.append(puff)


func _puff(at: Vector2, tint: Color) -> void:
	if Settings.calm_storm:
		return
	var puff := puffs[_next_puff]
	_next_puff = (_next_puff + 1) % puffs.size()
	puff.global_position = at
	puff.color = tint
	puff.restart()


func _drawn_height_m() -> float:
	return height_m * character_size
