class_name SeagrassHint
extends Node2D
## One short crayon hint. It settles down after a few seconds, and stays as a reminder.

const WARM_BROWN := Color(0.48, 0.35, 0.24)
const FADE_OUT_AT := 5.1

@export var hint_texture: Texture2D


func _ready() -> void:
	z_index = 20
	rotation_degrees = -2.0
	modulate.a = 0.0
	if hint_texture != null:
		var art := Sprite2D.new()
		art.texture = hint_texture
		add_child(art)
	else:
		_add_label()
		var squiggle := Sprite2D.new()
		squiggle.texture = SeagrassArt.squiggle_texture()
		squiggle.position = Vector2(0.0, 16.0)
		add_child(squiggle)
	var tween := create_tween().bind_node(self)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.4)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_interval(FADE_OUT_AT)
	tween.tween_property(self, "modulate:a", Task.REMINDER_ALPHA, 0.6)


func _add_label() -> void:
	var label := Label.new()
	label.text = "Plant between the waves."
	label.add_theme_font_size_override("font_size", Settings.sized(44))
	label.add_theme_color_override("font_color", WARM_BROWN)
	label.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 0.95, 0.45))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 1)
	label.reset_size()
	label.position = label.get_size() * -0.5 + Vector2(0.0, -30.0)
	add_child(label)
