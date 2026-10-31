class_name DaySlot
extends Control
## One slot of one day. Passive display: the Calendar fills it in.

const BASE_BADGE_FONT := 15

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
var occurrence: int = 0:
	set(value):
		if occurrence != value:
			occurrence = value
			queue_redraw()
var open: bool = false:
	set(value):
		if open != value:
			open = value
			queue_redraw()
var future: bool = false:
	set(value):
		if future != value:
			future = value
			queue_redraw()
var drag_over: bool = false:
	set(value):
		if drag_over != value:
			drag_over = value
			queue_redraw()

var _grain: int = 5
var _badge_font: int = BASE_BADGE_FONT


## A different wobble for every slot, so the boxes feel hand drawn.
func setup(grain: int) -> void:
	_grain = grain


func set_font_size(badge: int) -> void:
	_badge_font = badge
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func _make_custom_tooltip(for_text: String) -> Control:
	return Crayon.tooltip_label(for_text, Crayon.font_size(Crayon.BASE_TOOLTIP_FONT, Settings.large_text))


func _draw() -> void:
	if size.x < 12 or size.y < 12:
		return
	var box := Rect2(Vector2(5, 5), size - Vector2(10, 10))
	var frame := Crayon.FAINT
	var thickness := 3.0
	if open or drag_over:
		frame = Crayon.WARM
		thickness = 6.0 if drag_over else 5.0
		draw_rect(box, Color(Crayon.WARM, 0.10))
	elif future:
		frame = Color(Crayon.FAINT, 0.5)
		thickness = 2.0
	draw_polyline(Crayon.rect_path(box, _grain), frame, thickness)
	if action == "":
		return
	var glyph := box.grow(-26.0)
	if art != null:
		draw_texture_rect(art, glyph, false)
	else:
		Crayon.draw_glyph(self, action, glyph)
	if occurrence >= 2:
		var badge := Vector2(box.end.x - 26.0, box.position.y + 26.0)
		Crayon.draw_badge(self, get_theme_default_font(), badge, occurrence, _badge_font)
