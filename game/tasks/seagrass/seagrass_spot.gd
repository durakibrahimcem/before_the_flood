class_name SeagrassSpot
extends Node2D
## One marked planting spot in the shallows.

enum State {EMPTY, HOLDING, ROOTED}

@export var marker: Texture2D

var state: State = State.EMPTY
var highlight_nearest := false
var covered := false
var shoot: SeagrassShoot = null

var _time := 0.0
var _marker: Texture2D


func _ready() -> void:
	z_index = 0
	_marker = marker if marker != null else SeagrassArt.spot_texture()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.03
	var speed := 1.8
	if state == State.HOLDING:
		pulse = 0.05
		speed = 2.4
	elif state == State.ROOTED:
		pulse = 0.012
		speed = 1.1
	elif highlight_nearest:
		pulse = 0.07
		speed = 3.0
	var pulse_scale := 1.0 + sin(_time * speed) * pulse
	var sway := sin(_time * 1.1) * 0.03 if state == State.ROOTED else 0.0
	draw_set_transform(Vector2.ZERO, sway, Vector2(pulse_scale, pulse_scale))
	var tint := Color(1.0, 1.0, 1.0, 0.95)
	if state == State.ROOTED:
		tint = Color(1.0, 1.0, 1.0, 0.7)
	draw_texture(_marker, _marker.get_size() * -0.5, tint)
