extends Node2D
## One quiet hint: a short label and a wobbly crayon arrow. It stays as a reminder.

const CRAYON := Color(0.55, 0.42, 0.28)

@export var hint_texture: Texture2D

var _tween: Tween = null


func _ready() -> void:
	visible = false


func show_hint() -> void:
	visible = true
	modulate.a = 1.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(3.5)
	_tween.tween_property(self, "modulate:a", Task.REMINDER_ALPHA, 0.5)


func _draw() -> void:
	if hint_texture != null:
		draw_texture(hint_texture, Vector2(-hint_texture.get_width() * 0.5, -hint_texture.get_height() - 20.0))
		return
	var y := 0.0
	while y > -62.0:
		var next_y := maxf(y - 14.0, -62.0)
		draw_line(Vector2(sin(y * 0.45) * 3.0, y), Vector2(sin(next_y * 0.45) * 3.0, next_y), CRAYON, 4.0)
		y = next_y
	draw_line(Vector2(-12.0, -46.0), Vector2(0.0, -62.0), CRAYON, 4.0)
	draw_line(Vector2(12.0, -46.0), Vector2(0.0, -62.0), CRAYON, 4.0)
