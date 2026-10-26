extends Node

## Guard end-to-end de la pelea: el codigo del JUGADOR se compila, corre y
## le hace dano al enemigo. Run: godot --headless scenes/qa/battle_sandbox_guard.tscn --quit-after 900
##
## ponytail: hasta ahora la pelea evaluaba la solucion de referencia del
## runner. Este guard cierra el circuito: escribe una solucion en el
## editor, la manda y comprueba que el enemigo pierde HP de verdad.

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const ENEMY_SCENE := "res://scenes/overworld/enemy.tscn"

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

# La estructura correcta y el algoritmo equivocado: el gate de forma
# pasa, compila y los tests fallan. Un "return 0" solo probaria el gate.
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

# La solucion canonica del hash_map (el challenge del Memory Leak).
const HASH_MAP_SOLUTION := """#include <unordered_map>

int countUnique(vector<int> arr) {
    std::unordered_map<int, int> seen;
    for (int v : arr) {
        seen[v] = 1;
    }
    return (int)seen.size();
}"""

var _passed: Array = []
var _failed: Array = []
var _last_result: Variant = null


func _ready() -> void:
	EventBus.code_executed.connect(_on_code_executed)
	_run()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed.append(label)
	else:
		_failed.append(label)


func _on_code_executed(result) -> void:
	_last_result = result


## Arranca una pelea y devuelve el nodo de la batalla.
func _start_battle(enemy_id: String, display_name: String, hp: int,
		challenge_id: String) -> Node:
	var enemy_scene: PackedScene = load(ENEMY_SCENE)
	var battle_scene: PackedScene = load(BATTLE_SCENE)
	if enemy_scene == null or battle_scene == null:
		_failed.append("could not load battle or enemy scene")
		return null
	var enemy := enemy_scene.instantiate()
	add_child(enemy)
	enemy.set("display_name", display_name)
	enemy.set("max_hp", hp)
	enemy.set("challenge_id", challenge_id)
	enemy.set("respawn_time", 30.0)
	var battle := battle_scene.instantiate()
	add_child(battle)
	var data := EnemyData.create(display_name, hp, challenge_id, enemy, enemy_id, -1)
	battle.set("_enemy_data", data.to_dict())
	# ponytail: la batalla arranca con el EVENTO, no con
	# GameManager.start_battle: el challenge lo resuelve el battle a partir
	# del enemy_data. Sin esto el editor se abria con su challenge por
	# defecto (bubble_sort) y el AST buscaba la funcion equivocada.
	EventBus.battle_requested.emit(data.to_dict())
	await _wait_for_phase(battle, Battle.BattlePhase.EDITING)
	return battle


func _run() -> void:
	if CppSandbox.new().find_compiler().is_empty():
		print("SKIP: no C++ compiler on this machine")
		_finish()
		return

	var battle: Node = await _start_battle("slime_aritm", "Guard Slime", 80, "simple_dp")
	if battle == null:
		_finish()
		return

	var terminal := battle.get_node_or_null("BattleTerminal")
	_check(terminal != null, "the battle has its code editor")
	if terminal == null:
		_finish()
		return
	var editor: CodeEdit = terminal.get_node("Panel/CodeEdit")
	_check(editor != null, "the editor exposes the code area")
	if editor == null:
		_finish()
		return
	# abrir el editor: asi el challenge es el del enemigo, no el de por defecto
	battle.call("_on_attack_pressed")
	await get_tree().process_frame
	_check(String(terminal.get("_challenge_id")) == "simple_dp",
		"the editor opened with the enemy's challenge (%s)" % String(terminal.get("_challenge_id")))

	# --- 0. el checklist en vivo ---------------------------------------------
	# El checklist lee el AST, y el AST viene de clang en un proceso aparte:
	# el refresh es una corrutina. Si ese camino se rompe, el jugador deja
	# de ver que le falta y solo se entera al submitir.
	var contract: RichTextLabel = terminal.get_node_or_null("Panel/Contract/ContractText")
	_check(contract != null, "the battle shows the contract")
	if contract != null:
		# el debounce son 0.25 s y clang tarda ~100 ms: hay que esperar.
		await get_tree().create_timer(1.2).timeout
		var text: String = contract.text
		_check(text.contains("REQUIERE"),
			"the contract lists what the challenge requires")
		_check(text.contains("bucle"),
			"the checklist names the missing structure in the player's language")
		# con el starter code (que no tiene bucle) el tick del bucle va vacio
		_check(not text.contains("✓ un bucle"),
			"the starter code does not tick the loop it does not have")
		_check(text.contains("PRÁCTICA"),
			"the contract says what the fight practices")
		_check(text.contains("Recursión"),
			"the contract names the concept (Recursión)")

	# el enemigo tambien lo dice: "Lv 6 · Recursión"
	var portrait: Node = battle.get_node_or_null("BattleArena/PortraitsRow/EnemyPortrait")
	_check(portrait != null, "the battle has the enemy portrait")
	if portrait != null:
		_check(String(portrait.get("practice_concept")) == "Recursión",
			"the enemy names the concept it practices (%s)"
				% String(portrait.get("practice_concept")))

	# --- 1. la solucion correcta le hace dano al enemigo ---------------------
	var hp_before: int = GameManager.get_hp("enemy")
	editor.text = CORRECT
	terminal.call("_on_submit_pressed")
	var result: Variant = await _wait_for_result()
	_check(result != null, "the battle produced a result")
	if result != null:
		_check(bool(result.success),
			"the player's correct solution wins the challenge")
		_check(int(result.passed) == int(result.total),
			"every case passed (%d/%d)" % [int(result.passed), int(result.total)])
	await get_tree().create_timer(0.8).timeout
	_check(GameManager.get_hp("enemy") < hp_before,
		"the enemy loses HP: %d -> %d" % [hp_before, GameManager.get_hp("enemy")])

	# --- 2. una solucion incorrecta no le hace dano --------------------------
	# La pelea sigue viva: se vuelve a pedir el mismo enemigo (el dato de
	# la pelea sigue en el nodo) y se manda otra solucion.
	GameManager.reset_battle_state()
	battle.call("_on_attack_pressed")
	await get_tree().process_frame
	hp_before = GameManager.get_hp("enemy")
	editor.text = WRONG
	terminal.call("_on_submit_pressed")
	var bad: Variant = await _wait_for_result()
	_check(bad != null, "the wrong solution produced a result")
	if bad != null:
		_check(not bool(bad.success),
			"the wrong solution loses the challenge")
		var errors: Array = bad.errors
		_check(errors.size() > 0 and String(errors[0]).contains("expected"),
			"the failure says what was expected (%s)" % str(errors))
	await get_tree().create_timer(0.8).timeout
	_check(GameManager.get_hp("enemy") == hp_before,
		"a wrong solution does not damage the enemy")

	# La primera pelea sigue viva (el turno del jugador sigue abierto) y
	# escucharia el mismo evento: se la libera antes de la del jefe.
	battle.queue_free()
	await get_tree().process_frame

	# --- 3. la pelea de jefe --------------------------------------------------
	# El Memory Leak es el primer jefe de capitulo y su pelea nunca se habia
	# fighteado: 250 de vida, el banner del jefe y otro challenge.
	var boss: Node = await _start_battle("memory_leak", "Jefe: Memory Leak", 250, "hash_map")
	if boss != null:
		var banner_found: bool = false
		var arena := boss.get_node_or_null("BattleArena")
		if arena != null:
			for child in arena.get_children():
				if child.has_method("show_banner"):
					banner_found = true
		_check(banner_found, "the boss fight shows the BOSS ENCOUNTER banner")

		var boss_terminal := boss.get_node_or_null("BattleTerminal")
		var boss_editor: CodeEdit = boss_terminal.get_node("Panel/CodeEdit") if boss_terminal != null else null
		_check(boss_editor != null, "the boss fight has a code editor")
		if boss_editor != null:
			boss.call("_on_attack_pressed")
			await get_tree().process_frame
			var boss_hp_before: int = GameManager.get_hp("enemy")
			boss_editor.text = HASH_MAP_SOLUTION
			boss_terminal.call("_on_submit_pressed")
			var boss_result: Variant = await _wait_for_result()
			_check(boss_result != null and bool(boss_result.success),
				"the correct solution defeats the boss")
			await get_tree().create_timer(0.8).timeout
			_check(GameManager.get_hp("enemy") < boss_hp_before,
				"the boss loses HP: %d -> %d" % [boss_hp_before, GameManager.get_hp("enemy")])

	_finish()


## Espera a que la pelea llegue a una fase.
func _wait_for_phase(battle: Node, phase: int) -> void:
	for i in 300:
		await get_tree().process_frame
		if int(battle.get("_phase")) == phase:
			return


## Espera el resultado del proximo code_executed.
func _wait_for_result() -> Variant:
	for i in 900:
		await get_tree().process_frame
		if _last_result != null:
			var r: Variant = _last_result
			_last_result = null
			return r
	return null


func _finish() -> void:
	print("\n========== BATTLE SANDBOX GUARD ==========")
	for p in _passed:
		print("  PASS: ", p)
	for f in _failed:
		print("  FAIL: ", f)
	print("PASSED: %d | FAILED: %d" % [_passed.size(), _failed.size()])
	get_tree().quit(1 if _failed.size() > 0 else 0)
