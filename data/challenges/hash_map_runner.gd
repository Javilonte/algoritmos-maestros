extends RefCounted
class_name HashMapRunner

static func run_test(test: TestCase, _player_code: String) -> Dictionary:
	var arr: Array = (test.inputs[0] as Array).duplicate()
	var actual: int = _count_unique(arr)
	var expected: int = int(test.expected)
	var passed: bool = actual == expected
	var error: String = "" if passed else "expected %d unique values, got %d for %s" % [expected, actual, str(arr)]
	return { "passed": passed, "actual": actual, "error": error }

## ponytail: returns the count of distinct integers in the array.
## Reference impl uses a Dictionary as an O(n) hash map; the player's
## solution should do the same.
static func _count_unique(arr: Array) -> int:
	var seen: Dictionary = {}
	for v in arr:
		seen[int(v)] = true
	return seen.size()
