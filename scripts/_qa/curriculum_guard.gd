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

## El skill que cada challenge practica. Viene de la tabla del plan de
## aprendizaje: cada challenge es el ejercicio de UN concepto.
const SKILLS: Dictionary = {
	"main_exit_check": "root_arithmetic",
	"linear_search": "ptr_if_else",
	"factorial": "stl_loops",
	"binary_search": "ptr_arrays",
	"bubble_sort": "stl_functions",
	"use_std_sort": "stl_containers",
	"hash_map": "ptr_dynamic",
	"fibonacci": "recursion",
	"simple_dp": "recursion",
	"template_generic": "templates",
	"thread_join": "concurrency",
	"final_gate": "final_boss",
}

## Los turnos que cada enemigo deberia tardar en morir, segun la tabla del
## plan ("turnos objetivo"). El knob es el HP del enemigo, no el dano del
## challenge: subir el HP sube los turnos sin tocar la economia de dano.
const TARGET_TURNS: Dictionary = {
	"slime_aritm": 1,
	"buggo_ciego": 2,
	"ogro_bucle": 2,
	"fantasma_offbyone": 2,
	"memory_leak": 3,
	"hidra_recursiva": 2,
	"golem_generico": 2,
	"dragon_caos": 3,
	"wyrm_paralelo": 2,
	"compilador_divino": 6,
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
	"hash_map": """#include <unordered_map>

int countUnique(vector<int> arr) {
    std::unordered_map<int, int> seen;
    for (int v : arr) {
        seen[v] = 1;
    }
    return (int)seen.size();
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
	_check_skills()
	_check_turns()
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


## Cada enemigo tarda los turnos que dice el plan. Se calcula con el motor
## REAL (ScoringEngine) y el mejor caso: todos los tests pasan, rapido y
## sin combo.
func _check_turns() -> void:
	for enemy_id in TARGET_TURNS:
		var catalog: Dictionary = EnemyCatalog.fetch(enemy_id)
		if catalog.is_empty():
			_failed.append("'%s' is not in the catalog" % enemy_id)
			continue
		var challenge: ChallengeResource = ChallengeRegistry.get_by_id(
			String(catalog.get("challenge_id", "")))
		if challenge == null:
			_failed.append("'%s' has no challenge" % enemy_id)
			continue
		var result := TestResult.new()
		result.passed = challenge.test_cases.size()
		result.total = challenge.test_cases.size()
		result.ast_valid = true
		result.ast_quality = 1.0
		var roll: DamageRoll = ScoringEngine.calculate_damage(result, challenge, 0, 0)
		var damage: int = maxi(int(roll.amount), 1)
		var hp: int = int(catalog.get("max_hp", 0))
		var turns: int = int(ceil(float(hp) / float(damage)))
		_check("'%s' takes %d turns to kill (target %d: %d hp, %d dmg)"
				% [enemy_id, turns, int(TARGET_TURNS[enemy_id]), hp, damage],
			turns == int(TARGET_TURNS[enemy_id]))


## Cada challenge dice que skill practica, y el skill existe.
func _check_skills() -> void:
	for id in SKILLS:
		var challenge: ChallengeResource = ChallengeRegistry.get_by_id(id)
		if challenge == null:
			_failed.append("'%s' does not load" % id)
			continue
		var expected: String = String(SKILLS[id])
		_check("'%s' practices '%s'" % [id, expected], String(challenge.skill_id) == expected)
		_check("'%s' has a name in the skill tree" % expected, not SkillTree.skill_info(challenge.skill_id).is_empty())

	# Ningun challenge sin concepto: la pelea tiene que decir QUE se
	# practica, no solo que hay que escribir una funcion.
	for id in ChallengeRegistry.list_all().map(func(c): return String(c.id)):
		var challenge: ChallengeResource = ChallengeRegistry.get_by_id(id)
		_check("'%s' declares a skill" % id, not String(challenge.skill_id).is_empty())
		_check("'%s' skill exists" % id, not SkillTree.skill_info(challenge.skill_id).is_empty())


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
