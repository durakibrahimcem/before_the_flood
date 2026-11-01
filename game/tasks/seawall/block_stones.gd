extends Node2D
## Hand-drawn stone joints over one wall block, so the stack reads as stone in
## the same line as the rooms. The block's texture is 220 by 96 and the sprite
## is centred, so this draws in the block's own centred pixel space. Scaled with
## the block, so the joints belong to its face through every squash.

const INK := Color(0.30, 0.27, 0.24, 0.38)
const LEFT := -96.0
const RIGHT := 96.0
const TOP := -38.0
const BOTTOM := 38.0
const JOINT_Y := 8.0

## Varies the joint placing per block, like stones laid by hand. Never random
## at runtime: the caller passes a fixed value per block.
var skin := 0


func _draw() -> void:
	_outline()
	_joint(Vector2(LEFT, JOINT_Y), Vector2(RIGHT, JOINT_Y), 3.0)
	# Two staggered vertical joints, one above the course line, one below.
	var upper := LEFT + 34.0 + float(skin % 3) * 26.0
	var lower := upper + 58.0 + float(skin % 2) * 22.0
	_joint(Vector2(upper, TOP + 5.0), Vector2(upper, JOINT_Y - 3.0), 2.0)
	_joint(Vector2(lower, JOINT_Y + 3.0), Vector2(lower, BOTTOM - 5.0), 4.0)


func _outline() -> void:
	var phase := float(skin % 7)
	var corners: Array[Vector2] = []
	for i: int in 40:
		var t := i / 40.0
		var at := _edge_point(t)
		corners.append(at + Vector2(sin(t * 26.0 + phase) * 1.4, cos(t * 22.0 + phase) * 1.4))
	for i: int in corners.size():
		draw_line(corners[i], corners[(i + 1) % corners.size()], INK, 2.5)


## Walks the block's outline, a corner at each quarter turn.
func _edge_point(t: float) -> Vector2:
	var side := int(t * 4.0)
	var local := fposmod(t * 4.0, 1.0)
	match side:
		0:
			return Vector2(lerpf(LEFT, RIGHT, local), TOP)
		1:
			return Vector2(RIGHT, lerpf(TOP, BOTTOM, local))
		2:
			return Vector2(lerpf(RIGHT, LEFT, local), BOTTOM)
	return Vector2(LEFT, lerpf(BOTTOM, TOP, local))


func _joint(from: Vector2, to: Vector2, phase: float) -> void:
	var steps := 10
	for i: int in steps:
		var a := from.lerp(to, i / float(steps))
		var b := from.lerp(to, (i + 1) / float(steps))
		a.x += sin(i * 2.1 + phase + float(skin % 5)) * 1.2
		b.x += sin((i + 1) * 2.1 + phase + float(skin % 5)) * 1.2
		draw_line(a, b, INK, 2.2)
