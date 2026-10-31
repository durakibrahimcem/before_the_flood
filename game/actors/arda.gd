class_name Arda
extends CharacterBody2D
## The player, at the age the clock says. Offers `carried` and the "walker" group to tasks.

const WADE_FLOOR := 0.4
const WADE_FULL_M := 1.2
const SHOULDER_SHARE := 0.2
const BOB_HEIGHT := 7.0
const BOB_SPEED := 9.0
const AGE_METRES := { 2026: 1.3, 2050: 1.75, 2080: 1.7 }
const STRIDE := 0.35
const RIPPLE_MIN_DEPTH_M := 0.03
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
			$Foot.scale = Vector2.ONE * minf(1.0, room.px_per_m / FOOT_PX_PER_M)
var pixels_per_metre: float = 200.0
var height_m: float = 1.3
var _walked: float = 0.0
var _stepped_at: float = -STRIDE

@onready var body_sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group("walker")
	WorldClock.year_changed.connect(_on_year_changed)
	WorldClock.refresh()


func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO if frozen else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var depth := room.depth_at(global_position) if room != null else 0.0
	velocity = direction * speed * wade_factor(depth)
	move_and_slide()
	_walked += velocity.length() * delta / speed
	if velocity != Vector2.ZERO and _walked - _stepped_at >= STRIDE:
		_stepped_at = _walked
		_step(depth)
	if direction.x != 0.0:
		body_sprite.flip_h = direction.x < 0.0
	body_sprite.position.y = -absf(sin(_walked * BOB_SPEED)) * BOB_HEIGHT
	_set_waterline(depth)


func _step(depth: float) -> void:
	if depth <= RIPPLE_MIN_DEPTH_M:
		Sfx.play("step_dry")
		return
	Sfx.play("step_wet")
	var wet_m := minf(depth, height_m * (1.0 - SHOULDER_SHARE))
	room.add_ripple(position - Vector2(0.0, wet_m * pixels_per_metre))


func wade_factor(depth: float) -> float:
	return lerpf(1.0, WADE_FLOOR, clampf(depth / WADE_FULL_M, 0.0, 1.0))


func _on_year_changed(_state: WorldState) -> void:
	height_m = AGE_METRES[WorldClock.nearest_era()]
	var texture_height := float(body_sprite.texture.get_height())
	var ratio := height_m * pixels_per_metre / texture_height
	body_sprite.scale = Vector2(ratio, ratio)
	if room != null:
		_set_waterline(room.depth_at(global_position))


func _set_waterline(depth: float) -> void:
	var above := maxf(1.0 - depth / height_m, SHOULDER_SHARE)
	(body_sprite.material as ShaderMaterial).set_shader_parameter("waterline", above)
