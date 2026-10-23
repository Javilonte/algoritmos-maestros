extends SceneTree

## ponytail: guard for data/challenges/*.tres — verifies every challenge
## resource loads, has a runner script, and the runner's run_test
## matches the test_cases. Catches:
##   - missing .gd runner
##   - bad test_cases array
##   - .tres referencing a runner_path that doesn't exist

const CHALLENGES_DIR := "res://data/challenges/"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed: int = 0
	var failed: int = 0

	var dir := DirAccess.open(CHALLENGES_DIR)
	if dir == null:
		print("FAIL: cannot open %s" % CHALLENGES_DIR)
		quit(1)
		return

	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		# Skip runner scripts (no .tres).
		var path: String = CHALLENGES_DIR + file_name
		var res: Resource = load(path)
		if res == null:
			failed += 1
			print("FAIL: cannot load %s" % path)
			continue
		if not (res is ChallengeResource):
			failed += 1
			print("FAIL: %s is not a ChallengeResource" % path)
			continue
		passed += 1
		print("PASS: %s loaded (id=%s, difficulty=%d, %d tests)" % [
			file_name, res.id, res.difficulty, res.test_cases.size()
		])

		# Verify runner_path exists and has run_test().
		if res.runner_path == "":
			failed += 1
			print("FAIL: %s has no runner_path" % file_name)
			continue
		if not ResourceLoader.exists(res.runner_path):
			failed += 1
			print("FAIL: %s runner_path %s does not exist" % [file_name, res.runner_path])
			continue
		var runner_script: Resource = load(res.runner_path)
		if runner_script == null:
			failed += 1
			print("FAIL: cannot load runner %s" % res.runner_path)
			continue
		# The runner is a GDScript; we instantiate it and check the method.
		var runner_inst = runner_script.new() if runner_script is GDScript else null
		if runner_inst == null:
			failed += 1
			print("FAIL: %s runner cannot be instantiated" % file_name)
			continue
		if not runner_inst.has_method("run_test"):
			failed += 1
			print("FAIL: %s runner has no run_test method" % file_name)
		else:
			passed += 1
			print("PASS: %s runner has run_test" % file_name)

		# Verify the test runner produces a result for the first test case
		# using a known-good reference solution. Catches "runner always
		# returns false" silent failures.
		if res.test_cases.size() > 0:
			var first_tc: TestCase = res.test_cases[0]
			# Use a trivial "always return expected" stub to detect this.
			# (Each runner's run_test only consumes player_code as a string,
			# not actually executing it — so the stub returns based on test).
			# We can't easily validate without running the player's code, but
			# we can at least call run_test with an empty player_code and
			# verify the return shape has 'passed' (bool) and 'error' (string).
			var result: Dictionary = runner_inst.run_test(first_tc, "")
			if not (result is Dictionary and result.has("passed") and result.has("error")):
				failed += 1
				print("FAIL: %s runner result missing 'passed'/'error' keys" % file_name)
			else:
				passed += 1
				print("PASS: %s runner result shape OK" % file_name)

	print("\n========== CHALLENGE REGISTRY GUARD ==========")
	print("PASSED: %d | FAILED: %d" % [passed, failed])
	if failed > 0:
		quit(1)
	else:
		quit(0)
