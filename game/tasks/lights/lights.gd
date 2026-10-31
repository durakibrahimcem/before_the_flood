class_name LightsTask
extends Task
## The night-lights task: switch off the salon lights before bed, then the street follows.

signal switch_flipped(zone_index: int)
signal home_dark(home_index: int)

const PHASE1_SECONDS := 15.0
const REACH_PX := 100.0
const NEIGHBOUR_DELAY := 1.5
const LAST_FLIP_HOLD := 1.2
const CAPTION_HOLD := 1.2
const WALKER_START := Vector2(960, 940)
const WALKER_HEIGHT_M := 1.3
const WALKER_PX_PER_M := 200.0
const NIGHT_WASH := Color(0.05, 0.07, 0.14, 0.6)
const STREET_WASH := Color(0.04, 0.05, 0.12, 0.75)
const STREET_BAND := Color(0.14, 0.15, 0.22, 0.9)
const SALON_TINT := Color(0.82, 0.86, 1.0)
const STREET_TINT := Color(0.68, 0.74, 0.96)
const HINT_TEXT := "Switch off the lights before bed."
const CAPTION_TEXT := "One by one, the street follows."
const HOME_POSITIONS: Array[Vector2] = [
	Vector2(960, 920),
	Vector2(430, 920),
	Vector2(1490, 920),
]
## One entry per possible switch: the zone it lights, the switch spot, and the lit window inside.
const ZONES: Array[Dictionary] = [
	{ "zone": Rect2(40, 620, 540, 400), "switch": Vector2(300, 870), "window": Rect2(120, 640, 200, 120) },
	{ "zone": Rect2(620, 540, 480, 300), "switch": Vector2(960, 700), "window": Rect2(760, 560, 180, 90) },
	{ "zone": Rect2(1300, 480, 560, 380), "switch": Vector2(1660, 700), "window": Rect2(1500, 500, 200, 110) },
	{ "zone": Rect2(60, 300, 380, 280), "switch": Vector2(210, 430), "window": Rect2(120, 320, 160, 90) },
	{ "zone": Rect2(480, 200, 400, 280), "switch": Vector2(680, 350), "window": Rect2(560, 230, 160, 90) },
	{ "zone": Rect2(940, 220, 380, 260), "switch": Vector2(1120, 350), "window": Rect2(1020, 250, 150, 90) },
	{ "zone": Rect2(1360, 160, 420, 280), "switch": Vector2(1580, 310), "window": Rect2(1450, 190, 170, 90) },
	{ "zone": Rect2(1120, 860, 480, 200), "switch": Vector2(1360, 960), "window": Rect2(1230, 880, 180, 80) },
]

@export var switch_texture: Texture2D
@export var home_texture: Texture2D
@export var walker_texture: Texture2D = preload("res://actors/arda_placeholder.png")

var walker: CharacterBody2D
var switches_done := 0
var switches_total := 0
var phase := 0

var time_left := PHASE1_SECONDS
var _ending := false
var _froze_walker := false
var _owns_walker := false
var _walker_mode := Node.PROCESS_MODE_INHERIT
var _zones: Array[SalonZone] = []
var _switches: Array[LightSwitch] = []
var _homes: Array[StreetHome] = []
var _timer_bar: Polygon2D
var _caption: CrayonHint

@onready var _night: CanvasLayer = $Night
@onready var _tint: CanvasModulate = $Night/Tint
@onready var _salon: Node2D = $Night/Salon
@onready var _street: Node2D = $Night/Street


func _init() -> void:
	action = "light"


func _begin() -> void:
	switches_total = target_count(3)
	time_left = PHASE1_SECONDS
	_tint.color = SALON_TINT
	_build_salon()
	_acquire_walker()
	phase = 1


func _physics_process(delta: float) -> void:
	if phase != 1 or _ending:
		return
	time_left -= delta
	if time_left < 0.0:
		time_left = 0.0
	_timer_bar.scale.x = time_left / PHASE1_SECONDS
	_update_reach()
	if Input.is_action_just_pressed("interact"):
		var nearest := _nearest_switch_index()
		if nearest >= 0:
			_flip(nearest)
	if switches_done >= switches_total:
		_begin_ending(LAST_FLIP_HOLD)
	elif time_left <= 0.0:
		_begin_ending(0.0)


func _exit_tree() -> void:
	_unfreeze_walker()


## The salon stage: night wash, lit zones, switches, the timer bar and the hint.
func _build_salon() -> void:
	_salon.add_child(_screen_polygon(NIGHT_WASH))
	var active := mini(switches_total, ZONES.size())
	for i: int in active:
		var entry: Dictionary = ZONES[i]
		var zone := SalonZone.new()
		zone.setup(entry["zone"] as Rect2, entry["window"] as Rect2)
		_salon.add_child(zone)
		_zones.append(zone)
		var light := LightSwitch.new()
		light.setup(i, switch_texture)
		light.position = entry["switch"] as Vector2
		_salon.add_child(light)
		_switches.append(light)
	_timer_bar = Polygon2D.new()
	_timer_bar.polygon = PackedVector2Array([
		Vector2(0, -3), Vector2(320, -3), Vector2(320, 3), Vector2(0, 3),
	])
	_timer_bar.color = Color(1.0, 0.92, 0.72, 0.85)
	_timer_bar.position = Vector2(800, 40)
	_salon.add_child(_timer_bar)
	var hint := CrayonHint.new()
	hint.text = HINT_TEXT
	hint.position = Vector2(960, 150)
	_salon.add_child(hint)


## Use the walker the room already has, or spawn our own inside the night layer.
func _acquire_walker() -> void:
	walker = get_tree().get_first_node_in_group("walker") as CharacterBody2D
	if walker != null:
		return
	_owns_walker = true
	walker = TaskWalker.new()
	if walker_texture != null:
		var sprite := Sprite2D.new()
		sprite.texture = walker_texture
		sprite.centered = false
		sprite.offset = -Vector2(float(walker_texture.get_width()) / 2.0, float(walker_texture.get_height()))
		var ratio := WALKER_HEIGHT_M * WALKER_PX_PER_M / float(walker_texture.get_height())
		sprite.scale = Vector2(ratio, ratio)
		walker.add_child(sprite)
	else:
		walker.add_child(_figure())
	walker.position = WALKER_START
	_night.add_child(walker)


## A simple crayon figure when no walker art is set yet, with its feet at the origin.
func _figure() -> Node2D:
	var figure := Node2D.new()
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-42, -172), Vector2(42, -172), Vector2(32, 0), Vector2(-32, 0),
	])
	body.color = Color(0.38, 0.56, 0.76)
	figure.add_child(body)
	var head := Polygon2D.new()
	head.polygon = _circle(Vector2(0, -214), 46.0, 22)
	head.color = Color(0.95, 0.93, 0.88)
	figure.add_child(head)
	return figure


func _circle(center: Vector2, radius: float, count: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i: int in count:
		var angle := TAU * float(i) / float(count)
		result.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return result


func _update_reach() -> void:
	if walker == null or not is_instance_valid(walker):
		return
	for light: LightSwitch in _switches:
		light.set_in_reach(not light.flipped and walker.position.distance_to(light.position) <= REACH_PX)


func _nearest_switch_index() -> int:
	if walker == null or not is_instance_valid(walker):
		return -1
	var best := -1
	var best_distance := REACH_PX
	for i: int in _switches.size():
		var light: LightSwitch = _switches[i]
		if light.flipped:
			continue
		var distance := walker.position.distance_to(light.position)
		if distance <= best_distance:
			best = i
			best_distance = distance
	return best


func _flip(index: int) -> void:
	var light: LightSwitch = _switches[index]
	light.flip()
	(_zones[index] as SalonZone).dim()
	switches_done += 1
	switch_flipped.emit(index)


## Phase 1 is over: hold the last dim, then hand over to the quiet street ending.
func _begin_ending(hold: float) -> void:
	_ending = true
	_freeze_walker()
	for light: LightSwitch in _switches:
		light.set_in_reach(false)
	if hold > 0.0:
		var tween := create_tween()
		tween.tween_interval(hold)
		tween.tween_callback(_run_ending)
	else:
		_run_ending()


## Phase 2: the salon goes to bed, and the street follows one home at a time.
func _run_ending() -> void:
	var fade := create_tween()
	fade.tween_property(_salon, "modulate:a", 0.0, 0.4)
	if _owns_walker and walker != null and is_instance_valid(walker):
		fade.tween_property(walker, "modulate:a", 0.0, 0.4)
	await fade.finished
	_salon.hide()
	_build_street()
	phase = 2
	_street.modulate.a = 0.0
	var reveal := create_tween().set_parallel(true)
	reveal.tween_property(_street, "modulate:a", 1.0, 0.5)
	reveal.tween_property(_tint, "color", STREET_TINT, 1.2)
	await reveal.finished
	(_homes[0] as StreetHome).go_dark()
	home_dark.emit(0)
	await _wait(NEIGHBOUR_DELAY)
	(_homes[1] as StreetHome).go_dark()
	home_dark.emit(1)
	await _wait(NEIGHBOUR_DELAY)
	(_homes[2] as StreetHome).go_dark()
	home_dark.emit(2)
	await _wait(CAPTION_HOLD)
	_caption.fade_out(0.5)
	_unfreeze_walker()
	complete(float(switches_done) / float(switches_total))


func _build_street() -> void:
	_street.add_child(_screen_polygon(STREET_WASH))
	var band := Polygon2D.new()
	band.polygon = SalonZone.wobbly_rect(Rect2(0, 900, 1920, 180), 90.0)
	band.color = STREET_BAND
	_street.add_child(band)
	for i: int in HOME_POSITIONS.size():
		var home := StreetHome.new()
		home.home_texture = home_texture
		home.position = HOME_POSITIONS[i]
		_street.add_child(home)
		_homes.append(home)
	_caption = CrayonHint.new()
	_caption.text = CAPTION_TEXT
	_caption.auto_fade_after = 0.0
	_caption.position = Vector2(960, 140)
	_street.add_child(_caption)


func _freeze_walker() -> void:
	if walker == null or not is_instance_valid(walker):
		return
	_walker_mode = walker.process_mode
	walker.process_mode = Node.PROCESS_MODE_DISABLED
	_froze_walker = true


func _unfreeze_walker() -> void:
	if not _froze_walker:
		return
	_froze_walker = false
	if walker != null and is_instance_valid(walker):
		walker.process_mode = _walker_mode


func _wait(seconds: float) -> void:
	var tween := create_tween()
	tween.tween_interval(seconds)
	await tween.finished


func _screen_polygon(color: Color) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(1920, 0), Vector2(1920, 1080), Vector2(0, 1080),
	])
	polygon.color = color
	return polygon
