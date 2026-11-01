class_name WrittenLabel
extends Label
## Each new line appears as if written out by hand. Whoever sets the text needs to know nothing about it.

const SECONDS_PER_CHARACTER := 0.016
const LONGEST_SECONDS := 0.7

var _written := ""
var _tween: Tween


func _process(_delta: float) -> void:
	if text == _written:
		return
	_written = text
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if text.is_empty() or Settings.calm_storm:
		visible_ratio = 1.0
		return
	visible_ratio = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "visible_ratio", 1.0, minf(text.length() * SECONDS_PER_CHARACTER, LONGEST_SECONDS))
