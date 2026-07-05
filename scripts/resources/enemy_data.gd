class_name EnemyData
extends Resource

## Datos tipados de un enemigo para el sistema de batalla.
## Reemplaza el uso de Dictionary crudo para mayor type-safety.

@export var display_name: String = "Bug Monster"
@export var max_hp: int = 100
@export var challenge_id: String = "main_exit_check"
@export var respawn_time: float = 30.0
@export var xp_reward: int = 50
@export var enemy_id: String = ""

## Referencia al nodo Enemy en el mundo (no se serializa).
var node: Enemy = null

## Challenge tipado resuelto desde ChallengeRegistry.
var challenge: ChallengeData = null

static func create(
	p_display_name: String,
	p_max_hp: int,
	p_challenge_id: String,
	p_node: Enemy = null,
	p_enemy_id: String = "",
	p_xp_reward: int = -1
) -> EnemyData:
	var data := EnemyData.new()
	data.display_name = p_display_name
	data.max_hp = p_max_hp
	data.challenge_id = p_challenge_id
	data.node = p_node
	data.enemy_id = p_enemy_id
	if p_xp_reward >= 0:
		data.xp_reward = p_xp_reward
	data.challenge = ChallengeRegistry.fetch(StringName(p_challenge_id))
	return data

## Convierte a Dictionary para uso legacy (se mantiene por compatibilidad).
func to_dict() -> Dictionary:
	var out := {
		"display_name": display_name,
		"max_hp": max_hp,
		"challenge_id": challenge_id,
		"xp_reward": xp_reward,
		"enemy_id": enemy_id,
		"node": node,
		"stdin": "",
		"expected_output": "",
		"time_limit_sec": 2.0,
		"memory_limit_kb": 128000,
		"base_score": 0,
		"hint_lines": [],
		"challenge_prompt": "",
	}
	if challenge != null:
		out["stdin"] = challenge.stdin
		out["expected_output"] = challenge.expected_output
		out["time_limit_sec"] = challenge.time_limit_sec
		out["memory_limit_kb"] = challenge.memory_limit_kb
		out["base_score"] = challenge.base_score
		out["hint_lines"] = Array(challenge.hint_lines)
		out["challenge_prompt"] = challenge.prompt
	return out

static func from_dict(data: Dictionary) -> EnemyData:
	var e := EnemyData.new()
	e.display_name = String(data.get("display_name", "Unknown"))
	e.max_hp = int(data.get("max_hp", 100))
	e.challenge_id = String(data.get("challenge_id", "main_exit_check"))
	e.xp_reward = int(data.get("xp_reward", 50))
	e.enemy_id = String(data.get("enemy_id", ""))
	var node_ref: Variant = data.get("node")
	if node_ref is Enemy:
		e.node = node_ref as Enemy
	e.challenge = ChallengeRegistry.fetch(StringName(e.challenge_id))
	return e
