class_name Storm
extends CanvasLayer
## The storm behind each flood: rain outdoors, lightning everywhere. Calm storm turns off the flashes.

const RAGING_FROM := 0.05
const FLASH_ALPHA := 0.3
const FLASH_GAP_MIN := 6.0
const FLASH_GAP_MAX := 14.0
const THUNDER_DELAY_MIN := 0.3
const THUNDER_DELAY_MAX := 1.4
const QUIET_DB := -16.0
const LOUD_DB := -5.0
const RAIN_OUTDOORS_DB := -13.0
const RAIN_INDOORS_DB := -30.0

## Set by Main on each room change. The rain stays outside.
var outdoors := false
var raging := false
var strength := 0.0

var _next_flash := FLASH_GAP_MIN
var _flash_tween: Tween

@onready var rain: CPUParticles2D = $Rain
@onready var flash: ColorRect = $Flash
@onready var thunder: AudioStreamPlayer = $Thunder
@onready var rain_sound: AudioStreamPlayer = $RainSound


func _ready() -> void:
	rain.texture = _streak()
	(rain_sound.stream as AudioStreamOggVorbis).loop = true
	WorldClock.year_changed.connect(_on_year_changed)
	WorldClock.refresh()


func _process(delta: float) -> void:
	if not raging or Settings.calm_storm:
		return
	_next_flash -= delta
	if _next_flash <= 0.0:
		_next_flash = randf_range(FLASH_GAP_MIN, FLASH_GAP_MAX)
		strike()


## Two quick pulses of light, then thunder a moment later.
func strike() -> void:
	if Settings.calm_storm:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(flash, "color:a", FLASH_ALPHA * strength, 0.05)
	_flash_tween.tween_property(flash, "color:a", 0.03, 0.09)
	_flash_tween.tween_property(flash, "color:a", FLASH_ALPHA * strength * 0.7, 0.05)
	_flash_tween.tween_property(flash, "color:a", 0.0, 0.32)
	var delay := randf_range(THUNDER_DELAY_MIN, THUNDER_DELAY_MAX)
	create_tween().tween_callback(_rumble).set_delay(delay)


func _rumble() -> void:
	thunder.volume_db = lerpf(QUIET_DB, LOUD_DB, strength)
	thunder.play()


func _on_year_changed(state: WorldState) -> void:
	strength = state.severity
	raging = strength >= RAGING_FROM
	rain.emitting = raging and outdoors
	rain.modulate.a = strength
	rain_sound.volume_db = RAIN_OUTDOORS_DB if outdoors else RAIN_INDOORS_DB
	if raging != rain_sound.playing:
		rain_sound.playing = raging


func _streak() -> ImageTexture:
	var image := Image.create(2, 30, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)
