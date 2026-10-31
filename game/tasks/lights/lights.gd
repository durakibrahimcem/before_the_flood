class_name LightsTask
extends Task
## The night-lights task: switch off the salon lights before bed, then the street follows.

signal switch_flipped(zone_index: int)
signal home_dark(home_index: int)

const PHASE1_SECONDS := 25.0
const REACH_PX := 100.0
const NEIGHBOUR_DELAY := 1.5
const LAST_FLIP_HOLD := 1.2
const CAPTION_HOLD := 1.2
const WALKER_START := Vector2(960, 940)
const WALKER_HEIGHT_M := 1.3
const WALKER_PX_PER_M := 200.0
const NIGHT_TINT := Color(0.34, 0.38, 0.60)
const DARK_TINT := Color(0.17, 0.19, 0.33)
const STREET_PAINTING := preload("res://rooms/street/street.png")
const STREET_NIGHT := Color(0.27, 0.3, 0.5)
const STREET_TINT := Color(0.68, 0.74, 0.96)
const HINT_TEXT := "Switch off the lights before bed."
const CAPTION_TEXT := "One by one, the street follows."
## The windows Ebru painted: the family's home first, then the house next door.
const HOME_WINDOWS: Array[Array] = [
	[Rect2(866, 302, 74, 92), Rect2(1042, 305, 66, 85)],
	[Rect2(1736, 302, 74, 92)],
]
## One entry per light left on: where it glows, how far, the wall switch, and where Arda stands to reach it.
const ZONES: Array[Dictionary] = [
	{ "glow": Vector2(742, 50), "size": Vector2(1500, 1100), "switch": Vector2(483, 325), "stand": Vector2(483, 590), "lamp": true },
	{ "glow": Vector2(804, 545), "size": Vector2(420, 170), "switch": Vector2(650, 325), "stand": Vector2(650, 590) },
	{ "glow": Vector2(1153, 545), "size": Vector2(420, 170), "switch": Vector2(1000, 325), "stand": Vector2(1000, 590) },
	{ "glow": Vector2(279, 545), "size": Vector2(420, 170), "switch": Vector2(120, 325), "stand": Vector2(120, 590) },
	{ "glow": Vector2(1540, 340), "size": Vector2(760, 300), "switch": Vector2(1300, 325), "stand": Vector2(1300, 650) },
	{ "glow": Vector2(1850, 520), "size": Vector2(300, 520), "switch": Vector2(1785, 325), "stand": Vector2(1750, 700) },
]

@export var switch_texture: Texture2D
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
@onready var _tint: CanvasModulate = $Tint
@onready var _salon: Node2D = $Night/Salon
@onready var _street: Node2D = $Night/Street


func _init() -> void:
	action = "light"


func _begin() -> void:
	switches_total = mini(target_count(3), ZONES.size())
	time_left = PHASE1_SECONDS
	_tint.color = NIGHT_TINT
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


## The salon stage: a light for each switch, the timer bar and the hint. The tint darkens the real room.
func _build_salon() -> void:
	for i: int in switches_total:
		var entry: Dictionary = ZONES[i]
		var zone := SalonZone.new()
		zone.setup(entry["glow"] as Vector2, entry["size"] as Vector2, entry.get("lamp", false))
		_salon.add_child(zone)
		_zones.append(zone)
		var light := LightSwitch.new()
		light.setup(i, switch_texture)
		light.position = entry["switch"] as Vector2
		light.stand = entry["stand"] as Vector2
		_salon.add_child(light)
		_switches.append(light)
	_timer_bar = Polygon2D.new()
	_timer_bar.polygon = PackedVector2Array([
		Vector2(0, -3), Vector2(320, -3), Vector2(320, 3), Vector2(0, 3),
	])
	_timer_bar.color = Color(1.0, 0.92, 0.72, 0.85)
	_timer_bar.position = Vector2(800, 70)
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
		light.set_in_reach(not light.flipped and walker.position.distance_to(light.stand) <= REACH_PX)


func _nearest_switch_index() -> int:
	if walker == null or not is_instance_valid(walker):
		return -1
	var best := -1
	var best_distance := REACH_PX
	for i: int in _switches.size():
		var light: LightSwitch = _switches[i]
		if light.flipped:
			continue
		var distance := walker.position.distance_to(light.stand)
		if distance <= best_distance:
			best = i
			best_distance = distance
	return best


func _flip(index: int) -> void:
	var light: LightSwitch = _switches[index]
	Sfx.play("switch")
	light.flip()
	var zone := _zones[index] as SalonZone
	zone.dim()
	if zone.is_lamp:
		_show_lamp_off()
	switches_done += 1
	var darker := NIGHT_TINT.lerp(DARK_TINT, float(switches_done) / float(switches_total))
	create_tween().tween_property(_tint, "color", darker, SalonZone.DIM_SECONDS)
	switch_flipped.emit(index)


func _show_lamp_off() -> void:
	var room: Room = (walker as Arda).room if walker is Arda else null
	if room != null and room.has_node("LampOn"):
		room.get_node("LampOn").hide()
		room.get_node("LampOff").show()


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
	for zone: SalonZone in _zones:
		zone.dim()
	_show_lamp_off()
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
	await _wait(CAPTION_HOLD)
	_caption.fade_out(0.5)
	_unfreeze_walker()
	complete(float(switches_done) / float(switches_total))


func _build_street() -> void:
	var painting := Sprite2D.new()
	painting.texture = STREET_PAINTING
	painting.centered = false
	painting.modulate = STREET_NIGHT
	_street.add_child(painting)
	for windows: Array in HOME_WINDOWS:
		var home := StreetHome.new()
		home.window_rects.assign(windows)
		_street.add_child(home)
		_homes.append(home)
	_caption = CrayonHint.new()
	_caption.text = CAPTION_TEXT
	_caption.auto_fade_after = 0.0
	_caption.position = Vector2(960, 140)
	_street.add_child(_caption)


func result_text() -> String:
	return "%d of %d lights off" % [switches_done, switches_total]


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
