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

		# El invariante que mas duele cuando se rompe: un enemigo del
		# nivel tiene que pertenecer al skill del capitulo. Si no, el
		# gate por skill deja el nivel VACIO (nadie puede pelear) o deja
		# una pelea de otro capitulo.
		var skill_ids: Array = data.get("requires_skills", [])
		if skill_ids.is_empty():
			continue
		for skill_id in skill_ids:
			_check(SkillTree.skills.get(skill_id, null) != null,
				"the level '%s' names a skill that exists (%s)" % [id, skill_id])
		for spot in enemies:
			var enemy_id: String = String(spot.get("id", ""))
			var owner_skill: String = ""
			for skill_id in skill_ids:
				var node = SkillTree.skills.get(skill_id, null)
				if node != null and enemy_id in node.enemies_unlocked:
					owner_skill = String(skill_id)
					break
			_check(not owner_skill.is_empty(),
				"the level '%s' only fights the enemies of its chapter skills ('%s')" % [id, enemy_id])

	# --- la pantalla de niveles tiene que mostrar todos ----------------------
	var select_scene: PackedScene = load("res://scenes/ui/level_select.tscn") as PackedScene
	_check(select_scene != null, "the level select scene loads")
	if select_scene != null:
		var select := select_scene.instantiate()
		add_child(select)
		await get_tree().process_frame
		await get_tree().process_frame
		var grid := select.get_node_or_null("Body/Grid")
		_check(grid != null, "the level select has a grid")
		if grid != null:
			_check(grid.get_child_count() == levels.size(),
				"the level select shows every level (%d of %d)"
					% [grid.get_child_count(), levels.size()])
			# con nueve niveles y dos columnas eran cinco filas: la ultima se
			# salia de la pantalla. Tres columnas, tres filas.
			var columns: int = int(grid.get("columns")) if grid.get("columns") != null else 2
			var rows: int = int(ceil(float(grid.get_child_count()) / float(maxi(columns, 1))))
			_check(rows <= 4, "the level grid fits in %d rows (%d levels, %d columns)"
				% [rows, grid.get_child_count(), columns])
		select.queue_free()

	print("\n========== LEVEL GUARD ==========")
	for p in _passed:
		print("  PASS: ", p)
	for f in _failed:
		print("  FAIL: ", f)
	print("PASSED: %d | FAILED: %d" % [_passed.size(), _failed.size()])
	get_tree().quit(1 if _failed.size() > 0 else 0)
