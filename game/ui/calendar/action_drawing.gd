class_name ActionDrawing
extends Control
## One card in the tray. Passive display: the Calendar owns every click.

const BASE_BADGE_FONT := 15

var action: String = ""
var art: Texture2D = null
var count: int = 0:
	set(value):
		if count != value:
			count = value
			queue_redraw()
var hovered: bool = false:
	set(value):
		if hovered != value:
			hovered = value
			queue_redraw()

var _caption: Label = null
var _badge_font: int = BASE_BADGE_FONT


## Called by the Calendar once the card is in the tree.
func setup(card_action: String, card_art: Texture2D, caption: String, tip: String) -> void:
	action = card_action
	art = card_art
	tooltip_text = tip
	_caption.text = caption
	queue_redraw()


func set_font_size(caption: int, badge: int) -> void:
	_caption.add_theme_font_size_override("font_size", caption)
	_badge_font = badge
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void: hovered = true)
	mouse_exited.connect(func() -> void: hovered = false)
	_caption = Label.new()
	_caption.name = "Caption"
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_color_override("font_color", Crayon.INK)
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -46.0
	_caption.offset_bottom = -10.0
	add_child(_caption)


func _make_custom_tooltip(for_text: String) -> Control:
	return Crayon.tooltip_label(for_text, Crayon.font_size(Crayon.BASE_TOOLTIP_FONT, Settings.large_text))


func _draw() -> void:
	if action == "" or size.x < 12 or size.y < 12:
		return
	var box := Rect2(Vector2(6, 6), size - Vector2(12, 12))
	if hovered:
		draw_rect(box, Color(1.0, 0.85, 0.55, 0.28))
	var glyph := Rect2(box.position + Vector2(18, 16), box.size - Vector2(36, 70))
	if art != null:
		draw_texture_rect(art, glyph, false)
	else:
		Crayon.draw_glyph(self, action, glyph)
	draw_polyline(Crayon.rect_path(box, Crayon.grain(action)), Crayon.color(action), 5.0 if hovered else 3.0)
	if count >= 1:
		var badge := Vector2(box.get_center().x, box.position.y + 24.0)
		Crayon.draw_badge(self, get_theme_default_font(), badge, count, _badge_font)
