extends Node
## Bot-driven demo for the end sequence. Asserts the real UI, prints DEMO PASS, quits.

const SEQUENCE := preload("res://ui/end/end_sequence.tscn")
const PLANS_PATH := "res://data/plans.json"

const FULL_CAPTION := "Old Arda and the child they once were plant dune grass side by side. The homes still stand."
const PARTIAL_CAPTION := "The street survives in part. Arda sits on the step of the home that remains."
const NONE_CAPTION := "Arda packs the teddy and closes the door. Another future can be drawn."
const GHOST_CAPTION := "Each mark is a future you tried. The bright one is your newest."
const KEEPER_CAPTION := "All 462 futures were tested. Yours is one of the %d that keep every home."
const NOT_FOUND_CAPTION := "Finish all six choices to earn a rank."
const BAD_CODE_MESSAGE := "That code doesn't match a plan. Check the three letters."
const LOADED_MESSAGE := "Loaded. Their future is ready."
const NO_CODE_LINE := "Finish all six choices to get a code of your own."
const CREDITS := "Art by Ebru. Built with help from AI tools for code and writing drafts. Fonts: Caveat and Playfair Display (SIL Open Font License). Music rendered with FluidSynth and the FluidR3 GM SoundFont (MIT license). Sound effects made by our own scripts."
const LINK_TEXT := "Learn more about climate adaptation"
const CARD_TITLES := ["The sea", "Storms", "Seagrass", "Waste", "Seawalls", "This game"]
const CARD_BODIES := [
	"The world's seas are rising, and how far depends on us. These numbers follow IPCC projections, counted from 2026 rather than the IPCC's 1995 to 2014 baseline.",
	"A higher sea lets storms reach further inland, more often. The water you see is the year's worst storm at its peak, not a permanent level.",
	"Mediterranean seagrass cuts wave height by about 20 to 30 percent. Real meadows recover far more slowly than in this game, and they also lock away carbon.",
	"Plastic blocking drains puts over 200 million people at risk of worse flooding.",
	"Well-built walls can protect dense cities. Ours failed because it was built fast and then neglected. Its harm to the meadow is a simplified game rule.",
	"The country is fictional and the model is simplified. It shows how choices connect, not what will happen anywhere real. COP 31 topics: seas, resilient cities, zero waste, climate education.",
]

var failed := false
var fail_count := 0
var retry_count := 0
var loaded_codes: Array[String] = []
var seq: EndSequence
var _plans: Array = []
var _calm_before := false
var _large_before := false


func _ready() -> void:
	_calm_before = Settings.calm_storm
	_large_before = Settings.large_text
	Settings.set_options(false, false)
	seq = SEQUENCE.instantiate()
	add_child(seq)
	seq.retry_requested.connect(_on_retry)
	seq.code_loaded.connect(_on_code)
	await _frames(2)

	_check_retry_lines()
	Run.plan = Plan.from_code("3AT")
	Run.ghosts.clear()
	Run.ghosts.append(0.9)
	Run.ghosts.append(1.3)
	Run.ghosts.append(0.371)
	var outcome: Dictionary = Sim.outcome(Run.plan)
	seq.play(outcome)
	await _frames(2)

	check(seq.step_index() == 0, "play restarts at step 0")
	check(seq.steps[0].visible, "the ending step is visible")
	check(seq.picture.variant == "full", "both homes draw the full variant, got %s" % seq.picture.variant)
	check(seq.ending_caption.text == FULL_CAPTION, "full caption text, got '%s'" % seq.ending_caption.text)
	if failed:
		_finish()
		return

	await _tap()
	check(seq.step_index() == 1, "interact advances to the rank step")
	check(seq.steps[1].visible, "the rank step is visible")
	var number := seq.get_node("Steps/RankStep/Number") as Label
	var caption := seq.get_node("Steps/RankStep/Caption") as Label
	var expected_rank := _rank_of("3AT")
	var keepers := _keepers()
	check(expected_rank == 1, "the sample plan 3AT ranks 1, got %d" % expected_rank)
	check(number != null and number.text == str(expected_rank), "the rank label shows %d, got '%s'" % [expected_rank, number.text if number != null else ""])
	check(caption != null and caption.text == KEEPER_CAPTION % keepers, "keeper caption, got '%s'" % caption.text if caption != null else "no caption")
	check(seq.rank_card.show_rank() == expected_rank, "show_rank returns the plan rank")
	if failed:
		_finish()
		return

	seq.next.pressed.emit()
	check(not seq.chart.marks_fully_shown(), "the chart marks arrive one by one")
	await _frames(2)
	check(seq.step_index() == 2, "Next advances to the ghost step")
	check(seq.steps[2].visible, "the ghost step is visible")
	check(seq.chart.depths == [0.9, 1.3, 0.371], "the chart holds the run ghosts, got %s" % str(seq.chart.depths))
	check(seq.chart.newest_index() == 2, "the newest ghost is the last one")
	check(seq.ghost_caption.text == GHOST_CAPTION, "ghost caption text, got '%s'" % seq.ghost_caption.text)
	if failed:
		_finish()
		return

	seq.click.pressed.emit()
	await _frames(2)
	check(seq.step_index() == 3, "a background click advances to the real step")
	check(seq.steps[3].visible, "the real step is visible")
	for i: int in CARD_BODIES.size():
		var body := seq.get_node("Steps/RealStep/Box/Grid/Card%d/Inner/Body" % i) as Label
		var title := seq.get_node("Steps/RealStep/Box/Grid/Card%d/Inner/Title" % i) as Label
		check(body != null and body.text == String(CARD_BODIES[i]), "card %d body text" % i)
		check(title != null and title.text == String(CARD_TITLES[i]), "card %d title text" % i)
	var credits := seq.get_node("Steps/RealStep/Box/Credits") as Label
	check(credits != null and credits.text == CREDITS, "credits line exact, got '%s'" % credits.text if credits != null else "no credits")
	var link := seq.get_node("Steps/RealStep/Box/Link") as LinkButton
	check(link != null and link.text == LINK_TEXT, "the learn-more link exists with its caption")
	if failed:
		_finish()
		return

	await _tap()
	check(seq.step_index() == 4, "interact advances to the share step")
	check(seq.steps[4].visible, "the share step is visible")
	var code_label := seq.get_node("Steps/ShareStep/Code") as Label
	check(code_label != null and code_label.text == "3AT", "the big code label shows 3AT")
	var share_line := seq.get_node("Steps/ShareStep/Line") as Label
	check(share_line != null and share_line.text == "Share it, and a friend can walk your future.", "the share line under the code")
	var edit := seq.get_node("Steps/ShareStep/RowCenter/Row/Edit") as LineEdit
	var message := seq.get_node("Steps/ShareStep/Message") as Label
	check(edit != null, "the friend code box exists")
	check(message != null, "the message label exists")
	edit.text = "ZZZ"
	edit.text_submitted.emit("ZZZ")
	await _frames(2)
	check(message.visible, "the invalid code message is visible")
	check(message.text == BAD_CODE_MESSAGE, "invalid code message text, got '%s'" % message.text)
	check(loaded_codes.is_empty(), "an invalid code loads nothing")
	edit.text = "bfn"
	edit.text_submitted.emit("bfn")
	await _frames(2)
	check(loaded_codes.size() == 1 and loaded_codes[0] == "BFN", "a lowercase friend code loads BFN, got %s" % str(loaded_codes))
	check(message.visible and message.text == LOADED_MESSAGE, "the loaded message shows")
	if failed:
		_finish()
		return

	await _tap()
	check(seq.step_index() == 5, "interact advances to the retry step")
	check(seq.steps[5].visible, "the retry step is visible")
	(seq.get_node("Steps/RetryStep/Retry") as Button).pressed.emit()
	await _frames(2)
	check(retry_count == 1, "the retry button asks for a retry, count %d" % retry_count)
	if failed:
		_finish()
		return

	seq.play(Sim.outcome(Plan.from_code("00S")))
	await _frames(2)
	check(not message.visible and edit.text.is_empty(), "a fresh play clears the share message and box")
	check(seq.picture.variant == "partial", "one home draws the partial variant, got %s" % seq.picture.variant)
	check(seq.ending_caption.text == PARTIAL_CAPTION, "partial caption text")
	seq.play(Sim.outcome(Plan.from_code("3Y6")))
	await _frames(2)
	check(seq.picture.variant == "partial", "one home draws the partial variant, got %s" % seq.picture.variant)
	check(seq.ending_caption.text == PARTIAL_CAPTION, "partial caption text for one home")
	seq.play(Sim.outcome(Plan.from_code("24F")))
	await _frames(2)
	check(seq.picture.variant == "none", "no homes draw the none variant, got %s" % seq.picture.variant)
	check(seq.ending_caption.text == NONE_CAPTION, "none caption text")
	if failed:
		_finish()
		return

	Run.ghosts.clear()
	seq.play(Sim.outcome(Run.plan))
	await _frames(2)
	await _tap()
	check(seq.step_index() == 1, "at the rank step with cleared ghosts")
	var rank_number := seq.get_node("Steps/RankStep/Number") as Label
	check(rank_number != null and rank_number.text == "1", "the rank still shows 1")
	await _tap()
	check(seq.step_index() == 3, "with nothing to compare, the ghost chart is skipped")
	check(seq.chart.depths.is_empty(), "cleared ghosts empty the chart")
	check(seq.chart.newest_index() == -1, "no newest ghost when the chart is empty")
	if failed:
		_finish()
		return

	Run.plan = Plan.new()
	seq.play(Sim.outcome(Run.plan))
	await _frames(2)
	await _tap()
	check(seq.step_index() == 1, "at the rank step without a code")
	var empty_number := seq.get_node("Steps/RankStep/Number") as Label
	var empty_caption := seq.get_node("Steps/RankStep/Caption") as Label
	check(empty_number != null and empty_number.text == "-", "without a code the rank shows a dash")
	check(empty_caption != null and empty_caption.text == NOT_FOUND_CAPTION, "without a code the rank caption guides gently")
	await _tap()
	await _tap()
	check(seq.step_index() == 4, "at the share step without a code")
	var no_code := seq.get_node("Steps/ShareStep/Code") as Label
	var no_line := seq.get_node("Steps/ShareStep/Line") as Label
	check(no_code != null and no_code.text == "-", "without a code the share step shows a dash")
	check(no_line != null and no_line.text == NO_CODE_LINE, "the no-code share line")
	if failed:
		_finish()
		return

	var guard := 0
	while not seq.share_card.warm_ready() and guard < 3000:
		await get_tree().process_frame
		guard += 1
	check(seq.share_card.warm_ready(), "the code map finishes warming, %d frames" % guard)
	edit.text = "ZZZ"
	edit.text_submitted.emit("ZZZ")
	await _frames(2)
	check(message.visible and message.text == BAD_CODE_MESSAGE, "a cached invalid code still gets the gentle message")
	check(loaded_codes.size() == 1, "a cached invalid code loads nothing, got %s" % str(loaded_codes))
	edit.text = "00s"
	edit.text_submitted.emit("00s")
	await _frames(2)
	check(loaded_codes.size() == 2 and loaded_codes[1] == "00S", "a warmed code loads without freezing, got %s" % str(loaded_codes))
	check(message.visible and message.text == LOADED_MESSAGE, "the warmed load message shows")
	if failed:
		_finish()
		return

	## Each step has its own small entrance, right after it appears.
	Run.plan = Plan.from_code("3AT")
	Run.ghosts.assign([0.9, 1.3, 0.371])
	seq.play(Sim.outcome(Run.plan))
	seq.click.pressed.emit()
	check(is_equal_approx(seq.rank_card.scale.x, RankCard.SETTLE_FROM), "the rank card starts its settle a touch small")
	check(seq.steps[1].modulate.a == 0.0, "the rank step still fades in from hidden")
	seq.click.pressed.emit()
	check(not seq.chart.marks_fully_shown(), "the chart holds its marks back at first")
	check(seq.ghost_caption.modulate.a == 0.0, "the ghost caption waits with the marks")
	seq.click.pressed.emit()
	var staggered_card := seq.get_node("Steps/RealStep/Box/Grid/Card0") as Control
	check(staggered_card != null and staggered_card.modulate.a == 0.0, "the real cards stagger in from hidden")
	seq.click.pressed.emit()
	var settle_code := seq.get_node("Steps/ShareStep/Code") as Control
	check(settle_code != null and settle_code.modulate.a == 0.0, "the plan code fades in")
	check(settle_code != null and is_equal_approx(settle_code.scale.x, ShareCard.CODE_SETTLE_FROM), "the plan code settles a touch small")
	seq.click.pressed.emit()
	check(seq.retry_button.modulate.a == 0.0, "the retry button arrives last")
	if failed:
		_finish()
		return

	## Calm storm keeps every entrance a plain fade.
	Settings.set_options(true, false)
	seq.play(Sim.outcome(Run.plan))
	seq.click.pressed.emit()
	check(seq.rank_card.scale == Vector2.ONE, "calm storm keeps the rank from settling smaller")
	check(seq.steps[1].modulate.a == 0.0, "the calm rank step still fades in from hidden")
	seq.click.pressed.emit()
	check(seq.chart.marks_fully_shown(), "calm storm shows every mark at once")
	seq.click.pressed.emit()
	var calm_card := seq.get_node("Steps/RealStep/Box/Grid/Card0") as Control
	check(calm_card != null and calm_card.modulate.a == 1.0, "calm storm keeps the cards plainly visible")
	if failed:
		_finish()
		return

	## Larger text must not break the sequence or its layout.
	Settings.set_options(false, true)
	seq.play(Sim.outcome(Run.plan))
	await _frames(2)
	check(seq.ending_caption.get_theme_font_size("font_size") == Settings.sized(38), "the ending caption grows under larger text")
	seq.click.pressed.emit()
	await _frames(2)
	check(seq.step_index() == 1, "larger text still reaches the rank step")
	var big_caption := seq.get_node("Steps/RankStep/Caption") as Label
	var big_number := seq.get_node("Steps/RankStep/Number") as Label
	check(big_caption != null and big_caption.get_theme_font_size("font_size") == Settings.sized(EndPalette.BODY_SIZE), "the rank caption grows under larger text")
	check(big_number != null and big_number.text == "1", "the rank number still reads 1 under larger text")
	Settings.set_options(false, false)
	if failed:
		_finish()
		return

	Run.plan = Plan.from_code("3AT")
	Run.ghosts.assign([0.9, 1.3])
	seq.play(Sim.outcome(Run.plan))
	await _frames(2)
	for expected: int in 6:
		check(seq.step_index() == expected, "final pass reaches step %d" % expected)
		await _tap()
	check(retry_count == 2, "moving on from the end is a retry, count %d" % retry_count)
	_finish()


func check(condition: bool, msg: String) -> void:
	if not condition:
		failed = true
		fail_count += 1
		print("DEMO FAIL: %s" % msg)


func _finish() -> void:
	Settings.set_options(_calm_before, _large_before)
	if failed:
		print("DEMO FAIL: %d checks failed" % fail_count)
		get_tree().quit(1)
		return
	print("DEMO PASS")
	get_tree().quit()


func _tap() -> void:
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(2)
	press.pressed = false
	Input.parse_input_event(press)
	await _frames(1)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


## A loss says what to try next. A plan that saved everyone gets no advice.
func _check_retry_lines() -> void:
	for plan: Plan in Plan.all_plans():
		var fix := Sim.best_fix(plan)
		if fix == "" or int(Sim.outcome(plan)["homes"]) >= Sim.ALL_HOMES:
			continue
		Run.plan = plan
		seq.play(Sim.outcome(plan))
		check(seq.retry_body.text.ends_with(String(EndSequence.TRY_LINES[fix])), "a loss gets a tip, got '%s'" % seq.retry_body.text)
		break
	Run.plan = Plan.from_code("3AT")
	seq.play(Sim.outcome(Run.plan))
	check(seq.retry_body.text == EndSequence.RETRY_LINE, "a full save gets the plain line, got '%s'" % seq.retry_body.text)


func _rank_of(code: String) -> int:
	for entry: Dictionary in _plans_data():
		if String(entry.get("code", "")) == code:
			return int(entry.get("rank", 0))
	return 0


func _keepers() -> int:
	var total := 0
	for entry: Dictionary in _plans_data():
		if int(entry.get("homes", 0)) == Sim.ALL_HOMES:
			total += 1
	return total


func _plans_data() -> Array:
	if _plans.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLANS_PATH))
		if parsed is Array:
			_plans = parsed
	return _plans


func _on_retry() -> void:
	retry_count += 1


func _on_code(code: String) -> void:
	loaded_codes.append(code)
