class_name Newspapers
extends RefCounted
## Picks the front page for a plan. The lead story points at the best fix.

const PATH := "res://data/newspapers.json"
const TIERS: Array[float] = [0.25, 0.75]

static var _papers: Array = []


## Returns { "headline": String, "story": String, "picture": String }.
static func pick(plan: Plan, era: int) -> Dictionary:
	if _papers.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_papers = parsed["papers"]
	var fix := fix_key(plan)
	var tier := tier_of(Sim.at(plan, era).flood_m["salon"])
	var fallback: Dictionary = _papers[0]
	for paper: Dictionary in _papers:
		if int(paper["era"]) == era and paper["fix"] == fix:
			fallback = paper
			if int(paper["tier"]) == tier:
				return paper
	return fallback


static func fix_key(plan: Plan) -> String:
	if plan.counts["wall"] > 0:
		return "wall"
	var fix := Sim.best_fix(plan)
	return fix if fix != "" else "none"


static func tier_of(depth_m: float) -> int:
	for index: int in TIERS.size():
		if depth_m < TIERS[index]:
			return index
	return TIERS.size()
