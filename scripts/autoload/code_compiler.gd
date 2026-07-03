extends Node

var _compile_start_ms: int = 0

func compile_and_execute(challenge_id: String, code: String) -> void:
	var challenge: ChallengeResource = ChallengeRegistry.get_by_id(challenge_id)
	if challenge == null:
		push_error("CodeCompiler: unknown challenge '%s'" % challenge_id)
		return
	_compile_start_ms = Time.get_ticks_msec()
	GameManager.change_state(GameManager.GameState.COMPILING)
	EventBus.compiling_started.emit(challenge_id)

	# Fase 1: lexing
	EventBus.compiling_progress.emit("lexing", 0.10)
	await get_tree().create_timer(0.15).timeout

	# Fase 2: AST structural validation (real tree-sitter via GDExtension)
	EventBus.compiling_progress.emit("parsing AST", 0.25)
	await get_tree().create_timer(0.2).timeout
	var ast: Dictionary = AstValidator.validate(code, challenge)
	if not bool(ast.get("valid", false)):
		EventBus.compiling_progress.emit("FAILED", 1.0)
		await get_tree().create_timer(0.1).timeout
		var errs: PackedStringArray = AstValidator.friendly_errors(ast)
		var msg: String = "Compilation failed"
		if errs.size() > 0:
			msg = String(errs[0])
		else:
			msg = "Structural validation failed (see code quality 0.0)."
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
		return

	# Fase 3: legacy main_exit_check-style validation (preserved for the
	# original main_exit_check challenge; harmless for others).
	EventBus.compiling_progress.emit("syntax check", 0.4)
	await get_tree().create_timer(0.15).timeout
	var legacy: Dictionary = CodeValidator.evaluate(challenge_id, code)
	if not bool(legacy.get("success", false)):
		# AST structural already passed; if the legacy validator also fails it's
		# often because the C++ side doesn't know the challenge_id. We fall
		# through to oracle tests anyway — TestRunner surfaces any errors.
		pass

	# Fase 4: linking
	EventBus.compiling_progress.emit("linking", 0.55)
	await get_tree().create_timer(0.2).timeout

	# Fase 5: optimizing
	EventBus.compiling_progress.emit("optimizing", 0.7)
	await get_tree().create_timer(0.15).timeout

	# Fase 6: running tests
	GameManager.change_state(GameManager.GameState.EXECUTING)
	EventBus.compiling_progress.emit("running tests", 0.85)
	var runner := TestRunner.new()
	var result: TestResult = await runner.run(challenge, code)
	result.compile_time_ms = Time.get_ticks_msec() - _compile_start_ms

	EventBus.compiling_progress.emit("done", 1.0)
	await get_tree().create_timer(0.1).timeout
	var summary: String = result.ast_summary
	var ok_msg: String = "Compiled %dms | AST %s | %d/%d tests" % [
		result.compile_time_ms, summary, result.passed, result.total
	]
	EventBus.compiling_finished.emit(result.success, ok_msg)
	EventBus.code_executed.emit(result)
