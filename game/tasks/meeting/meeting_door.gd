class_name MeetingDoor
extends Node2D
## The door Ebru painted on the house next door: a doormat to knock at, a
## speech bubble and a window that lights up.

const INK := Color("3b342e")
const PAPER := Color("f7efe2")
const MAT := Color("c9b291")
const LAMP := Color("ffdf9e")
const TINT := Color("7fa06a")
const MAT_OFFSET := Vector2(0.0, 30.0)
const MAT_SIZE := Vector2(112.0, 22.0)
const BUBBLE_SIZE := Vector2(640.0, 190.0)
const BUBBLE_OFFSET := Vector2(-760.0, -350.0)
const BUBBLE_Z := 20
const TITLE := "next door"
## The neighbours' window, measured from the foot of their door.
const WINDOW := Rect2(155.0, -79.0, 74.0, 92.0)
const WINDOW_GROW := 20.0
const WINDOW_GLOW_ALPHA := 0.3

var _active := false
var _bubble: Panel
var _speech: Label
var _window: Node2D
var _bubble_tween: Tween


func _ready() -> void:
	# Below the walker and the houses, so the mat lies on the ground.
	z_index = -1
	_build_bubble()
	_build_window()


func _process(_delta: float) -> void:
	if _active:
		queue_redraw()


## World position of the doormat; the player stands here to knock.
func mat_position() -> Vector2:
	return global_position + MAT_OFFSET


## Marks this door as the one to visit; its doormat pulses gently.
func set_active(active: bool) -> void:
	_active = active
	queue_redraw()


## The door states a worry in its bubble.
func say(text: String) -> void:
	_speech.text = text
	_open_bubble(false)


## The door answers an argument; the same bubble, gently warmed.
func reply(text: String) -> void:
	_speech.text = text
	_open_bubble(true)


func hide_speech() -> void:
	_fade_bubble(0.0, false)


## A right answer lights the window; no fanfare, no penalty elsewhere.
func light_up() -> void:
	_window.show()


func _build_window() -> void:
	_window = Node2D.new()
	_window.z_index = BUBBLE_Z
	_window.hide()
	add_child(_window)
	var glow := Polygon2D.new()
	glow.polygon = SalonZone.wobbly_rect(WINDOW.grow(WINDOW_GROW), 34.0)
	glow.color = Color(LAMP, WINDOW_GLOW_ALPHA)
	_window.add_child(glow)
	var pane := Polygon2D.new()
	pane.polygon = SalonZone.wobbly_rect(WINDOW, 26.0)
	pane.color = LAMP
	_window.add_child(pane)


func _build_bubble() -> void:
	_bubble = Panel.new()
	_bubble.size = BUBBLE_SIZE
	_bubble.position = BUBBLE_OFFSET
	_bubble.z_index = BUBBLE_Z
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.visible = false
	_bubble.modulate.a = 0.0
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = TINT
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	_bubble.add_theme_stylebox_override("panel", style)
	add_child(_bubble)
	var name_label := Label.new()
	name_label.text = TITLE
	name_label.position = Vector2(18.0, 10.0)
	name_label.size = Vector2(BUBBLE_SIZE.x - 36.0, 30.0)
	name_label.add_theme_font_size_override("font_size", Settings.sized(22))
	name_label.add_theme_color_override("font_color", TINT.darkened(0.25))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(name_label)
	_speech = Label.new()
	_speech.position = Vector2(18.0, 44.0)
	_speech.size = Vector2(BUBBLE_SIZE.x - 36.0, BUBBLE_SIZE.y - 58.0)
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.add_theme_font_size_override("font_size", Settings.sized(34))
	_speech.add_theme_color_override("font_color", INK)
	_speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(_speech)


func _open_bubble(warm: bool) -> void:
	_bubble.self_modulate = Color(1.0, 0.96, 0.88) if warm else Color.WHITE
	_bubble.visible = true
	_fade_bubble(1.0, true)


func _fade_bubble(alpha: float, open: bool) -> void:
	if _bubble_tween != null and _bubble_tween.is_valid():
		_bubble_tween.kill()
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(_bubble, "modulate:a", alpha, 0.25 if open else 0.2)
	if not open:
		_bubble_tween.tween_callback(_bubble.hide)


func _draw() -> void:
	var mat := Rect2(MAT_OFFSET - MAT_SIZE * 0.5, MAT_SIZE)
	draw_rect(mat, MAT)
	draw_rect(mat, INK, false, 3.0)
	if _active:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		draw_rect(mat.grow(5.0 + 5.0 * pulse), Color(TINT.r, TINT.g, TINT.b, 0.25 + 0.3 * pulse), false, 4.0)
