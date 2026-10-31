extends Sprite2D
## One heavy concrete block. Code-drawn placeholder until art drops in.

const TEXTURE_W := 220
const TEXTURE_H := 96

@export var block_texture: Texture2D

static var _placeholder_cache: ImageTexture

var _base_scale := Vector2.ONE
var _release_mode := 0  # 0 hold still, 1 tilt in place, 2 slide to a rest point
var _tilt := 0.0
var _rest := Vector2.ZERO
var _tween: Tween = null


func _ready() -> void:
	if block_texture == null:
		block_texture = _placeholder_texture()
	texture = block_texture


## Repeats need more blocks under the same crane, so the blocks get shorter.
func setup_height(height: float) -> void:
	_base_scale = Vector2(1.0, height / float(TEXTURE_H))
	scale = _base_scale


## Small pop when the crane picks the block up at the rail end.
func appear() -> void:
	_kill_tween()
	scale = _base_scale * 0.85
	_tween = create_tween()
	_tween.tween_property(self, "scale", _base_scale, 0.15)


## The impact frame: squashed, held still while the freeze lasts.
func impact() -> void:
	_kill_tween()
	scale = _base_scale * Vector2(1.06, 0.88)


## A crooked block settles tilted on the stack.
func prepare(tilt: float) -> void:
	_release_mode = 1
	_tilt = tilt


## A missed block slides out of the wall's way and settles on the sand.
func prepare_slide(rest: Vector2, lean: float) -> void:
	_release_mode = 2
	_rest = rest
	_tilt = lean


## Called once the freeze ends: recover, then settle into the planned pose.
func release() -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "scale", _base_scale, 0.16)
	if _release_mode == 1:
		if _tilt != 0.0:
			_tween.tween_property(self, "rotation", _tilt, 0.22)
	elif _release_mode == 2:
		_tween.set_parallel(true)
		_tween.tween_property(self, "position", _rest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "rotation", _tilt, 0.35)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


static func _placeholder_texture() -> ImageTexture:
	if _placeholder_cache != null:
		return _placeholder_cache
	var img := Image.create_empty(TEXTURE_W, TEXTURE_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.72, 0.70, 0.66))
	img.fill_rect(Rect2i(0, 0, TEXTURE_W, 9), Color(0.87, 0.85, 0.80))
	img.fill_rect(Rect2i(0, TEXTURE_H - 11, TEXTURE_W, 11), Color(0.52, 0.50, 0.46))
	var crack := Color(0.35, 0.33, 0.30)
	for i: int in 18:
		img.set_pixel(54 + i, 14 + int(i * 0.5), crack)
	for i: int in 14:
		img.set_pixel(148 + i, 30 + int(i * 0.6), crack)
	img.fill_rect(Rect2i(0, TEXTURE_H - 5, 5, 5), Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(TEXTURE_W - 5, 0, 5, 5), Color(0, 0, 0, 0))
	_placeholder_cache = ImageTexture.create_from_image(img)
	return _placeholder_cache
