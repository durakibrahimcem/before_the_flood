class_name SortBin
extends Area2D
## A labelled bin. A dumb node: it reports walker touches, the task keeps the rules.

signal touched(body: Node2D)

const GROUP := "sort_bin"
const OUTLINE := Color(0.13, 0.11, 0.09)
const BODY_FILL := Color(0.93, 0.92, 0.88)
const LID_FILL := Color(0.82, 0.8, 0.76)
const ICON_FILL := Color(0.96, 0.95, 0.92)
const ICON_OFFSET := Vector2(0.0, -108.0)
const ICON_SCALE := Vector2(0.8, 0.8)
const LABEL_WIDTH := 170.0
const LABEL_TOP := 100.0

## One of plastic, paper, glass, metal.
@export var kind: String = "plastic"
## Ebru's bin painting drop-in; null draws the code placeholder.
@export var art: Texture2D
## Optional icon art above the bin; null draws the code icon.
@export var icon_art: Texture2D


func _ready() -> void:
	monitoring = true
	add_to_group(GROUP)
	body_entered.connect(_on_body_entered)
	_build_label()
	if art != null:
		var sprite := Sprite2D.new()
		sprite.texture = art
		add_child(sprite)
	if icon_art != null:
		var icon := Sprite2D.new()
		icon.texture = icon_art
		icon.position = ICON_OFFSET
		add_child(icon)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("walker"):
		touched.emit(body)


func _build_label() -> void:
	var label := Label.new()
	label.text = kind.capitalize()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 36.0)
	label.position = Vector2(-LABEL_WIDTH / 2.0, LABEL_TOP)
	var settings := LabelSettings.new()
	settings.font_size = 30
	settings.font_color = Color.WHITE
	settings.outline_size = 10
	settings.outline_color = Color(0.13, 0.11, 0.09, 0.9)
	label.label_settings = settings
	add_child(label)


func _draw() -> void:
	_draw_icon()
	if art == null:
		_draw_body()


## The icon keeps the bin readable without colour, so it draws even over real art.
func _draw_icon() -> void:
	if icon_art != null:
		return
	var points := SortItem.silhouette(kind)
	draw_set_transform(ICON_OFFSET, 0.0, ICON_SCALE)
	draw_colored_polygon(points, ICON_FILL)
	draw_polyline(SortItem.closed(points), OUTLINE, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A simple bin with a lid and a kind-coloured band.
func _draw_body() -> void:
	var lid := Rect2(-66.0, -72.0, 132.0, 22.0)
	var body := Rect2(-60.0, -50.0, 120.0, 126.0)
	var band := Rect2(-60.0, -10.0, 120.0, 30.0)
	var band_colour: Color = SortItem.KIND_COLORS.get(kind, Color(0.6, 0.6, 0.6))
	draw_rect(body, BODY_FILL)
	draw_rect(band, band_colour)
	draw_rect(lid, LID_FILL)
	draw_rect(lid, OUTLINE, false, 3.0)
	draw_rect(body, OUTLINE, false, 3.0)
