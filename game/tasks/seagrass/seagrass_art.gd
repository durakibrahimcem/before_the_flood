class_name SeagrassArt
## Placeholder art for the seagrass task, drawn entirely in code.
## Every piece reaches the game through an exported Texture2D, so painted art drops in unchanged.

const BLADE_DEEP := Color(0.34, 0.60, 0.40)
const BLADE_SOFT := Color(0.50, 0.72, 0.46)
const SAND := Color(0.93, 0.82, 0.60)
const SKIN := Color(0.96, 0.79, 0.64)
const SHIRT := Color(0.83, 0.68, 0.40)
const TROUSERS := Color(0.47, 0.38, 0.33)
const HAIR := Color(0.38, 0.28, 0.20)
const CRAYON := Color(0.55, 0.40, 0.28)

static var _shoot: ImageTexture
static var _spot: ImageTexture
static var _walker: ImageTexture
static var _squiggle: ImageTexture


static func shoot_texture() -> ImageTexture:
	## A few soft green blades, feet at the bottom of the image.
	if _shoot != null:
		return _shoot
	var img := Image.create(48, 64, false, Image.FORMAT_RGBA8)
	_blade(img, Vector2(24.0, 60.0), Vector2(8.0, 14.0), 3.0, BLADE_DEEP)
	_blade(img, Vector2(24.0, 60.0), Vector2(16.0, 5.0), 2.7, BLADE_SOFT)
	_blade(img, Vector2(24.0, 60.0), Vector2(25.0, 2.0), 2.4, BLADE_DEEP)
	_blade(img, Vector2(24.0, 60.0), Vector2(33.0, 7.0), 2.6, BLADE_SOFT)
	_blade(img, Vector2(24.0, 60.0), Vector2(41.0, 16.0), 2.2, BLADE_DEEP)
	_shoot = ImageTexture.create_from_image(img)
	return _shoot


static func spot_texture() -> ImageTexture:
	## A soft sand-toned ring that marks a planting spot.
	if _spot != null:
		return _spot
	var img := Image.create(72, 72, false, Image.FORMAT_RGBA8)
	_ring(img, Vector2(36.0, 36.0), 24.0, 3.2, SAND)
	_ring(img, Vector2(36.0, 36.0), 14.0, 1.6, Color(SAND, 0.55))
	_spot = ImageTexture.create_from_image(img)
	return _spot


static func walker_texture() -> ImageTexture:
	## A simple standing figure in warm colours, feet near the bottom.
	if _walker != null:
		return _walker
	var img := Image.create(56, 88, false, Image.FORMAT_RGBA8)
	_ellipse(img, Vector2(28.0, 14.0), 11.0, 11.0, SKIN)
	_ellipse(img, Vector2(28.0, 9.0), 11.0, 6.0, HAIR)
	_ellipse(img, Vector2(28.0, 44.0), 14.0, 20.0, SHIRT)
	_ellipse(img, Vector2(19.0, 79.0), 4.0, 6.0, TROUSERS)
	_ellipse(img, Vector2(37.0, 79.0), 4.0, 6.0, TROUSERS)
	_walker = ImageTexture.create_from_image(img)
	return _walker


static func squiggle_texture() -> ImageTexture:
	## A crayon squiggle for the hint underline.
	if _squiggle != null:
		return _squiggle
	var img := Image.create(440, 30, false, Image.FORMAT_RGBA8)
	for i in range(441):
		var x := float(i)
		var y := 15.0 + sin(x * 0.05) * 6.0 + sin(x * 0.013) * 2.0
		_brush(img, x, y, 2.2 + sin(x * 0.23) * 0.7, CRAYON)
	_squiggle = ImageTexture.create_from_image(img)
	return _squiggle


static func _blade(img: Image, base: Vector2, tip: Vector2, width: float, color: Color) -> void:
	var mid := (base + tip) * 0.5
	var dir := (tip - base).normalized()
	var side := Vector2(-dir.y, dir.x) * 5.0
	for i in range(25):
		var t := float(i) / 24.0
		var pos := base.bezier_interpolate(mid + side, mid - side * 0.5, tip, t)
		_brush(img, pos.x, pos.y, lerpf(width, width * 0.3, t), color)


static func _ring(img: Image, center: Vector2, radius: float, thickness: float, color: Color) -> void:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var band := absf(Vector2(x, y).distance_to(center) - radius)
			if band > thickness:
				continue
			_blend(img, x, y, Color(color.r, color.g, color.b, color.a * (1.0 - band / thickness)))


static func _ellipse(img: Image, center: Vector2, rx: float, ry: float, color: Color) -> void:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var d := Vector2((x - center.x) / rx, (y - center.y) / ry).length()
			if d > 1.0:
				continue
			_blend(img, x, y, Color(color.r, color.g, color.b, color.a * clampf(1.15 - d * 1.15, 0.0, 1.0)))


static func _brush(img: Image, x: float, y: float, radius: float, color: Color) -> void:
	var r := ceili(radius)
	for py in range(int(y) - r, int(y) + r + 1):
		for px in range(int(x) - r, int(x) + r + 1):
			var edge := clampf(radius - Vector2(px, py).distance_to(Vector2(x, y)), 0.0, 1.0)
			if edge <= 0.0:
				continue
			_blend(img, px, py, Color(color.r, color.g, color.b, color.a * edge))


static func _blend(img: Image, x: int, y: int, color: Color) -> void:
	if color.a <= 0.0:
		return
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var dst := img.get_pixel(x, y)
	var a := color.a + dst.a * (1.0 - color.a)
	if a <= 0.0:
		img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
		return
	img.set_pixel(x, y, Color(
		(color.r * color.a + dst.r * dst.a * (1.0 - color.a)) / a,
		(color.g * color.a + dst.g * dst.a * (1.0 - color.a)) / a,
		(color.b * color.a + dst.b * dst.a * (1.0 - color.a)) / a,
		a
	))
