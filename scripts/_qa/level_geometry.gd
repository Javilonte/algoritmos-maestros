class_name LevelGeometry

## Las invariantes de la geometria de un nivel, en un solo lugar.
##
## ponytail: el guard del nivel 01 validaba la geometria con sus propias
## lineas. Con un nivel por capitulo, ocho niveles, esa logica se iba a
## duplicar ocho veces. La geometria es la MISMA para todos: lo que cambia
## son los numeros.
##
## Las invariantes salen de la fisica real del jugador (la velocidad de
## salto y la de carrera), no de numeros inventados: un hueco es
## franqueable si el salto lo alcanza.

const PLAYER_SCRIPT := "res://scripts/platformer/platformer_player.gd"
const TILE := 32


## Lo que el jugador puede frquear: un hueco y una subida.
static func player_limits() -> Dictionary:
	var consts: Dictionary = (load(PLAYER_SCRIPT) as GDScript).get_script_constant_map()
	var gravity: float = consts["GRAVITY"]
	var jump_velocity: float = consts["JUMP_VELOCITY"]
	var run_speed: float = consts["RUN_SPEED"]
	# ponytail: la velocidad de salto es NEGATIVA (sube). El tiempo en el
	# aire es 2|v|/g: sin el absoluto daba un alcance negativo.
	var max_height: float = jump_velocity * jump_velocity / (2.0 * gravity)
	var air_time: float = 2.0 * absf(jump_velocity) / gravity
	var reach: float = run_speed * air_time
	return {
		"max_gap": int(floor(reach / float(TILE))),
		"max_rise": int(floor(max_height / float(TILE))),
		"max_height": max_height,
		"reach": reach,
	}


## Todos los chequeos de un nivel, uno por uno.
##
## ponytail: devuelve {label, ok} y no solo las fallas: asi cada invariante
## sale como un assert con su nombre, y el guard del nivel 01 no perdio
## el detalle cuando la logica se movio aca.
static func validate(level_data: Dictionary, limits: Dictionary) -> Array:
	var checks: Array = []
	var ground: Array = level_data.get("ground", [])
	var floating: Array = level_data.get("floating", [])
	var enemies: Array = level_data.get("enemies", [])
	var checkpoints: Array = level_data.get("checkpoints", [])
	var player_start: Vector2i = level_data.get("player_start", Vector2i.ZERO)
	var level_id: String = String(level_data.get("id", "?"))
	var max_gap: int = int(limits["max_gap"])
	var max_rise: int = int(limits["max_rise"])

	# --- los huecos entre spans ---------------------------------------------
	for i in range(ground.size() - 1):
		var a: Dictionary = ground[i]
		var b: Dictionary = ground[i + 1]
		var gap: int = int(b["x0"]) - int(a["x1"]) - 1
		var rise: int = int(a["top"]) - int(b["top"])
		checks.append({
			"label": "%s: gap %d->%d is %d tiles (max %d)" % [level_id, i + 1, i + 2, gap, max_gap],
			"ok": gap <= max_gap,
		})
		# Un hueco largo sólo puede aterrizar a la misma altura o más abajo:
		# subir mientras se cruza un hueco del ancho máximo no cabe.
		checks.append({
			"label": "%s: gap %d->%d does not climb while crossing %d tiles" % [level_id, i + 1, i + 2, gap],
			"ok": not (gap >= max_gap and rise > 0),
		})

	# --- las subidas ---------------------------------------------------------
	for i in range(ground.size() - 1):
		var a: Dictionary = ground[i]
		var b: Dictionary = ground[i + 1]
		var rise: int = int(a["top"]) - int(b["top"])
		checks.append({
			"label": "%s: step %d->%d rises %d tiles (max %d)" % [level_id, i + 1, i + 2, rise, max_rise],
			"ok": rise <= max_rise,
		})

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
			checks.append({
				"label": "%s: platform %d-%d has ground under it" % [level_id, px0, px1],
				"ok": false,
			})
			continue
		var rise: int = int(below.min()) - py
		checks.append({
			"label": "%s: platform %d-%d sits %d tiles above the ground (max %d)" % [level_id, px0, px1, rise, max_rise],
			"ok": rise <= max_rise and rise >= 0,
		})

	# --- los enemigos --------------------------------------------------------
	for spot in enemies:
		var enemy_id: String = String(spot.get("id", ""))
		var row: int = int(spot.get("y", -1))
		var patrol: Vector2i = spot.get("patrol", Vector2i.ZERO)
		var catalog: Dictionary = EnemyCatalog.fetch(enemy_id)
		checks.append({
			"label": "%s: enemy '%s' exists in the catalog" % [level_id, enemy_id],
			"ok": not catalog.is_empty(),
		})
		if not catalog.is_empty():
			var challenge_id: String = String(catalog.get("challenge_id", ""))
			checks.append({
				"label": "%s: enemy '%s' points at a shipped challenge (%s)" % [level_id, enemy_id, challenge_id],
				"ok": ChallengeRegistry.has(challenge_id),
			})
		checks.append({
			"label": "%s: enemy '%s' patrols solid ground at row %d" % [level_id, enemy_id, row],
			"ok": surface_at(ground, floating, patrol.x) == row and surface_at(ground, floating, patrol.y) == row,
		})

	# --- los checkpoints y el spawn ------------------------------------------
	for cp in checkpoints:
		var cx: int = int(cp["x"])
		var cy: int = int(cp["y"])
		checks.append({
			"label": "%s: checkpoint %d stands on solid ground at row %d" % [level_id, cx, cy],
			"ok": surface_at(ground, floating, cx) == cy,
		})

	checks.append({
		"label": "%s: the player spawns on solid ground at row %d" % [level_id, player_start.y],
		"ok": surface_at(ground, floating, player_start.x) == player_start.y,
	})

	return checks


## La fila de la superficie en la columna x: el suelo si hay suelo, la
## plataforma si no. -1 si no hay nada.
##
## ponytail: el SUELO manda, no la plataforma. Una plataforma esta arriba
## del suelo (por eso las plataformas son atajos), así que un enemigo que
## patrulla por el suelo bajo una plataforma sigue en el suelo. Tomar la
## superficie más alta hacía fallar al nivel 01 entero.
static func surface_at(ground: Array, floating: Array, x: int) -> int:
	for span in ground:
		if int(span["x0"]) <= x and x <= int(span["x1"]):
			return int(span["top"])
	for plat in floating:
		if int(plat["x0"]) <= x and x <= int(plat["x1"]):
			return int(plat["y"])
	return -1
