extends SceneTree
## Run: tools/g --headless --path game --script tools/solve.gd
## Scores all plans, prints the balance rules and writes data/plans.json.


func _initialize() -> void:
	var rows := Solver.score_all()
	var failed := 0
	for check: Dictionary in Solver.check(rows):
		print("%s  %s  %s" % ["PASS" if check["passed"] else "FAIL", check["rule"], check["detail"]])
		failed += 0 if check["passed"] else 1
	if failed > 0:
		printerr("Balance rules failed, so plans.json was not written.")
		quit(1)
		return
	var file := FileAccess.open(Solver.PLANS_PATH, FileAccess.WRITE)
	if file == null:
		printerr("Could not write plans.json")
		quit(1)
		return
	file.store_string(JSON.stringify(rows, "  "))
	file.close()
	print("Wrote %d plans. Best: %s, %.2f m in 2080" % [rows.size(), rows[0]["plan"], rows[0]["depth_2080"]])
	quit(0)
