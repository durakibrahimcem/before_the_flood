class_name MeetingDoor
extends Node2D
## One house front on the street: placeholder art drawn in code, a doormat to
## knock at, a speech bubble and a window lamp. Ebru's art drops in via `art`.

const INK := Color("3b342e")
const PAPER := Color("f7efe2")
const WALL := Color("efe3d0")
const MAT := Color("c9b291")
const LAMP := Color("ffdf9e")
const WINDOW := Color("d8cdb8")
const MAT_OFFSET := Vector2(0.0, 180.0)
const BUBBLE_SIZE := Vector2(640.0, 190.0)

@export var art: Texture2D = null
@export var tint: Color = Color("7fa06a")
@export var door_color: Color = Color("4f7d4f")
@export var title: String = "the green door"

var _active := false
var _lit := false
var _bubble: Panel
var _speech: Label
var _bubble_tween: Tween


func _ready() -> void:
	_build_bubble()


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
	_lit = true
	queue_redraw()


func _build_bubble() -> void:
	_bubble = Panel.new()
	_bubble.size = BUBBLE_SIZE
	_bubble.position = Vector2(-BUBBLE_SIZE.x / 2.0, -585.0)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.visible = false
	_bubble.modulate.a = 0.0
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = tint
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	_bubble.add_theme_stylebox_override("panel", style)
	add_child(_bubble)
	var name_label := Label.new()
	name_label.text = title
	name_label.position = Vector2(18.0, 10.0)
	name_label.size = Vector2(BUBBLE_SIZE.x - 36.0, 30.0)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", tint.darkened(0.25))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(name_label)
	_speech = Label.new()
	_speech.position = Vector2(18.0, 44.0)
	_speech.size = Vector2(BUBBLE_SIZE.x - 36.0, BUBBLE_SIZE.y - 58.0)
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.add_theme_font_size_override("font_size", 34)
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
	if art != null:
		draw_texture(art, Vector2(-art.get_width() / 2.0, -art.get_height()))
		if _lit:
			draw_circle(Vector2(0.0, -art.get_height() / 2.0), 90.0, Color(LAMP, 0.18))
	else:
		_draw_house()
	_draw_mat()


func _draw_house() -> void:
	var wall := Rect2(Vector2(-150.0, -260.0), Vector2(300.0, 260.0))
	draw_rect(wall, WALL)
	draw_rect(wall, INK, false, 4.0)
	var roof := PackedVector2Array([Vector2(-185.0, -260.0), Vector2(185.0, -260.0), Vector2(0.0, -380.0)])
	draw_colored_polygon(roof, tint)
	draw_polyline(PackedVector2Array([roof[0], roof[1], roof[2], roof[0]]), INK, 4.0)
	var door := Rect2(Vector2(-45.0, -170.0), Vector2(90.0, 170.0))
	draw_rect(door, door_color)
	draw_rect(door, INK, false, 3.0)
	draw_circle(Vector2(26.0, -84.0), 5.0, INK)
	var window := Rect2(Vector2(78.0, -225.0), Vector2(64.0, 64.0))
	if _lit:
		draw_circle(window.get_center(), 52.0, Color(LAMP, 0.30))
		draw_rect(window, LAMP)
	else:
		draw_rect(window, WINDOW)
	draw_rect(window, INK, false, 3.0)
	draw_line(Vector2(window.position.x, window.get_center().y), Vector2(window.end.x, window.get_center().y), INK, 2.0)
	draw_line(Vector2(window.get_center().x, window.position.y), Vector2(window.get_center().x, window.end.y), INK, 2.0)


func _draw_mat() -> void:
	var mat := Rect2(MAT_OFFSET + Vector2(-70.0, -14.0), Vector2(140.0, 28.0))
	draw_rect(mat, MAT)
	draw_rect(mat, INK, false, 3.0)
	if _active:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		draw_rect(mat.grow(5.0 + 5.0 * pulse), Color(tint.r, tint.g, tint.b, 0.25 + 0.3 * pulse), false, 4.0)
