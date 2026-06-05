extends Area2D
class_name Enemy

@export var display_name: String = "Bug Monster"
@export var max_hp: int = 100
@export var challenge_id: String = "main_exit_check"
@export var respawn_time: float = 30.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _is_defeated: bool = false

func _ready() -> void:
	add_to_group("enemies")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _is_defeated:
		return
	if not (body.is_in_group("player") or body.name == "Player"):
		return
	var enemy_data: Dictionary = {
		"display_name": display_name,
		"max_hp": max_hp,
		"challenge_id": challenge_id,
		"node": self,
	}
	EventBus.battle_requested.emit(enemy_data)

func defeat() -> void:
	_is_defeated = true
	visible = false
	set_deferred("monitoring", false)
	var timer := get_tree().create_timer(respawn_time)
	timer.timeout.connect(respawn)

func respawn() -> void:
	_is_defeated = false
	visible = true
	monitoring = true
