extends Node
## Player options, saved between sessions.

signal changed

const SAVE_PATH := "user://settings.json"

var calm_storm: bool = false
var large_text: bool = false
var volume: float = 1.0


func _ready() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if parsed is Dictionary:
			calm_storm = bool(parsed.get("calm_storm", false))
			large_text = bool(parsed.get("large_text", false))
			volume = clampf(float(parsed.get("volume", 1.0)), 0.0, 1.0)
	_apply_volume()


func set_options(calm: bool, large: bool) -> void:
	calm_storm = calm
	large_text = large
	_save()
	changed.emit()


func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	_save()


func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({ "calm_storm": calm_storm, "large_text": large_text, "volume": volume }))
