extends Node

## Guard de la economia de la pelea: que los tres desenlaces sean
## distintos y que el reloj no castigue al que escribe.
## Run: godot --headless scenes/qa/battle_economy_guard.tscn --quit-after 9000
##
## ponytail: la economia era una sola regla para todo: 12 de dano por
## cualquier fallo. Un codigo al que le falta un bucle (todavia no esta
## listo) costaba lo mismo que un algoritmo que corre y da la respuesta
## equivocada (un error de verdad). Y el reloj corria mientras el
## jugador escribia: 30 segundos para escribir una funcion Y resolver un
## problema de programacion dinamica.
##
## Este guard comprueba los tres desenlaces por separado:
##   - el codigo que no esta listo no le hace dano a nadie
##   - el error de algoritmo golpea, y golpea mas cuanto mas dificil
##   - acertar hace dano al enemigo Y cura al jugador
##   - el reloj esta congelado mientras se escribe

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const ENEMY_SCENE := "res://scenes/overworld/enemy.tscn"
const CHALLENGE := "simple_dp"

## Le falta el bucle: el gate de forma lo rechaza.
const NOT_READY := """int climbStairs(int n) {
    return n;
}"""

## La estructura correcta y el algoritmo equivocado: compila y falla.
const WRONG := """int climbStairs(int n) {
    int total = 0;
    for (int i = 1; i <= n; i++) {
        if (i % 2 == 0) {
            total += i;
        } else {
            total -= i;
        }
    }
    return total;
}"""

const CORRECT := """int climbStairs(int n) {
    int a = 1;
    int b = 1;
    for (int i = 2; i <= n; i++) {
        int c = a + b;
        a = b;
        b = c;
    }
    if (n <= 1) {
        return 1;
    }
    return b;
}"""

var _passed: Array = []
var _failed: Array = []
var _results: Array = []


func _ready() -> void:
	EventBus.code_executed.connect(_on_code_executed)
	_run()


func _on_code_executed(result) -> void:
	_results.append(result)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed.append(label)
	else:
		_failed.append(label)


func _run() -> void:
	if CppSandbox.new().find_compiler().is_empty():
		print("SKIP: no C++ compiler on this machine")
		_finish()
		return

	var battle_scene: PackedScene = load(BATTLE_SCENE)
	var enemy_scene: PackedScene = load(ENEMY_SCENE)
	if battle_scene == null or enemy_scene == null:
		_failed.append("could not load battle or enemy scene")
		_finish()
		return

	var enemy := enemy_scene.instantiate()
	add_child(enemy)
	enemy.set("display_name", "Guard Slime")
	enemy.set("max_hp", 80)
	enemy.set("challenge_id", CHALLENGE)
	enemy.set("respawn_time", 30.0)

	var battle := battle_scene.instantiate()
	add_child(battle)
	var data := EnemyData.create("Guard Slime", 80, CHALLENGE, enemy, "slime_aritm", 25)
	battle.set("_enemy_data", data.to_dict())
	EventBus.battle_requested.emit(data.to_dict())
	await _wait_for_phase(battle, Battle.BattlePhase.EDITING)

	var terminal := battle.get_node_or_null("BattleTerminal")
	if terminal == null:
		_failed.append("the battle has no code editor")
		_finish()
		return
	var editor: CodeEdit = terminal.get_node("Panel/CodeEdit")
	battle.call("_on_attack_pressed")
	await get_tree().process_frame

	# --- 1. el reloj esta congelado mientras se escribe ----------------------
	var timer: Label = battle.get_node_or_null(
		"BattleArena/StatusBar/TimerChip/TimerBox/TimerRow/BattleTimer")
	_check(timer != null, "the battle shows the turn clock")
	var full: int = 30
	if timer != null:
		full = int(timer.text)
		await get_tree().create_timer(1.5).timeout
		_check(int(timer.text) == full,
			"the clock is frozen while the player writes (%s -> %s)" % [full, timer.text])

	var player_hp_start: int = GameManager.get_hp("player")
	var enemy_hp_start: int = GameManager.get_hp("enemy")

	# --- 2. el codigo que no esta listo no le hace dano a nadie --------------
	editor.text = NOT_READY
	terminal.call("_on_submit_pressed")
	var r1: Variant = await _wait_for_result()
	_check(r1 != null, "the not-ready code produced a result")
	if r1 != null:
		_check(String(r1.failure_kind) == "shape",
			"the missing structure is reported as a shape failure")
	await get_tree().create_timer(1.2).timeout
	_check(GameManager.get_hp("player") == player_hp_start,
		"the not-ready code does not hurt the player (%d -> %d)"
			% [player_hp_start, GameManager.get_hp("player")])
	_check(GameManager.get_hp("enemy") == enemy_hp_start,
		"the not-ready code does not hurt the enemy")

	# --- 3. el error de algoritmo golpea, y mas si es mas dificil ----------
	var diff: int = int(ChallengeRegistry.get_by_id(CHALLENGE).difficulty)
	var expected_damage: int = 12 + 2 * diff
	editor.text = WRONG
	terminal.call("_on_submit_pressed")
	var r2: Variant = await _wait_for_result()
	_check(r2 != null, "the wrong algorithm produced a result")
	if r2 != null:
		_check(String(r2.failure_kind) == "algorithm",
			"a wrong answer is reported as an algorithm failure")
	await get_tree().create_timer(1.5).timeout
	var after_error: int = GameManager.get_hp("player")
	_check(player_hp_start - after_error == expected_damage,
		"the wrong algorithm costs %d life (100 -> %d)" % [expected_damage, after_error])
	_check(GameManager.get_hp("enemy") == enemy_hp_start,
		"the wrong algorithm does not hurt the enemy")

	# --- 4. ahora el reloj corre --------------------------------------------
	# Se mide aqui y no al final: cuando el enemigo muere la pelea termina y
	# el label se congela (que es lo correcto).
	if timer != null:
		_check(int(timer.text) < full,
			"the clock runs once the player has submitted (%d -> %s)" % [full, timer.text])

	# --- 5. acertar hace dano al enemigo Y cura al jugador ------------------
	editor.text = CORRECT
	terminal.call("_on_submit_pressed")
	var r3: Variant = await _wait_for_result()
	_check(r3 != null, "the correct solution produced a result")
	await get_tree().create_timer(1.2).timeout
	var healed: int = GameManager.get_hp("player")
	_check(GameManager.get_hp("enemy") < enemy_hp_start,
		"the correct solution hurts the enemy (%d -> %d)"
			% [enemy_hp_start, GameManager.get_hp("enemy")])
	_check(healed > after_error,
		"the correct solution heals the player (%d -> %d)" % [after_error, healed])

	_finish()


func _wait_for_result() -> Variant:
	var waited: int = 0
	while _results.is_empty() and waited < 200:
		await get_tree().create_timer(0.1, true).timeout
		waited += 1
	if _results.is_empty():
		return null
	return _results.pop_front()


func _wait_for_phase(battle: Node, phase: int) -> void:
	var waited: int = 0
	while int(battle.get("_phase")) != phase and waited < 200:
		await get_tree().create_timer(0.1, true).timeout
		waited += 1


func _finish() -> void:
	print("\n========== BATTLE ECONOMY GUARD ==========")
	for p in _passed:
		print("  PASS: ", p)
	for f in _failed:
		print("  FAIL: ", f)
	print("PASSED: %d | FAILED: %d" % [_passed.size(), _failed.size()])
	get_tree().quit(1 if _failed.size() > 0 else 0)
