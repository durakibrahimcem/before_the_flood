class_name SeagrassShoot
extends Node2D
## One seagrass shoot. It roots in place, or washes away on the wave.

@export var texture: Texture2D

var _sprite: Sprite2D
var _tween: Tween


func _ready() -> void:
	z_index = 1
	_sprite = Sprite2D.new()
	_sprite.texture = texture if texture != null else SeagrassArt.shoot_texture()
	_sprite.position = Vector2(0.0, -_sprite.texture.get_height() * 0.5)
	add_child(_sprite)


func root() -> void:
	## Pop in, settle, then a gentle idle sway.
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_sprite.scale = Vector2(0.4, 0.5)
	_tween = create_tween().bind_node(self)
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_sprite, "scale", Vector2.ONE, 0.45)
	_tween.chain().tween_callback(_start_sway)


func wash_away() -> void:
	## Soft drift down the screen with a little sway, fade out, then free.
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().bind_node(self)
	_tween.set_parallel(true)
	_tween.tween_property(self, "position:y", position.y + 150.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "position:x", position.x + 20.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "rotation_degrees", 8.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(queue_free)


func _start_sway() -> void:
	_tween = create_tween().bind_node(self)
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.set_loops()
	_tween.tween_property(self, "rotation_degrees", -4.0, 1.6)
	_tween.tween_property(self, "rotation_degrees", 4.0, 1.6)
