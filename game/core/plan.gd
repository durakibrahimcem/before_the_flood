class_name Plan
extends RefCounted
## The player's choices. Everything about the future is computed from this.

const ACTIONS := ["grass", "dune", "sort", "light", "meet", "wall"]
const SLOTS := 6
const MAX_SKILL := 1.3
const CODE_ALPHABET := "23456789ABCDEFGHJKMNPQRSTVWXYZ01"

static var _all: Array[Plan] = []
static var _by_code: Dictionary = {}

var counts: Dictionary = {}
var skill: Dictionary = {}


func _init() -> void:
	for action: String in ACTIONS:
		counts[action] = 0
		skill[action] = 1.0


func total() -> int:
	var sum := 0
	for action: String in ACTIONS:
		sum += counts[action]
	return sum


func add(action: String, performance: float) -> void:
	if not action in ACTIONS:
		push_error("Unknown action: %s" % action)
		return
	var n: int = counts[action] + 1
	var strength := 1.0 + (MAX_SKILL - 1.0) * clampf(performance, 0.0, 1.0)
	skill[action] = (float(skill[action]) * (n - 1) + strength) / n
	counts[action] = n


func strength(action: String) -> float:
	return float(counts[action]) * float(skill[action])


func duplicate_plan() -> Plan:
	var copy := Plan.new()
	copy.counts = counts.duplicate()
	copy.skill = skill.duplicate()
	return copy


func cache_key() -> String:
	var parts := PackedStringArray()
	for action: String in ACTIONS:
		parts.append("%d:%.6f" % [counts[action], skill[action]])
	return ",".join(parts)


## A short code for these choices. It does not carry skill, so a friend replays them at normal strength.
func code() -> String:
	_index_plans()
	for known: String in _by_code:
		if (_by_code[known] as Plan).counts == counts:
			return known
	return ""


static func from_code(text: String) -> Plan:
	_index_plans()
	var found: Plan = _by_code.get(text.strip_edges().to_upper())
	return found.duplicate_plan() if found != null else null


static func all_plans() -> Array[Plan]:
	if _all.is_empty():
		_fill(Plan.new(), 0, SLOTS, _all)
	return _all


static func _index_plans() -> void:
	if not _by_code.is_empty():
		return
	var plans := all_plans()
	for index: int in plans.size():
		var scrambled := (index * 2741 + 77) % 32768
		var text := ""
		for shift: int in [10, 5, 0]:
			text += CODE_ALPHABET[(scrambled >> shift) & 31]
		_by_code[text] = plans[index]


static func _fill(partial: Plan, index: int, left: int, result: Array[Plan]) -> void:
	if index == ACTIONS.size() - 1:
		var last := partial.duplicate_plan()
		last.counts[ACTIONS[index]] = left
		result.append(last)
		return
	for amount: int in range(left + 1):
		var next := partial.duplicate_plan()
		next.counts[ACTIONS[index]] = amount
		_fill(next, index + 1, left - amount, result)
