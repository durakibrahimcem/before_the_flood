class_name Ayla
extends Node2D
## Arda's mother, at home in the salon. She is there while the home stands, and gone by 2080.

const ART := preload("res://actors/art/ayla_idle.png")
const ACTOR_SHADER := preload("res://water/actor.gdshader")
const SPOT := Vector2(1400, 650)
const HEIGHT_M := 1.65
const LAST_ERA := 2050
const SHOULDER_SHARE := 0.2
const BREATH_PHASE := 1.7
## Her feet. Round, so Arda slides past her instead of stopping dead on the way to the fridge.
const FOOT_RADIUS := 26.0
## She turns to Arda only once they are clearly past her, so she doesn't flicker as they stand close.
const LOOK_MARGIN := 70.0

var room: Room
var _material: ShaderMaterial
var _foot: CollisionShape2D
var _sprite: Sprite2D
var _walker: Node2D


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
	_material.set_shader_parameter("breath_phase", BREATH_PHASE)
	sprite.material = _material
	add_child(sprite)
	_sprite = sprite
	var body := StaticBody2D.new()
	_foot = CollisionShape2D.new()
	var round_foot := CircleShape2D.new()
	round_foot.radius = FOOT_RADIUS
	_foot.shape = round_foot
	body.add_child(_foot)
	add_child(body)
	WorldClock.year_changed.connect(_on_year_changed)
	WorldClock.refresh()


func _process(_delta: float) -> void:
	# Arda joins the room after she does.
	if _walker == null:
		_walker = get_tree().get_first_node_in_group("walker") as Node2D
		return
	var away := _walker.global_position.x - global_position.x
	if absf(away) > LOOK_MARGIN:
		_sprite.flip_h = away > 0.0


func looks_right() -> bool:
	return _sprite.flip_h


func _on_year_changed(state: WorldState) -> void:
	visible = WorldClock.nearest_era() <= LAST_ERA and state.home_alive.get("own", true)
	_foot.set_deferred("disabled", not visible)
	var above := maxf(1.0 - room.depth_at(position) / (HEIGHT_M * room.character_size()), SHOULDER_SHARE)
	_material.set_shader_parameter("waterline", above)
