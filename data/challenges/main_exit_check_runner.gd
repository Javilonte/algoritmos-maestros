extends RefCounted
class_name MainExitCheckRunner

static func run_test(_test: TestCase, _player_code: String) -> Dictionary:
	return { "passed": true, "actual": null, "error": "" }
