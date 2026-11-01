extends Node2D
## Calm foam where the drawn water meets the seawall's face, so the sea is seen
## touching the villain. Drawn in code, not particles, to keep the
## single-threaded web build light. Settings.calm_storm stills and quietens it.
## The node sits in the wall texture's pixel space.

const FOAM := Color(0.95, 0.98, 0.97)
## The wall's own height map, the same image ShoreWall hands the flood shader.
## Preloaded directly, so this script never loads ShoreWall while ShoreWall
## loads this one.
const HEIGHT := preload("res://rooms/shore/wall_height.png")
const WIDTH := 1920.0
const COLUMN_STEP := 16.0
## The wall's height map, sampled between these y values, runs 2.4 m down to 0 m.
const FACE_TOP_Y := 380.0
const FACE_BOTTOM_Y := 700.0
const SAMPLE_STEP := 4.0
## The face's own heights at its foot and top, from wall_height.png.
const FACE_FOOT_M := 1.0
const FACE_TOP_M := 2.35
const SWAY_PX := 2.2
const SWAY_SPEED := 0.7

var _columns: Array[PackedFloat32Array] = []
var _room: Room
var _level := 0.0
var _strength := 0.0
var _time := 0.0
var _line_cache: PackedFloat32Array = []
var _cached_level := -1.0

static var _images: Dictionary = {}


func _ready() -> void:
	var node := get_parent()
	while node != null and not node is Room:
		node = node.get_parent()
	_room = node as Room
	_build_columns()


func _process(delta: float) -> void:
	if _room == null:
		return
	_level = _room.drawn_flood_m()
	if not Settings.calm_storm:
		_time += delta
	var rise := clampf((_level - FACE_FOOT_M) / 0.15, 0.0, 1.0)
	var sink := 1.0 - clampf((_level - FACE_TOP_M) / 0.25, 0.0, 1.0)
	_strength = rise * sink if (get_parent() as Sprite2D).visible else 0.0
	visible = _strength > 0.01
	if not visible:
		return
	if absf(_level - _cached_level) > 0.004:
		_cached_level = _level
		_rebuild_line()
	queue_redraw()


## For the demo: how strongly the foam shows, 0 to 1.
func strength() -> float:
	return _strength


## For the demo: where the foam sits at the middle of the wall, in texture pixels.
func waterline_y() -> float:
	if _line_cache.is_empty():
		return -1.0
	return _line_cache[_line_cache.size() / 2]


func _draw() -> void:
	var image := _image_of((get_parent() as Sprite2D).texture)
	if image == null or _line_cache.is_empty():
		return
	var calm := Settings.calm_storm
	var quiet := 0.65 if calm else 1.0
	var points: Array[Vector2] = []
	var solid: Array[bool] = []
	for i: int in _line_cache.size():
		var x := i * COLUMN_STEP
		var y := _line_cache[i] + _sway(x)
		points.append(Vector2(x, y))
		solid.append(_solid(image, x, y))
	for i: int in points.size() - 1:
		if not solid[i] or not solid[i + 1]:
			continue
		_pass(points[i], points[i + 1], _strength * quiet * 0.16, 14.0, 5.0)
		_pass(points[i], points[i + 1], _strength * quiet * 0.34, 8.0, 0.0)
		_pass(points[i], points[i + 1], _strength * quiet * 0.55, 3.0, -1.0)
	# A few soft clumps, like foam resting against stone.
	for i: int in 16:
		var x := 60.0 + i * 120.0 + sin(i * 2.7) * 18.0
		if not _solid(image, x, _at(x)):
			continue
		var at := Vector2(x, _at(x) + _sway(x) + 1.0)
		draw_circle(at, 3.5 + sin(i * 1.9) * 1.2, Color(FOAM.r, FOAM.g, FOAM.b, _strength * quiet * 0.4))


func _pass(from: Vector2, to: Vector2, alpha: float, width: float, drop: float) -> void:
	draw_line(from + Vector2(0.0, drop), to + Vector2(0.0, drop), Color(FOAM.r, FOAM.g, FOAM.b, alpha), width)


func _sway(x: float) -> float:
	return sin(_time * SWAY_SPEED + x * 0.005) * SWAY_PX if not Settings.calm_storm else 0.0


func _at(x: float) -> float:
	var index := clampi(int(round(x / COLUMN_STEP)), 0, _line_cache.size() - 1)
	return _line_cache[index]


## Where the drawn water surface crosses the wall face, per column. The heights
## run bottom-up: index 0 is the buried toe, the last index the face's top.
func _rebuild_line() -> void:
	if _line_cache.is_empty():
		_line_cache.resize(_columns.size())
	for i: int in _columns.size():
		var heights := _columns[i]
		if _level <= 0.0 or heights[0] >= _level:
			_line_cache[i] = FACE_BOTTOM_Y
			continue
		if heights[heights.size() - 1] < _level:
			_line_cache[i] = FACE_TOP_Y - 10.0
			continue
		var found := -1
		for j: int in heights.size():
			if heights[j] >= _level:
				found = j
				break
		if found <= 0:
			_line_cache[i] = FACE_BOTTOM_Y
			continue
		var below := heights[found - 1]
		var above := heights[found]
		var share := 0.0 if is_equal_approx(above, below) else (_level - below) / (above - below)
		var y := FACE_BOTTOM_Y - (found - 1 + share) * SAMPLE_STEP
		_line_cache[i] = clampf(y, FACE_TOP_Y - 10.0, FACE_BOTTOM_Y)


## The wall face's height at every column, straight out of wall_height.png, the
## same map the flood shader reads, so the foam sits on the water it draws.
func _build_columns() -> void:
	var image := HEIGHT.get_image()
	if image == null:
		return
	image.decompress()
	for x: int in range(0, int(WIDTH), int(COLUMN_STEP)):
		var heights := PackedFloat32Array()
		heights.resize(int((FACE_BOTTOM_Y - FACE_TOP_Y) / SAMPLE_STEP) + 1)
		var i := 0
		var y := FACE_BOTTOM_Y
		while y >= FACE_TOP_Y:
			heights[i] = _height_at(image, float(x), y)
			i += 1
			y -= SAMPLE_STEP
		_columns.append(heights)


## The flood shader's height_at(), for the wall's own height map. If that
## formula changes, both must.
func _height_at(image: Image, x: float, y: float) -> float:
	var uv := Vector2(x, y) / Room.ROOM_SIZE
	var pixel := image.get_pixelv(Vector2i(int(x), int(y)))
	if pixel.r > 0.99:
		return Room.OBJECT_FULL_M * 40.0
	if pixel.g > 0.5:
		return maxf(_room.floor_line - uv.y, 0.0) * _room.wall_m_per_uv
	var tilt := uv.x * 0.7 + (uv.y - _room.floor_line) * 0.3 + 0.25 * sin(uv.x * 9.0 + uv.y * 7.0)
	return pixel.r * Room.OBJECT_FULL_M + tilt * Room.CREEP_M


func _solid(image: Image, x: float, y: float) -> bool:
	var at := Vector2i(clampi(int(x), 0, image.get_width() - 1), clampi(int(y), 0, image.get_height() - 1))
	return image.get_pixelv(at).a > 0.5


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
