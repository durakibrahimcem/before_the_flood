class_name SeagrassTask
extends Task
## The seagrass task: plant shoots in the calm moments between the waves.

const WASH_SECONDS := 1.5
const CALM_SECONDS := 2.5
const CYCLE := WASH_SECONDS + CALM_SECONDS
const TIMEOUT_SECONDS := 40.0
const PLANT_RADIUS := 110.0
const TOP := 300.0
const BOTTOM := 1120.0
const RETREAT_SECONDS := 0.6

## Handcrafted anchors for up to repeat 5 (Plan.SLOTS caps repeats at 6 picks).
## Staggered so they never read as a grid. min() below guards the ceiling.
const ANCHORS := [
	Vector2(830, 890), Vector2(1010, 800), Vector2(640, 780), Vector2(1180, 720),
	Vector2(450, 900), Vector2(1340, 560), Vector2(860, 560), Vector2(240, 640),
	Vector2(1560, 840), Vector2(1720, 620), Vector2(700, 470), Vector2(1200, 470),
	Vector2(330, 440), Vector2(1500, 440), Vector2(960, 660), Vector2(520, 560),
]

@export var shoot_texture: Texture2D
@export var spot_marker: Texture2D
@export var hint_texture: Texture2D
@export var walker_figure: Texture2D

var goal := 0
var rooted := 0
var elapsed := 0.0
var washing := true
var walker: CharacterBody2D = null
var spots: Array[SeagrassSpot] = []

var _wave: SeagrassWave
var _edge := TOP
var _running := false
var _ended := false
var _spawned_walker: TaskWalker = null
var _highlighted: SeagrassSpot = null


func _init() -> void:
	action = "grass"


func _ready() -> void:
	finished.connect(_on_finished)


func is_calm() -> bool:
	return not washing


func result_text() -> String:
	return "%d of %d shoots rooted" % [rooted, goal]


func debug_note() -> String:
	return "%d %d %d" % [rooted, goal, 1 if is_calm() else 0]


func _begin() -> void:
	if not is_inside_tree():
		await tree_entered
	goal = min(target_count(6), ANCHORS.size())
	_wave = SeagrassWave.new()
	add_child(_wave)
	for i in range(goal):
		var spot := SeagrassSpot.new()
		spot.marker = spot_marker
		spot.position = ANCHORS[i]
		add_child(spot)
		spots.append(spot)
	var hint := SeagrassHint.new()
	hint.hint_texture = hint_texture
	hint.position = Vector2(960.0, 150.0)
	add_child(hint)
	_acquire_walker()
	if walker != null:
		walker.set("carried", "shoot")
	_running = true


## The wave clock lives on the physics tick, so the plant decision never judges
## a stale phase.
func _physics_process(delta: float) -> void:
	if not _running or _ended:
		return
	elapsed += delta
	var phase := fposmod(elapsed, CYCLE)
	washing = phase < WASH_SECONDS
	_edge = _edge_at(phase)
	_wave.set_edge(_edge)
	_update_highlight()
	if Input.is_action_just_pressed("interact"):
		var spot := _nearest_empty_spot()
		if spot != null:
			_plant(spot)
	_check_washes()
	if elapsed >= target_time(TIMEOUT_SECONDS):
		complete(float(rooted) / float(goal))
	if _spawned_walker != null:
		_spawned_walker.position.x = clampf(_spawned_walker.position.x, 40.0, 1880.0)
		_spawned_walker.position.y = clampf(_spawned_walker.position.y, 200.0, 1040.0)


func _edge_at(phase: float) -> float:
	if washing:
		var p := phase / WASH_SECONDS
		return TOP + (BOTTOM - TOP) * smoothstep(0.0, 1.0, p)
	var calm := phase - WASH_SECONDS
	if calm < RETREAT_SECONDS:
		var q := calm / RETREAT_SECONDS
		var eased := 1.0 - (1.0 - q) * (1.0 - q)
		return BOTTOM + (TOP - BOTTOM) * eased
	return TOP + sin(elapsed * 1.3) * 6.0


## Any CharacterBody2D in the "walker" group is the player: Arda in a room,
## a TaskWalker in a bare scene. Only a missing walker is spawned here.
func _acquire_walker() -> void:
	for node: Node in get_tree().get_nodes_in_group("walker"):
		if node is CharacterBody2D:
			walker = node
			return
	_spawned_walker = TaskWalker.new()
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 14.0
	capsule.height = 60.0
	shape.shape = capsule
	_spawned_walker.add_child(shape)
	var figure := Sprite2D.new()
	figure.texture = walker_figure if walker_figure != null else SeagrassArt.walker_texture()
	figure.z_index = 2
	_spawned_walker.add_child(figure)
	add_child(_spawned_walker)
	_spawned_walker.position = Vector2(960.0, 960.0)
	walker = _spawned_walker


func _nearest_empty_spot() -> SeagrassSpot:
	if walker == null:
		return null
	var nearest: SeagrassSpot = null
	var best := PLANT_RADIUS
	var feet := to_local(walker.global_position)
	for spot: SeagrassSpot in spots:
		if spot.state != SeagrassSpot.State.EMPTY:
			continue
		var d := feet.distance_to(spot.position)
		if d <= best:
			best = d
			nearest = spot
	return nearest


func _plant(spot: SeagrassSpot) -> void:
	Sfx.play("plant")
	var shoot := SeagrassShoot.new()
	shoot.texture = shoot_texture
	shoot.position = spot.position
	add_child(shoot)
	spot.shoot = shoot
	shoot.root()
	if is_calm():
		spot.state = SeagrassSpot.State.ROOTED
		rooted += 1
		if rooted >= goal:
			complete(float(rooted) / float(goal))
	else:
		spot.state = SeagrassSpot.State.HOLDING
		spot.covered = _edge >= spot.position.y


func _check_washes() -> void:
	for spot: SeagrassSpot in spots:
		if spot.state != SeagrassSpot.State.HOLDING or spot.shoot == null:
			continue
		if washing and not spot.covered and _edge >= spot.position.y:
			_wash(spot)
		elif is_calm() and _edge <= spot.position.y:
			_wash(spot)


func _wash(spot: SeagrassSpot) -> void:
	spot.shoot.wash_away()
	spot.shoot = null
	spot.state = SeagrassSpot.State.EMPTY
	spot.covered = false


func _update_highlight() -> void:
	var nearest: SeagrassSpot = null
	if walker != null:
		var best := INF
		var feet := to_local(walker.global_position)
		for spot: SeagrassSpot in spots:
			if spot.state != SeagrassSpot.State.EMPTY:
				continue
			var d := feet.distance_to(spot.position)
			if d < best:
				best = d
				nearest = spot
	if _highlighted != nearest:
		if _highlighted != null:
			_highlighted.highlight_nearest = false
		_highlighted = nearest
		if _highlighted != null:
			_highlighted.highlight_nearest = true


func _on_finished(_performance: float) -> void:
	_ended = true
	if walker != null and is_instance_valid(walker):
		walker.set("carried", "")
	var tween := create_tween().bind_node(self)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.75)
	tween.tween_callback(queue_free)
