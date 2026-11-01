class_name Room
extends Node2D
## One painted location. Listens to the clock and sets its own water and ageing.

signal door_used(target_room: String, arrive_at: Vector2)

const SHADER := preload("res://water/flood.gdshader")
const OBJECT_FULL_M := 2.5
const CREEP_M := 0.05
const ROOM_SIZE := Vector2(1920.0, 1080.0)
## Brian is gone by the time the bowls sit empty.
const BOWLS_EMPTY_YEAR := 2040.0
## People and Brian are drawn larger than the painted scale, so they read at a glance.
const CHARACTER_SIZES := { "bedroom": 1.2, "aylin": 1.2, "salon": 1.2, "street": 1.8, "shore": 1.35 }
const FIRST_YEAR := 2026.0
const LAST_YEAR := 2080.0
const RIPPLE_SLOTS := 8
const RIPPLE_SECONDS := 1.3
const OUTDOOR_ROOMS := ["street", "shore"]
## The strongest slide, in pixels, for an object at the very front. The floor and walls never move.
const SLIDE_PX := 9.0
const SLIDE_EASE := 1.5
const SURGE_FADE := 2.2
const OUTDOOR_MIRROR_SOFT := 0.09
const INDOOR_MIRROR_SOFT := 0.001

@export var room_name: String = ""
@export var painting: Texture2D
@export var height: Texture2D
@export var aged_cared: Texture2D
@export var aged_damaged: Texture2D
@export var floor_line: float = 0.48
@export var wall_m_per_uv: float = 5.4
@export var spawn: Vector2 = Vector2(960, 700)
## How many pixels one metre takes here. The street is seen from far further away than a room.
@export var px_per_m: float = 200.0
## The painting with its cut-out objects lifted off, and that picture's heights.
@export var plate: Texture2D
@export var plate_height: Texture2D

var flood_m: float = 0.0
## Tasks place things on the objects, so the view rests while one runs.
var hold_view := false
var _material: ShaderMaterial
var _object_materials: Array[ShaderMaterial] = []
var _height_image: Image
var _ripples: Array[Vector3] = []
var _surge := 0.0
var _slide_px := 0.0
var _view_ready := false
var _sliders: Array[Sprite2D] = []


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("height_map", height)
	_material.set_shader_parameter("mirror_source", painting)
	_material.set_shader_parameter("floor_line", floor_line)
	_material.set_shader_parameter("wall_m_per_uv", wall_m_per_uv)
	_material.set_shader_parameter("creep_m", CREEP_M)
	_material.set_shader_parameter("mirror_soft", OUTDOOR_MIRROR_SOFT if room_name in OUTDOOR_ROOMS else INDOOR_MIRROR_SOFT)
	_material.set_shader_parameter("aged_cared", aged_cared if aged_cared != null else _blank())
	_material.set_shader_parameter("aged_damaged", aged_damaged if aged_damaged != null else _blank())
	var background := Sprite2D.new()
	background.name = "Painting"
	background.texture = plate
	background.centered = false
	background.z_index = -1
	background.material = _material
	add_child(background)
	# Bowls and lamps sit on the same layer, so the painting must draw first.
	move_child(background, 0)
	for child: Node in get_children():
		if child.has_meta("cut"):
			var cutout := _material.duplicate() as ShaderMaterial
			cutout.set_shader_parameter("cut_mask", child.get_meta("cut"))
			child.material = cutout
			_object_materials.append(cutout)
			_sliders.append(child)
	for bowls: String in ["BowlsFull", "BowlsEmpty"]:
		if has_node(bowls):
			var layer := _material.duplicate() as ShaderMaterial
			layer.set_shader_parameter("quality", 0.0)
			get_node(bowls).material = layer
			_object_materials.append(layer)
	if room_name in OUTDOOR_ROOMS:
		var props := WorldProps.new()
		props.outdoor_room = room_name
		props.room = self
		add_child(props)
	if room_name == "shore":
		var wall := ShoreWall.new()
		wall.name = "ShoreWall"
		var wall_layer := _material.duplicate() as ShaderMaterial
		wall_layer.set_shader_parameter("height_map", ShoreWall.HEIGHT)
		wall.material = wall_layer
		_object_materials.append(wall_layer)
		add_child(wall)
	if room_name == "bedroom":
		var marks := HeightMarks.new()
		marks.name = "HeightMarks"
		marks.room = self
		add_child(marks)
	_height_image = height.get_image()
	_height_image.decompress()
	_material.set_shader_parameter("height_map", plate_height)
	WorldClock.year_changed.connect(_on_year_changed)
	WorldClock.refresh()
	# After the room's own hook, so they always read this year's water.
	if room_name == "salon":
		var ayla := Ayla.new()
		ayla.name = "Ayla"
		ayla.room = self
		add_child(ayla)
		var brian := Brian.new()
		brian.name = "Brian"
		brian.room = self
		add_child(brian)


func character_size() -> float:
	return CHARACTER_SIZES.get(room_name, 1.0)


func _on_year_changed(state: WorldState) -> void:
	flood_m = float(state.flood_m.get(room_name, 0.0))
	var aged := inverse_lerp(FIRST_YEAR, LAST_YEAR, state.year)
	_material.set_shader_parameter("flood_m", flood_m)
	_material.set_shader_parameter("aged", aged)
	_material.set_shader_parameter("severity", state.severity)
	for object_material: ShaderMaterial in _object_materials:
		object_material.set_shader_parameter("flood_m", flood_m)
		object_material.set_shader_parameter("aged", aged)
		object_material.set_shader_parameter("severity", state.severity)
	_update_details(state)


func _update_details(state: WorldState) -> void:
	if has_node("BowlsFull"):
		var full := state.year < BOWLS_EMPTY_YEAR and Run.fed_today()
		$BowlsFull.visible = full
		$BowlsEmpty.visible = not full
	if has_node("LampOn"):
		var home_stands: bool = state.home_alive.get("own", true)
		$LampOn.visible = home_stands
		$LampOff.visible = not home_stands


## Starts a ring on the water. The oldest ring gives way once all the slots are taken.
func add_ripple(point: Vector2) -> void:
	if _ripples.size() == RIPPLE_SLOTS:
		_ripples.pop_front()
	var uv := point / ROOM_SIZE
	_ripples.append(Vector3(uv.x, uv.y, 0.0))


func ripple_count() -> int:
	return _ripples.size()


## The water heaves for a moment, as when a wall breaks.
func start_surge() -> void:
	_surge = 1.0


## How far something this near the front has slid. Near objects move more than far ones.
func slide_at(nearness: float) -> float:
	return _slide_px * nearness


## Objects slide as whole paper cut-outs, slowly and against the walker, like a multiplane camera.
func _update_view(delta: float) -> void:
	var walker := get_tree().get_first_node_in_group("walker") as Node2D
	var target := 0.0
	if walker != null and not hold_view and not Settings.calm_storm:
		target = (0.5 - walker.global_position.x / ROOM_SIZE.x) * 2.0 * SLIDE_PX
	_slide_px = lerpf(_slide_px, target, 1.0 - exp(-SLIDE_EASE * delta)) if _view_ready else target
	_view_ready = true
	for sprite: Sprite2D in _sliders:
		sprite.position.x = slide_at(sprite.position.y / ROOM_SIZE.y)


func _process(delta: float) -> void:
	_update_view(delta)
	if _surge > 0.0:
		_surge = maxf(_surge * exp(-SURGE_FADE * delta) - delta * 0.01, 0.0)
		_material.set_shader_parameter("surge", _surge)
		for object_material: ShaderMaterial in _object_materials:
			object_material.set_shader_parameter("surge", _surge)
	var was_active := not _ripples.is_empty()
	var still_alive: Array[Vector3] = []
	for ring: Vector3 in _ripples:
		ring.z += delta / RIPPLE_SECONDS
		if ring.z < 1.0:
			still_alive.append(ring)
	_ripples = still_alive
	if was_active:
		_material.set_shader_parameter("ripples", PackedVector3Array(_ripples))
		_material.set_shader_parameter("ripple_count", _ripples.size())


## Water depth in metres at a room position, matching the flood shader's height_at().
func depth_at(point: Vector2) -> float:
	var uv := (point / ROOM_SIZE).clamp(Vector2.ZERO, Vector2.ONE)
	var size := _height_image.get_size()
	var pixel := _height_image.get_pixel(mini(int(uv.x * size.x), size.x - 1), mini(int(uv.y * size.y), size.y - 1))
	var ground: float
	if pixel.r > 0.99:
		return 0.0
	if pixel.g > 0.5:
		ground = maxf(floor_line - uv.y, 0.0) * wall_m_per_uv
	else:
		var tilt := uv.x * 0.7 + (uv.y - floor_line) * 0.3 + 0.25 * sin(uv.x * 9.0 + uv.y * 7.0)
		ground = pixel.r * OBJECT_FULL_M + tilt * CREEP_M
	return maxf(0.0, flood_m - ground)


static func _blank() -> ImageTexture:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(image)
