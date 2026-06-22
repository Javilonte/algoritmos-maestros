extends Node

var _ts_parser = null

func _ready():
	if ClassDB.class_exists("TreeSitterParser"):
		_ts_parser = ClassDB.instantiate("TreeSitterParser")

func evaluate(challenge_id: String, code: String) -> Dictionary:
	if _ts_parser == null:
		return {"success": false, "message": "Tree-sitter parser is not available."}
	return _ts_parser.validate(code, challenge_id)
