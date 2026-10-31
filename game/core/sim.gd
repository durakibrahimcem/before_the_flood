class_name Sim
extends RefCounted
## Pure simulation: the future depends only on the plan and the year.

const FIRST_YEAR := 2026
const LAST_YEAR := 2080
const CRACK_YEARS := 8

static var _balance: Dictionary = {}
static var _sea: Dictionary = {}
static var _cache: Dictionary = {}


static func reload_data() -> void:
	_balance = _load_json("res://data/balance.json")
	_sea = _load_json("res://data/sea.json")
	_cache.clear()


static func at(plan: Plan, year: float) -> WorldState:
	var table := _table(plan)
	var clamped := clampf(year, FIRST_YEAR, LAST_YEAR)
	var low := mini(floori(clamped), LAST_YEAR - 1)
	var mix := clamped - low
	var rows: Array = table["rows"]
	var a: Dictionary = rows[low - FIRST_YEAR]
	var b: Dictionary = rows[low + 1 - FIRST_YEAR]
	var b_cfg := _config()

	var state := WorldState.new()
	state.year = clamped
	state.water_m = lerpf(a["level"], b["level"], mix)
	state.meadow = lerpf(a["meadow"], b["meadow"], mix)
	state.dune = lerpf(a["dune"], b["dune"], mix)
	state.wall_state = _wall_state(plan, clamped)

	var rooms: Dictionary = b_cfg["room_ground_m"]
	for room: String in rooms:
		state.flood_m[room] = maxf(0.0, state.water_m - float(rooms[room]))

	var lost: Dictionary = table["lost"]
	var alive := 0
	for home: String in lost:
		var standing: bool = clamped < float(lost[home])
		state.home_alive[home] = standing
		alive += 1 if standing else 0
	state.homes = alive
	state.neighbours = (1 if state.home_alive["near"] else 0) + (1 if state.home_alive["far"] else 0)
	state.severity = clampf(float(state.flood_m["salon"]) / float(b_cfg["severity_full_m"]), 0.0, 1.0)
	return state


static func outcome(plan: Plan) -> Dictionary:
	var table := _table(plan)
	var lost: Dictionary = table["lost"]
	var homes := 0
	for home: String in lost:
		homes += 1 if float(lost[home]) > LAST_YEAR else 0
	var depth_2050: float = at(plan, 2050).flood_m["salon"]
	var depth_2080: float = at(plan, 2080).flood_m["salon"]
	var peak: float = table["peak"]
	return {
		"homes": homes,
		"depth_2050": depth_2050,
		"depth_2080": depth_2080,
		"peak_m": peak,
		"breach_year": breach_year(plan),
		"score": homes * 2.0 - depth_2080 - 0.25 * peak,
	}


static func best_fix(plan: Plan) -> String:
	var base: float = outcome(plan)["score"]
	var best_action := ""
	var best_gain := 0.0
	for candidate: Plan in _neighbours(plan):
		var gain: float = float(outcome(candidate)["score"]) - base
		if gain > best_gain + 0.0001:
			best_gain = gain
			best_action = _added_action(plan, candidate)
	return best_action


static func breach_year(plan: Plan) -> int:
	if plan.counts["wall"] == 0:
		return 0
	var cfg := _config()
	var year: int = int(cfg["breach_first_year"]) + int(cfg["breach_step_years"]) * (int(plan.counts["wall"]) - 1)
	return mini(year, int(cfg["breach_latest_year"]))


static func _neighbours(plan: Plan) -> Array[Plan]:
	var result: Array[Plan] = []
	if plan.total() < Plan.SLOTS:
		for add: String in Plan.ACTIONS:
			var extra := plan.duplicate_plan()
			extra.counts[add] += 1
			result.append(extra)
		return result
	for remove: String in Plan.ACTIONS:
		if plan.counts[remove] == 0:
			continue
		for add: String in Plan.ACTIONS:
			if add == remove:
				continue
			var swapped := plan.duplicate_plan()
			swapped.counts[remove] -= 1
			swapped.counts[add] += 1
			result.append(swapped)
	return result


static func _added_action(before: Plan, after: Plan) -> String:
	for action: String in Plan.ACTIONS:
		if after.counts[action] > before.counts[action]:
			return action
	return ""


static func _table(plan: Plan) -> Dictionary:
	var key := plan.cache_key()
	if _cache.has(key):
		return _cache[key]
	var cfg := _config()
	var rows: Array = []
	var peak_level := 0.0
	var lost: Dictionary = {}
	var ground: Dictionary = cfg["ground_m"]
	for home: String in ground:
		lost[home] = INF
	var limit: float = float(cfg["home_limit_m"]) + float(cfg["light_margin_m"]) * _level(plan.strength("light"), float(cfg["light_keep"]))
	for year: int in range(FIRST_YEAR, LAST_YEAR + 1):
		var row := _row(plan, year)
		rows.append(row)
		var level: float = row["level"]
		peak_level = maxf(peak_level, level)
		for home: String in ground:
			if lost[home] == INF and level - float(ground[home]) > limit:
				lost[home] = float(year)
	var table := {
		"rows": rows,
		"lost": lost,
		"peak": maxf(0.0, peak_level - float(ground["own"])),
	}
	_cache[key] = table
	return table


static func _row(plan: Plan, year: int) -> Dictionary:
	var cfg := _config()
	var meet := plan.strength("meet")
	var cover: float = float(cfg["cover_base"]) + float(cfg["cover_first"]) * minf(meet, 1.0) + float(cfg["cover_second"]) * clampf(meet - 1.0, 0.0, 1.0)
	var world: float = minf(float(cfg["world_max"]), float(cfg["world_per_meet"]) * meet + float(cfg["world_per_light"]) * plan.strength("light"))
	var keep: float = cfg["level_keep"]

	var span := float(year - FIRST_YEAR) / float(LAST_YEAR - FIRST_YEAR)
	var natural: float = 1.0 - float(cfg["meadow_decline"]) * pow(span, float(cfg["meadow_power"]))
	var meadow := minf(1.0, natural + _level(plan.strength("grass"), keep) * cover * _growth(year, float(cfg["tau_grass"])))
	var has_wall: bool = plan.counts["wall"] > 0
	if has_wall:
		meadow *= 1.0 - float(cfg["wall_harm"]) * _growth(year, float(cfg["tau_wall"]))

	var dune_share: float = _level(plan.strength("dune"), keep) * cover * _growth(year, float(cfg["tau_dune"]))
	var drains: float = float(cfg["drain_max_m"]) * pow(float(cfg["drain_keep"]), plan.strength("sort"))
	var level: float = _sea_rise(year, world) + float(cfg["storm_base_m"]) + float(cfg["grass_max_m"]) * (1.0 - meadow) + drains - float(cfg["dune_max_m"]) * dune_share

	if has_wall:
		var walls: int = plan.counts["wall"]
		if year < breach_year(plan):
			level = maxf(0.0, level - float(cfg["wall_crest_m"]) - float(cfg["wall_extra_m"]) * (walls - 1))
		else:
			level += float(cfg["breach_after_m"]) * (1.0 + float(cfg["breach_growth"]) * (walls - 1))
	return { "level": level, "meadow": meadow, "dune": dune_share }


static func _wall_state(plan: Plan, year: float) -> int:
	var breach := breach_year(plan)
	if breach == 0:
		return WorldState.Wall.NONE
	if year >= breach:
		return WorldState.Wall.BREACHED
	if year >= breach - CRACK_YEARS:
		return WorldState.Wall.CRACKED
	return WorldState.Wall.STANDING


static func _sea_rise(year: int, world: float) -> float:
	var sea := _sea_data()
	var high: Dictionary = sea["high"]
	var low: Dictionary = sea["low"]
	var rise_high := _curve(high, year) - _curve(high, FIRST_YEAR)
	var rise_low := _curve(low, year) - _curve(low, FIRST_YEAR)
	return lerpf(rise_high, rise_low, world)


static func _curve(path: Dictionary, year: int) -> float:
	var t := float(year - 2005)
	return float(path["a"]) * t + float(path["b"]) * t * t


static func _growth(year: int, tau: float) -> float:
	return 1.0 - exp(-float(year - FIRST_YEAR) / tau)


static func _level(amount: float, keep: float) -> float:
	return 1.0 - pow(keep, amount)


static func _config() -> Dictionary:
	if _balance.is_empty():
		reload_data()
	return _balance


static func _sea_data() -> Dictionary:
	if _sea.is_empty():
		reload_data()
	return _sea


static func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "Bad data file: %s" % path)
	return parsed
