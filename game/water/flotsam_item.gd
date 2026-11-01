class_name FlotsamItem
extends Sprite2D
## One keep of the home that floats when the flood reaches it. It drifts, bobs
## on the water's own waves, and settles back out of sight as the water leaves.

const WATER_SHADER := preload("res://water/actor.gdshader")
## The scale the placeholder art was drawn for.
const BASE_PX_PER_M := 200.0
## How quickly the hull follows the water up and down.
const LIFT_EASE := 2.0
## How fast the keep fades in and out.
const FADE_SPEED := 0.9
## The keep's own slow bob and rock, on top of the water's waves.
const BOB_M := 0.018
const BOB_SPEED := 0.9
const ROCK_RAD := 0.03
const ROCK_SPEED := 0.7
## The walker nudges drifting keepsakes aside, so they never sit on Arda.
const CLEAR_PX := 80.0
## Seconds between the rings a drifting keep stirs into the water.
const RING_GAP := 4.0
## The walker only nudges a keep when their feet share the water.
const CLEAR_Y := 130.0

const PAPER := Color("F4EDDC")
const INK := Color("4E3B2E")
const SEA := Color("5B93A0")
const SUN := Color("F2C94C")
## The salon sofa, so the cushion reads as one of its own.
const SOFA := Color("8F4E62")

# The keep's art rides in Sprite2D's own texture; the placeholder fills it in
# while Ebru's is missing.
@export var shape: String = "boat"
## The floor spot this keep belongs to, in room pixels.
@export var rest: Vector2 = Vector2.ZERO
## How deep the hull rides under the surface, in metres.
@export var draft_m: float = 0.03
## How far it may drift from its rest spot, in pixels.
@export var wander_px: float = 140.0
## How fast it drifts, in pixels per second.
@export var drift_px: float = 8.0
## The keep leaves a ring on the water now and then while it drifts.
@export var leaves_rings := false

var room: Room

var _anchor := Vector2.ZERO
var _surface_m := 0.0
var _lift := 0.0
var _phase := 0.0
var _next_ring := 0.0
var _wave_m := 0.0
var _material: ShaderMaterial


func _ready() -> void:
	# The water keeps moving while the world is paused under a held scrub,
	# so the keeps must keep following it instead of hanging in the air.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if texture == null:
		texture = placeholder(shape)
	_material = ShaderMaterial.new()
	_material.shader = WATER_SHADER
	material = _material
	offset = -texture.get_size() * 0.5
	scale = Vector2.ONE * room.px_per_m / BASE_PX_PER_M
	_anchor = rest
	modulate.a = 0.0
	_phase = float(get_instance_id() % 360) * TAU / 360.0
	_next_ring = 1.0 + fmod(_phase, 2.0)
	position = _bottom_position(0.0)


func is_floating() -> bool:
	return _lift > 0.4


func _process(delta: float) -> void:
	var paused := get_tree().paused
	var lively := not Settings.calm_storm and not paused
	# The drawn line, not the true one: an eased arrival moves the picture first.
	var depth := room.depth_at(_anchor) + room.drawn_flood_m() - room.flood_m
	_surface_m = lerpf(_surface_m, depth, 1.0 - exp(-LIFT_EASE * delta))
	var floating := depth > draft_m
	_lift = move_toward(_lift, 1.0 if floating else 0.0, FADE_SPEED * delta)
	_wave_m = _wave_height_m()
	if floating and lively:
		_drift(delta)
	var above := maxf(_surface_m + _wave_m - draft_m, 0.0)
	if lively:
		above += sin(_age() * BOB_SPEED + _phase) * BOB_M * _lift
	position = _bottom_position(above)
	rotation = sin(_age() * ROCK_SPEED + _phase) * ROCK_RAD * _lift if lively else 0.0
	modulate.a = _lift
	var drawn_m := texture.get_size().y * scale.y / room.px_per_m
	_material.set_shader_parameter("waterline", clampf(1.0 - (draft_m + _wave_m) / drawn_m, 0.0, 1.0))
	_material.set_shader_parameter("breath_phase", _phase)
	if leaves_rings and floating and _lift > 0.5 and lively:
		_next_ring -= delta
		if _next_ring <= 0.0:
			_next_ring = RING_GAP
			room.add_ripple(position + Vector2(0.0, texture.get_size().y * scale.y * 0.5))


func _age() -> float:
	return Time.get_ticks_msec() * 0.001


## Where the keep sits for a given height of hull above the floor.
func _bottom_position(above_m: float) -> Vector2:
	return Vector2(_anchor.x, _anchor.y - above_m * room.px_per_m - texture.get_size().y * scale.y * 0.5)


## Slow wander around the rest spot, plus a gentle nudge away from the walker.
func _drift(delta: float) -> void:
	var t := _age()
	var vx := (sin(t * 0.07 + _phase) + 0.6 * sin(t * 0.11 + _phase * 2.0)) * drift_px
	_anchor.x += vx * delta
	var walker := get_tree().get_first_node_in_group("walker") as Node2D
	if walker != null:
		# The walker's body reaches from their feet up past the waterline, so
		# only a keep inside that drawn span needs nudging clear of them.
		var top: float = walker.global_position.y - 1.4 * room.px_per_m * room.character_size()
		if global_position.y > top - CLEAR_Y and global_position.y < walker.global_position.y + CLEAR_Y:
			var gap := global_position.x - walker.global_position.x
			if absf(gap) < CLEAR_PX:
				var side := signf(gap)
				_anchor.x += (side if side != 0.0 else 1.0) * drift_px * 3.0 * delta
	_anchor.x = clampf(_anchor.x, rest.x - wander_px, rest.x + wander_px)


## The same wave the flood shader draws, so the keep rides the water it sees.
## The numbers are flood.gdshader's waves(): if one changes, both must.
func _wave_height_m() -> float:
	var p := _anchor / Room.ROOM_SIZE
	var t := _age()
	var wave := sin(p.x * 46.0 + t * 1.7) * 0.5 + sin(p.x * 97.0 - t * 2.3 + p.y * 30.0) * 0.3 + sin(p.y * 70.0 + t * 1.1) * 0.2
	var active := clampf(room.drawn_flood_m() / 0.03, 0.0, 1.0)
	return wave * 0.012 * active * (1.0 + 8.0 * room.surge_level())


## A simple stand-in drawn in code, so the game works before the art exists.
## Built once per shape: painting pixels per room entry would hitch a door.
static var _art := {}


static func placeholder(shape: String) -> ImageTexture:
	if not _art.has(shape):
		_art[shape] = _draw_shape(shape)
	return _art[shape]


static func _draw_shape(shape: String) -> ImageTexture:
	var sizes := { "boat": Vector2i(96, 64), "cushion": Vector2i(110, 70), "photo": Vector2i(90, 110) }
	var size: Vector2i = sizes.get(shape, Vector2i(64, 64))
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	if shape == "cushion":
		_cushion(image)
	elif shape == "photo":
		_photo(image)
	else:
		_boat(image)
	return ImageTexture.create_from_image(image)


static func _boat(image: Image) -> void:
	_outlined_tri(image, Vector2(16, 36), Vector2(80, 36), Vector2(88, 58), PAPER)
	_outlined_tri(image, Vector2(16, 36), Vector2(88, 58), Vector2(8, 58), PAPER)
	_outlined_tri(image, Vector2(20, 36), Vector2(48, 8), Vector2(76, 36), PAPER)
	# A fold of sea where the paper dips into the water.
	_tri(image, Vector2(10, 58), Vector2(86, 58), Vector2(86, 53), SEA)
	_tri(image, Vector2(10, 58), Vector2(86, 53), Vector2(10, 53), SEA)


static func _cushion(image: Image) -> void:
	var size := image.get_size()
	var half := Vector2(size) * 0.5
	for y: int in size.y:
		for x: int in size.x:
			var p := Vector2(x + 0.5, y + 0.5) - half
			var q := p.abs() - (half - Vector2(18.0, 18.0))
			var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - 18.0
			if d < -3.0:
				image.set_pixel(x, y, SOFA)
			elif d < 0.0:
				image.set_pixel(x, y, INK)
	for y: int in range(int(half.y) - 3, int(half.y) + 4):
		for x: int in range(int(half.x) - 3, int(half.x) + 4):
			if Vector2(x - half.x + 0.5, y - half.y + 0.5).length() < 3.0:
				image.set_pixel(x, y, INK)


static func _photo(image: Image) -> void:
	var size := image.get_size()
	for y: int in size.y:
		for x: int in size.x:
			var framed := x >= 9 and x < size.x - 9 and y >= 9 and y < size.y - 9
			image.set_pixel(x, y, PAPER if framed else INK)
	# The picture inside: a day at the sea, with a small sun.
	for y: int in range(70, size.y - 9):
		for x: int in range(9, size.x - 9):
			image.set_pixel(x, y, SEA)
	for y: int in range(24, 34):
		for x: int in range(54, 64):
			if Vector2(x - 58.5, y - 28.5).length() < 5.0:
				image.set_pixel(x, y, SUN)


static func _tri(image: Image, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var min_x := maxi(0, int(floor(minf(a.x, minf(b.x, c.x)))))
	var max_x := mini(image.get_width() - 1, int(ceil(maxf(a.x, maxf(b.x, c.x)))))
	var min_y := maxi(0, int(floor(minf(a.y, minf(b.y, c.y)))))
	var max_y := mini(image.get_height() - 1, int(ceil(maxf(a.y, maxf(b.y, c.y)))))
	var ab := b - a
	var bc := c - b
	var ca := a - c
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var s1 := ab.cross(p - a) >= 0.0
			var s2 := bc.cross(p - b) >= 0.0
			var s3 := ca.cross(p - c) >= 0.0
			if s1 == s2 and s2 == s3:
				image.set_pixel(x, y, color)


## A flat shape with a hand-inked edge: the outline is the same triangle, grown.
static func _outlined_tri(image: Image, a: Vector2, b: Vector2, c: Vector2, fill: Color) -> void:
	var mid := (a + b + c) / 3.0
	var grow := func(p: Vector2) -> Vector2: return mid + (p - mid) * 1.09
	_tri(image, grow.call(a), grow.call(b), grow.call(c), INK)
	_tri(image, a, b, c, fill)
