extends Node
## Gate demo: the salon's keepsakes lift off on the flood, ride its waves, keep
## clear of Arda, hold still under calm storm, and settle back when it leaves.

const SALON := preload("res://rooms/salon/salon.tscn")
const ARDA := preload("res://actors/arda.tscn")

func _ready() -> void:
	Run.new_run()
	var salon: Room = SALON.instantiate()
	add_child(salon)
	await get_tree().process_frame
	var flotsam := salon.get_node_or_null("Flotsam") as Flotsam
	assert(flotsam != null, "the salon carries keepsakes")
	var boat := flotsam.item("Boat")
	assert(boat != null and boat.texture != null, "the paper boat has art")
	assert(flotsam.item("Cushion") != null, "the cushion is there")
	assert(flotsam.item("Photo") != null, "the framed photo is there")
	assert(not boat.is_floating() and is_zero_approx(boat.modulate.a), "nothing floats in a dry 2026")

	WorldClock.scrub(2080.0)
	var lifted := await _until(6.0, func() -> bool: return boat.modulate.a > 0.7)
	assert(lifted, "the boat lifts off on the flood of 2080")
	assert(boat.is_floating(), "the boat is up on the water")
	assert(boat.position.y < boat.rest.y - 80.0, "the boat floats above its resting spot, got y %f" % boat.position.y)
	var line := float((boat.material as ShaderMaterial).get_shader_parameter("waterline"))
	assert(line > 0.5 and line < 1.0, "the hull rides in the water, waterline %f" % line)

	# Let the lift finish, then the boat may only move with the water.
	await _wait(3.0)
	var risen := boat.position.y
	await _wait(0.7)
	assert(absf(boat.position.y - risen) < 12.0, "the boat bobs gently, not wildly")
	var ringed := await _until(8.0, func() -> bool: return salon.ripple_count() > 0)
	assert(ringed, "the drifting boat stirs a ring into the water now and then")

	# Arda wades past: the keepsake drifts clear, never sitting on the walker.
	var arda := ARDA.instantiate() as Arda
	salon.add_child(arda)
	arda.room = salon
	arda.position = Vector2(boat.position.x - 40.0, 930.0)
	var gap := boat.position.x - arda.position.x
	await _wait(2.0)
	assert(boat.position.x - arda.position.x > gap + 15.0, "the boat drifts away from Arda")

	# Set directly, never saved: a demo must not touch the player's settings file.
	var was_calm := Settings.calm_storm
	Settings.calm_storm = true
	var held := boat.position
	await _wait(0.7)
	assert(boat.position.distance_to(held) < 6.0, "calm storm holds the keepsakes still")
	Settings.calm_storm = was_calm

	WorldClock.scrub(2026.0)
	var settled := await _until(6.0, func() -> bool: return boat.modulate.a < 0.2)
	assert(settled, "the boat settles when the flood leaves")
	assert(not boat.is_floating(), "the boat is down off the water")
	await _wait(3.0)
	assert(boat.modulate.a < 0.15, "the settled boat slips out of sight")
	assert(boat.position.y > boat.rest.y - 40.0, "the boat rests back where it came from, got y %f" % boat.position.y)

	print("DEMO PASS")
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Polls until the check passes, or the seconds run out; returns whether it passed.
func _until(seconds: float, check: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not check.call() and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.05).timeout
	return check.call()
