extends CPUParticles2D
## One pooled dust puff. The task alternates two of these so bursts can overlap.

@export var dust_texture: Texture2D

static var _texture_cache: ImageTexture
static var _ramp_cache: Gradient
static var _curve_cache: Curve


func _ready() -> void:
	one_shot = true
	explosiveness = 1.0
	emitting = false
	amount = 14
	lifetime = 0.5
	gravity = Vector2(0.0, 700.0)
	direction = Vector2(0.0, -1.0)
	spread = 55.0
	initial_velocity_min = 60.0
	initial_velocity_max = 140.0
	scale_amount_min = 0.7
	scale_amount_max = 1.5
	color = Color(0.78, 0.73, 0.66, 0.9)
	texture = _soft_texture() if dust_texture == null else dust_texture
	emission_shape = EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(100.0, 5.0)
	color_ramp = _fade_ramp()
	scale_amount_curve = _shrink_curve()


## Fire one burst. Strength 0 to 1 sizes it; aligned landings are biggest.
func burst(at: Vector2, strength: float) -> void:
	position = at
	amount = 6 + int(round(8.0 * strength))
	restart()
	emitting = true


static func _soft_texture() -> ImageTexture:
	if _texture_cache != null:
		return _texture_cache
	var img := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	for y: int in 24:
		for x: int in 24:
			var d := Vector2(x - 11.5, y - 11.5).length() / 12.0
			if d <= 1.0:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, pow(1.0 - d, 1.5) * 0.85))
	_texture_cache = ImageTexture.create_from_image(img)
	return _texture_cache


static func _fade_ramp() -> Gradient:
	if _ramp_cache != null:
		return _ramp_cache
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	_ramp_cache = grad
	return grad


static func _shrink_curve() -> Curve:
	if _curve_cache != null:
		return _curve_cache
	var curve := Curve.new()
	curve.clear_points()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.25))
	_curve_cache = curve
	return curve
