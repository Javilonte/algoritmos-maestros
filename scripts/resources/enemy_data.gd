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
## ponytail: Node, not Enemy. Three unrelated enemy classes exist (Enemy,
## IsoEnemy, CrowEnemy) and all three are consumed polymorphically via
## has_method("defeat"); typing this as Enemy made EnemyData.create()
## unusable from the ISO enemies and made from_dict() silently drop their
## nodes. Widening accepts strictly more, so existing callers still fit.
var node: Node = null

## Challenge tipado resuelto desde ChallengeRegistry.
var challenge: ChallengeResource = null

static func create(
	p_display_name: String,
	p_max_hp: int,
	p_challenge_id: String,
	p_node: Node = null,
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
	data.challenge = ChallengeRegistry.get_by_id(p_challenge_id)
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
	# ponytail: only prompt and the time limit have a real source on
	# ChallengeResource. The old block also read stdin / expected_output /
	# memory_limit_kb / base_score / hint_lines, which exist solely on the
	# stale ChallengeData twin — it crashed here on every battle request.
	# Those 5 keys keep their literal defaults because nothing in scripts/
	# reads them (CodeCompiler and TestRunner consume the typed resource
	# directly). Ceiling: if a consumer ever needs stdin/expected_output,
	# map them from challenge.test_cases[0].inputs / .expected here.
	if challenge != null:
		out["challenge_prompt"] = challenge.prompt
		out["time_limit_sec"] = float(challenge.time_limit_ms) / 1000.0
	return out

static func from_dict(data: Dictionary) -> EnemyData:
	var e := EnemyData.new()
	e.display_name = String(data.get("display_name", "Unknown"))
	e.max_hp = int(data.get("max_hp", 100))
	e.challenge_id = String(data.get("challenge_id", "main_exit_check"))
	e.xp_reward = int(data.get("xp_reward", 50))
	e.enemy_id = String(data.get("enemy_id", ""))
	var node_ref: Variant = data.get("node")
	if node_ref is Node:
		e.node = node_ref as Node
	e.challenge = ChallengeRegistry.get_by_id(e.challenge_id)
	return e
