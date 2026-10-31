class_name Newspapers
extends RefCounted
## Picks the front page for a plan. The lead story points at the best fix.

const PATH := "res://data/newspapers.json"
const TIERS: Array[float] = [0.25, 0.75]
const WALL_CLUE_ERA := 2080

static var _papers: Array = []
static var _clues: Dictionary = {}


## Returns { "headline", "story", "picture", "action" }. Action is the fix the paper hints at.
static func pick(plan: Plan, era: int) -> Dictionary:
	_load()
	var fix := fix_key(plan)
	var tier := tier_of(Sim.at(plan, era).flood_m["salon"])
	var found: Dictionary = {}
	for paper: Dictionary in _papers:
		if int(paper["era"]) == era and paper["fix"] == fix:
			found = paper
			if int(paper["tier"]) == tier:
				break
	if found.is_empty():
		return { "headline": "", "story": "", "picture": "", "action": "" }
	var page := found.duplicate()
	page["action"] = fix
	# Seawall papers keep their story, then quietly point at what would have helped.
	if fix == "wall" and era == WALL_CLUE_ERA:
		var action := Sim.best_fix(plan)
		page["action"] = action
		page["story"] = "%s %s" % [page["story"], _clues.get(action, "")]
		page["story"] = (page["story"] as String).strip_edges()
	return page


static func _load() -> void:
	if not _papers.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary and parsed.get("papers") is Array:
		_papers = parsed["papers"]
		_clues = parsed.get("clues", {})
	else:
		push_error("Bad newspaper file: %s" % PATH)


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
