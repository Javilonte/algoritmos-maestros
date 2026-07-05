extends Node

signal player_spawned(player: Node2D)
signal player_despawned(player: Node2D)
signal terminal_toggled(is_open: bool)
signal code_submitted(challenge_id: String, code: String)
signal code_validated(challenge_id: String, success: bool, message: String)
signal scene_change_requested(path: String)
signal battle_requested(enemy_data: Dictionary)
signal battle_started(enemy_data: Dictionary)
signal battle_ended(result: String)
signal hp_changed(side: String, current: int, max_hp: int)
signal turn_changed(is_player_turn: bool)

signal compiling_started(challenge_id: String)
signal compiling_progress(stage: String, ratio: float)
signal compiling_finished(success: bool, message: String)
signal code_executed(result)
signal damage_calculated(roll)
signal combo_changed(combo: int, multiplier: float)
signal battle_timer_tick(remaining_ms: int)
signal battle_timer_expired()

signal dialogue_requested(npc_id: String, data: DialogueData)
signal dialogue_ended(npc_id: String)
signal skill_unlocked(skill_id: StringName)
signal damage_dealt(amount: int, hp_after: int)

func emit_terminal_toggled(is_open: bool) -> void:
	terminal_toggled.emit(is_open)
