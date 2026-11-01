extends Node
## Gate demo: a bot scrubs the clock at different speeds and the wash follows.
##
## Every wait is measured in seconds of real delta, so the asserts hold at any
## frame rate, including the headless runner.

const FAST_YPS := 30.0

var _delta := 0.0
var _rate := 0.0
var _forward_pitch := 0.0
var wash: ScrubWash


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _seconds(0.2)
	wash = get_tree().get_first_node_in_group("scrub_wash") as ScrubWash
	assert(wash != null, "the Sfx autoload hosts the wash")
	# At rest the loop parks its mixing voice; a scrub must wake it again.
	assert(not wash.is_playing(), "the wash parks its voice while still")

	_check_rest()
	await _scrub(FAST_YPS, 0.8)
	_check_forward()
	await _scrub(0.0, 1.2)
	assert(wash.level() < 0.15, "the wash settles after a scrub: %f" % wash.level())

	await _scrub(-FAST_YPS, 0.8)
	_check_backward()
	await _scrub(0.0, 2.0)
	assert(wash.level() < 0.05, "the wash falls silent at rest: %f" % wash.level())

	await _check_jump_puff()

	await _check_paused_scrub()

	print("DEMO PASS")
	get_tree().quit()


func _process(delta: float) -> void:
	_delta = delta
	if _rate != 0.0:
		WorldClock.scrub(WorldClock.year + _rate * delta)


func _check_rest() -> void:
	assert(wash.level() < 0.05, "the wash is silent while time stands still: %f" % wash.level())
	assert(wash.pitch() < 0.85, "the wash rests low: %f" % wash.pitch())


func _check_forward() -> void:
	assert(wash.is_playing(), "the wash wakes under a scrub")
	assert(wash.level() > 0.5, "a fast scrub opens the wash: %f" % wash.level())
	_forward_pitch = wash.pitch()
	assert(_forward_pitch > 1.05, "a fast scrub lifts the pitch: %f" % _forward_pitch)
	assert(not wash.going_back(), "scrubbing forward reads as forward")


func _check_backward() -> void:
	assert(wash.level() > 0.5, "a fast backwards scrub opens the wash too: %f" % wash.level())
	assert(wash.going_back(), "scrubbing back reads as back")
	assert(wash.pitch() < _forward_pitch - 0.03,
		"the backwards pitch sits lower: %f" % wash.pitch())


func _check_jump_puff() -> void:
	WorldClock.jump(2080)
	await _seconds(0.1)
	assert(wash.level() > 0.35, "a year jump puffs the wash: %f" % wash.level())
	await _seconds(1.2)
	assert(wash.level() < 0.15, "the puff fades away: %f" % wash.level())


func _check_paused_scrub() -> void:
	# Holding T pauses the world; the wash still has to follow the years.
	WorldClock.scrub(2040.0)
	get_tree().paused = true
	await _scrub(FAST_YPS, 0.8)
	assert(wash.level() > 0.5, "the wash follows a scrub while paused: %f" % wash.level())
	_rate = 0.0
	await _seconds(0.5)
	get_tree().paused = false
	assert(not get_tree().paused, "the world resumes")


## Scrubs at years per second, then waits, so the wash can react.
func _scrub(rate: float, seconds: float) -> void:
	_rate = rate
	await _seconds(seconds)


## Waits measured seconds, so the demo cannot be fooled by a fast headless loop.
## _process stamps every frame's delta before this coroutine resumes, so
## several waits may overlap without stealing each other's time.
func _seconds(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().process_frame
		elapsed += maxf(_delta, 0.0)
