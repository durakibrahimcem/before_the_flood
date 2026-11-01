class_name MeetingCards
extends Control
## The three argument cards: paper buttons in a loose row at the bottom of the
## street. Clicks (and the demo's pressed emissions) arrive as card_chosen.

signal card_chosen(index: int)

const CARD_SIZE := Vector2(560.0, 150.0)
const CARD_GAP := 24.0
const CARD_Y := 900.0
const SCREEN_W := 1920.0
const PAPER := Color("f7efe2")
const PAPER_WARM := Color("f2e3cb")
const BADGE := Color("e7dbc8")
const INK := Color("3b342e")

var _buttons: Array[Button] = []
var _texts: Array[Label] = []
var _tween: Tween


func _ready() -> void:
	size = Vector2(SCREEN_W, 1080.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	var row_width := CARD_SIZE.x * 3.0 + CARD_GAP * 2.0
	for index: int in 3:
		_build_card(index, (SCREEN_W - row_width) / 2.0 + index * (CARD_SIZE.x + CARD_GAP))


## Shows the three texts on the cards; they are clickable right away.
func show_answers(texts: Array) -> void:
	for index: int in 3:
		_texts[index].text = str(texts[index])
		_buttons[index].disabled = false
		_buttons[index].visible = true
	_fade(1.0, 0.15)


## Hides the cards; the buttons stop taking input at once.
func hide_cards() -> void:
	for button: Button in _buttons:
		button.disabled = true
	_fade(0.0, 0.12)


## For scripted demos: emits the pressed signal, the exact path a click takes.
func press(index: int) -> void:
	_buttons[index].pressed.emit()


## One card lifts in the shared task feel; the pop pivots on the card's middle.
func pop_card(index: int) -> void:
	var button := _buttons[index]
	button.pivot_offset = button.size * 0.5
	TaskJuice.pop(button)


func _build_card(index: int, x: float) -> void:
	var button := Button.new()
	button.position = Vector2(x, CARD_Y)
	button.size = CARD_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.rotation = deg_to_rad(0.4 if index % 2 == 0 else -0.4)
	button.disabled = true
	button.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = INK
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("disabled", style)
	var warm := style.duplicate() as StyleBoxFlat
	warm.bg_color = PAPER_WARM
	button.add_theme_stylebox_override("hover", warm)
	button.add_theme_stylebox_override("pressed", warm)
	add_child(button)
	button.pressed.connect(card_chosen.emit.bind(index))
	var badge_panel := Panel.new()
	badge_panel.position = Vector2(12.0, 10.0)
	badge_panel.size = Vector2(30.0, 30.0)
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = BADGE
	badge_style.set_corner_radius_all(8)
	badge_panel.add_theme_stylebox_override("panel", badge_style)
	button.add_child(badge_panel)
	var badge_label := Label.new()
	badge_label.text = str(index + 1)
	badge_label.size = badge_panel.size
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size", Settings.sized(20))
	badge_label.add_theme_color_override("font_color", INK)
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_panel.add_child(badge_label)
	var text_label := Label.new()
	text_label.position = Vector2(20.0, 44.0)
	text_label.size = Vector2(CARD_SIZE.x - 40.0, CARD_SIZE.y - 58.0)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", Settings.sized(28))
	text_label.add_theme_color_override("font_color", INK)
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(text_label)
	_buttons.append(button)
	_texts.append(text_label)


func _fade(alpha: float, time: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", alpha, time)
	if alpha <= 0.0:
		_tween.tween_callback(_hide_buttons)


func _hide_buttons() -> void:
	for button: Button in _buttons:
		button.visible = false
