extends Node

## Guard del sandbox de C++: el codigo del jugador se compila y se corre
## de verdad. Run: godot --headless scenes/qa/cpp_sandbox_guard.tscn --quit-after 400
##
## ponytail: hasta ahora los runners de cada challenge llamaban a su propia
## solucion de referencia. Este guard es la prueba de que el codigo del
## JUGADOR es el que se evalua: una solucion correcta pasa todos los casos
## y una solucion que devuelve cualquier cosa falla con el detalle real.
##
## Si la maquina no tiene compilador C++ el guard SE SALTA: el juego
## depende de el, pero el suite no puede romper por una maquina sin
## toolchain.

const CHALLENGE := "res://data/challenges/simple_dp.tres"

const CORRECT := """int climbStairs(int n) {
    int a = 1;
    int b = 1;
    for (int i = 2; i <= n; i++) {
        int c = a + b;
        a = b;
        b = c;
    }
    if (n <= 1) {
        return 1;
    }
    return b;
}"""

const WRONG := """int climbStairs(int n) {
    return 0;
}"""

const BROKEN := """int climbStairs(int n) {
    for (int i = 0 i < n; i++) {}
    return 0
}"""

var _passed: Array = []
var _failed: Array = []
var _skipped: bool = false


func _ready() -> void:
	_run()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed.append(label)
	else:
		_failed.append(label)


func _run() -> void:
	var challenge: ChallengeResource = load(CHALLENGE)
	if challenge == null:
		_failed.append("could not load the challenge")
		_finish()
		return

	var sandbox := CppSandbox.new()
	if sandbox.find_compiler().is_empty():
		_skipped = true
		print("SKIP: no C++ compiler on this machine (clang++ / g++ / c++)")
		_finish()
		return

	# --- 1. la solucion del jugador es la que se evalua ----------------------
	var ok: Dictionary = await sandbox.run(CORRECT, challenge)
	_check(bool(ok.get("compiled", false)), "the player's code compiles")
	var results: Array = ok.get("results", [])
	var passed: int = 0
	for r in results:
		if bool(r.get("passed", false)):
			passed += 1
	_check(passed == challenge.test_cases.size(),
		"the player's correct solution passes every case (%d/%d)" % [passed, challenge.test_cases.size()])

	# --- 2. una solucion incorrecta falla con el detalle real ---------------
	var bad: Dictionary = await sandbox.run(WRONG, challenge)
	_check(bool(bad.get("compiled", false)), "a wrong solution still compiles")
	var bad_results: Array = bad.get("results", [])
	_check(bad_results.size() == challenge.test_cases.size(),
		"every case is evaluated (%d)" % bad_results.size())
	var first_error: String = ""
	var all_failed: bool = not bad_results.is_empty()
	for r in bad_results:
		if bool(r.get("passed", false)):
			all_failed = false
		if first_error.is_empty():
			first_error = String(r.get("error", ""))
	_check(all_failed, "a wrong solution fails every case")
	_check(first_error.contains("expected"), "the failure says what was expected (%s)" % first_error)

	# --- 3. el codigo roto da el error del compilador -----------------------
	var broken: Dictionary = await sandbox.run(BROKEN, challenge)
	_check(not bool(broken.get("compiled", false)), "broken code does not compile")
	var output: String = String(broken.get("compile_output", ""))
	_check(output.contains("error:"), "the compiler's own error is reported")
	_check(not output.contains("/Users/"), "the compiler error does not leak the sandbox path")

	# --- 4. el challenge "escribi un main" -----------------------------------
	# El harness NO puede definir otro main: el codigo del jugador ES el
	# main. Es el challenge que va a ser la tutorial.
	var main_challenge: ChallengeResource = load("res://data/challenges/main_exit_check.tres")
	var main_result: Dictionary = await sandbox.run("int main() { return 0; }", main_challenge)
	_check(bool(main_result.get("compiled", false)), "a player's main compiles")
	_check(not bool(main_result.get("timed_out", false)), "a player's main does not hang")

	_finish()


func _finish() -> void:
	print("\n========== CPP SANDBOX GUARD ==========")
	for p in _passed:
		print("  PASS: ", p)
	for f in _failed:
		print("  FAIL: ", f)
	print("PASSED: %d | FAILED: %d" % [_passed.size(), _failed.size()])
	get_tree().quit(1 if _failed.size() > 0 else 0)
