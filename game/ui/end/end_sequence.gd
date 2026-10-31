class_name EndSequence
extends CanvasLayer
## The end-of-run sequence. Six quiet steps, advanced by interact, Skip or a click.

signal retry_requested
signal code_loaded(code: String)

const ENDING_CAPTIONS := {
	"full": "Old Arda plants seagrass in a thriving meadow. The crayon child plants beside them.",
	"partial": "The street survives in part. Arda sits on the step of the home that remains.",
	"none": "Arda packs the teddy and closes the door. Another future can be drawn.",
}
## Earned by filling Brian's bowls on all three days.
const FED_LINE := " Brian never went hungry."
const GHOST_CAPTION := "Each mark is a future you tried. The bright one is your newest."
const GHOST_EMPTY_CAPTION := "No past futures yet. Try again, and the marks begin."
const FADE_SECONDS := 0.2

@onready var click: Button = $ClickCatch
@onready var skip: Button = $Skip
@onready var picture: EndingPicture = $Steps/EndingStep/Picture
@onready var ending_caption: Label = $Steps/EndingStep/Caption
@onready var rank_card: RankCard = $Steps/RankStep
@onready var chart: GhostChart = $Steps/GhostStep/Chart
@onready var ghost_caption: Label = $Steps/GhostStep/Caption
@onready var share_card: ShareCard = $Steps/ShareStep
@onready var retry_button: Button = $Steps/RetryStep/Retry
@onready var steps: Array[Control] = [
	$Steps/EndingStep,
	$Steps/RankStep,
	$Steps/GhostStep,
	$Steps/RealStep,
	$Steps/ShareStep,
	$Steps/RetryStep,
]

var _current := -1
var _fade: Tween


func _ready() -> void:
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		click.add_theme_stylebox_override(state, empty)
	click.pressed.connect(advance)
	skip.pressed.connect(advance)
	retry_button.pressed.connect(_on_retry_pressed)
	share_card.loaded.connect(_on_code_loaded)
	for step: Control in steps:
		step.hide()


func play(outcome: Dictionary) -> void:
	if not is_inside_tree():
		push_warning("EndSequence.play called before the sequence is in the tree")
		return
	visible = true
	picture.show_outcome(int(outcome.get("homes", 0)))
	ending_caption.text = String(ENDING_CAPTIONS.get(picture.variant, "")) + (FED_LINE if Run.meals >= Run.DAYS else "")
	rank_card.show_rank()
	chart.set_depths(Run.ghosts)
	ghost_caption.text = GHOST_EMPTY_CAPTION if Run.ghosts.is_empty() else GHOST_CAPTION
	share_card.set_code(Run.plan.code())
	_show(0)


func step_index() -> int:
	return _current


func advance() -> void:
	if _current < 0:
		return
	if _current >= steps.size() - 1:
		retry_requested.emit()
		return
	_show(_current + 1)


func _show(index: int) -> void:
	_current = index
	for step: Control in steps:
		step.hide()
	var step := steps[index]
	if _fade != null:
		_fade.kill()
	if is_inside_tree():
		get_viewport().gui_release_focus()
	step.modulate.a = 0.0
	step.show()
	_fade = create_tween()
	_fade.tween_property(step, "modulate:a", 1.0, FADE_SECONDS)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		advance()
		get_viewport().set_input_as_handled()


func _on_retry_pressed() -> void:
	retry_requested.emit()


func _on_code_loaded(code: String) -> void:
	code_loaded.emit(code)
