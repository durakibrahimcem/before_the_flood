class_name ScrubWash
extends Node
## The time wash: a quiet loop that follows the T scrub.
##
## It watches WorldClock rather than the input, so it follows the years no matter
## who scrubs, and it keeps running while the world is paused, like the music.
## Volume and pitch follow the scrub speed, so fast years pour and slow ones sip.

const WASH := preload("res://audio/sfx/time_wash.ogg")
## The keys scrub at 30 years a second; a quick mouse can go faster.
const FULL_SPEED := 45.0
## A year jump is a puff, not a pour: cap how hard a single frame can push.
const SPIKE := 90.0
## Rises quickly and settles slowly, like water after a wave.
const ATTACK := 14.0
const RELEASE := 2.6
const MAX_DB := -16.0
const FADE_DB := -55.0
const PITCH_LOW := 0.8
const PITCH_HIGH := 1.3
## Falling years sit a little lower, so going back reads as going down.
const BACK_PITCH := 0.93
## Below this many years a second, the direction is noise, not a scrub.
const STILL_YPS := 1.0
## An era jump is one moment, not a scrub, so it gets one clear puff.
const JUMP_YPS := 26.0

var _player: AudioStreamPlayer
var _speed := 0.0
var _last_year := 0.0
var _going_back := false


func _ready() -> void:
	# One wash serves the whole game; a second would double the sound.
	if not get_tree().get_nodes_in_group("scrub_wash").is_empty():
		set_process(false)
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("scrub_wash")
	_last_year = WorldClock.year
	var ogg := WASH as AudioStreamOggVorbis
	ogg.loop = true
	_player = AudioStreamPlayer.new()
	_player.stream = ogg
	_player.volume_db = FADE_DB
	_player.pitch_scale = PITCH_LOW
	add_child(_player)
	_player.play()
	WorldClock.jumped.connect(_on_jumped)


## One soft swell for a tap between eras, whatever the frame rate does.
func _on_jumped(to_year: int) -> void:
	_speed = maxf(_speed, JUMP_YPS)


func _process(delta: float) -> void:
	var raw := clampf((WorldClock.year - _last_year) / delta, -SPIKE, SPIKE)
	# A jump from rest (an era tap, a new run) is a puff, not a pour: without
	# this, one 54-year frame would sound like the fastest scrub there is.
	if absf(_speed) < STILL_YPS:
		raw = clampf(raw, -JUMP_YPS, JUMP_YPS)
	_last_year = WorldClock.year
	if absf(raw) >= STILL_YPS:
		_going_back = raw < 0.0
	var rate := ATTACK if absf(raw) > absf(_speed) else RELEASE
	_speed += (raw - _speed) * (1.0 - exp(-rate * delta))
	var drive := clampf(absf(_speed) / FULL_SPEED, 0.0, 1.0)
	_player.volume_db = lerpf(FADE_DB, MAX_DB, pow(drive, 0.7))
	_player.pitch_scale = lerpf(PITCH_LOW, PITCH_HIGH, drive) * (BACK_PITCH if _going_back else 1.0)
	# Silence costs a mixing voice on the web, so park the stream while still.
	_player.stream_paused = _player.volume_db <= FADE_DB + 1.0


## The wash's loudness, 0 silent to 1 at full scrub.
func level() -> float:
	return inverse_lerp(FADE_DB, MAX_DB, _player.volume_db)


## The pitch the wash is playing at, near 1.0 in normal time.
func pitch() -> float:
	return _player.pitch_scale


## Whether the last real scrub moved the years backwards.
func going_back() -> bool:
	return _going_back


func is_playing() -> bool:
	return _player.playing
