extends Node

signal code_submitted(challenge_id: String, code: String)
signal code_validated(challenge_id: String, success: bool, message: String)
signal battle_requested(enemy_data: Dictionary)
signal battle_started(enemy_data: Dictionary)
signal battle_ended(result: String)
signal hp_changed(side: String, current: int, max_hp: int)
signal dialogue_requested(npc_id: String, data: DialogueData)
signal dialogue_ended(npc_id: String)
signal skill_unlocked(skill_id: StringName)
signal damage_dealt(amount: int, hp_after: int)
