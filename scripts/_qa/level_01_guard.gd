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

	# --- los huecos entre spans ---------------------------------------------
	for i in range(ground.size() - 1):
		var a: Dictionary = ground[i]
		var b: Dictionary = ground[i + 1]
		var gap: int = int(b["x0"]) - int(a["x1"]) - 1
		var rise: int = int(a["top"]) - int(b["top"])
		_check(gap <= max_gap,
			"gap %d->%d is %d tiles (max %d)" % [i + 1, i + 2, gap, max_gap])
		# Un hueco largo sólo puede aterrizar a la misma altura o más abajo:
		# subir mientras se cruza un的最大_gap tiles no cabe en el salto.
		_check(not (gap >= max_gap and rise > 0),
			"gap %d->%d does not climb while crossing %d tiles" % [i + 1, i + 2, gap])

	# --- las subidas ---------------------------------------------------------
	for i in range(ground.size() - 1):
		var a: Dictionary = ground[i]
		var b: Dictionary = ground[i + 1]
		var rise: int = int(a["top"]) - int(b["top"])
		_check(rise <= max_rise,
			"step %d->%d rises %d tiles (max %d)" % [i + 1, i + 2, rise, max_rise])

	# --- las plataformas -----------------------------------------------------
	for plat in floating:
		var px0: int = int(plat["x0"])
		var px1: int = int(plat["x1"])
		var py: int = int(plat["y"])
		var below: Array = []
		for span in ground:
			if not (int(span["x1"]) < px0 or int(span["x0"]) > px1):
				below.append(int(span["top"]))
		if below.is_empty():
			_check(false, "platform %d-%d has ground under it" % [px0, px1])
			continue
		var rise: int = int(below.min()) - py
		_check(rise <= max_rise and rise >= 0,
			"platform %d-%d sits %d tiles above the ground (max %d)" % [px0, px1, rise, max_rise])

	# --- los enemigos --------------------------------------------------------
	for spot in enemies:
		var enemy_id: String = String(spot.get("id", ""))
		var row: int = int(spot.get("y", -1))
		var patrol: Vector2i = spot.get("patrol", Vector2i.ZERO)
		var catalog: Dictionary = EnemyCatalog.fetch(enemy_id)
		_check(not catalog.is_empty(), "enemy '%s' exists in the catalog" % enemy_id)
		if not catalog.is_empty():
			_check(ChallengeRegistry.has(String(catalog.get("challenge_id", ""))),
				"enemy '%s' points at a shipped challenge (%s)"
				% [enemy_id, String(catalog.get("challenge_id", ""))])
		_check(_surface_at(ground, floating, patrol.x) == row
				and _surface_at(ground, floating, patrol.y) == row,
			"enemy '%s' patrols solid ground at row %d" % [enemy_id, row])

	# --- los checkpoints -----------------------------------------------------
	for cp in checkpoints:
		var cx: int = int(cp["x"])
		var cy: int = int(cp["y"])
		_check(_surface_at(ground, floating, cx) == cy,
			"checkpoint %d stands on solid ground at row %d" % [cx, cy])

	# --- el spawn ------------------------------------------------------------
	_check(_surface_at(ground, floating, player_start.x) == player_start.y,
		"the player spawns on solid ground at row %d" % player_start.y)

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

	_finish()


## La fila de superficie bajo una columna, o -1 si no hay nada.
func _surface_at(ground: Array, floating: Array, x: int) -> int:
	for span in ground:
		if int(span["x0"]) <= x and x <= int(span["x1"]):
			return int(span["top"])
	for plat in floating:
		if int(plat["x0"]) <= x and x <= int(plat["x1"]):
			return int(plat["y"])
	return -1


func _finish() -> void:
	print("\n========== LEVEL 01 GUARD ==========")
	for p in _passed:
		print("  PASS: ", p)
	for f in _failed:
		print("  FAIL: ", f)
	print("====================================")
	print("PASSED: %d | FAILED: %d" % [_passed.size(), _failed.size()])
	get_tree().quit(1 if _failed.size() > 0 else 0)
