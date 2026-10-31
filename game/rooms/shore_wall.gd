class_name ShoreWall
extends Sprite2D
## Ebru's seawall across the beach. It stands, cracks and breaks with the plan, and hides the sea.

const FOOT_Y := 561.0
const BODY_SIZE := Vector2(1920, 40)
const HEIGHT := preload("res://rooms/shore/wall_height.png")
const TEXTURES := {
	WorldState.Wall.STANDING: preload("res://rooms/shore/wall.png"),
	WorldState.Wall.CRACKED: preload("res://rooms/shore/wall_cracked.png"),
	WorldState.Wall.BREACHED: preload("res://rooms/shore/wall_breached.png"),
}

var _foot: CollisionShape2D


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
	WorldClock.year_changed.connect(_on_year_changed)
	WorldClock.refresh()


func _on_year_changed(state: WorldState) -> void:
	var built := state.wall_state != WorldState.Wall.NONE
	visible = built
	_foot.set_deferred("disabled", not built)
	if built:
		texture = TEXTURES[state.wall_state]
