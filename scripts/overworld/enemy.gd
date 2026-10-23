extends Area2D
class_name Enemy

## Enemigo del overworld. Datos consumidos desde un EnemyData resource
## (configurado por el spawner). Mantiene exports como fallback para
## escenas que no usen EnemyData.

@export var display_name: String = "Bug Monster"
@export var max_hp: int = 100
@export var challenge_id: String = "main_exit_check"
@export var respawn_time: float = 30.0
@export var enemy_id: String = ""  # id del EnemyCatalog, opcional

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _is_defeated: bool = false
var _respawn_timer: SceneTreeTimer = null

func _ready() -> void:
	add_to_group("enemies")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _is_defeated:
		return
	if not body.is_in_group("player"):
		return
	var data := EnemyData.create(display_name, max_hp, challenge_id, self, enemy_id)
	EventBus.battle_requested.emit(data.to_dict())

## Aplica los datos de un EnemyData (llamado por el spawner).
func apply_data(data: EnemyData) -> void:
	if data == null:
		return
	display_name = data.display_name
	max_hp = data.max_hp
	challenge_id = data.challenge_id
	respawn_time = data.respawn_time
	if data.node:
		enemy_id = String(data.node.name)

## Desactiva al enemigo e inicia el timer de respawn.
func defeat() -> void:
	_is_defeated = true
	visible = false
	set_deferred("monitoring", false)
	_respawn_timer = get_tree().create_timer(respawn_time)
	_respawn_timer.timeout.connect(respawn)

## Reaparece el enemigo y reactiva la colisión.
func respawn() -> void:
	_is_defeated = false
	visible = true
	monitoring = true
	_respawn_timer = null
