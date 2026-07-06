extends Node

const _GameStateMachineScript := preload("res://scripts/autoload/game_state_machine.gd")
const _CombatStatsScript := preload("res://scripts/autoload/combat_stats.gd")

enum GameState { BOOT, MAIN_MENU, OVERWORLD, TERMINAL, BATTLE, COMPILING, EXECUTING, DIALOGUE }

const PLAYER_MAX_HP: int = 100

const COMBO_DECAY_MS: int = 10000
const MAX_COMBO: int = 5

var current_challenge_id: String = ""
var current_enemy_data: Dictionary = {}

var player_hp: int:
	get:
		return _player_stats.hp
var player_max_hp: int:
	get:
		return _player_stats.max_hp
var enemy_hp: int:
	get:
		return _enemy_stats.hp
var enemy_max_hp: int:
	get:
		return _enemy_stats.max_hp

var _fsm: RefCounted = _GameStateMachineScript.new(GameState.BOOT)
var _player_stats: RefCounted = _CombatStatsScript.new(PLAYER_MAX_HP)
var _enemy_stats: RefCounted = _CombatStatsScript.new(0)

var _combo_count: int = 0
var _combo_decay_timer: SceneTreeTimer = null

func change_state(new_state: GameState) -> void:
	_fsm.change_state(new_state)

func _ready() -> void:
	EventBus.skill_unlocked.connect(_on_skill_unlocked)
	EventBus.battle_ended.connect(_on_battle_ended)
	get_tree().set_auto_accept_quit(false)
	get_tree().root.close_requested.connect(_on_app_close_requested)

func _on_skill_unlocked(_skill_id: StringName) -> void:
	SaveManager.save_game(get_save_data())

func _on_battle_ended(_result: String) -> void:
	SaveManager.save_game(get_save_data())

func _on_app_close_requested() -> void:
	SaveManager.save_game(get_save_data())
	get_tree().quit()

func is_state(state: GameState) -> bool:
	return _fsm.is_state(state)

func is_player_input_allowed() -> bool:
	return _fsm.is_state(GameState.OVERWORLD)

func get_hp(side: String) -> int:
	return _enemy_stats.hp if side == "enemy" else _player_stats.hp

func start_battle(enemy_data: Dictionary) -> void:
	current_enemy_data = enemy_data
	_enemy_stats.reset_to(int(enemy_data.get("max_hp", 100)))
	_player_stats.hp = _player_stats.max_hp
	_fsm.change_state(GameState.BATTLE)
	EventBus.hp_changed.emit("player", _player_stats.hp, _player_stats.max_hp)
	EventBus.hp_changed.emit("enemy", _enemy_stats.hp, _enemy_stats.max_hp)
	EventBus.turn_changed.emit(true)
	_combo_count = 0
	EventBus.combo_changed.emit(0, 1.0)

func apply_damage(side: String, amount: int) -> void:
	if side == "enemy":
		_enemy_stats.apply_damage(amount)
		EventBus.hp_changed.emit("enemy", _enemy_stats.hp, _enemy_stats.max_hp)
	elif side == "player":
		_player_stats.apply_damage(amount)
		EventBus.hp_changed.emit("player", _player_stats.hp, _player_stats.max_hp)

func reset_battle_state() -> void:
	_player_stats.hp = _player_stats.max_hp
	_enemy_stats.reset_to(0)
	current_enemy_data = {}
	_combo_count = 0

func reset_to_new_game() -> void:
	_player_stats.set_max(PLAYER_MAX_HP)
	_enemy_stats.reset_to(0)
	current_enemy_data = {}
	current_challenge_id = ""
	_fsm.change_state(GameState.BOOT)
	_combo_count = 0

func get_save_data() -> Dictionary:
	var skill_tree_data: Dictionary = {}
	var st := get_node_or_null("/root/SkillTree")
	if st and st.has_method("save_state"):
		skill_tree_data = st.save_state()
	return {
		"player_hp": _player_stats.hp,
		"player_max_hp": _player_stats.max_hp,
		"skill_tree": skill_tree_data,
		"save_version": 1,
	}

func apply_save_data(data: Dictionary) -> void:
	_player_stats.hp = int(data.get("player_hp", PLAYER_MAX_HP))
	_player_stats.max_hp = int(data.get("player_max_hp", PLAYER_MAX_HP))
	if data.has("skill_tree"):
		var st := get_node_or_null("/root/SkillTree")
		if st and st.has_method("load_state"):
			var raw: Variant = data["skill_tree"]
			if raw is Dictionary:
				st.load_state(raw)

func get_combo_count() -> int:
	return _combo_count

func get_combo_multiplier() -> float:
	return 1.0 + min(_combo_count, MAX_COMBO) * 0.2

func increment_combo() -> void:
	_combo_count += 1
	EventBus.combo_changed.emit(_combo_count, get_combo_multiplier())
	_reset_combo_decay()

func reset_combo() -> void:
	if _combo_count > 0:
		_combo_count = 0
		EventBus.combo_changed.emit(0, 1.0)

func _reset_combo_decay() -> void:
	_combo_decay_timer = get_tree().create_timer(COMBO_DECAY_MS / 1000.0)
	_combo_decay_timer.timeout.connect(_on_combo_decay)

func _on_combo_decay() -> void:
	if _combo_count > 0:
		_combo_count = 0
		EventBus.combo_changed.emit(0, 1.0)
