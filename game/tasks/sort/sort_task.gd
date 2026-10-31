class_name SortTask
extends Task
## The waste sorting task: carry each item to its labelled bin before time runs out.

const BASE_ITEMS := 8
const KINDS: Array[String] = ["plastic", "paper", "glass", "metal"]
const ITEM_SCENE: PackedScene = preload("res://tasks/sort/sort_item.tscn")
const FIELD := Rect2(340.0, 540.0, 1240.0, 340.0)
const ITEM_GAP := 90.0
const WALKER_CLEARANCE := 170.0
const WALKER_START := Vector2(960, 980)
const WALKER_SPEED := 460.0
const WALKER_MIN := Vector2(40.0, 40.0)
const WALKER_MAX := Vector2(1880.0, 1040.0)
const PLACE_ATTEMPTS := 80
const ITEM_GROUP := "sort_item"
const WALKER_GROUP := "walker"
const LABEL_WIDTH := 200.0
const LABEL_LIFT := Vector2(-100.0, -90.0)

@export var seconds := 25.0
## 0 randomizes the layout each run; a nonzero seed makes it repeatable.
@export var layout_seed := 0
## Art drop-in per kind; empty means code placeholders.
@export var item_art: Dictionary[String, Texture2D] = {}
## Art drop-in for the placeholder walker we spawn; the room's own walker needs none.
@export var walker_art: Texture2D

var total_items := 0
var sorted_correct := 0
var time_left := 0.0
var running := false

var _walker: CharacterBody2D
var _own_walker := false
var _rng := RandomNumberGenerator.new()
var _carried_label: Label

@onready var hint: CrayonHint = $Hint
@onready var hud: SortHud = $Hud


func _init() -> void:
	action = "sort"


func _begin() -> void:
	if not is_node_ready():
		await ready
	total_items = target_count(BASE_ITEMS)
	time_left = seconds
	running = true
	_seed_rng()
	_find_walker()
	_spawn_items()
	_connect_bins()
	_build_carried_label()
	hint.show_hint()
	hud.update_state(sorted_correct, total_items, 1.0)
	_update_carried_label()


func _process(_delta: float) -> void:
	if not running:
		return
	if _walker == null:
		_end()
		return
	if hint.visible and Input.is_action_just_pressed("interact"):
		hint.fade_out()
	hud.update_state(sorted_correct, total_items, time_left / maxf(seconds, 0.001))
	_update_carried_label()


## The timer steps with the fixed physics tick, so it never drifts from the walk.
func _physics_process(delta: float) -> void:
	if not running or _walker == null:
		return
	_walker.global_position = Vector2(
		clampf(_walker.global_position.x, WALKER_MIN.x, WALKER_MAX.x),
		clampf(_walker.global_position.y, WALKER_MIN.y, WALKER_MAX.y))
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0 or (_items_left() == 0 and _carried() == ""):
		_end()


func _end() -> void:
	running = false
	hint.fade_out()
	if _own_walker and _walker != null:
		_walker.set_physics_process(false)
	complete(float(sorted_correct) / float(total_items))


## The walker's carried word; empty when the walker is gone or carries nothing.
func _carried() -> String:
	if _walker == null:
		return ""
	var value: Variant = _walker.get("carried")
	if value == null:
		return ""
	return String(value)


func _set_carried(text: String) -> void:
	if _walker == null:
		return
	_walker.set("carried", text)


## Live items on this task only, so two task instances cannot see each other.
func _items_left() -> int:
	var count := 0
	for child: Node in get_children():
		if child is SortItem and not child.is_queued_for_deletion():
			count += 1
	return count


func _seed_rng() -> void:
	if layout_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = layout_seed


## Borrow the room's walker when there is one, otherwise spawn our own.
func _find_walker() -> void:
	_walker = get_tree().get_first_node_in_group(WALKER_GROUP) as CharacterBody2D
	if _walker != null:
		return
	var walker := TaskWalker.new()
	walker.position = WALKER_START
	walker.speed = WALKER_SPEED
	walker.add_child(_make_walker_shape())
	if walker_art != null:
		var sprite := Sprite2D.new()
		sprite.texture = walker_art
		walker.add_child(sprite)
	else:
		walker.add_child(WalkerBody.new())
	add_child(walker)
	_walker = walker
	_own_walker = true


func _make_walker_shape() -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40.0, 64.0)
	shape.shape = rect
	return shape


func _spawn_items() -> void:
	var placed := PackedVector2Array()
	for i: int in total_items:
		var item := ITEM_SCENE.instantiate() as SortItem
		item.kind = KINDS[i % KINDS.size()]
		if item_art.has(item.kind):
			item.art = item_art[item.kind]
		item.position = _item_spot(placed)
		placed.append(item.position)
		item.add_to_group(ITEM_GROUP)
		item.touched.connect(_on_item_touched.bind(item))
		add_child(item)


## Rejection sampling with a bounded loop, so placement always finishes.
func _item_spot(placed: PackedVector2Array) -> Vector2:
	var spot := Vector2.ZERO
	for attempt: int in PLACE_ATTEMPTS:
		spot = Vector2(
			_rng.randf_range(FIELD.position.x, FIELD.position.x + FIELD.size.x),
			_rng.randf_range(FIELD.position.y, FIELD.position.y + FIELD.size.y))
		if _spot_clear(spot, placed):
			break
	return spot


func _spot_clear(spot: Vector2, placed: PackedVector2Array) -> bool:
	# Compare in this task's space, so a transformed root cannot drop items on the walker.
	if spot.distance_to(to_local(_walker.global_position)) < WALKER_CLEARANCE:
		return false
	for other: Vector2 in placed:
		if spot.distance_to(other) < ITEM_GAP:
			return false
	return true


## Bins are our own children, so a second task instance can never wire in.
func _connect_bins() -> void:
	for child: Node in get_children():
		var bin := child as SortBin
		if bin != null and not bin.touched.is_connected(_on_bin_touched):
			bin.touched.connect(_on_bin_touched.bind(bin))


## Pickup: only while the run is live and the walker's hands are empty.
func _on_item_touched(_body: Node2D, item: SortItem) -> void:
	if not running:
		return
	if _carried() != "":
		return
	_set_carried(item.kind)
	item.queue_free()
	_update_carried_label()
	_pop_carried_label()


## Deposit: the right bin counts, any bin clears the hands, a wrong bin loses the item.
func _on_bin_touched(_body: Node2D, bin: SortBin) -> void:
	if not running:
		return
	var carried := _carried()
	if carried == "":
		return
	if carried == bin.kind:
		sorted_correct += 1
	_set_carried("")
	_update_carried_label()


func _build_carried_label() -> void:
	if _carried_label != null:
		return
	var label := Label.new()
	label.name = "CarriedLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 34.0)
	var settings := LabelSettings.new()
	settings.font_size = 26
	settings.font_color = Color.WHITE
	settings.outline_size = 10
	settings.outline_color = Color(0.13, 0.11, 0.09, 0.9)
	label.label_settings = settings
	label.hide()
	add_child(label)
	_carried_label = label


func _update_carried_label() -> void:
	if _carried_label == null or _walker == null:
		return
	var carried := _carried()
	_carried_label.visible = carried != ""
	if carried == "":
		return
	_carried_label.text = carried.capitalize()
	_carried_label.position = to_local(_walker.global_position) + LABEL_LIFT


## A tiny pop, so a pickup feels handled.
func _pop_carried_label() -> void:
	var tween := create_tween()
	tween.tween_property(_carried_label, "scale", Vector2(1.3, 1.3), 0.0)
	tween.tween_property(_carried_label, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
