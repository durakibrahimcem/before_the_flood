extends SceneTree
## Run: tools/g --headless --path game --script tests/test_sim.gd

var failures := 0


func _initialize() -> void:
	_test_same_plan_same_future()
	_test_doing_nothing()
	_test_plan_codes()
	_test_bad_codes()
	_test_best_fix()
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
	_expect(Sim.at(plan, 2063.4).water_m == Sim.at(plan.duplicate_plan(), 2063.4).water_m, "same plan gives same water")


func _test_doing_nothing() -> void:
	var outcome := Sim.outcome(Plan.new())
	_expect(is_equal_approx(snappedf(outcome["depth_2050"], 0.001), 0.525), "nothing gives 0.525 m in 2050, got %f" % outcome["depth_2050"])
	_expect(is_equal_approx(snappedf(outcome["depth_2080"], 0.001), 1.261), "nothing gives 1.261 m in 2080, got %f" % outcome["depth_2080"])
	_expect(outcome["homes"] == 0, "nothing loses every home")
	var today := Sim.at(Plan.new(), 2026.0)
	_expect(today.flood_m["salon"] == 0.0 and today.homes == 3, "every home is dry and standing in 2026")
	_expect(today.flood_m["street"] == 0.0, "the street is dry in 2026")


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
	_expect(Sim.best_fix(walled) != "wall", "more wall is never the fix")
	_expect(Sim.best_fix(walled) != "", "a fix exists for six walls")


func _test_balance() -> void:
	var rows := Solver.score_all()
	for check: Dictionary in Solver.check(rows):
		_expect(check["passed"], "%s %s" % [check["rule"], check["detail"]])
