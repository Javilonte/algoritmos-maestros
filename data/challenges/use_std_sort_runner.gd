extends RefCounted
class_name UseStdSortRunner

## Referencia de `use_std_sort`: ordena ascendente.
##
## ponytail: el sandbox corre el C++ del JUGADOR contra los test cases.
## Este runner es la referencia en GDScript: el challenge_registry_guard lo
## instancia y lo llama, asi que tiene que devolver la forma
## {passed, actual, error} y resolver el mismo caso que la referencia C++.

static func run_test(test: TestCase, _player_code: String) -> Dictionary:
	var actual: Array = _sort_ascending(test.inputs[0])
	var expected: Array = test.expected
	var passed: bool = actual == expected
	var error: String = "" if passed else "expected %s, got %s" % [str(expected), str(actual)]
	return {"passed": passed, "actual": actual, "error": error}


## El equivalente GDScript de std::sort sobre un vector<int>.
static func _sort_ascending(values: Array) -> Array:
	var out: Array = values.duplicate()
	out.sort()
	return out
