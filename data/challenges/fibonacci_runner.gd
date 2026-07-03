extends RefCounted
class_name FibonacciRunner

static func run_test(test: TestCase, _player_code: String) -> Dictionary:
	var n: int = int(test.inputs[0])
	var actual: int = _fibonacci(n)
	var expected: int = int(test.expected)
	var passed: bool = actual == expected
	var error: String = "" if passed else "expected %d, got %d" % [expected, actual]
	return { "passed": passed, "actual": actual, "error": error }

static func _fibonacci(n: int) -> int:
	if n <= 1:
		return n
	return _fibonacci(n - 1) + _fibonacci(n - 2)
