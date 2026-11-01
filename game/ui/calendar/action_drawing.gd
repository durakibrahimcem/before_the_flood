class_name ActionDrawing
extends Control
## One card in the tray. Passive display: the Calendar owns every click.

const BASE_BADGE_FONT := 26
## Room under the drawing for the name and a line saying what the action does.
const CAPTION_LINE := 1.35
const TIP_LINES := 2.0
const TEXT_MARGIN := 10.0
const TIP_SIDE_MARGIN := 22.0

var action: String = ""
## The number key that picks this drawing.
var key_number: int = 0
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
var _tip: Label = null
var _badge_font: int = BASE_BADGE_FONT
var _text_height: float = 0.0


## Called by the Calendar once the card is in the tree.
func setup(card_action: String, card_art: Texture2D, caption: String, tip: String, key: int) -> void:
	action = card_action
	art = card_art
	key_number = key
	_caption.text = caption
	_tip.text = tip
	queue_redraw()


func set_font_size(caption: int, tip: int, badge: int) -> void:
	_caption.add_theme_font_size_override("font_size", caption)
	_tip.add_theme_font_size_override("font_size", tip)
	_badge_font = badge
	var tip_height := tip * CAPTION_LINE * TIP_LINES
	_text_height = caption * CAPTION_LINE + tip_height + TEXT_MARGIN
	_tip.offset_top = -TEXT_MARGIN - tip_height
	_tip.offset_bottom = -TEXT_MARGIN
	_caption.offset_top = -_text_height
	_caption.offset_bottom = _tip.offset_top
	queue_redraw()


func tip_text() -> String:
	return _tip.text


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
	add_child(_caption)
	_tip = Label.new()
	_tip.name = "Tip"
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.add_theme_color_override("font_color", Crayon.INK)
	_tip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_tip.offset_left = TIP_SIDE_MARGIN
	_tip.offset_right = -TIP_SIDE_MARGIN
	add_child(_tip)


func _draw() -> void:
	if action == "" or size.x < 12 or size.y < 12:
		return
	var box := Rect2(Vector2(6, 6), size - Vector2(12, 12))
	if hovered:
		draw_rect(box, Color(1.0, 0.85, 0.55, 0.28))
	var glyph := Rect2(box.position + Vector2(18, 16), box.size - Vector2(36, 20.0 + _text_height))
	if art != null:
		draw_texture_rect(art, glyph, false)
	else:
		Crayon.draw_glyph(self, action, glyph)
	draw_polyline(Crayon.rect_path(box, Crayon.grain(action)), Crayon.color(action), 5.0 if hovered else 3.0)
	if key_number > 0:
		draw_string(get_theme_default_font(), box.position + Vector2(14, 34), str(key_number), HORIZONTAL_ALIGNMENT_LEFT, -1, _badge_font + 8, Crayon.INK)
	if count >= 1:
		var badge := Vector2(box.get_center().x, box.position.y + 24.0)
		Crayon.draw_badge(self, get_theme_default_font(), badge, count, _badge_font)
