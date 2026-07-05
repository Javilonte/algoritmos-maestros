extends Node
class_name CombatController

## Máquina de estados del combate. Orquesta:
## 1. Timer de 30s (se congela al enviar código).
## 2. Petición HTTP al sandbox C++ (Judge0) con fallback offline.
## 3. Cálculo de daño via DamageResolver.
## 4. Señales hacia VFX, UI y datos.
##
## Señales:
##   round_started(enemy_data)
##   timer_tick(remaining)
##   submission_received(uuid)
##   compilation_completed(result)
##   damage_applied(amount, hp_after, breakdown)
##   round_ended(victory)
##   state_changed(new_state)

signal round_started(enemy_data: Dictionary)
signal timer_tick(remaining: float)
signal submission_received(uuid: String)
signal compilation_completed(result: Dictionary)
signal damage_applied(amount: int, hp_after: int, breakdown: Dictionary)
signal round_ended(victory: bool)
signal state_changed(new_state: String)

enum State { IDLE, AWAITING_INPUT, FREEZE_TIMER, HTTP_INFLIGHT, RESOLVE_DMG }

const ROUND_DURATION: float = 30.0
const NETWORK_TIMEOUT: float = 6.0

@export var sandbox: SandboxClient
@export var terminal: Node  # BattleTerminal

var state: State = State.IDLE
var current_enemy: Dictionary = {}
var enemy_hp: int = 0
var enemy_max_hp: int = 0
var time_at_submit: float = -1.0
var pending_uuid: String = ""
var _used_macros: Array[String] = []
var _network_watchdog: SceneTreeTimer = null

func _ready() -> void:
	if sandbox == null:
		sandbox = SandboxClient.new()
		add_child(sandbox)
	if terminal and terminal.has_signal("submitted"):
		terminal.submitted.connect(_on_terminal_submitted)
	if sandbox:
		sandbox.submission_completed.connect(_on_compilation_completed)

## Inicia un round contra un enemigo.
func start_round(enemy_data: Dictionary) -> void:
	current_enemy = enemy_data
	enemy_max_hp = int(enemy_data.get("max_hp", 100))
	enemy_hp = enemy_max_hp
	round_started.emit(current_enemy)
	if terminal and terminal.has_method("open_for"):
		terminal.open_for(String(enemy_data.get("challenge_id", "")))
	_used_macros.clear()
	_set_state(State.AWAITING_INPUT)

## Llamado por la UI cuando el jugador presiona Enter o se acaba el tiempo.
func submit_current_code(code: String) -> void:
	if state != State.AWAITING_INPUT:
		return
	time_at_submit = _read_time_left()
	_freeze_timer()
	pending_uuid = _new_uuid()
	submission_received.emit(pending_uuid)
	if terminal and terminal.has_method("lock"):
		terminal.lock(true)
	_set_state(State.FREEZE_TIMER)
	_arm_network_watchdog()
	if sandbox:
		if sandbox.has_method("set_context"):
			sandbox.set_context(_build_challenge_context())
		sandbox.submit(code, time_at_submit, pending_uuid)

func _build_challenge_context() -> Dictionary:
	var ctx := {
		"stdin": "",
		"expected_output": "",
		"base_score": 10,
		"time_limit_sec": 2.0,
	}
	if terminal and terminal.has_method("get_code"):
		pass
	if current_enemy != null:
		ctx["stdin"] = String(current_enemy.get("stdin", ""))
		ctx["expected_output"] = String(current_enemy.get("expected_output", ""))
		ctx["base_score"] = int(current_enemy.get("base_score", 10))
		ctx["time_limit_sec"] = float(current_enemy.get("time_limit_sec", 2.0))
	return ctx

func cancel_round() -> void:
	if state == State.IDLE:
		return
	_set_state(State.IDLE)

func get_state_name() -> String:
	return State.keys()[state]

## --- Internals ---

func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(get_state_name())

func _read_time_left() -> float:
	## Lee del nodo Timer del BattleTerminal (o un Timer hijo del controlador).
	if terminal and terminal.has_method("get_time_left"):
		return float(terminal.get_time_left())
	return 0.0

func _freeze_timer() -> void:
	if terminal and terminal.has_method("pause_timer"):
		terminal.pause_timer()

func _resume_timer() -> void:
	if terminal and terminal.has_method("resume_timer"):
		terminal.resume_timer()

func _new_uuid() -> String:
	return str(Time.get_ticks_msec()) + "_" + str(randi() % 100000)

func _arm_network_watchdog() -> void:
	_network_watchdog = get_tree().create_timer(NETWORK_TIMEOUT)
	_network_watchdog.timeout.connect(_on_network_timeout)

func _on_network_timeout() -> void:
	if state == State.HTTP_INFLIGHT or state == State.FREEZE_TIMER:
		# El sandbox ya tiene su propio retry; si llegamos aqui significa
		# que ni online ni offline respondieron. Daño mínimo de timeout.
		_on_compilation_completed({
			"compiled": false,
			"stderr": "network timeout",
			"offline": true,
			"uuid": pending_uuid,
		})

func _on_terminal_submitted(_success: bool) -> void:
	## Compatibilidad con la señal legacy del BattleTerminal.
	## El BattleTerminal hace su propia validación con Tree-sitter;
	## aquí siempre intentamos compilar vía HTTP para calcular daño real.
	var code := ""
	if terminal and terminal.has_method("get_code"):
		code = String(terminal.get_code())
	submit_current_code(code)

func _on_compilation_completed(result: Dictionary) -> void:
	if result.get("uuid", "") != pending_uuid and not pending_uuid.is_empty():
		return  # respuesta obsoleta
	_set_state(State.RESOLVE_DMG)
	compilation_completed.emit(result)
	var resolved := DamageResolver.compute(result, time_at_submit, current_enemy, _used_macros)
	var dmg: int = int(resolved.get("damage", 0))
	enemy_hp = max(0, enemy_hp - dmg)
	damage_applied.emit(dmg, enemy_hp, resolved.get("breakdown", {}))
	if enemy_hp <= 0:
		round_ended.emit(true)
		_set_state(State.IDLE)
		return
	# Reinicia el round con timer fresco.
	if terminal and terminal.has_method("reset_for_next_round"):
		terminal.reset_for_next_round()
	_used_macros.clear()
	_resume_timer()
	_set_state(State.AWAITING_INPUT)
