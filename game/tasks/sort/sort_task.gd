class_name SortTask
extends Task
## The waste sorting task: carry each item to its labelled bin before time runs out.

const BASE_ITEMS := 8
const KINDS: Array[String] = ["plastic", "paper", "glass", "metal"]
const ITEM_SCENE: PackedScene = preload("res://tasks/sort/sort_item.tscn")
## Ebru's waste, by the bin it belongs in. A juice carton is mostly card, so it goes with paper.
const ITEM_ART := {
	"plastic": [preload("res://tasks/sort/art/bag.png")],
	"paper": [preload("res://tasks/sort/art/paper.png"), preload("res://tasks/sort/art/carton.png")],
	"glass": [preload("res://tasks/sort/art/bottle.png")],
	"metal": [preload("res://tasks/sort/art/can.png")],
}
const ITEM_TILT := 0.4
## The pavement and road beside Ebru's bins, near enough for a full round in the time.
const FIELD := Rect2(120.0, 590.0, 900.0, 320.0)
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
const VERDICT_LIFT := Vector2(-100.0, -120.0)
const VERDICT_RIGHT := Color(0.72, 0.95, 0.6)
const VERDICT_WRONG := Color(1.0, 0.72, 0.6)

@export var seconds := 40.0
## 0 randomizes the layout each run; a nonzero seed makes it repeatable.
@export var layout_seed := 0
## Art drop-in for the placeholder walker we spawn; the room's own walker needs none.
@export var walker_art: Texture2D

var total_items := 0
var sorted_correct := 0
var time_left := 0.0
var running := false

var _carried_art: Texture2D
var _returning := 0
var _walker: CharacterBody2D
var _own_walker := false
var _rng := RandomNumberGenerator.new()
var _carried_label: Label

@onready var hint: SortHint = $Hint
@onready var hud: SortHud = $Hud


func _init() -> void:
	action = "sort"


func _begin() -> void:
	if not is_node_ready():
		await ready
	total_items = target_count(BASE_ITEMS)
	seconds = target_time(seconds)
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
	if time_left <= 0.0 or (_items_left() == 0 and _returning == 0 and _carried() == ""):
		_end()


func instruction() -> CanvasItem:
	return hint


func result_text() -> String:
	return "%d of %d sorted" % [sorted_correct, total_items]


func debug_note() -> String:
	var item := Vector2(-1, -1)
	for child: Node in get_children():
		if child is SortItem and not child.is_queued_for_deletion():
			item = (child as SortItem).position
			break
	return "%d %d %s %d %d" % [sorted_correct, total_items, _carried() if _carried() != "" else "none", item.x, item.y]


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
		var kind := KINDS[i % KINDS.size()]
		var pictures: Array = ITEM_ART[kind]
		var spot := _item_spot(placed)
		placed.append(spot)
		_add_item(kind, pictures[i / KINDS.size() % pictures.size()], spot)


func _add_item(kind: String, art: Texture2D, spot: Vector2) -> void:
	var item := ITEM_SCENE.instantiate() as SortItem
	item.kind = kind
	item.art = art
	item.flipped = _rng.randf() < 0.5
	item.rotation = _rng.randf_range(-ITEM_TILT, ITEM_TILT)
	item.position = spot
	item.add_to_group(ITEM_GROUP)
	item.touched.connect(_on_item_touched.bind(item))
	add_child(item)


## A slip costs the walk, not the item.
func _put_back(kind: String, art: Texture2D) -> void:
	_returning -= 1
	if not running:
		return
	var placed := PackedVector2Array()
	for node: Node in get_tree().get_nodes_in_group(ITEM_GROUP):
		if is_ancestor_of(node) and not node.is_queued_for_deletion():
			placed.append((node as SortItem).position)
	_add_item(kind, art, _item_spot(placed))


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
	_carried_art = item.art
	Sfx.play("pickup")
	item.queue_free()
	_update_carried_label()
	_pop_carried_label()


## Deposit: the right bin counts, any bin clears the hands, a wrong bin sends the item back.
func _on_bin_touched(_body: Node2D, bin: SortBin) -> void:
	if not running:
		return
	var carried := _carried()
	if carried == "":
		return
	var correct := carried == bin.kind
	if correct:
		sorted_correct += 1
	else:
		# Physics objects can't be added while the physics server reports this touch.
		_returning += 1
		_put_back.call_deferred(carried, _carried_art)
	Sfx.play("drop" if correct else "knock")
	_set_carried("")
	_update_carried_label()
	_show_verdict(bin, correct)


## The painted bins cannot react, so a short word rises from the bin that was used.
func _show_verdict(bin: SortBin, correct: bool) -> void:
	var label := Label.new()
	label.text = "+1" if correct else "Wrong bin"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 34.0)
	label.pivot_offset = Vector2(LABEL_WIDTH * 0.5, 17.0)
	label.position = bin.position + VERDICT_LIFT
	var settings := LabelSettings.new()
	settings.font_size = Settings.sized(34)
	settings.font_color = VERDICT_RIGHT if correct else VERDICT_WRONG
	settings.outline_size = 10
	settings.outline_color = Color(0.13, 0.11, 0.09, 0.9)
	label.label_settings = settings
	add_child(label)
	label.scale = Vector2(1.4, 1.4)
	var tween := create_tween().bind_node(label).set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 46.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.6)
	tween.chain().tween_callback(label.queue_free)


func _build_carried_label() -> void:
	if _carried_label != null:
		return
	var label := Label.new()
	label.name = "CarriedLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 34.0)
	var settings := LabelSettings.new()
	settings.font_size = Settings.sized(26)
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
