class_name Solver
extends RefCounted
## Scores every possible plan and checks the balance rules.

const TARGET_LOW := 0.04
const TARGET_HIGH := 0.07


static func score_all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for plan: Plan in Plan.all_plans():
		var row: Dictionary = Sim.outcome(plan)
		row["plan"] = plan.counts.duplicate()
		row["code"] = plan.code()
		result.append(row)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	for index: int in result.size():
		result[index]["rank"] = index + 1
	return result


## Returns one entry per rule: { "rule": String, "passed": bool, "detail": String }.
static func check(rows: Array[Dictionary]) -> Array[Dictionary]:
	var best := rows.filter(func(r: Dictionary) -> bool: return r["homes"] == 3)
	var walls := rows.filter(func(r: Dictionary) -> bool: return r["plan"]["wall"] > 0)
	var others := rows.filter(func(r: Dictionary) -> bool: return r["plan"]["wall"] == 0)
	var share := float(best.size()) / rows.size()
	var checks: Array[Dictionary] = []
	checks.append(_rule("Best ending share is 4 to 7 percent", share >= TARGET_LOW and share <= TARGET_HIGH, "%d of %d" % [best.size(), rows.size()]))
	checks.append(_rule("Every full save includes a meeting", best.all(func(r: Dictionary) -> bool: return r["plan"]["meet"] > 0), ""))
	for action: String in Plan.ACTIONS:
		if action != "wall":
			checks.append(_rule("%s appears in a full save" % action, best.any(func(r: Dictionary) -> bool: return r["plan"][action] > 0), ""))
	checks.append(_rule("No full save uses a wall", not best.any(func(r: Dictionary) -> bool: return r["plan"]["wall"] > 0), ""))
	checks.append(_rule("Walls beat no walls in 2050", _median(walls, "depth_2050") < _median(others, "depth_2050"), ""))
	checks.append(_rule("Walls lose to no walls in 2080", _median(walls, "depth_2080") > _median(others, "depth_2080"), ""))
	var six := Plan.new()
	six.counts["wall"] = Plan.SLOTS
	var nothing := Plan.new()
	var six_depth: float = Sim.outcome(six)["depth_2080"]
	var none_depth: float = Sim.outcome(nothing)["depth_2080"]
	checks.append(_rule("Six walls are worse than nothing in 2080", six_depth > none_depth, "%.2f against %.2f" % [six_depth, none_depth]))
	checks.append(_rule("At least one wall plan keeps a home", walls.any(func(r: Dictionary) -> bool: return r["homes"] > 0), ""))
	checks.append(_rule("Skill cannot turn 0 homes into 3", _skill_is_bounded(), ""))
	return checks


static func _rule(rule: String, passed: bool, detail: String) -> Dictionary:
	return { "rule": rule, "passed": passed, "detail": detail }


static func _median(rows: Array, key: String) -> float:
	var values: Array[float] = []
	for row: Dictionary in rows:
		values.append(row[key])
	values.sort()
	return values[values.size() / 2]


static func _skill_is_bounded() -> bool:
	for plan: Plan in Plan.all_plans():
		if Sim.outcome(plan)["homes"] != 0:
			continue
		var skilled := plan.duplicate_plan()
		for action: String in Plan.ACTIONS:
			skilled.skill[action] = Plan.MAX_SKILL
		if Sim.outcome(skilled)["homes"] == 3:
			return false
	return true
