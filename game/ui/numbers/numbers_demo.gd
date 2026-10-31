extends Node
## Gate for the numbers scrap: reads 2026, then follows jumps and scrubs.

const PANEL := preload("res://ui/numbers/numbers_panel.tscn")


func _ready() -> void:
	Settings.set_options(false, false)
	var panel: NumbersPanel = PANEL.instantiate()
	add_child(panel)
	await _frames(2)

	assert(_value(panel, "Homes").text == "2 of 2", "every home stands in 2026")
	assert(_value(panel, "Flood").text == "dry", "the salon is dry in 2026")
	assert(_value(panel, "Neighbours").text == "yes", "the neighbours stay in 2026")
	assert(_dateline(panel).text == "2026", "the dateline shows the year")
	_check_rows(panel)
	_check_fits(panel)

	WorldClock.jump(2050)
	assert(_value(panel, "Flood").modulate.a < 1.0, "an era arrival wets the ink")
	await _settle()
	assert(is_equal_approx(_value(panel, "Flood").modulate.a, 1.0), "the pulse dries on its own")
	_check_rows(panel)
	WorldClock.scrub(2038.0)
	assert(is_equal_approx(_value(panel, "Flood").modulate.a, 1.0), "scrub ticks do not pulse")
	_check_rows(panel)
	WorldClock.scrub(2063.0)
	assert(is_equal_approx(_value(panel, "Homes").modulate.a, 1.0), "every row keeps full ink after a scrub")
	_check_rows(panel)
	WorldClock.jump(2080)
	assert(_dateline(panel).modulate.a < 1.0, "a big arrival pulses every changed row")
	await _settle()
	for row: String in ["Homes", "Flood", "Neighbours"]:
		assert(is_equal_approx(_value(panel, row).modulate.a, 1.0), "%s dries to full ink on its own" % row)
	assert(is_equal_approx(_dateline(panel).modulate.a, 1.0), "the dateline dries to full ink")
	_check_rows(panel)

	var normal := _value(panel, "Homes").get_theme_font_size("font_size")
	Settings.set_options(false, true)
	await _frames(2)
	assert(_value(panel, "Homes").get_theme_font_size("font_size") > normal, "large text grows the numbers")
	_check_fits(panel)
	Settings.set_options(false, false)
	await _frames(2)
	assert(_value(panel, "Homes").get_theme_font_size("font_size") == normal, "the numbers return to normal size")

	print("DEMO PASS")
	get_tree().quit()


## The rows must read exactly what the simulation says for the current year.
func _check_rows(panel: NumbersPanel) -> void:
	var state := Sim.at(Run.plan, WorldClock.year)
	assert(_value(panel, "Homes").text == "%d of 2" % state.homes, "homes track the simulation")
	var depth := float(state.flood_m.get("salon", 0.0))
	assert(_value(panel, "Flood").text == ("dry" if depth < 0.05 else "%.1f m" % depth), "flood tracks the simulation")
	assert(_value(panel, "Neighbours").text == ("yes" if state.neighbours > 0 else "no"), "neighbours track the simulation")
	assert(_dateline(panel).text == str(roundi(state.year)), "the dateline tracks the year")


## The scrap must hold every row and value inside its paper edges.
func _check_fits(panel: NumbersPanel) -> void:
	var origin := panel.global_position
	for row: String in ["Homes", "Flood", "Neighbours"]:
		var box: Control = panel.get_node("Rows/" + row) as Control
		var bottom: float = box.global_position.y - origin.y + box.size.y
		assert(bottom <= panel.size.y - 6.0, "%s stays on the paper, bottom %.1f of %.1f" % [row, bottom, panel.size.y])
		var value := _value(panel, row)
		var right: float = value.global_position.x - origin.x + value.size.x
		assert(right <= panel.size.x - 4.0, "%s value stays on the paper, right %.1f of %.1f" % [row, right, panel.size.x])


func _value(panel: NumbersPanel, row: String) -> Label:
	return panel.get_node("Rows/" + row + "/Value") as Label


func _dateline(panel: NumbersPanel) -> Label:
	return panel.get_node("Rows/Dateline") as Label


func _settle() -> void:
	await get_tree().create_timer(0.35).timeout


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
