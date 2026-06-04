extends Node

signal player_spawned(player: Node2D)
signal player_despawned(player: Node2D)
signal terminal_toggled(is_open: bool)
signal code_submitted(challenge_id: String, code: String)
signal code_validated(challenge_id: String, success: bool, message: String)
signal scene_change_requested(path: String)

func emit_terminal_toggled(is_open: bool) -> void:
	terminal_toggled.emit(is_open)
