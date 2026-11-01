extends Node
## Plays short sounds from a small pool, so they can overlap. Every sound is made by audio/tools.

const POOL_SIZE := 8
## Each play shifts a little, so repeated actions never sound like a loop.
const PITCH_SPREAD := 0.06
## These read as one object in the world, so they keep their own voice.
const STEADY: Array[String] = ["paper", "scribble", "door", "chime", "thunder", "rain"]
const FOLDER := "res://audio/sfx/%s.ogg"
const LEVELS_DB := {
	"step_dry": -20.0, "step_wet": -14.0, "scribble": -13.0, "paper": -12.0, "switch": -8.0, "door": -13.0,
	"block": -5.0, "wave_crash": -9.0, "pickup": -18.0, "drop": -11.0, "plant": -12.0, "knock": -8.0, "chime": -15.0,
}

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound: String in LEVELS_DB:
		_streams[sound] = load(FOLDER % sound)
	for i: int in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)


func play(sound: String) -> void:
	var player := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stream = _streams[sound]
	player.volume_db = LEVELS_DB[sound]
	player.pitch_scale = 1.0 if sound in STEADY else randf_range(1.0 - PITCH_SPREAD, 1.0 + PITCH_SPREAD)
	player.play()
