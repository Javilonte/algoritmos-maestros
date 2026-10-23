extends RefCounted
class_name BinarySearchRunner

static func run_test(test: TestCase, _player_code: String) -> Dictionary:
	var arr: Array = (test.inputs[0] as Array).duplicate()
	var target: int = int(test.inputs[1])
	var actual: int = _binary_search(arr, target)
	var expected: int = int(test.expected)
	var passed: bool = actual == expected
	var error: String = "" if passed else "expected %d, got %d for target %d in %s" % [expected, actual, target, str(arr)]
	return { "passed": passed, "actual": actual, "error": error }

## ponytail: assumes the array is sorted ascending (per the prompt).
## Returns the index of target, or -1 if absent. Iterative mid = lo + (hi-lo)/2
## avoids overflow vs (lo+hi)/2.
static func _binary_search(arr: Array, target: int) -> int:
	var lo: int = 0
	var hi: int = arr.size() - 1
	while lo <= hi:
		var mid: int = lo + (hi - lo) / 2
		var v: int = int(arr[mid])
		if v == target:
			return mid
		if v < target:
			lo = mid + 1
		else:
			hi = mid - 1
	return -1
