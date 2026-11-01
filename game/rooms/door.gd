class_name Door
extends Area2D
## Sends the walker to another room when touched.

## Arda's physics body reaches its new spot a step after a room change. Until then it still
## sits at the old room's coordinates, where it could touch a door here by accident.
const SETTLE_STEPS := 2
const PLACE_NAMES := {
	"bedroom": "Arda's room", "aylin": "Ayla's room", "salon": "Salon", "street": "Street", "shore": "Shore",
}
const LABEL_FADE_PER_SECOND := 6.0
const LABEL_SIZE := Vector2(260, 56)
const LABEL_LEFT := -130.0
const INK := Color(0.97, 0.95, 0.88)
const OUTLINE := Color(0.2, 0.17, 0.14)

@export var target_room: String = ""
@export var arrive_at: Vector2 = Vector2.ZERO
## How far above the door's foot its name sits. High enough to clear a person standing there.
@export var label_lift := 92.0

var _settling := SETTLE_STEPS
var _label: Label


func _ready() -> void:
	monitoring = false
	body_entered.connect(_on_body_entered)
	_label = Label.new()
	_label.text = PLACE_NAMES.get(target_room, "")
	_label.size = LABEL_SIZE
	_label.position = Vector2(LABEL_LEFT, -label_lift)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.z_index = 2
	_label.modulate.a = 0.0
	_label.add_theme_font_size_override("font_size", 36)
	_label.add_theme_color_override("font_color", INK)
	_label.add_theme_color_override("font_outline_color", OUTLINE)
	_label.add_theme_constant_override("outline_size", 10)
	add_child(_label)


## Every door stays named, because the doors all look alike. Tasks get the room to themselves.
func _process(delta: float) -> void:
	var goal := 0.0 if (get_parent() as Room).hold_view else 1.0
	_label.modulate.a = move_toward(_label.modulate.a, goal, LABEL_FADE_PER_SECOND * delta)


func _physics_process(_delta: float) -> void:
	_settling -= 1
	if _settling == 0:
		monitoring = true
		set_physics_process(false)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("walker"):
		(get_parent() as Room).door_used.emit(target_room, arrive_at)
