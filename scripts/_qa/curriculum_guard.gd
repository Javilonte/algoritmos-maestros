extends Node

## Guard del curriculo: el mapeo enemigo -> challenge es el que dice el
## plan, y cada challenge nuevo se gana con una solucion natural.
## Run: godot --headless scenes/qa/curriculum_guard.tscn --quit-after 8000
##
## ponytail: dos Checks distintos y los dos importan.
##
## 1. El MAPEO: cada enemigo pelea con el concepto de su capitulo. El
##    tutorial con "escribi una funcion que compile" y el jefe final con
##    el examen, no al reves. El mapeo esta en el plan; aca esta copiado
##    para que un cambio accidental en el catalogue rompa el suite.
##
## 2. La SOLUCION CANONICA: cada challenge nuevo tiene una solucion
##    natural —la que escribiria un jugador que entendio el enunciado— y
##    esa solucion tiene que pasar el gate de forma Y los test cases en el
##    sandbox. Es el bug que ya se comio dos veces: el gate rechazaba la
##    solucion correcta y el challenge era IMPOSIBLE.
##
## Si la maquina no tiene compilador C++ el guard SE SALTA: el juego
## depende de el, pero el suite no puede romper por una maquina sin
## toolchain.

## El plan: odd/tasks/learning-path-and-difficulty.md, "Cambios de mapeo".
const CURRICULUM: Dictionary = {
	"slime_aritm": "main_exit_check",
	"buggo_ciego": "linear_search",
	"ogro_bucle": "factorial",
	"fantasma_offbyone": "binary_search",
	"memory_leak": "hash_map",
	"hidra_recursiva": "fibonacci",
	"golem_generico": "bubble_sort",
	"dragon_caos": "use_std_sort",
	"wyrm_paralelo": "template_generic",
	"compilador_divino": "final_gate",
}

## La segunda fase: el enemigo escala en vez de desaparecer.
const SECOND_PHASE: Dictionary = {
	"hidra_recursiva": "simple_dp",
	"wyrm_paralelo": "thread_join",
}

## La solucion natural de cada challenge nuevo, en C++.
const CANONICAL: Dictionary = {
	"use_std_sort": """#include <algorithm>

vector<int> sortWithStd(vector<int> arr) {
    sort(arr.begin(), arr.end());
    return arr;
}""",
	"template_generic": """template <typename T>
int maxOf(vector<T> arr) {
    T best = arr[0];
    for (int i = 1; i < (int)arr.size(); i++) {
        if (arr[i] > best) {
            best = arr[i];
        }
    }
    return (int)best;
}""",
	"thread_join": """#include <thread>
#include <vector>

int sumInThreads(int n) {
    int chunks = 4;
    std::vector<int> partials(chunks, 0);
    std::vector<std::thread> workers;
    for (int c = 0; c < chunks; c++) {
        int from = c * (n / chunks) + 1;
        int to = (c == chunks - 1) ? n : (c + 1) * (n / chunks);
        workers.push_back(std::thread([&partials, from, to, c]() {
            int acc = 0;
            for (int i = from; i <= to; i++) {
                acc += i;
            }
            partials[c] = acc;
        }));
    }
    for (auto& w : workers) {
        w.join();
    }
    int total = 0;
    for (int p : partials) {
        total += p;
    }
    return total;
}""",
	"final_gate": """#include <algorithm>
#include <unordered_map>

int sumOfDistinctSorted(vector<int> arr) {
    sort(arr.begin(), arr.end());
    std::unordered_map<int, int> seen;
    int total = 0;
    for (int i = 0; i < (int)arr.size(); i++) {
        if (seen.find(arr[i]) == seen.end()) {
            seen[arr[i]] = 1;
            total += arr[i];
        }
    }
    return total;
}""",
}

var _passed: Array = []
var _failed: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	_check_mapping()
	var sandbox := CppSandbox.new()
	if sandbox.find_compiler().is_empty():
		print("SKIP: no C++ compiler on this machine")
		get_tree().quit(0)
		return
	await _check_canonical(sandbox)
	_finish()


## El mapeo del catalogo tiene que ser el del plan.
func _check_mapping() -> void:
	for enemy_id in CURRICULUM:
		var expected: String = String(CURRICULUM[enemy_id])
		var data: Dictionary = EnemyCatalog.fetch(enemy_id)
		if data.is_empty():
			_failed.append("'%s' is not in the catalog" % enemy_id)
			continue
		var actual: String = String(data.get("challenge_id", ""))
		_check("'%s' fights '%s'" % [enemy_id, expected], actual == expected)
		_check("'%s' exists" % expected, ChallengeRegistry.has(expected))

	for enemy_id in SECOND_PHASE:
		var expected: String = String(SECOND_PHASE[enemy_id])
		var data: Dictionary = EnemyCatalog.fetch(enemy_id)
		var actual: String = String(data.get("challenge_id_next", ""))
		_check("'%s' escalates to '%s'" % [enemy_id, expected], actual == expected)
		_check("'%s' exists" % expected, ChallengeRegistry.has(expected))


## La solucion natural de cada challenge nuevo: el gate la tiene que
## aceptar y los test cases tienen que pasar en el sandbox.
func _check_canonical(sandbox: CppSandbox) -> void:
	for id in CANONICAL:
		var challenge: ChallengeResource = ChallengeRegistry.get_by_id(id)
		if challenge == null:
			_failed.append("'%s' does not load" % id)
			continue
		var code: String = String(CANONICAL[id])
		var ast: Dictionary = await AstValidator.validate(code, challenge)
		var valid: bool = bool(ast.get("valid", false))
		_check("'%s': the gate accepts the canonical solution" % id, valid)
		if not valid:
			print("      the gate could not find: %s" % str(ast.get("required_features_missing", [])))
			print("      errors: %s" % str(ast.get("errors", [])))

		var run: Dictionary = await sandbox.run(code, challenge)
		_check("'%s': the canonical solution compiles" % id, bool(run.get("compiled", false)))
		if not bool(run.get("compiled", false)):
			print("      compiler said: %s" % String(run.get("compile_output", "")))
			continue
		_check("'%s': the canonical solution does not hang" % id, not bool(run.get("timed_out", false)))
		var results: Array = run.get("results", [])
		_check("'%s': every case ran (%d)" % [id, challenge.test_cases.size()],
			results.size() == challenge.test_cases.size())
		var all_passed: bool = results.size() == challenge.test_cases.size()
		for r in results:
			if not bool((r as Dictionary).get("passed", false)):
				all_passed = false
		_check("'%s': every case passes" % id, all_passed)


func _check(message: String, ok: bool) -> void:
	if ok:
		_passed.append(message)
	else:
		_failed.append(message)


func _finish() -> void:
	print("\n========== CURRICULUM GUARD ==========")
	for p in _passed:
		print("  PASS: ", p)
	for f in _failed:
		print("  FAIL: ", f)
	print("PASSED: %d | FAILED: %d" % [_passed.size(), _failed.size()])
	get_tree().quit(1 if _failed.size() > 0 else 0)
