extends RefCounted
class_name TestRunner

func run(challenge: ChallengeResource, player_code: String) -> TestResult:
	var result := TestResult.new()
	result.challenge_id = String(challenge.id)
	result.total = challenge.test_cases.size()

	# AST gate: structural validation BEFORE running any test (cheap fail-fast).
	var ast: Dictionary = AstValidator.validate(player_code, challenge)
	result.ast_valid = bool(ast.get("valid", false))
	result.ast_quality = float(ast.get("quality", 0.0))
	result.ast_summary = String(ast.get("feature_summary", ""))
	var ast_errors: PackedStringArray = AstValidator.friendly_errors(ast)
	for err in ast_errors:
		result.errors.append("AST: " + err)

	if not result.ast_valid:
		result.success = false
		# Skip oracle execution — it's meaningless if the function isn't even declared.
		return result

	# Legacy path: also call the old validate so behaviour matches the existing flow.
	var ast_check: Dictionary = CodeValidator.evaluate(String(challenge.id), player_code)
	if not bool(ast_check.get("success", false)):
		# AST structural pass but legacy validator complains (e.g. Unknown challenge).
		# Don't fail tests just because of that — we already passed structural.
		pass

	# Oracle tests using the challenge runner.
	if challenge.runner_path.is_empty():
		push_error("TestRunner: challenge '%s' has no runner_path" % challenge.id)
		result.errors.append("no runner configured for this challenge")
		return result

	var runner_script := load(challenge.runner_path)
	if runner_script == null:
		push_error("TestRunner: could not load runner script '%s'" % challenge.runner_path)
		result.errors.append("runner script not found")
		return result

	var start: int = Time.get_ticks_msec()
	for test in challenge.test_cases:
		var outcome: Dictionary = runner_script.run_test(test, player_code)
		if bool(outcome.get("passed", false)):
			result.passed += 1
		else:
			var err_msg: String = String(outcome.get("error", "failed"))
			result.errors.append("%s: %s" % [test.name, err_msg])
			result.failed_test_names.append(test.name)
	result.execute_time_ms = Time.get_ticks_msec() - start
	result.success = result.passed == result.total and result.total > 0
	return result
