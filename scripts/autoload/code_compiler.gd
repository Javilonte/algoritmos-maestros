extends Node

## Compila y ejecuta el codigo del jugador.
##
## ponytail: hasta ahora los runners de cada challenge llamaban a su propia
## solucion de referencia — el codigo del jugador NUNCA se ejecutaba y las
## fases "linking" y "optimizing" eran barras de progreso falsas. Ahora el
## codigo del jugador se compila con clang++ y se corre contra los test
## cases de verdad, en un sandbox local (scripts/battle/cpp_sandbox.gd).
##
## El orden es: forma primero (barato, y el checklist del editor ya le
## muestra al jugador lo que falta), despues compilacion, despues tests.

var _compile_start_ms: int = 0


func compile_and_execute(challenge_id: String, code: String) -> void:
	var challenge: ChallengeResource = ChallengeRegistry.get_by_id(challenge_id)
	if challenge == null:
		push_error("CodeCompiler: unknown challenge '%s'" % challenge_id)
		return
	_compile_start_ms = Time.get_ticks_msec()
	GameManager.change_state(GameManager.GameState.COMPILING)
	EventBus.compiling_started.emit(challenge_id)

	# --- Fase 1: lexing / AST -------------------------------------------------
	EventBus.compiling_progress.emit("lexing", 0.10)
	await get_tree().create_timer(0.15).timeout
	EventBus.compiling_progress.emit("parsing AST", 0.25)
	await get_tree().create_timer(0.1).timeout
	var ast: Dictionary = AstValidator.validate(code, challenge)
	if not bool(ast.get("valid", false)):
		await _fail_structure(challenge_id, challenge, ast)
		return

	# --- Fase 2: compilar de verdad -------------------------------------------
	EventBus.compiling_progress.emit("compiling", 0.40)
	var sandbox := CppSandbox.new()
	var sandbox_result: Dictionary = await sandbox.run(code, challenge)
	if not bool(sandbox_result.get("compiled", false)):
		await _fail_compile(challenge_id, challenge, ast, sandbox_result)
		return

	# --- Fase 3: correr los tests de verdad -----------------------------------
	GameManager.change_state(GameManager.GameState.EXECUTING)
	EventBus.compiling_progress.emit("running tests", 0.85)
	var result := _result_from_sandbox(challenge_id, challenge, ast, sandbox_result)
	result.compile_time_ms = Time.get_ticks_msec() - _compile_start_ms

	EventBus.compiling_progress.emit("done", 1.0)
	await get_tree().create_timer(0.1).timeout
	var ok_msg: String = "Compiled %dms | AST %s | %d/%d tests" % [
		result.compile_time_ms, result.ast_summary, result.passed, result.total
	]
	EventBus.compiling_finished.emit(result.success, ok_msg)
	EventBus.code_executed.emit(result)


## La forma no esta: el checklist del editor ya le decia que faltaba, asi
## que el mensaje es corto y en el idioma del jugador.
func _fail_structure(challenge_id: String, challenge: ChallengeResource, ast: Dictionary) -> void:
	EventBus.compiling_progress.emit("FAILED", 1.0)
	await get_tree().create_timer(0.1).timeout
	var missing: Array = ast.get("required_features_missing", [])
	var msg: String = ""
	if missing.size() > 0:
		msg = AstValidator.missing_features_message(missing)
	else:
		var errs: PackedStringArray = AstValidator.friendly_errors(ast)
		msg = String(errs[0]) if errs.size() > 0 else "Structural validation failed."
	EventBus.compiling_finished.emit(false, msg)
	var failed := TestResult.new()
	failed.challenge_id = challenge_id
	failed.total = challenge.test_cases.size()
	failed.errors.append("AST: " + msg)
	failed.success = false
	failed.ast_valid = false
	failed.ast_quality = float(ast.get("quality", 0.0))
	failed.ast_summary = String(ast.get("feature_summary", ""))
	EventBus.code_executed.emit(failed)


## No compila: el error del compilador es el mejor feedback que existe.
func _fail_compile(challenge_id: String, challenge: ChallengeResource, ast: Dictionary, sandbox_result: Dictionary) -> void:
	EventBus.compiling_progress.emit("FAILED", 1.0)
	await get_tree().create_timer(0.1).timeout
	var output: String = String(sandbox_result.get("compile_output", "")).strip_edges()
	if bool(sandbox_result.get("timed_out", false)):
		output = "La compilacion tardo demasiado y se cancelo."
	var msg: String = output if not output.is_empty() else "Compilation failed."
	EventBus.compiling_finished.emit(false, msg)
	var failed := TestResult.new()
	failed.challenge_id = challenge_id
	failed.total = challenge.test_cases.size()
	failed.errors.append("compile: " + msg)
	failed.success = false
	failed.ast_valid = true
	failed.ast_quality = float(ast.get("quality", 0.0))
	failed.ast_summary = String(ast.get("feature_summary", ""))
	EventBus.code_executed.emit(failed)


## Arma el resultado con lo que devvio el sandbox.
##
## ponytail: un caso sin inputs (main_exit_check) solo pide que el codigo
## compile: el sandbox ya lo compilo, asi que ese caso pasa.
func _result_from_sandbox(challenge_id: String, challenge: ChallengeResource, ast: Dictionary, sandbox_result: Dictionary) -> TestResult:
	var result := TestResult.new()
	result.challenge_id = challenge_id
	result.total = challenge.test_cases.size()
	result.ast_valid = true
	result.ast_quality = float(ast.get("quality", 0.0))
	result.ast_summary = String(ast.get("feature_summary", ""))
	if bool(sandbox_result.get("timed_out", false)):
		result.errors.append(String(sandbox_result.get("runtime_output", "timeout")))
		return result
	var cases: Array = sandbox_result.get("results", [])
	var index: int = 0
	for test in challenge.test_cases:
		if test.inputs.is_empty():
			result.passed += 1
			index += 1
			continue
		if index >= cases.size():
			result.errors.append("%s: no devolvio resultado" % test.name)
			result.failed_test_names.append(test.name)
			index += 1
			continue
		var case: Dictionary = cases[index]
		if bool(case.get("passed", false)):
			result.passed += 1
		else:
			result.errors.append("%s: %s" % [test.name, String(case.get("error", "failed"))])
			result.failed_test_names.append(test.name)
		index += 1
	result.success = result.passed == result.total and result.total > 0
	return result
