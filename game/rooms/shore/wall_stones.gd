extends Node2D
## The seawall's stone skin, code-drawn over Ebru's slab so the villain reads as
## stacked stone: hand-drawn joints, damp that darkens at the foot as the years
## pass, and cracks once the wall starts to give. The node sits in the wall
## texture's pixel space, and never touches the art it draws over.

const INK := Color(0.30, 0.27, 0.24)
const DAMP := Color(0.13, 0.16, 0.19)
const WIDTH := 1920.0
const TOP_Y := 208.0
const FOOT_Y := 556.0
const COURSE_PX := 72.0
const DAMP_PX := 120.0
const CLIP_STEP := 16.0
## Fixed joint offsets, so the hand-drawn wobble never changes between runs.
const VERTICALS := [104.0, 302.0, 545.0, 706.0, 958.0, 1207.0, 1439.0, 1691.0]
## Each crack: where it starts along the wall, and how far up it runs.
const CRACKS := [Vector2(250.0, 250.0), Vector2(1180.0, 190.0), Vector2(1646.0, 140.0)]

var _damp := 0.0
var _cracked := false
var _shown_age := -1.0
var _shown_cracked := false
var _room: Room
var _water_level := -1.0

static var _images: Dictionary = {}


func _ready() -> void:
	var node := get_parent()
	while node != null and not node is Room:
		node = node.get_parent()
	_room = node as Room


func _process(_delta: float) -> void:
	if _room == null:
		return
	var level := _room.drawn_flood_m()
	if absf(level - _water_level) > 0.01:
		_water_level = level
		set_water(level)


func update_age(state: WorldState) -> void:
	var aged := clampf(
		(state.year - Room.FIRST_YEAR) / (Room.LAST_YEAR - Room.FIRST_YEAR), 0.0, 1.0
	)
	_damp = smoothstep(0.05, 0.75, aged)
	_cracked = state.wall_state == WorldState.Wall.CRACKED \
		or state.wall_state == WorldState.Wall.BREACHED
	if absf(aged - _shown_age) >= 0.01 or _cracked != _shown_cracked:
		_shown_age = aged
		_shown_cracked = _cracked
		queue_redraw()


## For the demo: how damp the foot is, 0 to 1.
func damp_level() -> float:
	return _damp


## For the demo: 1 once the wall's crack years have arrived.
func crack_level() -> float:
	return 1.0 if _cracked else 0.0


## The water climbs past the foot in the flooded years, so the skin steps back
## and lets the shader's water tint take over down there.
func set_water(level_m: float) -> void:
	modulate.a = clampf(1.0 - (level_m - 1.4) / 0.80, 0.45, 1.0)


func _draw() -> void:
	var image := _image_of((get_parent() as Sprite2D).texture)
	if image == null:
		return
	_draw_joints(image)
	_draw_damp(image)
	if _cracked:
		_draw_cracks(image)


func _draw_joints(image: Image) -> void:
	var course := 0
	var y := FOOT_Y - COURSE_PX
	while y > TOP_Y:
		for x: float in range(8.0, WIDTH - 8.0, CLIP_STEP):
			if not _solid(image, x + CLIP_STEP * 0.5, y):
				continue
			var a := Vector2(x, y + sin(x * 0.021 + course) * 1.6)
			var b := Vector2(x + CLIP_STEP, y + sin((x + CLIP_STEP) * 0.021 + course) * 1.6)
			draw_line(a, b, Color(INK.r, INK.g, INK.b, 0.30), 2.5)
		var verticals := VERTICALS.filter(func(v: float) -> bool: return int(v / 100.0 + course) % 2 == 0)
		for x: float in verticals:
			_stone_edge(image, x, y + 4.0, y + COURSE_PX - 4.0, course)
		course += 1
		y -= COURSE_PX


## One vertical joint between two courses, in short clipped strokes.
func _stone_edge(image: Image, x: float, from_y: float, to_y: float, course: int) -> void:
	var step := 12.0
	var y := from_y
	while y < to_y:
		var next_y := minf(y + step, to_y)
		if _solid(image, x, (y + next_y) * 0.5):
			var sway := sin(y * 0.05 + course) * 2.0
			var sway_next := sin(next_y * 0.05 + course) * 2.0
			draw_line(
				Vector2(x + sway, y),
				Vector2(x + sway_next, next_y),
				Color(INK.r, INK.g, INK.b, 0.30),
				2.5
			)
		y = next_y


func _draw_damp(image: Image) -> void:
	if _damp <= 0.01:
		return
	var y := FOOT_Y - 6.0
	while y > FOOT_Y - DAMP_PX:
		var fall := (FOOT_Y - y) / DAMP_PX
		var alpha := _damp * pow(1.0 - fall, 1.7) * 0.42
		var color := Color(DAMP.r, DAMP.g, DAMP.b, alpha)
		for x: float in range(0.0, WIDTH, CLIP_STEP):
			if _solid(image, x + CLIP_STEP * 0.5, y):
				draw_rect(Rect2(x, y, CLIP_STEP, 6.0), color)
		y -= 6.0


func _draw_cracks(image: Image) -> void:
	for crack: Vector2 in CRACKS:
		var points := PackedVector2Array()
		var steps := int(crack.y / 18.0)
		for i: int in steps + 1:
			var t := i / float(steps)
			var at := Vector2(
				crack.x + sin(i * 2.3 + crack.x) * 7.0 + t * 9.0,
				FOOT_Y - 4.0 - crack.y * t
			)
			if _solid(image, at.x, at.y):
				points.append(at)
			elif points.size() > 1:
				_polyline(points, 0.55)
				points = PackedVector2Array()
		if points.size() > 1:
			_polyline(points, 0.55)
		# A small branch partway up, like a crack finding its way.
		var branch := Vector2(crack.x + 14.0, FOOT_Y - 4.0 - crack.y * 0.42)
		if _solid(image, branch.x, branch.y):
			var tip := branch + Vector2(26.0, -30.0)
			draw_line(branch, tip, Color(INK.r, INK.g, INK.b, 0.45), 2.0)


func _polyline(points: PackedVector2Array, alpha: float) -> void:
	for i: int in points.size() - 1:
		draw_line(points[i], points[i + 1], Color(INK.r, INK.g, INK.b, alpha), 2.4)


func _solid(image: Image, x: float, y: float) -> bool:
	var at := Vector2i(clampi(int(x), 0, image.get_width() - 1), clampi(int(y), 0, image.get_height() - 1))
	return image.get_pixelv(at).a > 0.5


## One decompressed copy per wall texture, so the skin can clip to its picture.
static func _image_of(texture: Texture2D) -> Image:
	if texture == null:
		return null
	var key := texture.get_instance_id()
	if _images.has(key):
		return _images[key]
	var image := texture.get_image()
	if image == null:
		return null
	image.decompress()
	_images[key] = image
	return image
