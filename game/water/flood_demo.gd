extends Control
## Sweeps the flood up and down, and reports the frame rate for Gate 1.

const CYCLE_SECONDS := 10.0
const MAX_FLOOD_M := 1.7
const HEADLESS_FRAMES := 30

@onready var room: TextureRect = $Room
@onready var label: Label = $Label

var elapsed := 0.0
var frames := 0


func _process(delta: float) -> void:
	elapsed += delta
	frames += 1
	var phase := fposmod(elapsed / CYCLE_SECONDS, 1.0)
	var flood := (1.0 - cos(phase * TAU)) * 0.5 * MAX_FLOOD_M
	room.material.set_shader_parameter("flood_m", flood)
	var fps := Engine.get_frames_per_second()
	label.text = "%d fps   %.2f m" % [fps, flood]
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.title = 'FPS %d FLOOD %.2f GPU %s'" % [fps, flood, RenderingServer.get_video_adapter_name().replace("'", "")])
	elif DisplayServer.get_name() == "headless" and frames >= HEADLESS_FRAMES:
		assert(room.material.get_shader_parameter("flood_m") >= 0.0)
		print("DEMO PASS")
		get_tree().quit()
