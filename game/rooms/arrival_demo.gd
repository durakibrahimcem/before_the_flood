extends Node
## Gate demo: a bot jumps the clock and checks that the water arrives instead of teleporting.

const SALON := preload("res://rooms/salon/salon.tscn")
## Every rise finishes well inside this, so the demo never hangs on a stuck tween.
const SETTLE_MS := 4000

var room: Room
var arrival: FloodArrival


func _ready() -> void:
	var was_calm := Settings.calm_storm
	Settings.calm_storm = false
	Run.new_run()
	room = SALON.instantiate()
	add_child(room)
	arrival = room.get_node("FloodArrival") as FloodArrival
	await get_tree().process_frame

	_check_dry_start()
	await _check_jump_arrives()
	_check_jump_back_snaps()
	await _check_scrub_wins_mid_rise()
	await _check_calm_stays_under()
	await _check_entry_arrival()
	Settings.calm_storm = was_calm

	remove_child(room)
	room.queue_free()
	await get_tree().process_frame
	print("DEMO PASS")
	get_tree().quit()


func _level(year: float) -> float:
	return float(Sim.at(Run.plan, year).flood_m["salon"])


func _check_dry_start() -> void:
	assert(arrival.material_count() >= 7, "the arrival sees every water material: %d" % arrival.material_count())
	assert(not arrival.is_rising(), "a dry room does not rise")
	assert(is_equal_approx(arrival.displayed_m(), 0.0), "the salon starts dry")
	assert(is_equal_approx(arrival.shader_flood_m(), 0.0), "the painting starts dry")


## The first big reveal: a tap must raise the water, not pop it.
func _check_jump_arrives() -> void:
	var peak := _level(WorldClock.ERAS[2])
	WorldClock.jump(WorldClock.ERAS[2])
	assert(arrival.is_rising(), "the jump starts a rise")
	assert(arrival.displayed_m() < peak * 0.5, "the water does not teleport: %.3f of %.3f" % [arrival.displayed_m(), peak])
	assert(is_equal_approx(room.flood_m, peak), "the true level is there at once for gameplay")
	var seen := await _sample_until_settled(peak)
	assert(seen["mid"], "the water was seen rising through the middle")
	assert(is_equal_approx(arrival.displayed_m(), peak), "the water settles at the era's level")
	assert(is_equal_approx(arrival.shader_flood_m(), peak), "the painting settles at the era's level")
	assert(seen["peak"] <= peak * 1.1 + 0.01, "the overshoot stays within the art's 10%%: %.3f" % seen["peak"])
	assert(arrival.surges == 1, "the big rise heaved once: %d" % arrival.surges)


## Gameplay stays identical: coming back to today never lags the water behind.
func _check_jump_back_snaps() -> void:
	WorldClock.jump(WorldClock.ERAS[0])
	assert(not arrival.is_rising(), "jumping back to today never rises")
	assert(is_equal_approx(arrival.displayed_m(), 0.0), "the water is gone at once")
	assert(is_equal_approx(arrival.shader_flood_m(), 0.0), "the painting is dry at once")


## A held scrub owns the water, so a rise must give way the moment the slider moves.
func _check_scrub_wins_mid_rise() -> void:
	WorldClock.jump(WorldClock.ERAS[2])
	# Wall clock, not frames: a slow machine's long frames must not skip the hold.
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 60 and arrival.displayed_m() < 0.05:
		await get_tree().process_frame
	assert(arrival.is_rising(), "the rise is under way")
	assert(arrival.displayed_m() < 0.1, "the hold keeps the old line")
	WorldClock.scrub(2040.0)
	var live := _level(2040.0)
	assert(not arrival.is_rising(), "the scrub cancels the rise")
	assert(is_equal_approx(arrival.displayed_m(), live), "the water follows the slider: %.3f" % arrival.displayed_m())


## Calm storm keeps the arrival, but never overshoots.
func _check_calm_stays_under() -> void:
	WorldClock.scrub(WorldClock.ERAS[0])
	Settings.calm_storm = true
	var peak := _level(WorldClock.ERAS[2])
	WorldClock.jump(WorldClock.ERAS[2])
	var seen := await _sample_until_settled(peak)
	Settings.calm_storm = false
	assert(is_equal_approx(arrival.displayed_m(), peak), "calm still arrives at the era's level")
	assert(seen["peak"] <= peak + 0.005, "calm never overshoots: %.3f" % seen["peak"])
	assert(seen["mid"], "calm still rises through the middle")
	assert(arrival.surges == 1, "calm storm keeps the heave off: %d" % arrival.surges)


## Walking into a flooded room: the water comes in with the player.
func _check_entry_arrival() -> void:
	WorldClock.scrub(WorldClock.ERAS[2])
	room.queue_free()
	for i: int in 2:
		await get_tree().process_frame
	room = SALON.instantiate()
	add_child(room)
	arrival = room.get_node("FloodArrival") as FloodArrival
	var peak := _level(WorldClock.ERAS[2])
	assert(arrival.is_rising(), "a flooded room arrives rising")
	var seen := await _sample_until_settled(peak)
	assert(seen["mid"], "the entered room was seen filling")
	assert(is_equal_approx(arrival.displayed_m(), peak), "the entered room settles at its level")
	assert(not arrival.is_rising(), "the entry rise ends")


## Samples the rise every frame, and checks the painting follows the level the whole way.
func _sample_until_settled(peak: float) -> Dictionary:
	var highest := 0.0
	var mid := false
	var deadline := Time.get_ticks_msec() + SETTLE_MS
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var shown := arrival.displayed_m()
		assert(absf(arrival.shader_flood_m() - shown) < 0.0001, "the painting draws the arriving water")
		highest = maxf(highest, shown)
		if shown > peak * 0.15 and shown < peak * 0.85:
			mid = true
		if not arrival.is_rising():
			break
	assert(not arrival.is_rising(), "the rise finishes within %d ms" % SETTLE_MS)
	return { "peak": highest, "mid": mid }
