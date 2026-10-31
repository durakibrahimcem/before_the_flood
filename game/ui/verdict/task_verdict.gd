class_name TaskVerdict
extends CanvasLayer
## A paper card that says how a task went, then gets out of the way.

const LAYER := 90
const CARD_TOP := 190.0
const CARD_SIZE := Vector2(720.0, 170.0)
const HOLD_SECONDS := 2.2
## From the best result down. A score earns the first line it reaches.
const WORDS: Array[Dictionary] = [
	{ "from": 1.0, "word": "Awesome!", "ink": Color("3f7d4a") },
	{ "from": 0.75, "word": "Great job!", "ink": Color("3f7d4a") },
	{ "from": 0.5, "word": "Good work.", "ink": Color("8a6a2a") },
	{ "from": 0.25, "word": "Not bad, but it could be better.", "ink": Color("a0632e") },
	{ "from": 0.0, "word": "That went badly.", "ink": Color("a34a3a") },
]

var _card: PanelContainer
var _word: Label
var _detail: Label
var _tween: Tween


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_card = PanelContainer.new()
	_card.size = CARD_SIZE
	_card.position = Vector2((Room.ROOM_SIZE.x - CARD_SIZE.x) * 0.5, CARD_TOP)
	_card.pivot_offset = CARD_SIZE * 0.5
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", CrayonUI.style_panel())
	_card.hide()
	add_child(_card)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(column)
	_word = _line(52)
	column.add_child(_word)
	_detail = _line(34)
	_detail.add_theme_color_override("font_color", CrayonUI.INK)
	column.add_child(_detail)


## The verdict for a score from 0 to 1.
static func entry_for(performance: float) -> Dictionary:
	for entry: Dictionary in WORDS:
		if performance >= float(entry["from"]):
			return entry
	return WORDS[-1]


func show_result(performance: float, detail: String) -> void:
	var entry := entry_for(performance)
	_word.text = entry["word"]
	_word.add_theme_color_override("font_color", entry["ink"])
	_detail.text = detail
	_detail.visible = detail != ""
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_card.show()
	_card.modulate.a = 1.0
	_card.scale = Vector2(1.25, 1.25)
	_tween = create_tween().bind_node(self)
	_tween.tween_property(_card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_property(_card, "modulate:a", 0.0, 0.4)
	_tween.tween_callback(_card.hide)


func word() -> String:
	return _word.text if _card.visible else ""


func _line(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
