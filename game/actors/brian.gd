class_name Brian
extends Node2D
## Arda's dog, by the bowls in the salon. He waits for breakfast, is happy once fed, and is gone by the time the bowls stay empty.

const IDLE := preload("res://actors/art/brian_idle.png")
const HAPPY := preload("res://actors/art/brian_happy.png")
const ACTOR_SHADER := preload("res://water/actor.gdshader")
## Against the wall behind the bowls, so Arda coming to feed him doesn't stand in front of him.
const SPOT := Vector2(75, 536)
const HEIGHT_M := 0.7
const SHOULDER_SHARE := 0.2
## The idle tail hangs below his paws, so the happy pose lifts to keep the paws on the same spot. In art pixels.
const HAPPY_LIFT := 20.0

var room: Room
var _sprite: Sprite2D
var _material: ShaderMaterial


func _ready() -> void:
	position = SPOT
	_sprite = Sprite2D.new()
	_sprite.texture = IDLE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.centered = false
	_sprite.offset = Vector2(-IDLE.get_width() * 0.5, -IDLE.get_height())
	_sprite.scale = Vector2.ONE * HEIGHT_M * room.character_size() * room.px_per_m / IDLE.get_height()
	_material = ShaderMaterial.new()
	_material.shader = ACTOR_SHADER
	_sprite.material = _material
	add_child(_sprite)
	WorldClock.year_changed.connect(_on_year_changed)
	WorldClock.refresh()


func is_happy() -> bool:
	return _sprite.texture == HAPPY


func _on_year_changed(state: WorldState) -> void:
	visible = state.year < Room.BOWLS_EMPTY_YEAR
	_sprite.texture = HAPPY if Run.fed_today() else IDLE
	_sprite.position.y = -HAPPY_LIFT * _sprite.scale.y if is_happy() else 0.0
	var above := maxf(1.0 - room.depth_at(position) / (HEIGHT_M * room.character_size()), SHOULDER_SHARE)
	_material.set_shader_parameter("waterline", above)
