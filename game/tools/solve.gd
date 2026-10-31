extends SceneTree
## Run: tools/g --headless --path game --script tools/solve.gd
## Scores all plans, prints the balance rules and writes data/plans.json.


func _initialize() -> void:
	var rows := Solver.score_all()
	var failed := 0
	for check: Dictionary in Solver.check(rows):
		print("%s  %s  %s" % ["PASS" if check["passed"] else "FAIL", check["rule"], check["detail"]])
		failed += 0 if check["passed"] else 1
	var file := FileAccess.open("res://data/plans.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "  "))
	file.close()
	print("Wrote %d plans. Best: %s, %.2f m in 2080" % [rows.size(), rows[0]["plan"], rows[0]["depth_2080"]])
	quit(1 if failed > 0 else 0)
