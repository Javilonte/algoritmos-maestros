extends Node

enum GameState { BOOT, OVERWORLD, TERMINAL, BATTLE, PAUSED }

var current_state: GameState = GameState.BOOT
var current_challenge_id: String = ""

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
