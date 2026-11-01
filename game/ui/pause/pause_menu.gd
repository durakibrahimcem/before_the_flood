class_name PauseMenu
extends CanvasLayer
## Esc opens a paper pause menu. The world waits; the menu keeps drawing.

signal resumed
signal opened
## Sent before the world pauses, so a scrub can end and leave the pause to this menu.
signal opening

const LARGE_SCALE := 1.4
const ICON_BASE := 32

@onready var panel: PanelContainer = $Center/Panel
@onready var column: VBoxContainer = $Center/Panel/Column
@onready var title_label: Label = $Center/Panel/Column/Title
@onready var resume_button: Button = $Center/Panel/Column/Resume
@onready var calm_box: CheckBox = $Center/Panel/Column/Calm
@onready var large_box: CheckBox = $Center/Panel/Column/Large
@onready var hint_label: Label = $Center/Panel/Column/Hint

var volume_slider: HSlider
var squiggle_phase: float = 0.0
var _underline: Squiggle
var _owned_pause: bool = false
var _focus_to_restore: Control
var _sized: Array[Control] = []
var _bases: Array[int] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.theme = CrayonUI.build_theme()
	panel.add_theme_stylebox_override("panel", CrayonUI.style_panel())
	_underline = Squiggle.new()
	column.add_child(_underline)
	column.move_child(_underline, 1)
	resume_button.pressed.connect(resume)
	calm_box.toggled.connect(_on_box_toggled)
	large_box.toggled.connect(_on_box_toggled)
	Settings.changed.connect(_on_settings_changed)
	_add_volume()
	_track(title_label, 44)
	_track(resume_button, 30)
	_track(calm_box, 26)
	_track(large_box, 26)
	_track(hint_label, 19)
	_apply_text_sizes()
	_sync_boxes()
	visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		if visible:
			resume()
		else:
			opening.emit()
			open()
		get_viewport().set_input_as_handled()


func _add_volume() -> void:
	var label := Label.new()
	label.text = "Volume"
	volume_slider = HSlider.new()
	volume_slider.name = "Volume"
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.custom_minimum_size = Vector2(320, 32)
	volume_slider.value = Settings.volume
	volume_slider.value_changed.connect(Settings.set_volume)
	column.add_child(label)
	column.add_child(volume_slider)
	var after_large := large_box.get_index() + 1
	column.move_child(label, after_large)
	column.move_child(volume_slider, after_large + 1)
	_track(label, 26)


func open() -> void:
	## Show the menu. A pause we did not own stays owned by its holder.
	if visible:
		return
	_focus_to_restore = get_viewport().gui_get_focus_owner()
	_owned_pause = not get_tree().paused
	visible = true
	if _owned_pause:
		get_tree().paused = true
	_sync_boxes()
	resume_button.grab_focus()
	opened.emit()


func resume() -> void:
	## Step aside. Only a pause we own goes with us.
	visible = false
	if _owned_pause:
		get_tree().paused = false
	if _focus_to_restore != null and is_instance_valid(_focus_to_restore) and _focus_to_restore.is_visible_in_tree():
		_focus_to_restore.grab_focus()
	_focus_to_restore = null
	resumed.emit()
	_owned_pause = false


func _process(delta: float) -> void:
	if not visible:
		return
	squiggle_phase += delta
	_underline.phase = squiggle_phase
	_underline.queue_redraw()
	if not get_tree().paused:
		resume()


func _on_box_toggled(_on: bool) -> void:
	Settings.set_options(calm_box.button_pressed, large_box.button_pressed)


func _on_settings_changed() -> void:
	_apply_text_sizes()
	_sync_boxes()


func _sync_boxes() -> void:
	calm_box.set_pressed_no_signal(Settings.calm_storm)
	large_box.set_pressed_no_signal(Settings.large_text)


func _apply_text_sizes() -> void:
	var factor := LARGE_SCALE if Settings.large_text else 1.0
	for i: int in _sized.size():
		_sized[i].add_theme_font_size_override("font_size", int(round(_bases[i] * factor)))
	var icon_size := int(ICON_BASE * factor)
	for box: CheckBox in [calm_box, large_box]:
		box.add_theme_icon_override("unchecked", CrayonUI.box_icon(false, icon_size))
		box.add_theme_icon_override("checked", CrayonUI.box_icon(true, icon_size))


func _track(control: Control, base_size: int) -> void:
	_sized.append(control)
	_bases.append(base_size)


class Squiggle:
	extends Control
	## The wobbly sea line under the title.
	var phase: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(190, 18)

	func _draw() -> void:
		var line := CrayonUI.squiggle_points(Vector2(8, 9), Vector2(size.x - 8, 9), 4, 4.5, phase)
		CrayonUI.draw_crayon_polyline(self, line, CrayonUI.SEA, 3.0, 9)
