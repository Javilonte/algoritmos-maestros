extends Node

const CHALLENGES_DIR := "res://data/challenges/"

var _challenges: Dictionary = {}

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	var dir := DirAccess.open(CHALLENGES_DIR)
	if dir == null:
		push_warning("ChallengeRegistry: '%s' not found" % CHALLENGES_DIR)
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var path := CHALLENGES_DIR + file_name
		var res := load(path)
		if res is ChallengeResource:
			_challenges[String(res.id)] = res
		else:
			push_warning("ChallengeRegistry: '%s' is not a ChallengeResource" % path)

func get_by_id(id: String) -> ChallengeResource:
	if _challenges.has(id):
		return _challenges[id]
	return null

func has(id: String) -> bool:
	return _challenges.has(id)

func list_all() -> Array:
	return _challenges.values()

func list_by_difficulty(min_diff: int, max_diff: int = 10) -> Array:
	var out: Array = []
	for c in _challenges.values():
		if c.difficulty >= min_diff and c.difficulty <= max_diff:
			out.append(c)
	return out

func count() -> int:
	return _challenges.size()
