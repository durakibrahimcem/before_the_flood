class_name DragGhost
extends Control
## The little crayon card that follows the mouse during a drag.

const CARD := Vector2(112.0, 112.0)

var action: String = "":
	set(value):
		if action != value:
			action = value
			queue_redraw()
var art: Texture2D = null:
	set(value):
		if art != value:
			art = value
			queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = CARD
	hide()


func _draw() -> void:
	if action == "":
		return
	var box := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	draw_rect(box, Color(0.99, 0.97, 0.90, 0.85))
	var glyph := box.grow(-14.0)
	if art != null:
		draw_texture_rect(art, glyph, false)
	else:
		Crayon.draw_glyph(self, action, glyph)
	draw_polyline(Crayon.rect_path(box, Crayon.grain(action)), Crayon.color(action), 4.0)
