class_name EndSequence
extends CanvasLayer
## The end-of-run sequence. Six quiet steps, advanced by interact, Next or a click.

signal retry_requested
signal code_loaded(code: String)

const ENDING_CAPTIONS := {
	"full": "Old Arda and the child they once were plant dune grass side by side. The homes still stand.",
	"partial": "The street survives in part. Arda sits on the step of the home that remains.",
	"none": "Arda packs the teddy and closes the door. Another future can be drawn.",
}
## Earned by filling Brian's bowls on all three days.
const FED_LINE := " Brian never went hungry."
const RETRY_LINE := "Go back to 2026 and draw a different future."
## What the sim says would have helped most, so a loss always leaves something to try.
const TRY_LINES := {
	"grass": "Next time, plant more seagrass.",
	"dune": "Next time, plant more of the dunes.",
	"sort": "Next time, sort more waste.",
	"light": "Next time, switch off more lights.",
	"meet": "Next time, talk to more neighbours.",
	"wall": "Next time, build more of the seawall.",
}
const GHOST_CAPTION := "Each mark is a future you tried. The bright one is your newest."
## The chart only means something once there is a past future to compare with.
const GHOSTS_TO_COMPARE := 2
const FADE_SECONDS := 0.2

@onready var click: Button = $ClickCatch
@onready var next: Button = $Next
@onready var picture: EndingPicture = $Steps/EndingStep/Picture
@onready var ending_caption: Label = $Steps/EndingStep/Caption
@onready var rank_card: RankCard = $Steps/RankStep
@onready var chart: GhostChart = $Steps/GhostStep/Chart
@onready var ghost_step: Control = $Steps/GhostStep
@onready var ghost_caption: Label = $Steps/GhostStep/Caption
@onready var share_card: ShareCard = $Steps/ShareStep
@onready var retry_button: Button = $Steps/RetryStep/Retry
@onready var retry_body: Label = $Steps/RetryStep/Body
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
	Settings.size_text(ending_caption, 38)
	Settings.size_text(ghost_caption, 38)
	Settings.size_text(retry_body, 40)
	Settings.size_text(retry_button, 36)
	Settings.size_text(next, 34)
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		click.add_theme_stylebox_override(state, empty)
	click.pressed.connect(advance)
	next.pressed.connect(advance)
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
	retry_body.text = _retry_line(int(outcome.get("homes", 0)))
	chart.set_depths(Run.ghosts)
	ghost_caption.text = GHOST_CAPTION
	share_card.set_code(Run.plan.code())
	_show(0)


func _retry_line(homes: int) -> String:
	var tip: String = TRY_LINES.get(Sim.best_fix(Run.plan), "")
	if homes >= Sim.ALL_HOMES or tip == "":
		return RETRY_LINE
	return "%s %s" % [RETRY_LINE, tip]


func step_index() -> int:
	return _current


func advance() -> void:
	if _current < 0:
		return
	if _current >= steps.size() - 1:
		retry_requested.emit()
		return
	var step_after := _current + 1
	if steps[step_after] == ghost_step and Run.ghosts.size() < GHOSTS_TO_COMPARE:
		step_after += 1
	_show(step_after)


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
