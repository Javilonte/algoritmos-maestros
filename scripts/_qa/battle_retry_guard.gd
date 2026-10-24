extends Node

## Guard for the lose -> retry/run flow in scripts/battle/battle.gd.
## Run: godot --headless scenes/qa/battle_retry_guard.tscn --quit-after 250
##
## ponytail: battle.gd had zero test coverage and its retry handler never
## restored HP, so losing was an unwinnable loop. This pins the two prices
## the mechanic charges: retry costs the combo, fleeing costs a respawn
## wait. Scene-mounted rather than `-s` because autoload identifiers do
## not resolve in --headless script mode in this project.

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const ENEMY_SCENE := "res://scenes/overworld/enemy.tscn"

var _passed: Array = []
var _failed: Array = []


func _ready() -> void:
	_run()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed.append(label)
	else:
		_failed.append(label)


func _run() -> void:
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
	enemy.set("challenge_id", "bubble_sort")
	enemy.set("respawn_time", 30.0)

	var battle := battle_scene.instantiate()
	add_child(battle)

	var data := EnemyData.create("Guard Slime", 80, "bubble_sort", enemy, "slime_aritm", 25)
	_check(data.challenge != null, "EnemyData.create resolves the challenge from the registry")
	var battle_data := data.to_dict()
	battle.set("_enemy_data", battle_data)
	GameManager.start_battle(battle_data)

	# Lose: drain BOTH sides, then confirm the retry price is only the combo.
	# Draining the enemy matters — asserting a restore without damaging
	# first passes vacuously.
	GameManager.apply_damage("player", 9999)
	GameManager.apply_damage("enemy", 60)
	_check(GameManager.get_hp("player") == 0, "player HP can reach 0")
	_check(GameManager.get_hp("enemy") < GameManager.enemy_max_hp,
		"enemy HP can drop below max before the retry")
	GameManager.increment_combo()
	GameManager.increment_combo()
	_check(GameManager.get_combo_count() == 2, "combo builds before the loss")

	battle.call("_on_game_over_retry")

	_check(GameManager.get_hp("player") == GameManager.player_max_hp,
		"retry restores the player to full HP")
	_check(GameManager.get_hp("enemy") == GameManager.enemy_max_hp,
		"retry restores the enemy to full HP from a damaged state")
	_check(GameManager.get_combo_count() == 0,
		"retry costs the combo streak")
	_check(int(battle.get("_phase")) == int(Battle.BattlePhase.EDITING),
		"retry returns the battle to the EDITING phase")
	_check(bool(battle.get("visible")), "retry shows the battle again")

	# A retried fight must be winnable: one enemy turn must not re-lose it.
	GameManager.apply_damage("player", 12)
	_check(GameManager.get_hp("player") > 0,
		"an enemy turn after retry no longer kills an already-losing player")

	# Fleeing price: the enemy is defeated and stays gone for its timer.
	battle.call("_on_game_over_run")
	_check(not enemy.visible, "fleeing defeats the enemy so it vanishes")
	_check(bool(enemy.get("_is_defeated")), "fleeing leaves the enemy flagged defeated")
	_check(float(enemy.get("respawn_time")) == 30.0,
		"fleeing uses the enemy's own respawn timer")
	_check(not get_tree().paused, "fleeing unpauses the tree so the player can move")

	# The GameOver prices only reach the screen if Battle adds the node to the
	# tree BEFORE calling setup(). Regression pin for the silent no-op where
	# setup() aborted on a nil @onready and reported success anyway.
	battle.call("_show_game_over")
	await get_tree().process_frame
	var arena: Node = battle.get_node_or_null("BattleArena")
	var go: Node = arena.get_node_or_null("GameOver") if arena != null else null
	_check(go != null, "show_game_over adds the GameOver screen to the battle")
	if go != null:
		# ponytail: el contenido de la pantalla de derrota vive dentro de
		# un PanelContainer (antes flotaba como texto suelto sobre el
		# dim). El path cambio; el guard tiene que seguirlo.
		var subtitle: Label = go.get_node_or_null("CenterContainer/Panel/VBox/Subtitle")
		var run_button: Button = go.get_node_or_null("CenterContainer/Panel/VBox/ButtonRow/RunButton")
		_check(subtitle != null and subtitle.text.contains("Guard Slime"),
			"GameOver subtitle names the enemy (setup ran after add_child)")
		_check(subtitle != null and subtitle.text.contains("combo"),
			"GameOver subtitle states the retry cost")
		_check(run_button != null and run_button.text.contains("30s"),
			"GameOver run button states the real respawn seconds")

	_finish()


func _finish() -> void:
	print("\n========== BATTLE RETRY GUARD ==========")
	for p in _passed:
		print("  PASS: ", p)
	for f in _failed:
		print("  FAIL: ", f)
	print("=======================================")
	print("PASSED: %d | FAILED: %d" % [_passed.size(), _failed.size()])
	get_tree().quit(1 if _failed.size() > 0 else 0)