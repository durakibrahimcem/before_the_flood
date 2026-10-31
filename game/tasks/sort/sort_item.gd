class_name SortItem
extends Area2D
## A piece of waste to carry. A dumb node: it only reports walker touches.

signal touched(body: Node2D)

const KIND_COLORS := {
	"plastic": Color(0.98, 0.96, 0.36),
	"paper": Color(0.34, 0.49, 0.78),
	"glass": Color(0.56, 0.86, 0.45),
	"metal": Color(0.48, 0.47, 0.42),
}
const OUTLINE := Color(0.13, 0.11, 0.09)
const SHADOW := Color(1.0, 1.0, 1.0, 0.85)

## One of plastic, paper, glass, metal.
@export var kind: String = "plastic"
## Ebru's art drop-in; null draws the code placeholder.
@export var art: Texture2D


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	if art != null:
		var sprite := Sprite2D.new()
		sprite.texture = art
		add_child(sprite)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("walker"):
		touched.emit(body)


## One silhouette per kind, shared with the bin icons: bottle, sheet, jar, can.
static func silhouette(kind: String) -> PackedVector2Array:
	match kind:
		"paper":
			return PackedVector2Array([
				Vector2(-24, -12), Vector2(20, -24), Vector2(24, 12), Vector2(-20, 24)])
		"glass":
			return PackedVector2Array([
				Vector2(-13, -26), Vector2(13, -26), Vector2(13, -16), Vector2(10, -16),
				Vector2(10, 14), Vector2(6, 26), Vector2(-6, 26), Vector2(-10, 14),
				Vector2(-10, -16), Vector2(-13, -16)])
		"metal":
			return PackedVector2Array([
				Vector2(-9, -24), Vector2(9, -24), Vector2(13, -17), Vector2(13, 17),
				Vector2(9, 24), Vector2(-9, 24), Vector2(-13, 17), Vector2(-13, -17)])
		_:
			return PackedVector2Array([
				Vector2(-5, -28), Vector2(5, -28), Vector2(5, -16), Vector2(10, -10),
				Vector2(10, 18), Vector2(6, 28), Vector2(-6, 28), Vector2(-10, 18),
				Vector2(-10, -10), Vector2(-5, -16)])


## The silhouette as a closed loop, ready for draw_polyline.
static func closed(points: PackedVector2Array) -> PackedVector2Array:
	var loop := PackedVector2Array(points)
	if not loop.is_empty():
		loop.append(points[0])
	return loop


func _draw() -> void:
	if art != null:
		return
	var points := silhouette(kind)
	# A white shadow first, so the item reads over light and dark rooms alike.
	draw_set_transform(Vector2(3, 3), 0.0, Vector2.ONE)
	draw_colored_polygon(points, SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var fill: Color = KIND_COLORS.get(kind, KIND_COLORS["plastic"])
	draw_colored_polygon(points, fill)
	draw_polyline(closed(points), OUTLINE, 3.0)
