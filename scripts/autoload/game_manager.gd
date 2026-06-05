extends Node

enum GameState { BOOT, OVERWORLD, TERMINAL, BATTLE, PAUSED }

const PLAYER_MAX_HP: int = 100

var current_state: GameState = GameState.BOOT
var current_challenge_id: String = ""

var player_max_hp: int = PLAYER_MAX_HP
var player_hp: int = PLAYER_MAX_HP
var enemy_max_hp: int = 0
var enemy_hp: int = 0
var current_enemy_data: Dictionary = {}

func change_state(new_state: GameState) -> void:
	if new_state == current_state:
		return
	current_state = new_state

func is_state(state: GameState) -> bool:
	return current_state == state

func is_player_input_allowed() -> bool:
	return current_state == GameState.OVERWORLD

func set_challenge(challenge_id: String) -> void:
	current_challenge_id = challenge_id

func clear_challenge() -> void:
	current_challenge_id = ""

func start_battle(enemy_data: Dictionary) -> void:
	current_enemy_data = enemy_data
	enemy_max_hp = int(enemy_data.get("max_hp", 100))
	enemy_hp = enemy_max_hp
	player_hp = player_max_hp
	current_state = GameState.BATTLE
	EventBus.hp_changed.emit("player", player_hp, player_max_hp)
	EventBus.hp_changed.emit("enemy", enemy_hp, enemy_max_hp)
	EventBus.turn_changed.emit(true)

func apply_damage(side: String, amount: int) -> void:
	if side == "enemy":
		enemy_hp = max(0, enemy_hp - amount)
		EventBus.hp_changed.emit("enemy", enemy_hp, enemy_max_hp)
	elif side == "player":
		player_hp = max(0, player_hp - amount)
		EventBus.hp_changed.emit("player", player_hp, player_max_hp)

func reset_battle_state() -> void:
	player_hp = player_max_hp
	enemy_hp = 0
	enemy_max_hp = 0
	current_enemy_data = {}
