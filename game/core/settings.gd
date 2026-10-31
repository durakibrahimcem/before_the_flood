extends Node
## Player options, saved between sessions.

signal changed

const SAVE_PATH := "user://settings.json"

var calm_storm: bool = false
var large_text: bool = false


func _ready() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if parsed is Dictionary:
			calm_storm = bool(parsed.get("calm_storm", false))
			large_text = bool(parsed.get("large_text", false))


func set_options(calm: bool, large: bool) -> void:
	calm_storm = calm
	large_text = large
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({ "calm_storm": calm_storm, "large_text": large_text }))
	changed.emit()
