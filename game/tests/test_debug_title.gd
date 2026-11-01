extends SceneTree
## Run: tools/g --headless --path game --script tests/test_debug_title.gd
## Guards the tab-title debug protocol used by browser tests (time_control.gd).

var failures := 0


func _initialize() -> void:
	_test_full_state()
	_test_bools_never_break_the_format()
	print("RESULT: %s (%d failed)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _expect(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAILED: ", label)


func _sample_values() -> Dictionary:
	return {
		"year": 2080.0, "scrub": true, "where": "shore 300 800", "task": "wall 0 6",
		"cal": false, "news": true, "pause": false, "ctrl": false, "end": true,
		"step": 3, "verdict": true, "day": 2, "plan": "1,1,1,1,1,1", "ghosts": 4,
		"fed": true, "final": false, "frozen": true, "calm": true, "large": false,
		"vol": 0.5, "hover": "Retry", "rect": "860,540,200,72", "focus": "none",
	}


func _test_full_state() -> void:
	var title := TimeControl.format_title(_sample_values())
	_expect(title == "YEAR 2080.0 SCRUB 1 ROOM shore 300 800 TASK wall 0 6 | CAL 0 NEWS 1 PAUSE 0 CTRL 0 END 1 STEP 3 VERDICT 1 DAY 2 PLAN 1,1,1,1,1,1 GHOSTS 4 FED 1 FINAL 0 FROZEN 1 CALM 1 LARGE 0 VOL 0.50 HOVER Retry RECT 860,540,200,72 FOCUS none", "the full state formats to the exact protocol line, got: %s" % title)


func _test_bools_never_break_the_format() -> void:
	# A bool passed to %d makes GDScript drop the whole format and emit the raw
	# template, which would leave every browser test blind. Regression for that.
	var values := _sample_values()
	values["scrub"] = false
	values["calm"] = false
	values["end"] = false
	var title := TimeControl.format_title(values)
	_expect(not title.contains("%"), "no format placeholder leaks into the title")
	_expect("SCRUB 0" in title and "CALM 0" in title and "END 0" in title, "false bools format as 0")
	var parts := title.split(" | ")
	_expect(parts.size() == 2, "the title keeps its two sections")
	var tokens := parts[1].split(" ")
	_expect(tokens.size() % 2 == 0, "the state section is key/value pairs")
