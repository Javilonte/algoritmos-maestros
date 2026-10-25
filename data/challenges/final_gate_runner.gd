extends RefCounted
class_name FinalGateRunner

## Referencia de `final_gate`: la suma de los valores distintos.
##
## ponytail: el sandbox corre el C++ del JUGADOR contra los test cases.
## Este runner es la referencia en GDScript: el challenge_registry_guard lo
## instancia y lo llama, asi que tiene que devolver la forma
## {passed, actual, error} y resolver el mismo caso que la referencia C++.

static func run_test(test: TestCase, _player_code: String) -> Dictionary:
	var actual: int = _sum_of_distinct_sorted(test.inputs[0])
	var expected: int = int(test.expected)
	var passed: bool = actual == expected
	var error: String = "" if passed else "expected %d, got %d" % [expected, actual]
	return {"passed": passed, "actual": actual, "error": error}


## Ordena el vector y suma cada valor distinto una sola vez.
static func _sum_of_distinct_sorted(values: Array) -> int:
	var sorted: Array = values.duplicate()
	sorted.sort()
	var seen: Dictionary = {}
	var total: int = 0
	for value in sorted:
		if not seen.has(value):
			seen[value] = true
			total += int(value)
	return total
