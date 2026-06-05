extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_points: Array[Vector2] = [
	Vector2(400, 0),
	Vector2(-400, 0),
]
@export var enemy_data_list: Array[Dictionary] = [
	{"display_name": "Segfault Sprite", "max_hp": 100, "challenge_id": "main_exit_check"},
	{"display_name": "Null Pointer", "max_hp": 150, "challenge_id": "main_exit_check"},
]

func _ready() -> void:
	if enemy_scene == null:
		push_error("EnemySpawner: enemy_scene is not assigned.")
		return
	for i in spawn_points.size():
		var enemy: Enemy = enemy_scene.instantiate() as Enemy
		if enemy == null:
			push_error("EnemySpawner: enemy_scene root is not an Enemy.")
			continue
		enemy.position = spawn_points[i]
		var data: Dictionary = enemy_data_list[i] if i < enemy_data_list.size() else enemy_data_list[0]
		enemy.display_name = String(data.get("display_name", "Unknown"))
		enemy.max_hp = int(data.get("max_hp", 100))
		enemy.challenge_id = String(data.get("challenge_id", "main_exit_check"))
		add_child(enemy)
