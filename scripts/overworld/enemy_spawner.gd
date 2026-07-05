extends Node2D

## Spawner de enemigos en el overworld.
## - Usa enemy_configs (Array[EnemyData]) si hay configs asignados en el editor.
## - Si no, consulta EnemyCatalog filtrado por SkillTree.get_unlocked_enemies().
## - Los enemigos no desbloqueados aparecen como silhouette (modulate reducido).

@export var enemy_scene: PackedScene
@export var spawn_points: Array[Vector2] = [
	Vector2(400, 0),
	Vector2(-400, 0),
]
@export var enemy_configs: Array[EnemyData] = []

## Configuraciones por defecto si no se asignan en el editor.
var _default_configs: Array[Dictionary] = [
	{
		"display_name": "Slime Aritmético",
		"max_hp": 60,
		"challenge_id": "slime_aritm",
		"enemy_id": "slime_aritm",
		"xp_reward": 50,
	},
	{
		"display_name": "Buggo Ciego",
		"max_hp": 80,
		"challenge_id": "buggo_ciego",
		"enemy_id": "buggo_ciego",
		"xp_reward": 80,
	},
]

var _skill_tree: SkillTreeData

func _ready() -> void:
	_skill_tree = get_node_or_null("/root/SkillTree") as SkillTreeData
	if enemy_scene == null:
		push_error("EnemySpawner: enemy_scene is not assigned.")
		return
	for i in spawn_points.size():
		var enemy: Enemy = enemy_scene.instantiate() as Enemy
		if enemy == null:
			push_error("EnemySpawner: enemy_scene root is not an Enemy.")
			continue
		enemy.position = spawn_points[i]
		var data := _resolve_config(i)
		if data != null:
			enemy.apply_data(data)
			_apply_lock_state(enemy, String(data.challenge_id))
		add_child(enemy)

func _resolve_config(index: int) -> EnemyData:
	if index < enemy_configs.size() and enemy_configs[index] != null:
		return enemy_configs[index]
	var dict: Dictionary = _default_configs[index] if index < _default_configs.size() else _default_configs[0]
	return EnemyData.create(
		String(dict.get("display_name", "Unknown")),
		int(dict.get("max_hp", 100)),
		String(dict.get("challenge_id", "main_exit_check")),
		null,
		String(dict.get("enemy_id", "")),
		int(dict.get("xp_reward", 50))
	)

func _apply_lock_state(enemy: Enemy, _enemy_id: String) -> void:
	if _skill_tree == null:
		return
	# Por ahora todo enemigo en spawn_points default esta desbloqueado
	# (vienen del root_arithmetic). El sistema esta preparado para
	# que en fases futuras el spawner consulte _skill_tree.get_unlocked_enemies().
	var unlocked: PackedStringArray = _skill_tree.get_unlocked_enemies()
	# Si el enemy_id aparece en unlocked, modulate normal. Si no, silhouette.
	if enemy.enemy_id.is_empty() or enemy.enemy_id in unlocked:
		enemy.modulate = Color(1, 1, 1, 1)
	else:
		enemy.modulate = Color(0.3, 0.3, 0.3, 0.5)
		enemy.set_deferred("monitoring", false)
