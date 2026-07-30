extends RefCounted
class_name SimpleDpRunner

static func run_test(test: TestCase, _player_code: String) -> Dictionary:
	var n: int = int(test.inputs[0])
	var actual: int = _climb_stairs(n)
	var expected: int = int(test.expected)
	var passed: bool = actual == expected
	var error: String = "" if passed else "expected %d ways for n=%d, got %d" % [expected, n, actual]
	return { "passed": passed, "actual": actual, "error": error }

## ponytail: classic "climbing stairs" DP — ways(n) = ways(n-1) + ways(n-2)
## with base ways(0) = 1, ways(1) = 1. Same recurrence as Fibonacci but
## initialized at 1/1. Iterative O(n) (no recursion) to match the
## pedagogical goal of teaching tabulation over memoization.
static func _climb_stairs(n: int) -> int:
	if n <= 1:
		return 1
	var prev2: int = 1
	var prev1: int = 1
	var cur: int = 0
	for i in range(2, n + 1):
		cur = prev1 + prev2
		prev2 = prev1
		prev1 = cur
	return cur
