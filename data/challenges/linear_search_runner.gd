extends RefCounted
class_name LinearSearchRunner

static func run_test(test: TestCase, _player_code: String) -> Dictionary:
	var arr: Array = (test.inputs[0] as Array).duplicate()
	var target: int = int(test.inputs[1])
	var actual: int = _linear_search(arr, target)
	var expected: int = int(test.expected)
	var passed: bool = actual == expected
	var error: String = "" if passed else "expected %d, got %d for target %d in %s" % [expected, actual, target, str(arr)]
	return { "passed": passed, "actual": actual, "error": error }

static func _linear_search(arr: Array, target: int) -> int:
	for i in arr.size():
		if int(arr[i]) == target:
			return i
	return -1
