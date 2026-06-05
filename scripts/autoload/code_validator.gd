extends Node

static var REGEX_MAIN_EXIT: RegEx = RegEx.create_from_string(
	"(?xi) ^[\\s\\S]*? int\\s+main\\s*\\([^)]*\\)\\s*\\{[\\s\\S]*?return\\s+0\\s*;?[\\s\\S]*?\\} [\\s\\S]*? $"
)

static func evaluate(challenge_id: String, code: String) -> Dictionary:
	match challenge_id:
		"main_exit_check":
			return _eval_main_exit(code)
		_:
			return {"success": false, "message": "Unknown challenge '%s'." % challenge_id}

static func _eval_main_exit(code: String) -> Dictionary:
	if code.strip_edges().is_empty():
		return {"success": false, "message": "Code is empty."}
	if REGEX_MAIN_EXIT.search(code) == null:
		return {"success": false, "message": "Expected 'int main() { return 0; }'."}
	return {"success": true, "message": "Minimum C++ algorithm detected."}
