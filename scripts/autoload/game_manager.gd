extends Node

const GameStateMachine = preload("res://scripts/autoload/game_state_machine.gd")
const CombatStats = preload("res://scripts/autoload/combat_stats.gd")

enum GameState { BOOT, MAIN_MENU, OVERWORLD, TERMINAL, BATTLE }

const PLAYER_MAX_HP: int = 100

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

var _fsm := GameStateMachine.new(GameState.BOOT)
var _player_stats := CombatStats.new(PLAYER_MAX_HP)
var _enemy_stats := CombatStats.new(0)

func change_state(new_state: GameState) -> void:
	_fsm.change_state(new_state)

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

func reset_to_new_game() -> void:
	_player_stats.set_max(PLAYER_MAX_HP)
	_enemy_stats.reset_to(0)
	current_enemy_data = {}
	current_challenge_id = ""
	_fsm.change_state(GameState.BOOT)

func get_save_data() -> Dictionary:
	return {
		"player_hp": _player_stats.hp,
		"player_max_hp": _player_stats.max_hp,
	}

func apply_save_data(data: Dictionary) -> void:
	_player_stats.hp = int(data.get("player_hp", PLAYER_MAX_HP))
	_player_stats.max_hp = int(data.get("player_max_hp", PLAYER_MAX_HP))
