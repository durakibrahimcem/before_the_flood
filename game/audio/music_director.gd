class_name MusicDirector
extends Node
## Adaptive music: the piano stems follow the year, the damage and the water.
##
## Add this node anywhere in the scene and it wires itself to WorldClock. All
## eight stems share one AudioStreamSynchronized voice, so they can never
## drift apart and the mix needs no audio effects (which the Web build lacks).

const STEMS_DIR := "res://audio/stems/"
const STEM_ORDER := ["melody", "harmony", "low", "detuned"]
const MUFFLED_SUFFIX := "_lp"

## Stem volumes (linear) at each era, from the plan's music table. Between
## eras the values ease across, so the slider keeps the music moving.
const ERA_VOLUME := {
	2026.0: [1.0, 0.85, 0.75, 0.0],
	2050.0: [0.62, 0.3, 0.7, 0.0],
	2080.0: [0.55, 0.0, 0.0, 0.0],
}
const ERA_YEARS: Array[float] = [2026.0, 2050.0, 2080.0]

## Severity blends the melody into its detuned copy (a damaged 2080).
const DETUNE_FROM := 0.6
const DETUNE_TO := 0.9
## Flood water past Arda's head blends the stems into their low passed copies.
const MUFFLE_FROM_M := 1.3
const MUFFLE_TO_M := 1.55

## -79 dB instead of -80: the synchronized stream stops advancing sub-streams
## at the -80 dB cutoff, so silent stems would freeze and come back off beat.
const SILENCE_DB := -79.0
const RESPONSE := 6.0
const SETTLED_AT := 0.004

@export var master_db := -6.0
## Overall headroom for the summed stems.

var _stream: AudioStreamSynchronized
var _player: AudioStreamPlayer
var _targets: Dictionary = {}
var _current: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_stream()
	_player = AudioStreamPlayer.new()
	_player.stream = _stream
	_player.volume_db = master_db
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_player.play()
	WorldClock.year_changed.connect(_on_year_changed)
	WorldClock.refresh()


func _process(delta: float) -> void:
	var moving := false
	for stem: String in stem_names():
		var aim := float(_targets.get(stem, 0.0))
		var value := float(_current.get(stem, 0.0))
		var step := minf(delta * RESPONSE, 1.0)
		value += (aim - value) * step
		if absf(aim - value) < SETTLED_AT:
			value = aim
		if not is_equal_approx(value, float(_current.get(stem, 0.0))):
			moving = true
			_current[stem] = value
			_apply(stem, value)
	if not moving and settled():
		set_process(false)


func _on_year_changed(state: WorldState) -> void:
	set_process(true)
	var era := _era_volumes(state.year)
	var detune := smoothstep(DETUNE_FROM, DETUNE_TO, state.severity)
	var muffle := smoothstep(MUFFLE_FROM_M, MUFFLE_TO_M, float(state.flood_m.get("salon", 0.0)))
	var melody := era[0] * (1.0 - detune)
	var detuned := era[0] * detune
	_targets["melody"] = melody * (1.0 - muffle)
	_targets["harmony"] = era[1] * (1.0 - muffle)
	_targets["low"] = era[2] * (1.0 - muffle)
	_targets["detuned"] = detuned * (1.0 - muffle)
	_targets["melody_lp"] = melody * muffle
	_targets["harmony_lp"] = era[1] * muffle
	_targets["low_lp"] = era[2] * muffle
	_targets["detuned_lp"] = detuned * muffle


## Current volume of a stem, 0 to 1, eased toward the target.
func volume(stem: String) -> float:
	return float(_current.get(stem, 0.0))


## Where the stem is heading, 0 to 1.
func target(stem: String) -> float:
	return float(_targets.get(stem, 0.0))


## The decibels actually written to the synchronized stream.
func applied_db(stem: String) -> float:
	return _stream.get_sync_stream_volume(stem_index(stem))


## The stream behind a stem, or null when the file is missing.
func stem_stream(stem: String) -> AudioStream:
	return _stream.get_sync_stream(stem_index(stem))


func is_playing() -> bool:
	return _player != null and _player.playing


## Stops the mix and lets the audio server release the voice.
func stop_music() -> void:
	if _player != null:
		_player.stop()
	set_process(false)


func settled() -> bool:
	for stem: String in stem_names():
		if absf(target(stem) - volume(stem)) > SETTLED_AT:
			return false
	return true


func stem_names() -> PackedStringArray:
	var names := PackedStringArray()
	for stem: String in STEM_ORDER:
		names.append(stem)
	for stem: String in STEM_ORDER:
		names.append(stem + MUFFLED_SUFFIX)
	return names


func stem_index(stem: String) -> int:
	var muffled := stem.ends_with(MUFFLED_SUFFIX)
	var slot := stem.trim_suffix(MUFFLED_SUFFIX)
	var index := STEM_ORDER.find(slot)
	assert(index >= 0, "Unknown stem: %s" % stem)
	return index + (STEM_ORDER.size() if muffled else 0)


func _era_volumes(year: float) -> Array[float]:
	var hi := 1
	while hi < ERA_YEARS.size() - 1 and year > ERA_YEARS[hi]:
		hi += 1
	var lo: float = ERA_YEARS[hi - 1]
	var top: float = ERA_YEARS[hi]
	var t := smoothstep(lo, top, year)
	var a: Array = ERA_VOLUME[lo]
	var b: Array = ERA_VOLUME[top]
	return [
		lerpf(float(a[0]), float(b[0]), t),
		lerpf(float(a[1]), float(b[1]), t),
		lerpf(float(a[2]), float(b[2]), t),
		0.0,
	]


func _build_stream() -> void:
	var names := stem_names()
	_stream = AudioStreamSynchronized.new()
	_stream.stream_count = names.size()
	for stem: String in names:
		_current[stem] = 0.0
		_targets[stem] = 0.0
		_stream.set_sync_stream_volume(stem_index(stem), SILENCE_DB)
		var ogg: AudioStreamOggVorbis = load(STEMS_DIR + stem + ".ogg")
		if ogg == null:
			push_warning("MusicDirector: missing stem %s" % stem)
			continue
		ogg.loop = true
		_stream.set_sync_stream(stem_index(stem), ogg)


func _apply(stem: String, value: float) -> void:
	var db := SILENCE_DB if value <= 0.01 else linear_to_db(value)
	_stream.set_sync_stream_volume(stem_index(stem), db)
