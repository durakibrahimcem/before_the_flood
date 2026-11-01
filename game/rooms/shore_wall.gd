class_name ShoreWall
extends Sprite2D
## Ebru's seawall across the beach. It stands, cracks and breaks with the plan,
## and hides the sea. A code-drawn stone skin runs over it, and calm foam meets
## the water at its face; both are children, so the art itself never changes.

const FOOT_Y := 561.0
const BODY_SIZE := Vector2(1920, 40)
const HEIGHT := preload("res://rooms/shore/wall_height.png")
const TEXTURES := {
	WorldState.Wall.STANDING: preload("res://rooms/shore/wall.png"),
	WorldState.Wall.CRACKED: preload("res://rooms/shore/wall_cracked.png"),
	WorldState.Wall.BREACHED: preload("res://rooms/shore/wall_breached.png"),
}
const Stones := preload("res://rooms/shore/wall_stones.gd")
const Foam := preload("res://rooms/shore/wall_foam.gd")

var _foot: CollisionShape2D
var _stones: Node2D
var _foam: Node2D


func _ready() -> void:
	centered = false
	position = Vector2(0.0, FOOT_Y)
	offset = Vector2(0.0, -FOOT_Y)
	var body := StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = BODY_SIZE
	_foot = CollisionShape2D.new()
	_foot.shape = shape
	_foot.position = BODY_SIZE * 0.5
	body.add_child(_foot)
	add_child(body)
	_stones = Stones.new()
	_stones.name = "Stones"
	add_child(_stones)
	_stones.position = offset
	_foam = Foam.new()
	_foam.name = "Foam"
	add_child(_foam)
	_foam.position = offset
	WorldClock.year_changed.connect(_on_year_changed)
	WorldClock.refresh()


func _on_year_changed(state: WorldState) -> void:
	var built := state.wall_state != WorldState.Wall.NONE
	visible = built
	_foot.set_deferred("disabled", not built)
	if built:
		texture = TEXTURES[state.wall_state]
	_stones.update_age(state)


## For the demos: how damp the wall's foot is, 0 to 1.
func stone_damp() -> float:
	return _stones.damp_level()


## For the demos: 1 once the wall's crack years have arrived.
func stone_cracks() -> float:
	return _stones.crack_level()


## For the demos: how strongly the foam shows at the waterline, 0 to 1.
func foam_strength() -> float:
	return _foam.strength()


## For the demos: where the foam sits mid-wall, in wall texture pixels.
func foam_waterline_y() -> float:
	return _foam.waterline_y()
