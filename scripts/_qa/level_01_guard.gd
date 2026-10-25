extends Node

## Guard del Nivel 01: la geometría del nivel es código verificable.
##
## Un nivel diseñado a mano es el caso exacto donde un tile de diferencia lo
## vuelve incompletable. Este guard calcula el envelope de salto DEL JUGADOR
## REAL (leyendo las constantes de platformer_player.gd, no una copia) y
## asserta que el nivel respeta ese envelope.
##
## Run: godot --headless scenes/qa/level_01_guard.tscn --quit-after 400

const TILE := 32
const LEVEL_SCRIPT := "res://data/levels/level_01.gd"
const PLAYER_SCRIPT := "res://scripts/platformer/platformer_player.gd"
const WORLD := "res://scenes/platformer/platformer_world.tscn"
const LEVEL_SELECT := "res://scenes/ui/level_select.tscn"

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
	# --- el envelope real del jugador ----------------------------------------
	var player_consts: Dictionary = (load(PLAYER_SCRIPT) as GDScript).get_script_constant_map()
	var gravity: float = player_consts["GRAVITY"]
	var jump_velocity: float = player_consts["JUMP_VELOCITY"]
	var run_speed: float = player_consts["RUN_SPEED"]
	var max_height: float = jump_velocity * jump_velocity / (2.0 * gravity)
	# ponytail: la velocidad de salto es NEGATIVA (sube). El tiempo en el
	# aire es 2|v|/g: sin el absoluto daba un alcance negativo y el guard
	# se auto-declaraba incapaz de saltar un hueco.
	var air_time: float = 2.0 * absf(jump_velocity) / gravity
	var reach: float = run_speed * air_time
	var max_gap: int = int(floor(reach / float(TILE)))
	var max_rise: int = int(floor(max_height / float(TILE)))
	_check(max_gap >= 4 and max_rise >= 3,
		"the player can clear a 4 tile gap and a 3 tile rise (%.1f px high, %.1f px far)"
		% [max_height, reach])

	# --- el nivel ------------------------------------------------------------
	var level_script: GDScript = load(LEVEL_SCRIPT) as GDScript
	if level_script == null:
		_check(false, "the level script loads")
		_finish()
		return
	var consts: Dictionary = level_script.get_script_constant_map()
	_check(true, "the level script loads")

	var ground: Array = consts.get("GROUND_SPANS", [])
	var floating: Array = consts.get("FLOATING", [])
	var enemies: Array = consts.get("ENEMY_SPOTS", [])
	var checkpoints: Array = consts.get("CHECKPOINTS", [])
	var player_start: Vector2i = consts.get("PLAYER_START", Vector2i.ZERO)

	_check(ground.size() >= 8, "the level has %d ground spans" % ground.size())
	_check(enemies.size() >= 8, "the level has %d enemies" % enemies.size())
	_check(checkpoints.size() >= 3, "the level has %d checkpoints" % checkpoints.size())

	# --- la geometria --------------------------------------------------------
	# ponytail: las invariantes viven en LevelGeometry (las comparten todos
	# los niveles). Este guard conserva sus conteos, que son del nivel 01.
	for check in LevelGeometry.validate({
		"id": "level_01",
		"ground": ground,
		"floating": floating,
		"enemies": enemies,
		"checkpoints": checkpoints,
		"player_start": player_start,
	}, {"max_gap": max_gap, "max_rise": max_rise}):
		_check(bool(check.get("ok", false)), String(check.get("label", "")))

	_behavior()


## Fase 2: el nivel se JUEGA, no sólo se dibuja.
func _behavior() -> void:
	var world: Node = (load(WORLD) as PackedScene).instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame

	var entities: Node = world.get_node("Entities")
	var player: Node = world.get_node("Entities/Player")

	# --- los enemigos patrullan ---------------------------------------------
	var enemy: Node = null
	for child in entities.get_children():
		if child.has_method("defeat"):
			enemy = child
			break
	_check(enemy != null, "the level spawns an enemy")
	if enemy != null:
		var x_start: float = enemy.global_position.x
		for i in range(60):
			await get_tree().physics_frame
		_check(absf(enemy.global_position.x - x_start) > 4.0,
			"the enemy patrols (%.1f -> %.1f)" % [x_start, enemy.global_position.x])

	# --- los checkpoints existen y activan -----------------------------------
	var checkpoints: Array = []
	for child in entities.get_children():
		if child.has_method("get_checkpoint_position"):
			checkpoints.append(child)
	_check(checkpoints.size() >= 3, "the level spawns %d checkpoints" % checkpoints.size())

	var has_respawn_api: bool = world.has_method("get_respawn_point")
	_check(has_respawn_api, "the world exposes the respawn point")
	if not has_respawn_api:
		_finish()
		return

	if checkpoints.size() > 0:
		var cp: Node = checkpoints[0]
		var cp_pos: Vector2 = cp.get_checkpoint_position()
		player.global_position = cp_pos + Vector2(0, -20)
		player.velocity = Vector2.ZERO
		for i in range(10):
			await get_tree().physics_frame
		_check(world.get_respawn_point().distance_to(cp_pos) < 40.0,
			"touching a checkpoint moves the respawn point to it (%.1f)"
			% world.get_respawn_point().x)

	# --- caer mata y reaparece en el checkpoint -------------------------------
	var respawn_point: Vector2 = world.get_respawn_point()
	player.global_position = Vector2(respawn_point.x, respawn_point.y + 900.0)
	player.velocity = Vector2.ZERO
	for i in range(120):
		await get_tree().physics_frame
		if player.global_position.distance_to(respawn_point) < 60.0:
			break
	_check(player.global_position.distance_to(respawn_point) < 60.0,
		"falling out of the level respawns the player at the checkpoint (%.1f, %.1f)"
		% [player.global_position.x, player.global_position.y])

	# --- el gate: los enemigos bloqueados EXISTEN pero duermen ----------------
	# ponytail: antes el gate no spawneaba al enemigo bloqueado y el nivel
	# se veía vacio ("en el mapa solo veo 1"). Ahora todos estan en el
	# mapa, los bloqueados en gris y dormidos, y el gate sigue valiendo:
	# con un enemigo bloqueado no se puede pelear.
	var spawned: Array = []
	var locked_ids: Array = []
	var awake_ids: Array = []
	for child in entities.get_children():
		if child.has_method("defeat"):
			spawned.append(child)
			if bool(child.get("locked")):
				locked_ids.append(String(child.get("enemy_id")))
			else:
				awake_ids.append(String(child.get("enemy_id")))
	var level_enemy_count: int = _level_enemy_count(world)
	_check(spawned.size() == level_enemy_count,
		"every enemy of the level is on the map (%d of %d)" % [spawned.size(), level_enemy_count])
	_check(awake_ids.has("slime_aritm"),
		"the root skill is unlocked, so the first enemy is awake")
	# el Memory Leak esta en el roster del nivel 01 y su skill (ptr_dynamic)
	# no esta desbloqueado al arrancar: tiene que estar en el mapa dormido.
	_check(locked_ids.has("memory_leak"),
		"an enemy whose skill is locked is on the map but asleep")

	# desbloquear un skill DESPIERTA a su enemigo
	var ogre_before: Node = _find_enemy(spawned, "ogro_bucle")
	_check(ogre_before != null and bool(ogre_before.get("locked")),
		"the ogre sleeps before its skill is unlocked")
	# stl_loops pide nivel 2 y 150 XP. Cuanta XP haga falta depende de la
	# curva (las subidas de nivel se la comen), asi que el guard gana XP
	# hasta que el nodo cae, en vez de codificar un numero.
	var unlocked: bool = false
	for i in range(10):
		SkillTree.add_xp(200)
		# el nodo depende de la rama: primero la rama, despues el nodo
		SkillTree.try_unlock(&"branch_stl")
		if SkillTree.try_unlock(&"stl_loops"):
			unlocked = true
			break
	_check(unlocked, "the player can unlock a skill with the XP they earned")
	await get_tree().process_frame
	var ogre_after: Node = _find_enemy(spawned, "ogro_bucle")
	_check(ogre_after != null and not bool(ogre_after.get("locked")),
		"unlocking a skill wakes its enemy")

	# --- el arbol de skills se abre desde el platformer ---------------------
	# Sin esto el gate no tiene salida: el jugador no tendria como
	# desbloquear nada. La tecla ` es el mapeo 96 del InputMap.
	var ev := InputEventKey.new()
	ev.keycode = 96
	ev.physical_keycode = 96
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	_check(world.get("_skill_tree_layer") != null, "the skill tree opens from the platformer")
	_check(get_tree().paused, "the skill tree pauses the world")
	world.call("_close_skill_tree")
	await get_tree().process_frame
	_check(not get_tree().paused, "closing the skill tree unpauses the world")

	_finish()


## El enemigo spawneado con ese id, o null.
func _find_enemy(nodes: Array, enemy_id: String) -> Node:
	for node in nodes:
		if String(node.get("enemy_id")) == enemy_id:
			return node
	return null


## Cuántos enemigos declara el nivel (para comparar con los spawneados).
func _level_enemy_count(world: Node) -> int:
	var level: Dictionary = LevelRegistry.get_level(String(world.get("level_id")))
	return level.get("enemies", []).size()


## Fase 3: el nivel es elegible desde el menú.
func _registry_and_picker() -> void:
	var ids: PackedStringArray = LevelRegistry.get_ids()
	_check(ids.has("level_01"), "the registry lists level_01")

	var select_scene: PackedScene = load(LEVEL_SELECT) as PackedScene
	_check(select_scene != null, "the level select scene loads")

	# El mundo tiene que pintar el nivel que elige el menú, no uno fijo.
	var carries_level: bool = "current_level_id" in GameManager
	_check(carries_level, "GameManager carries the level the menu chose")
	if not carries_level:
		return
	GameManager.set("current_level_id", "level_01")
	var world: Node = (load(WORLD) as PackedScene).instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var ground: TileMapLayer = world.get_node("Ground")
	# La fila 13 en la columna 120 sólo existe en el Nivel 01: es el suelo
	# del acto 3, el del hueco de 4 tiles.
	_check(ground.get_cell_source_id(Vector2i(120, 13)) != -1,
		"the world paints the level the menu chose")
	_check(world.get("level_id") == "level_01",
		"the world reports the level it painted")
	GameManager.set("current_level_id", "")


## La fila de superficie bajo una columna, o -1 si no hay nada.
func _finish() -> void:
	print("\n========== LEVEL 01 GUARD ==========")
	for p in _passed:
		print("  PASS: ", p)
	for f in _failed:
		print("  FAIL: ", f)
	print("====================================")
	print("PASSED: %d | FAILED: %d" % [_passed.size(), _failed.size()])
	get_tree().quit(1 if _failed.size() > 0 else 0)
