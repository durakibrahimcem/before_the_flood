extends SceneTree
## Run: tools/g --headless --path game --script tools/check.gd
## Loads every script and scene, and fails if any of them is broken.

var failures := 0


func _initialize() -> void:
	_walk("res://")
	print("CHECK: %s (%d failed)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _walk(folder: String) -> void:
	for sub: String in DirAccess.get_directories_at(folder):
		if not sub.begins_with("."):
			_walk(folder.path_join(sub))
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			var script: Script = load(folder.path_join(file))
			if script == null or not script.can_instantiate():
				_fail(folder.path_join(file))
		elif file.ends_with(".tscn"):
			_check_scene(folder.path_join(file))
		elif file.ends_with(".gdshader"):
			if load(folder.path_join(file)) == null:
				_fail(folder.path_join(file))
		elif file.ends_with(".json"):
			if JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(file))) == null:
				_fail(folder.path_join(file))


func _check_scene(path: String) -> void:
	if load(path) == null:
		_fail(path)
	var links := RegEx.create_from_string("path=\"(res://[^\"]+)\"")
	for link: RegExMatch in links.search_all(FileAccess.get_file_as_string(path)):
		if not ResourceLoader.exists(link.get_string(1)):
			_fail("%s needs %s" % [path, link.get_string(1)])


func _fail(path: String) -> void:
	failures += 1
	printerr("BROKEN: ", path)
