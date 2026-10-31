extends Node
## Gate demo: a bot drives the clock through eras and plans and checks the mix.

const TOTAL_BUDGET := 8 * 1024 * 1024

var music: MusicDirector


func _ready() -> void:
	music = MusicDirector.new()
	add_child(music)
	await _settle()

	_check_setup()

	Run.new_run()
	await _settle()
	_check_2026()

	WorldClock.scrub(2080.0)
	await _settle()
	_check_2080_damaged()

	_use_plan({"wall": 6})
	WorldClock.refresh()
	await _settle()
	_check_2080_flooded()

	_use_plan({"grass": 2, "dune": 2, "meet": 2})
	WorldClock.refresh()
	await _settle()
	_check_2080_cared_for()

	WorldClock.scrub(2040.0)
	await _settle()
	_check_mid_slider()

	WorldClock.scrub(2050.0)
	await _settle()
	_check_2050()

	await _check_paused_scrub()

	_check_files()

	music.stop_music()
	music.queue_free()
	await get_tree().process_frame
	print("DEMO PASS")
	get_tree().quit()


func _check_setup() -> void:
	assert(music.is_playing(), "the music is playing")
	for stem: String in music.stem_names():
		var ogg := music.stem_stream(stem) as AudioStreamOggVorbis
		assert(ogg != null, "stem loaded: %s" % stem)
		assert(ogg.loop, "%s loops" % stem)
	assert(music.stem_names().size() == 8, "eight stems wired up")


func _check_2026() -> void:
	assert(is_equal_approx(WorldClock.year, 2026.0), "starts in 2026")
	_expect("melody", 1.0)
	_expect("harmony", 0.85)
	_expect("low", 0.75)
	_expect("detuned", 0.0)
	_expect_muffled(0.0)


func _check_2080_damaged() -> void:
	# The empty plan floods the salon to 0.91 m: severity 1, still above water.
	_expect("melody", 0.0)
	_expect("harmony", 0.0)
	_expect("low", 0.0)
	_expect("detuned", 0.55)
	_expect_muffled(0.0)


func _check_2080_flooded() -> void:
	# Six seawalls breach: the salon floods to 1.55 m and the mix goes dull.
	_expect("detuned", 0.0)
	_expect("detuned_lp", 0.5498)
	_expect("melody_lp", 0.0)
	assert(music.volume("harmony_lp") < 0.01, "the muffled harmony stays silent too")


func _check_2080_cared_for() -> void:
	# A cared for 2080 keeps the melody alone, warm and in tune.
	_expect("melody", 0.55)
	_expect("harmony", 0.0)
	_expect("low", 0.0)
	_expect("detuned", 0.0)
	_expect_muffled(0.0)


func _check_mid_slider() -> void:
	# Scrubbing between eras eases the mix instead of jumping it.
	var melody := music.volume("melody")
	var harmony := music.volume("harmony")
	assert(melody > 0.63 and melody < 0.99, "melody eases between eras: %f" % melody)
	assert(harmony > 0.31 and harmony < 0.84, "harmony thins between eras: %f" % harmony)


func _check_2050() -> void:
	_expect("melody", 0.62)
	_expect("harmony", 0.3)
	_expect("low", 0.7)
	_expect("detuned", 0.0)
	assert(music.volume("melody") < 1.0, "melody is quieter than 2026")


func _check_paused_scrub() -> void:
	# Holding T pauses the world; the music still has to follow the slider.
	get_tree().paused = true
	WorldClock.scrub(2026.0)
	await _settle()
	_expect("melody", 1.0)
	_expect("harmony", 0.85)
	get_tree().paused = false
	assert(not get_tree().paused, "the world resumes")


func _check_files() -> void:
	var total := 0
	for stem: String in music.stem_names():
		var path := "res://audio/stems/%s.ogg" % stem
		assert(FileAccess.file_exists(path), "stem file exists: %s" % path)
		total += FileAccess.open(path, FileAccess.READ).get_length()
	assert(total < TOTAL_BUDGET, "audio stays under 8 MB: %d bytes" % total)


func _use_plan(counts: Dictionary) -> void:
	var plan := Plan.new()
	for action: String in counts:
		plan.counts[action] = int(counts[action])
	Run.plan = plan


func _expect(stem: String, expected: float) -> void:
	var got := music.volume(stem)
	assert(absf(got - expected) < 0.01, "%s volume %f, expected %f" % [stem, got, expected])
	var db := music.applied_db(stem)
	var want_db := MusicDirector.SILENCE_DB if expected <= 0.01 else linear_to_db(expected)
	assert(absf(db - want_db) < 0.05, "%s decibels %f, expected %f" % [stem, db, want_db])


func _expect_muffled(expected: float) -> void:
	for stem: String in ["melody_lp", "harmony_lp", "low_lp", "detuned_lp"]:
		var got := music.volume(stem)
		assert(absf(got - expected) < 0.01, "%s volume %f, expected %f" % [stem, got, expected])


func _settle() -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while not music.settled() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert(music.settled(), "the mix settles within 3 s")
