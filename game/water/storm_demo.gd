extends Node
## Gate demo: the storm follows the flood, stays outdoors, and respects calm storm.

const STORM := preload("res://water/storm.tscn")


func _ready() -> void:
	Run.new_run()
	var storm: Storm = STORM.instantiate()
	add_child(storm)
	await get_tree().process_frame
	assert(not storm.raging and not storm.rain.emitting, "no storm in 2026")
	WorldClock.scrub(2080.0)
	assert(storm.raging, "a flooded future has a storm")
	assert(not storm.rain.emitting, "no rain indoors")
	storm.outdoors = true
	WorldClock.refresh()
	assert(storm.rain.emitting, "rain falls outdoors")
	storm.strike()
	var waited := 0
	while storm.flash.color.a <= 0.0 and waited < 60:
		await get_tree().process_frame
		waited += 1
	assert(storm.flash.color.a > 0.0, "lightning lights the screen")
	await get_tree().create_timer(0.6).timeout
	assert(is_zero_approx(storm.flash.color.a), "the flash fades away")
	Settings.set_options(true, false)
	storm.strike()
	await get_tree().create_timer(0.04).timeout
	assert(is_zero_approx(storm.flash.color.a), "calm storm has no flashes")
	Settings.set_options(false, false)
	WorldClock.scrub(2026.0)
	assert(not storm.raging and not storm.rain.emitting, "the storm clears back in 2026")
	print("DEMO PASS")
	get_tree().quit()
