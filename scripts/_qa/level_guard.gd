extends Node

## Guard de TODOS los niveles: la geometria de cada uno contra la fisica
## real del jugador.
## Run: godot --headless scenes/qa/level_guard.tscn --quit-after 1200
##
## ponytail: el guard del nivel 01 validaba la geometria con sus propias
## lineas. Con un nivel por capitulo, ocho niveles, esa logica se iba a
## duplicar ocho veces y a divergir. Las invariantes viven en
## `LevelGeometry` y este guard las corre para TODOS los niveles del
## registro: agregar un nivel es agregar un archivo, y el guard lo cover
## sin tocarlo.

var _passed: Array = []
var _failed: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed.append(label)
	else:
		_failed.append(label)


func _run() -> void:
	var limits: Dictionary = LevelGeometry.player_limits()
	_check(int(limits["max_gap"]) >= 4 and int(limits["max_rise"]) >= 3,
		"the player can clear a 4 tile gap and a 3 tile rise (%.1f px high, %.1f px far)"
			% [float(limits["max_height"]), float(limits["reach"])])

	var levels: Array = LevelRegistry.list_levels()
	_check(levels.size() >= 2, "the registry has %d levels" % levels.size())

	for entry in levels:
		var id: String = String(entry.get("id", ""))
		var data: Dictionary = LevelRegistry.get_level(id)
		_check(not data.is_empty(), "the level '%s' loads" % id)
		if data.is_empty():
			continue

		var ground: Array = data.get("ground", [])
		var enemies: Array = data.get("enemies", [])
		var checkpoints: Array = data.get("checkpoints", [])
		_check(ground.size() >= 5, "the level '%s' has %d ground spans" % [id, ground.size()])
		_check(enemies.size() >= 1, "the level '%s' has %d enemies" % [id, enemies.size()])
		_check(checkpoints.size() >= 2, "the level '%s' has %d checkpoints" % [id, checkpoints.size()])

		for check in LevelGeometry.validate(data, limits):
			_check(bool(check.get("ok", false)), String(check.get("label", "")))

		# Los enemigos del nivel tienen que ser del capitulo: el gate por
		# skill hace que el nivel se vacie si el roster no corresponde.
		var catalog: Dictionary = EnemyCatalog.fetch(String(enemies[0].get("id", "")))
		_check(not catalog.is_empty(),
			"the level '%s' starts with a catalog enemy ('%s')"
				% [id, String(enemies[0].get("id", ""))])

	print("\n========== LEVEL GUARD ==========")
	for p in _passed:
		print("  PASS: ", p)
	for f in _failed:
		print("  FAIL: ", f)
	print("PASSED: %d | FAILED: %d" % [_passed.size(), _failed.size()])
	get_tree().quit(1 if _failed.size() > 0 else 0)
