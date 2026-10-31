extends SceneTree
## Run: tools/g --headless --path game --script tests/test_sim.gd

var failures := 0


func _initialize() -> void:
	_test_same_plan_same_future()
	_test_doing_nothing()
	_test_plan_codes()
	_test_bad_codes()
	_test_best_fix()
	_test_breach_jumps()
	_test_wall_skill_counts()
	_test_newspapers()
	_test_balance()
	print("RESULT: %s (%d failed)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _expect(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAILED: ", label)


func _test_same_plan_same_future() -> void:
	var plan := Plan.new()
	plan.counts["grass"] = 2
	plan.counts["meet"] = 1
	var first := Sim.at(plan, 2063.4).water_m
	Sim.reload_data()
	_expect(first == Sim.at(plan, 2063.4).water_m, "same plan gives same water after a fresh compute")


func _test_doing_nothing() -> void:
	var outcome := Sim.outcome(Plan.new())
	_expect(is_equal_approx(snappedf(outcome["depth_2050"], 0.001), 0.175), "nothing gives 0.175 m in 2050, got %f" % outcome["depth_2050"])
	_expect(is_equal_approx(snappedf(outcome["depth_2080"], 0.001), 0.911), "nothing gives 0.911 m in 2080, got %f" % outcome["depth_2080"])
	_expect(outcome["homes"] == 0, "nothing loses every home")
	var today := Sim.at(Plan.new(), 2026.0)
	_expect(today.flood_m["salon"] == 0.0 and today.homes == Sim.ALL_HOMES, "every home is dry and standing in 2026")
	_expect(today.flood_m["street"] == 0.0, "the street is dry in 2026")
	_expect(today.saplings == 0, "nothing planted leaves the planters empty")
	var planted := Plan.new()
	planted.counts["dune"] = 1
	_expect(Sim.at(planted, 2026.0).saplings == 2, "a day of planting shows at once, in 2026")
	planted.counts["dune"] = 2
	planted.counts["meet"] = 3
	_expect(Sim.at(planted, 2026.0).saplings == 5, "saplings stop at the five planters")


func _test_plan_codes() -> void:
	var seen := {}
	var plans := Plan.all_plans()
	_expect(plans.size() == 462, "462 plans, got %d" % plans.size())
	for plan: Plan in plans:
		var code := plan.code()
		_expect(code.length() == 3 and not seen.has(code), "code is unique: %s" % code)
		seen[code] = true
	var sample := plans[137]
	var back := Plan.from_code(sample.code().to_lower())
	_expect(back != null and back.counts == sample.counts, "code converts both ways")


func _test_bad_codes() -> void:
	_expect(Plan.from_code("") == null, "empty code is refused")
	_expect(Plan.from_code("!!!") == null, "garbage code is refused")


func _test_best_fix() -> void:
	var walled := Plan.new()
	walled.counts["wall"] = 6
	var fix := Sim.best_fix(walled)
	_expect(fix != "wall" and fix != "", "six walls have a real fix, got '%s'" % fix)
	var fixed := walled.duplicate_plan()
	fixed.counts["wall"] -= 1
	fixed.counts[fix] += 1
	_expect(Sim.outcome(fixed)["score"] > Sim.outcome(walled)["score"], "the fix improves the future")
	_expect(Sim.best_fix(Plan.new()) != "", "an unfinished plan has a fix")


func _test_breach_jumps() -> void:
	var plan := Plan.new()
	plan.counts["wall"] = 1
	var breach := Sim.breach_year(plan)
	var before := Sim.at(plan, breach - 0.01)
	var after := Sim.at(plan, float(breach))
	_expect(after.water_m - before.water_m > 0.5, "the breach jumps the water, got %f" % (after.water_m - before.water_m))
	_expect(before.wall_state == WorldState.Wall.CRACKED and after.wall_state == WorldState.Wall.BREACHED, "the wall breaks at the breach year")


func _test_wall_skill_counts() -> void:
	var plain := Plan.new()
	plain.counts["wall"] = 1
	var strong := plain.duplicate_plan()
	strong.skill["wall"] = Plan.MAX_SKILL
	_expect(Sim.at(strong, 2050.0).water_m < Sim.at(plain, 2050.0).water_m, "a well built wall holds more water back")


func _test_newspapers() -> void:
	var wall := Plan.new()
	wall.counts["wall"] = 6
	var page := Newspapers.pick(wall, 2080)
	_expect(page["headline"] != "" and page["action"] != "wall", "wall plans still get a real clue, got '%s'" % page["action"])
	_expect(Newspapers.pick(Plan.new(), 2050)["headline"] != "", "every plan gets a paper")
	_expect(Newspapers.pick(Plan.new(), 2026)["headline"] == "", "no paper exists for 2026")


func _test_balance() -> void:
	var rows := Solver.score_all()
	for check: Dictionary in Solver.check(rows):
		_expect(check["passed"], "%s %s" % [check["rule"], check["detail"]])
	var shipped: Variant = JSON.parse_string(FileAccess.get_file_as_string(Solver.PLANS_PATH))
	_expect(shipped is Array and shipped[0]["code"] == rows[0]["code"] and is_equal_approx(shipped[0]["score"], rows[0]["score"]), "plans.json is up to date")
	_expect(Solver.rank_for(rows[4]["code"]) == 5, "ranks read from plans.json")
