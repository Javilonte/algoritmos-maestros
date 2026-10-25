extends RefCounted
class_name TemplateGenericRunner

## Referencia de `template_generic`: el maximo del vector.
##
## ponytail: el sandbox corre el C++ del JUGADOR contra los test cases.
## Este runner es la referencia en GDScript: el challenge_registry_guard lo
## instancia y lo llama, asi que tiene que devolver la forma
## {passed, actual, error} y resolver el mismo caso que la referencia C++.

static func run_test(test: TestCase, _player_code: String) -> Dictionary:
	var actual: int = _max_of(test.inputs[0])
	var expected: int = int(test.expected)
	var passed: bool = actual == expected
	var error: String = "" if passed else "expected %d, got %d" % [expected, actual]
	return {"passed": passed, "actual": actual, "error": error}


## El maximo del vector, como lo escribiria el jugador en C++ con un
## `template<typename T>`.
static func _max_of(values: Array) -> int:
	var best: int = int(values[0])
	for value in values:
		if int(value) > best:
			best = int(value)
	return best
