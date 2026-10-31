class_name RealCards
extends Control
## The "What's real" cards, the learn-more link and the credits.

const LEARN_URL := "https://climatepromise.undp.org/news-and-stories/what-climate-change-adaptation-and-why-it-crucial"
const LINK_TEXT := "Learn more about climate adaptation"
const CREDITS := "Art by Ebru. Built with help from AI tools for code and writing drafts. Fonts: Caveat and Playfair Display (SIL Open Font License). Music rendered with FluidSynth and the FluidR3 GM SoundFont (MIT license). Sound effects made by our own scripts."
const CARD_TITLES: Array[String] = ["The sea", "Storms", "Seagrass", "Waste", "Seawalls", "This game"]
const CARD_BODIES: Array[String] = [
	"The world's seas are rising, and how far depends on us. These numbers follow IPCC projections, counted from 2026 rather than the IPCC's 1995 to 2014 baseline.",
	"A higher sea lets storms reach further inland, more often. The water you see is the year's worst storm at its peak, not a permanent level.",
	"Mediterranean seagrass cuts wave height by about 20 to 30 percent. Real meadows recover far more slowly than in this game.",
	"Plastic blocking drains puts over 200 million people at risk of worse flooding.",
	"Well-built walls can protect dense cities. Ours failed because it was built fast and then neglected. Its harm to the meadow is a simplified game rule.",
	"The country is fictional and the model is simplified. It shows how choices connect, and doesn't predict any real place.",
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.name = "Box"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	_fill(box, 48, 36, 48, 28)
	var heading := _label("Heading", "What's real", EndPalette.TITLE_SIZE, EndPalette.INK)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 26)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i: int in CARD_TITLES.size():
		grid.add_child(_make_card(i))
	var link := LinkButton.new()
	link.name = "Link"
	link.text = LINK_TEXT
	link.add_theme_font_size_override("font_size", EndPalette.BODY_SIZE)
	link.add_theme_color_override("font_color", EndPalette.CRAYON)
	link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	link.pressed.connect(func() -> void: OS.shell_open(LEARN_URL))
	var credits := _label("Credits", CREDITS, 22, EndPalette.FADED)
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	box.add_child(grid)
	box.add_child(link)
	box.add_child(credits)
	add_child(box)


func _make_card(index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Card%d" % index
	card.custom_minimum_size = Vector2(560, 300)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = EndPalette.CARD
	style.border_color = EndPalette.BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", style)
	var inner := VBoxContainer.new()
	inner.name = "Inner"
	inner.add_theme_constant_override("separation", 12)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := _label("Title", String(CARD_TITLES[index]), EndPalette.CARD_TITLE_SIZE, EndPalette.INK)
	var body := _label("Body", String(CARD_BODIES[index]), 28, EndPalette.INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(title)
	inner.add_child(body)
	card.add_child(inner)
	return card


func _label(label_name: String, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _fill(control: Control, left: int, top: int, right: int, bottom: int) -> void:
	control.anchor_left = 0.0
	control.anchor_right = 1.0
	control.anchor_top = 0.0
	control.anchor_bottom = 1.0
	control.offset_left = left
	control.offset_top = top
	control.offset_right = -right
	control.offset_bottom = -bottom
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
