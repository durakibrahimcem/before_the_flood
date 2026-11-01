extends Node
## Gives every button in the game the same soft press, wherever it was built.

const PRESS_SCALE := Vector2(0.95, 0.95)
const HOVER_SCALE := Vector2(1.03, 1.03)
const PRESS_SECONDS := 0.06
const RELEASE_SECONDS := 0.16


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	var button := node as Button
	if button == null:
		return
	button.resized.connect(_centre.bind(button))
	button.ready.connect(_centre.bind(button))
	button.button_down.connect(_ease_to.bind(button, PRESS_SCALE, PRESS_SECONDS))
	button.button_up.connect(_ease_to.bind(button, Vector2.ONE, RELEASE_SECONDS))
	button.mouse_entered.connect(_ease_to.bind(button, HOVER_SCALE, RELEASE_SECONDS))
	button.mouse_exited.connect(_ease_to.bind(button, Vector2.ONE, RELEASE_SECONDS))


func _centre(button: Button) -> void:
	button.pivot_offset = button.size * 0.5


func _ease_to(button: Button, goal: Vector2, seconds: float) -> void:
	if button.has_meta(&"motion"):
		(button.get_meta(&"motion") as Tween).kill()
	var tween := button.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(button, "scale", goal, seconds)
	button.set_meta(&"motion", tween)
