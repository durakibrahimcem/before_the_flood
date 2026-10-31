class_name Plan
extends RefCounted
## The player's choices. Everything about the future is computed from this.

const ACTIONS := ["grass", "dune", "sort", "light", "meet", "wall"]
const SLOTS := 6
const MAX_SKILL := 1.3
const CODE_ALPHABET := "23456789ABCDEFGHJKMNPQRSTVWXYZ01"

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
	assert(action in ACTIONS, "Unknown action: %s" % action)
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
		parts.append("%d:%.3f" % [counts[action], skill[action]])
	return ",".join(parts)


func code() -> String:
	var index := all_plans().find_custom(func(other: Plan) -> bool: return other.counts == counts)
	if index < 0:
		return ""
	var scrambled := (index * 2741 + 77) % 32768
	var text := ""
	for shift: int in [10, 5, 0]:
		text += CODE_ALPHABET[(scrambled >> shift) & 31]
	return text


static func from_code(text: String) -> Plan:
	var wanted := text.strip_edges().to_upper()
	for plan: Plan in all_plans():
		if plan.code() == wanted:
			return plan
	return null


static func all_plans() -> Array[Plan]:
	var result: Array[Plan] = []
	_fill(Plan.new(), 0, SLOTS, result)
	return result


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
