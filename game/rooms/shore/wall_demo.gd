extends Node
## Self-driving demo for the seawall's stone skin on the shore: the foot darkens
## as the years pass, cracks arrive before the breach, and calm foam shows where
## the drawn water meets the face. Prints DEMO PASS or DEMO FAIL, then quits.

const SHORE := preload("res://rooms/shore/shore.tscn")
## One seawall in the plan: it cracks from 2054 and breaches in 2062.
const WALL_PLAN_YEAR := 2050

var failures := 0
var passed := 0


func _ready() -> void:
	var was_calm := Settings.calm_storm
	Settings.calm_storm = false
	Run.new_run()
	Run.record("wall", 1.0)
	var room: Room = SHORE.instantiate()
	add_child(room)
	await get_tree().process_frame
	var wall := room.get_node("ShoreWall") as ShoreWall

	_check(wall.visible, "the wall stands across the shore")
	_check(absf(wall.stone_damp()) < 0.02, "a fresh wall has a dry foot (got %.2f)" % wall.stone_damp())
	_check(wall.stone_cracks() < 0.5, "a fresh wall is uncracked")
	_check(wall.foam_strength() < 0.05, "no foam while the beach is dry (got %.2f)" % wall.foam_strength())

	WorldClock.scrub(WALL_PLAN_YEAR)
	await get_tree().process_frame
	_check(wall.stone_damp() > 0.15, "the foot dampens by 2050 (got %.2f)" % wall.stone_damp())
	_check(wall.stone_cracks() < 0.5, "2050 is still before the crack years")
	_check(wall.foam_strength() < 0.05, "the standing wall still keeps the sea off (got %.2f)" % wall.foam_strength())

	WorldClock.scrub(2056.0)
	await get_tree().process_frame
	_check(wall.stone_cracks() > 0.5, "the crack years show cracks")
	_check(wall.stone_damp() > 0.5, "the damp has settled in by the crack years (got %.2f)" % wall.stone_damp())

	WorldClock.scrub(2080.0)
	await get_tree().process_frame
	_check(wall.foam_strength() > 0.5, "foam where the sea meets the broken wall (got %.2f)" % wall.foam_strength())
	var line := wall.foam_waterline_y()
	_check(line > 370.0 and line < 480.0, "the foam sits on the wall's face (got %.0f)" % line)

	Settings.calm_storm = true
	await get_tree().process_frame
	_check(wall.foam_strength() > 0.5, "calm storm keeps the foam, only still (got %.2f)" % wall.foam_strength())
	Settings.calm_storm = was_calm

	Run.new_run()
	await get_tree().process_frame
	_check(not wall.visible, "without a wall in the plan the shore has no wall")
	_check(wall.foam_strength() < 0.05, "no foam without the wall (got %.2f)" % wall.foam_strength())

	_finish()


func _check(ok: bool, what: String) -> void:
	if ok:
		passed += 1
		print("ok  " + what)
	else:
		failures += 1
		print("DEMO FAIL: " + what)


func _finish() -> void:
	print("checks: %d passed, %d failed" % [passed, failures])
	if failures > 0:
		print("DEMO FAIL: %d check(s) failed" % failures)
		get_tree().quit(1)
	else:
		print("DEMO PASS")
		get_tree().quit()
