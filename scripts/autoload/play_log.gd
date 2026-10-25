extends Node

## El log de partidas: una linea JSON por evento, en `user://plays/`.
##
## ponytail: el juego no media nada. Lo unico que se persistia era el
## savegame, asi que no habia forma de saber si un enemigo era dificil
## porque era dificil o porque el concepto no se habia ensenado. Con este
## log, la dificultad se ajusta con datos y no con intuicion.
##
## Sin servidor y sin red: el juego es offline y los datos son del
## jugador. El buffer se escribe a disco en los momentos seguros (nivel,
## batalla, muerte) y NUNCA en un frame de combate: escribir un archivo
## en medio del combate es una caida de frames garantizada.
##
## ponytail: un archivo por sesion. Si se escribiera todo en un solo
## archivo, un crash lo dejaria a medio escribir y se perderia la sesion
## entera; con un archivo por sesion, solo se pierde la ultima linea.

const DIR := "user://plays"
const EXPORT_PATH := "user://plays_export.jsonl"
## Cuantas lineas se acumulan antes de escribir a disco.
const MAX_BUFFER: int = 24

var _buffer: Array[String] = []
var _session_id: String = ""
var _enabled: bool = true
var _level_start_ms: int = 0
var _level_deaths: int = 0
var _level_enemies: int = 0
var _level_attempts: Dictionary = {}
## La pelea en curso. Los intentos no llevan el enemy_id: lo toman de
## aca. Sin esto el reporte no puede agrupar los intentos por pelea, y
## las metricas por enemigo salen vacias (no se rompen: dejan de contar).
var _battle_context: Dictionary = {}


func _ready() -> void:
	# ponytail: en headless NO se loguea. Los guards corren headless y sus
	# peleas de prueba ensuciarian los datos del jugador: el reporte
	# mediria peleas que nunca ocurrieron. El guard del log se fuerza a
	# activarlo para poder probar la escritura.
	_enabled = DisplayServer.get_name() != "headless"
	_session_id = "%s_%d" % [
		Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_"),
		Time.get_ticks_msec() % 100000,
	]
	DirAccess.make_dir_recursive_absolute(DIR)


## Activa o desactiva el log (el guard del log lo activa a mano).
func set_enabled(value: bool) -> void:
	_enabled = value


## Anota un evento. `data` son los campos del evento (sin "event" ni "t").
func log_event(event_name: String, data: Dictionary = {}) -> void:
	if not _enabled:
		return
	var event: Dictionary = {
		"event": event_name,
		"t": Time.get_ticks_msec(),
		"session": _session_id,
	}
	for key in data.keys():
		event[key] = data[key]
	_buffer.append(JSON.stringify(event))


## Escribe lo que hay en el buffer. Se llama en los momentos seguros.
func flush() -> void:
	if _buffer.is_empty():
		return
	var path: String = "%s/%s.jsonl" % [DIR, _session_id]
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("PlayLog: could not open '%s'" % path)
		return
	f.seek_end()
	for line in _buffer:
		f.store_line(line)
	f.close()
	_buffer.clear()


## Concatena todas las sesiones en un solo archivo y devuelve la ruta.
## El jugador decide si lo comparte: el boton dice donde quedo.
func export_all(target_path: String = EXPORT_PATH) -> String:
	flush()
	var out := FileAccess.open(target_path, FileAccess.WRITE)
	if out == null:
		push_error("PlayLog: could not write '%s'" % target_path)
		return ""
	var dir := DirAccess.open(DIR)
	if dir != null:
		var names: PackedStringArray = dir.get_files()
		names.sort()
		for name in names:
			if not name.ends_with(".jsonl"):
				continue
			var content := FileAccess.get_file_as_string("%s/%s" % [DIR, name])
			for line in content.split("\n"):
				if not line.strip_edges().is_empty():
					out.store_line(line)
	out.close()
	return ProjectSettings.globalize_path(target_path)


## El intento de un nivel: cuantas veces se empezo en ESTA sesion.
func level_attempt(level_id: String) -> int:
	var n: int = int(_level_attempts.get(level_id, 0)) + 1
	_level_attempts[level_id] = n
	return n


# --- atajos de los eventos con estado -------------------------------------

func begin_level(level_id: String) -> void:
	_level_start_ms = Time.get_ticks_msec()
	_level_deaths = 0
	_level_enemies = 0
	log_event("level_start", {
		"level_id": level_id,
		"attempt": level_attempt(level_id),
	})


func end_level(level_id: String, completed: bool = false) -> void:
	log_event("level_complete", {
		"level_id": level_id,
		"completed": completed,
		"elapsed_ms": Time.get_ticks_msec() - _level_start_ms,
		"deaths": _level_deaths,
		"enemies": _level_enemies,
	})
	flush()


func note_checkpoint(level_id: String, index: int) -> void:
	log_event("checkpoint_reached", {
		"level_id": level_id,
		"index": index,
		"t_since_start_ms": Time.get_ticks_msec() - _level_start_ms,
	})


func note_death(level_id: String, pos: Vector2, cause: String) -> void:
	_level_deaths += 1
	log_event("player_death", {
		"level_id": level_id,
		"x": int(pos.x),
		"y": int(pos.y),
		"cause": cause,
	})


func note_battle_start(level_id: String, enemy_id: String, challenge_id: String,
		difficulty: int, hp: int, xp: int, battle_id: int = 0) -> void:
	_battle_context = {
		"enemy_id": enemy_id,
		"challenge_id": challenge_id,
		"battle_id": battle_id,
	}
	log_event("battle_start", {
		"level_id": level_id,
		"enemy_id": enemy_id,
		"challenge_id": challenge_id,
		"difficulty": difficulty,
		"hp": hp,
		"xp": xp,
		"battle_id": battle_id,
	})


func note_battle_attempt(index: int, elapsed_ms: int, compile_ok: bool, passed: int,
		total: int, ast_valid: bool, ast_quality: float, damage: int,
		player_hp: int, combo: int) -> void:
	var event := {
		"n": index,
		"elapsed_ms": elapsed_ms,
		"compile_ok": compile_ok,
		"passed": passed,
		"total": total,
		"ast_valid": ast_valid,
		"ast_quality": ast_quality,
		"damage": damage,
		"player_hp": player_hp,
		"combo": combo,
	}
	for key in _battle_context.keys():
		event[key] = _battle_context[key]
	log_event("battle_attempt", event)


func note_battle_end(result: String, turns: int, attempts: int, elapsed_ms: int) -> void:
	log_event("battle_end", {
		"result": result,
		"turns": turns,
		"attempts": attempts,
		"elapsed_ms": elapsed_ms,
	})


func note_skill_unlocked(skill_id: String, xp: int, level: int) -> void:
	log_event("skill_unlocked", {
		"skill_id": skill_id,
		"xp": xp,
		"level": level,
	})


func note_enemy_defeated() -> void:
	_level_enemies += 1


## La ruta del archivo de esta sesion (para el boton de exportar).
func session_path() -> String:
	return ProjectSettings.globalize_path("%s/%s.jsonl" % [DIR, _session_id])
