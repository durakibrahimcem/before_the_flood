extends Node
## Holds the year. Everything that changes with time listens here.

signal year_changed(state: WorldState)
signal jumped(to_year: int)

const ERAS: Array[int] = [2026, 2050, 2080]

var year: float = 2026.0


func scrub(to_year: float) -> void:
	year = clampf(to_year, ERAS[0], ERAS[-1])
	refresh()


func jump(to_year: int) -> void:
	var era := to_year if to_year in ERAS else nearest_era()
	jumped.emit(era)
	scrub(era)


func next_era() -> int:
	var index := ERAS.find(nearest_era())
	return ERAS[(index + 1) % ERAS.size()]


func nearest_era() -> int:
	var best := ERAS[0]
	for era: int in ERAS:
		if absf(era - year) < absf(best - year):
			best = era
	return best


func refresh() -> void:
	year_changed.emit(Sim.at(Run.plan, year))
