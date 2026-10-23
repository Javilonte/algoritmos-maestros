extends RefCounted
class_name FactorialRunner

static func run_test(test: TestCase, _player_code: String) -> Dictionary:
	var n: int = int(test.inputs[0])
	var actual: int = _factorial(n)
	var expected: int = int(test.expected)
	var passed: bool = actual == expected
	var error: String = "" if passed else "expected %d, got %d" % [expected, actual]
	return { "passed": passed, "actual": actual, "error": error }

static func _factorial(n: int) -> int:
	if n <= 1:
		return 1
	return n * _factorial(n - 1)
