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
const FIRST_YEAR := 2026.0
const LAST_YEAR := 2080.0

@export var room_name: String = ""
@export var painting: Texture2D
@export var height: Texture2D
@export var aged_cared: Texture2D
@export var aged_damaged: Texture2D
@export var floor_line: float = 0.48
@export var wall_m_per_uv: float = 5.4
@export var spawn: Vector2 = Vector2(960, 700)

var flood_m: float = 0.0
var _material: ShaderMaterial
var _object_materials: Array[ShaderMaterial] = []
var _height_image: Image


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("height_map", height)
	_material.set_shader_parameter("floor_line", floor_line)
	_material.set_shader_parameter("wall_m_per_uv", wall_m_per_uv)
	_material.set_shader_parameter("creep_m", CREEP_M)
	_material.set_shader_parameter("aged_cared", aged_cared if aged_cared != null else _blank())
	_material.set_shader_parameter("aged_damaged", aged_damaged if aged_damaged != null else _blank())
	var background := Sprite2D.new()
	background.name = "Painting"
	background.texture = painting
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
	for bowls: String in ["BowlsFull", "BowlsEmpty"]:
		if has_node(bowls):
			var layer := _material.duplicate() as ShaderMaterial
			layer.set_shader_parameter("quality", 0.0)
			get_node(bowls).material = layer
			_object_materials.append(layer)
	if room_name in ["street", "shore"]:
		var props := WorldProps.new()
		props.outdoor_room = room_name
		add_child(props)
	_height_image = height.get_image()
	_height_image.decompress()
	WorldClock.year_changed.connect(_on_year_changed)
	WorldClock.refresh()


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
		$BowlsFull.visible = state.year < BOWLS_EMPTY_YEAR
		$BowlsEmpty.visible = state.year >= BOWLS_EMPTY_YEAR
	if has_node("LampOn"):
		var home_stands: bool = state.home_alive.get("own", true)
		$LampOn.visible = home_stands
		$LampOff.visible = not home_stands


## Water depth in metres at a room position, matching the flood shader's height_at().
func depth_at(point: Vector2) -> float:
	var uv := (point / ROOM_SIZE).clamp(Vector2.ZERO, Vector2.ONE)
	var size := _height_image.get_size()
	var pixel := _height_image.get_pixel(mini(int(uv.x * size.x), size.x - 1), mini(int(uv.y * size.y), size.y - 1))
	var ground: float
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
