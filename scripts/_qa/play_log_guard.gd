extends Node

## Guard del log de partidas: los eventos se escriben, son JSONL valido y
## el reporte los agrega.
## Run: godot --headless scenes/qa/play_log_guard.tscn --quit-after 6000
##
## ponytail: el log se escribe en `user://plays/`, o sea la carpeta REAL
## del jugador. El guard no puede dejar ahi sus eventos de prueba: usa un
## archivo aparte y lo borra al terminar.
##
## ponytail: los nombres de los campos son un CONTRATO. El reporte de
## Python los lee por nombre: si un campo se renombra, el reporte deja de
## ver los datos en silencio (no se rompe, deja de contar). El guard
## comprueba los nombres.

const FIELDS: Dictionary = {
	"level_start": ["level_id", "attempt"],
	"level_complete": ["level_id", "completed", "elapsed_ms", "deaths", "enemies"],
	"checkpoint_reached": ["level_id", "index", "t_since_start_ms"],
	"player_death": ["level_id", "x", "y", "cause"],
	"battle_start": ["level_id", "enemy_id", "challenge_id", "difficulty", "hp", "xp", "battle_id"],
	"battle_attempt": ["n", "elapsed_ms", "compile_ok", "passed", "total",
		"ast_valid", "ast_quality", "damage", "player_hp", "combo",
		"enemy_id", "challenge_id", "battle_id"],
	"battle_end": ["result", "turns", "attempts", "elapsed_ms"],
	"skill_unlocked": ["skill_id", "xp", "level"],
}

var _passed: Array = []
var _failed: Array = []
var _session_file: String = ""
var _export_file: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed.append(label)
	else:
		_failed.append(label)


func _run() -> void:
	# el log no escribe en headless (para no ensuciar los datos del
	# jugador con las peleas de prueba de los guards); este si lo necesita.
	PlayLog.set_enabled(true)
	_session_file = PlayLog.session_path()

	# --- 1. los ocho eventos ------------------------------------------------
	PlayLog.begin_level("level_01")
	PlayLog.note_checkpoint("level_01", 2)
	PlayLog.note_death("level_01", Vector2(320, 900), "fall")
	PlayLog.note_battle_start("level_01", "slime_aritm", "main_exit_check", 1, 60, 350, 1)
	PlayLog.note_battle_attempt(1, 1200, true, 1, 1, true, 0.9, 60, 100, 0)
	PlayLog.note_battle_attempt(2, 3000, true, 0, 6, true, 0.8, 0, 80, 0)
	PlayLog.note_battle_end("win", 2, 2, 4200)
	PlayLog.note_skill_unlocked("stl_loops", 350, 2)
	PlayLog.end_level("level_01", false)
	PlayLog.flush()

	_check(FileAccess.file_exists(_session_file),
		"the session file was written (%s)" % _session_file)

	# --- 2. el archivo es JSONL valido y trae los ocho eventos --------------
	var events: Array = []
	if FileAccess.file_exists(_session_file):
		var content := FileAccess.get_file_as_string(_session_file)
		for line in content.split("\n"):
			var text := line.strip_edges()
			if text.is_empty():
				continue
			var parsed = JSON.parse_string(text)
			if typeof(parsed) != TYPE_DICTIONARY:
				_failed.append("a line is not valid JSON: %s" % text.substr(0, 60))
				continue
			events.append(parsed)
	# ocho tipos de evento, con un intento de batalla extra: nueve lineas.
	_check(events.size() == 9, "the events were written (%d)" % events.size())

	var seen: Dictionary = {}
	for event in events:
		seen[String(event.get("event", ""))] = true
		# el evento tiene que llevar SIEMPRE su timestamp y su sesion
		if not event.has("t") or not event.has("session"):
			_failed.append("'%s' has no timestamp/session" % String(event.get("event", "")))
	for name in FIELDS.keys():
		_check(seen.has(name), "the '%s' event was written" % name)

	# --- 3. los campos son el contrato del reporte --------------------------
	for event in events:
		var name := String(event.get("event", ""))
		if not FIELDS.has(name):
			continue
		for field in FIELDS[name]:
			_check(event.has(field), "'%s' has the field '%s'" % [name, field])

	# --- 4. la exportacion --------------------------------------------------
	_export_file = "user://plays_export_guard.jsonl"
	var exported: String = PlayLog.export_all(_export_file)
	_check(not exported.is_empty(), "the export returned a path")
	_check(FileAccess.file_exists(_export_file), "the export file exists")
	var exported_content := FileAccess.get_file_as_string(_export_file)
	_check(exported_content.contains("\"battle_attempt\""),
		"the export contains the battle attempts")

	# --- 5. el reporte agrega los datos -------------------------------------
	var report_script := "res://scripts/_qa/play_report.py"
	_check(FileAccess.file_exists(report_script), "the report script exists")
	var out: Array = []
	var code: int = OS.execute("python3", [
		ProjectSettings.globalize_path(report_script),
		ProjectSettings.globalize_path(_export_file),
	], out, true)
	var report_text: String = "\n".join(out)
	_check(code == 0, "the report script ran (exit %d)" % code)
	_check(report_text.contains("intentos al primer acierto"),
		"the report has the attempts metric")
	_check(report_text.contains("muertes por enemigo"),
		"the report has the deaths metric")
	_check(report_text.contains("turnos para matar"),
		"the report has the turns metric")

	_cleanup()
	_finish()


## El guard no deja basura en la carpeta del jugador.
func _cleanup() -> void:
	for path in [_session_file, _export_file]:
		if not path.is_empty() and FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _finish() -> void:
	print("\n========== PLAY LOG GUARD ==========")
	for p in _passed:
		print("  PASS: ", p)
	for f in _failed:
		print("  FAIL: ", f)
	print("PASSED: %d | FAILED: %d" % [_passed.size(), _failed.size()])
	get_tree().quit(1 if _failed.size() > 0 else 0)
