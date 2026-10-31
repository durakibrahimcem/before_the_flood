class_name DuneTask
extends Task
## The dunes task: sand blows from thin spots until the walker plants grass.

const BASE_SPOTS := 5
const PLANT_RADIUS := 70.0
const MARGIN := 36.0
const HINT := "Plant grass where the sand blows."
const SAND_FILL := Color(0.87, 0.73, 0.51)
const SAND_LINE := Color(0.55, 0.42, 0.26)
const SAND_RIDGE := Color(0.55, 0.42, 0.26, 0.22)
## Fixed spot pool; the last entry covers target_count at repeat 5.
const SPOT_POOL: Array[Vector2] = [
	Vector2(280, 640), Vector2(620, 720), Vector2(960, 600), Vector2(1290, 760),
	Vector2(1640, 660), Vector2(450, 820), Vector2(1050, 800), Vector2(1420, 560),
	Vector2(820, 690), Vector2(1720, 800), Vector2(180, 780), Vector2(1180, 660),
]
const CREST: Array[Vector2] = [
	Vector2(0, 615), Vector2(160, 560), Vector2(320, 640), Vector2(480, 545),
	Vector2(640, 605), Vector2(800, 650), Vector2(960, 555), Vector2(1120, 630),
	Vector2(1280, 540), Vector2(1440, 600), Vector2(1600, 645), Vector2(1760, 565),
	Vector2(1920, 610),
]
const RIDGE_1: Array[Vector2] = [
	Vector2(320, 750), Vector2(640, 715), Vector2(960, 665), Vector2(1280, 650),
	Vector2(1600, 755),
]
const RIDGE_2: Array[Vector2] = [
	Vector2(480, 830), Vector2(800, 880), Vector2(1120, 860), Vector2(1440, 835),
]

@export var dune_texture: Texture2D
@export var spot_texture: Texture2D
@export var plant_texture: Texture2D
## The real run lasts about 25 seconds; demos shorten it for a quick poor run.
@export var time_limit := 25.0

var walker: CharacterBody2D
var spots: Array[DuneSpot] = []
var planted_count := 0

var _total := 0
var _time_left := 0.0
var _was_interact_pressed := false
var _walker_z := 0


func _init() -> void:
	action = "dune"


func complete(performance: float) -> void:
	if not _done and walker != null and is_instance_valid(walker):
		walker.z_index = _walker_z
	super.complete(performance)


func _begin() -> void:
	_claim_walker()
	var wanted := target_count(BASE_SPOTS)
	_total = mini(wanted, SPOT_POOL.size())
	if _total < wanted:
		push_warning("dune spot pool too small for repeat %d" % repeat_index)
	for i: int in _total:
		var spot := DuneSpot.new()
		spot.spot_texture = spot_texture
		spot.plant_texture = plant_texture
		spot.position = SPOT_POOL[i]
		add_child(spot)
		spots.append(spot)
	_show_hint()
	_time_left = time_limit
	_was_interact_pressed = false
	set_physics_process(true)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _done:
		set_physics_process(false)
		return
	if _total == 0:
		return  # start() has not run yet
	if walker != null and is_instance_valid(walker):
		var pos := walker.global_position
		pos.x = clampf(pos.x, MARGIN, 1920.0 - MARGIN)
		pos.y = clampf(pos.y, MARGIN, 1080.0 - MARGIN)
		walker.global_position = pos
	_time_left -= delta
	if _time_left <= 0.0:
		complete(float(planted_count) / float(_total))
		return
	var pressed := Input.is_action_pressed("interact")
	if pressed and not _was_interact_pressed:
		_try_plant()
	_was_interact_pressed = pressed


func _try_plant() -> void:
	if walker == null or not is_instance_valid(walker):
		return
	var nearest: DuneSpot = null
	var best := PLANT_RADIUS
	for spot: DuneSpot in spots:
		if spot.is_planted:
			continue
		var distance := walker.global_position.distance_to(spot.global_position)
		if distance <= best:
			best = distance
			nearest = spot
	if nearest == null:
		return
	nearest.plant()
	planted_count += 1
	if planted_count == _total:
		complete(1.0)


func _claim_walker() -> void:
	var tree := get_tree()
	if tree != null:
		walker = tree.get_first_node_in_group("walker") as CharacterBody2D
	if walker == null:
		var fresh := TaskWalker.new()
		add_child(fresh)
		fresh.global_position = Vector2(960, 930)
		walker = fresh
	## The walker must stay visible over the task's own art while the task runs.
	_walker_z = walker.z_index
	walker.z_index = maxi(walker.z_index, 1)


func _show_hint() -> void:
	var hint := Label.new()
	hint.text = HINT
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(1200, 64)
	hint.pivot_offset = hint.size * 0.5
	hint.rotation_degrees = -2.0
	hint.position = Vector2(960.0 - hint.size.x * 0.5, 120.0)
	hint.add_theme_font_size_override("font_size", 40)
	hint.add_theme_color_override("font_color", Color(0.45, 0.33, 0.22))
	hint.add_theme_color_override("font_outline_color", Color(0.99, 0.96, 0.88))
	hint.add_theme_constant_override("outline_size", 10)
	add_child(hint)
	var fade := create_tween()
	fade.tween_interval(5.0)
	fade.tween_property(hint, "modulate:a", 0.0, 1.0)
	fade.tween_callback(hint.queue_free)


func _draw() -> void:
	if dune_texture != null:
		draw_texture_rect(dune_texture, Rect2(0, 0, 1920, 1080), false)
		return
	var band := PackedVector2Array(CREST)
	band.append(Vector2(1920, 1080))
	band.append(Vector2(0, 1080))
	draw_colored_polygon(band, SAND_FILL)
	draw_polyline(PackedVector2Array(CREST), SAND_LINE, 5.0)
	draw_polyline(PackedVector2Array(RIDGE_1), SAND_RIDGE, 3.0)
	draw_polyline(PackedVector2Array(RIDGE_2), SAND_RIDGE, 3.0)
