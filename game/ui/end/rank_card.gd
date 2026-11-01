class_name RankCard
extends Control
## Where your plan ranks among the 462 possible plans.

const PLANS_PATH := "res://data/plans.json"
const TITLE := "Your plan ranks"
const SUB_LINE := "of 462 possible plans. 1 is the best."
const KEEPER_CAPTION := "All 462 futures were tested. Yours is one of the %d that keep every home."
const OTHER_CAPTION := "All 462 futures were tested. %d keep every home. Yours can be one of them."
const EMPTY_CAPTION := "Finish all six choices to earn a rank."
## The rank arrives by settling, a touch small at first. No bounce.
const ARRIVE_SECONDS := 0.3
const SETTLE_FROM := 0.98
const SETTLE_SECONDS := 0.45

var _entries: Array = []
var _number: Label
var _sub: Label
var _caption: Label
var _entrance: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wide_label("Title", TITLE, EndPalette.TITLE_SIZE, EndPalette.INK, 170, 250))
	_number = _wide_label("Number", "-", EndPalette.RANK_SIZE, EndPalette.INK, 255, 440)
	_caption = _wide_label("Caption", "", EndPalette.BODY_SIZE, EndPalette.INK, 650, 710)
	_sub = _wide_label("Sub", SUB_LINE, 28, EndPalette.FADED, 452, 500)
	Settings.size_text(_caption, EndPalette.BODY_SIZE)
	Settings.size_text(_sub, 34)
	add_child(_number)
	add_child(_sub)
	add_child(_caption)


func show_rank() -> int:
	var code := Run.plan.code()
	var rank := 0
	var keepers := 0
	var homes := 0
	for entry: Dictionary in _load():
		if String(entry.get("code", "")) == code:
			rank = int(entry.get("rank", 0))
			homes = int(entry.get("homes", 0))
		if int(entry.get("homes", 0)) == Sim.ALL_HOMES:
			keepers += 1
	if rank > 0:
		_number.text = str(rank)
		_sub.visible = true
		if homes == Sim.ALL_HOMES:
			_caption.text = KEEPER_CAPTION % keepers
		else:
			_caption.text = OTHER_CAPTION % keepers
	else:
		_number.text = "-"
		_sub.visible = false
		_caption.text = EMPTY_CAPTION
	return rank


## Back to rest, so a quick skip leaves the card whole.
func rest_entrance() -> void:
	scale = Vector2.ONE
	modulate.a = 1.0


func play_entrance() -> Tween:
	if _entrance != null and _entrance.is_valid():
		_entrance.kill()
	pivot_offset = size * 0.5
	scale = Vector2.ONE * SETTLE_FROM
	modulate.a = 0.0
	_entrance = create_tween()
	_entrance.set_parallel(true)
	_entrance.tween_property(self, "modulate:a", 1.0, ARRIVE_SECONDS) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_entrance.tween_property(self, "scale", Vector2.ONE, SETTLE_SECONDS) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return _entrance


func _load() -> Array:
	if _entries.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLANS_PATH))
		if parsed is Array:
			_entries = parsed
	return _entries


func _wide_label(label_name: String, text: String, font_size: int, color: Color, top: int, bottom: int) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.offset_top = top
	label.offset_bottom = bottom
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
