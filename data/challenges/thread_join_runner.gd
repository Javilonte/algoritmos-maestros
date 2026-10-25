extends RefCounted
class_name ThreadJoinRunner

## Referencia de `thread_join`: la suma de 1 a n.
##
## ponytail: el sandbox corre el C++ del JUGADOR contra los test cases.
## Este runner es la referencia en GDScript: el challenge_registry_guard lo
## instancia y lo llama, asi que tiene que devolver la forma
## {passed, actual, error} y resolver el mismo caso que la referencia C++.
##
## La referencia no usa hilos: el resultado NO depende de como se reparta
## el trabajo, solo de la suma. Los hilos son el concepto que se ensena,
## no el resultado que se mide.

static func run_test(test: TestCase, _player_code: String) -> Dictionary:
	var n: int = int(test.inputs[0])
	var actual: int = _sum_in_threads(n)
	var expected: int = int(test.expected)
	var passed: bool = actual == expected
	var error: String = "" if passed else "expected %d, got %d" % [expected, actual]
	return {"passed": passed, "actual": actual, "error": error}


static func _sum_in_threads(n: int) -> int:
	var total: int = 0
	for i in range(1, n + 1):
		total += i
	return total
