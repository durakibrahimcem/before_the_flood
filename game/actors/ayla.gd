class_name Ayla
extends Node2D
## Arda's mother, at home in the salon. She is there while the home stands, and gone by 2080.

const ART := preload("res://actors/art/ayla_idle.png")
const ACTOR_SHADER := preload("res://water/actor.gdshader")
const SPOT := Vector2(1400, 650)
const HEIGHT_M := 1.65
const LAST_ERA := 2050
const SHOULDER_SHARE := 0.2
## Her feet. Round, so Arda slides past her instead of stopping dead on the way to the fridge.
const FOOT_RADIUS := 26.0

var room: Room
var _material: ShaderMaterial
var _foot: CollisionShape2D


func _ready() -> void:
	position = SPOT
	var sprite := Sprite2D.new()
	sprite.texture = ART
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.centered = false
	sprite.offset = Vector2(-ART.get_width() * 0.5, -ART.get_height())
	sprite.scale = Vector2.ONE * HEIGHT_M * room.character_size() * room.px_per_m / ART.get_height()
	_material = ShaderMaterial.new()
	_material.shader = ACTOR_SHADER
	sprite.material = _material
	add_child(sprite)
	var body := StaticBody2D.new()
	_foot = CollisionShape2D.new()
	var round_foot := CircleShape2D.new()
	round_foot.radius = FOOT_RADIUS
	_foot.shape = round_foot
	body.add_child(_foot)
	add_child(body)
	WorldClock.year_changed.connect(_on_year_changed)
	WorldClock.refresh()


func _on_year_changed(state: WorldState) -> void:
	visible = WorldClock.nearest_era() <= LAST_ERA and state.home_alive.get("own", true)
	_foot.set_deferred("disabled", not visible)
	var above := maxf(1.0 - room.depth_at(position) / (HEIGHT_M * room.character_size()), SHOULDER_SHARE)
	_material.set_shader_parameter("waterline", above)
